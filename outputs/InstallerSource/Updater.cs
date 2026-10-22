// Original Together launcher/updater. MIT. C# 5 / .NET Framework 4.8.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace TogetherSetup {
    internal sealed class UpdateManifest {
        public int schema;
        public string repository, version, asset, sha256, installer_sha256, issued_utc, expires_utc;
        public long size;
    }
    internal static class UpdatePolicy {
        public const string Repository="Krosoviblyat/BalatroTogether";
        public const long MaxPackage=512L*1024*1024;
        public static readonly UTF8Encoding Utf8=new UTF8Encoding(false,true);
        public static Version Number(string text) {
            var m=Regex.Match(text??"",@"^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-(dev|alpha|beta|rc)(?:\.(0|[1-9][0-9]*))?)?$");
            if(!m.Success)throw new Exception("Unrecognized update version.");
            // Stable sorts after prereleases; different prerelease stages remain ordered.
            int stage=m.Groups[4].Value=="dev"?0:m.Groups[4].Value=="alpha"?1:m.Groups[4].Value=="beta"?2:m.Groups[4].Value=="rc"?3:4;
            int serial=m.Groups[5].Success?Int32.Parse(m.Groups[5].Value,CultureInfo.InvariantCulture):0;
            if(serial>99999)throw new Exception("Update version is out of range.");
            return new Version(Int32.Parse(m.Groups[1].Value),Int32.Parse(m.Groups[2].Value),Int32.Parse(m.Groups[3].Value),stage*100000+serial);
        }
        public static UpdateManifest Verify(byte[] data,byte[] signature,string tag,DateTime now,string key) {
            if(data.Length==0||data.Length>65536||signature.Length>2048)throw new Exception("Invalid update metadata size.");
            using(var rsa=new RSACryptoServiceProvider()) {
                rsa.PersistKeyInCsp=false; rsa.FromXmlString(key);
                if(!rsa.VerifyData(data,CryptoConfig.MapNameToOID("SHA256"),signature))throw new Exception("Update signature is invalid. No files were installed.");
            }
            var m=new JavaScriptSerializer().Deserialize<UpdateManifest>(Utf8.GetString(data));
            if(m==null||(m.schema!=1&&m.schema!=2)||m.repository!=Repository||tag!="v"+m.version)throw new Exception("Update metadata does not match this release.");
            Number(m.version);
            string expected=m.schema==2?"BalatroTogether-Setup-"+m.version+".exe":"BalatroTogether-"+m.version+"-Easy-Installer.zip";
            if(m.asset!=expected||m.size<1||m.size>MaxPackage)throw new Exception("Invalid update package.");
            if(!Regex.IsMatch(m.sha256??"","^[a-f0-9]{64}$")||!Regex.IsMatch(m.installer_sha256??"","^[a-f0-9]{64}$"))throw new Exception("Invalid package hash.");
            if(m.schema==2&&m.sha256!=m.installer_sha256)throw new Exception("Standalone installer hashes do not match.");
            DateTime issued,expires;
            if(!DateTime.TryParseExact(m.issued_utc,"yyyy-MM-dd'T'HH:mm:ss'Z'",CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out issued)||
               !DateTime.TryParseExact(m.expires_utc,"yyyy-MM-dd'T'HH:mm:ss'Z'",CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out expires)||
               issued>now.AddMinutes(5)||expires<=now||expires<=issued||expires-issued>TimeSpan.FromDays(100))throw new Exception("Update metadata has expired or the PC clock is incorrect.");
            return m;
        }
        public static void VerifyPackage(string zip,UpdateManifest manifest) {
            if(new FileInfo(zip).Length!=manifest.size||Paths.Hash(zip)!=manifest.sha256)throw new Exception("The update download is incomplete or changed. No files were installed.");
        }
        public static string ExtractInstaller(string zip,string target,UpdateManifest manifest) {
            VerifyPackage(zip,manifest); Paths.NoLinks(target); Directory.CreateDirectory(target);
            using(var archive=ZipFile.OpenRead(zip)) {
                var entries=archive.Entries.Where(e=>e.FullName=="Install Balatro Together.exe").ToArray();
                if(entries.Length!=1||entries[0].Length<2||entries[0].Length>MaxPackage)throw new Exception("The update installer is missing or duplicated.");
                string exe=Path.Combine(target,"Install Balatro Together.exe");
                // Only this exact filename is extracted; archive paths are never trusted.
                using(var input=entries[0].Open()) using(var output=new FileStream(exe,FileMode.CreateNew)) {
                    byte[] buffer=new byte[65536];long total=0;int n;
                    while((n=input.Read(buffer,0,buffer.Length))>0){total+=n;if(total>entries[0].Length||total>MaxPackage)throw new Exception("The update installer exceeds its declared size.");output.Write(buffer,0,n);}
                    if(total!=entries[0].Length)throw new Exception("The update installer is incomplete.");
                }
                if(Paths.Hash(exe)!=manifest.installer_sha256)throw new Exception("The update installer failed verification.");
                return exe;
            }
        }
        public static string PrepareInstaller(string package,string target,UpdateManifest manifest) {
            if(manifest.schema==1)return ExtractInstaller(package,target,manifest);
            if(manifest.schema!=2)throw new Exception("Unknown update format.");
            VerifyPackage(package,manifest);Paths.NoLinks(target);Directory.CreateDirectory(target);
            string exe=Path.Combine(target,"Install Balatro Together.exe");File.Copy(package,exe,false);
            if(Paths.Hash(exe)!=manifest.installer_sha256)throw new Exception("The update installer failed verification.");
            return exe;
        }
    }
    internal sealed class UpdateSettings {
        public string game, highest_version;
        public bool automatic=true;
        public bool reduced_motion;
    }
    internal static class UpdateStorage {
        static readonly byte[] Entropy=Encoding.UTF8.GetBytes("BalatroTogether.GitHub.ReadOnly.v1");
        public static string Root(UserPaths user) { return Path.Combine(user.Local,"BalatroTogether"); }
        public static string SettingsPath(UserPaths user) { return Path.Combine(Root(user),"launcher.json"); }
        public static UpdateSettings Load(UserPaths user) {
            string path=SettingsPath(user); Paths.NoLinks(path);
            if(!File.Exists(path))return new UpdateSettings();
            if(new FileInfo(path).Length>65536)throw new Exception("Launcher settings need review.");
            return new JavaScriptSerializer().Deserialize<UpdateSettings>(File.ReadAllText(path))??new UpdateSettings();
        }
        public static void Save(UserPaths user,UpdateSettings settings) {
            Atomic(SettingsPath(user),Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(settings)));
        }
        public static void Atomic(string path,byte[] bytes) {
            Paths.NoLinks(path); Directory.CreateDirectory(Path.GetDirectoryName(path));
            string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
            File.WriteAllBytes(temp,bytes);
            if(File.Exists(path))File.Replace(temp,path,null); else File.Move(temp,path);
        }
        public static void SaveToken(UserPaths user,string token) {
            string path=Path.Combine(Root(user),"github-token.bin"); Paths.NoLinks(path);
            token=token.Trim();
            if(token.Length==0) { if(File.Exists(path))File.Delete(path); return; }
            if(!Regex.IsMatch(token,"^[A-Za-z0-9_]{20,255}$"))throw new Exception("Paste a GitHub access token, without spaces.");
            Atomic(path,ProtectedData.Protect(Encoding.UTF8.GetBytes(token),Entropy,DataProtectionScope.CurrentUser));
        }
        public static string Token(UserPaths user) {
            string path=Path.Combine(Root(user),"github-token.bin"); Paths.NoLinks(path);
            if(!File.Exists(path))return "";
            if(new FileInfo(path).Length>16384)throw new Exception("Reconnect GitHub access in the launcher.");
            try { return Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(path),Entropy,DataProtectionScope.CurrentUser)); }
            catch(CryptographicException) { throw new Exception("Reconnect GitHub access under this Windows account."); }
        }
        public static string InstallLauncher(UserPaths user,string game) {
            string folder=Path.Combine(Root(user),"Launcher"),path=Path.Combine(folder,"Play Balatro Together.exe");
            Paths.NoLinks(path); Directory.CreateDirectory(folder);
            string source=Assembly.GetExecutingAssembly().Location;
            if(!Paths.Equal(source,path)) {
                string temp=Path.Combine(folder,Guid.NewGuid().ToString("N")+".exe"); File.Copy(source,temp,false);
                if(Paths.Hash(temp)!=Paths.Hash(source))throw new Exception("Launcher copy verification failed.");
                for(int i=0;;i++) { try { if(File.Exists(path))File.Replace(temp,path,null); else File.Move(temp,path); break; }
                    catch(IOException) { if(i>=20)throw; System.Threading.Thread.Sleep(100); } }
            }
            var settings=Load(user); settings.game=game;
            if(String.IsNullOrEmpty(settings.highest_version)||UpdatePolicy.Number(settings.highest_version)<UpdatePolicy.Number(Build.Version)) settings.highest_version=Build.Version;
            Save(user,settings); return path;
        }
    }
    internal class GitHubUpdates {
        readonly string token;
        public GitHubUpdates(string credential) { token=credential; }
        public static bool AssetHost(Uri uri) {
            return uri.Scheme=="https"&&uri.Port==443&&String.IsNullOrEmpty(uri.UserInfo)&&
                (uri.Host=="api.github.com"||uri.Host=="release-assets.githubusercontent.com"||uri.Host=="objects.githubusercontent.com");
        }
        public virtual void Download(string api,string target,long limit,Action<long> progress) {
            Uri uri=new Uri(api);
            if(uri.Host!="api.github.com"||!AssetHost(uri)||!uri.AbsolutePath.StartsWith("/repos/"+UpdatePolicy.Repository+"/",StringComparison.Ordinal))throw new Exception("Unexpected update address.");
            for(int redirect=0;redirect<=5;redirect++) {
                if(!AssetHost(uri))throw new Exception("Unexpected update download host.");
                var request=(HttpWebRequest)WebRequest.Create(uri); request.AllowAutoRedirect=false; request.Timeout=20000; request.ReadWriteTimeout=30000;
                request.UserAgent="BalatroTogether-Updater/"+Build.Version; request.Accept=api.Contains("/assets/")?"application/octet-stream":"application/vnd.github+json";
                if(uri.Host=="api.github.com") { request.Headers["X-GitHub-Api-Version"]="2026-03-10"; if(token.Length>0)request.Headers["Authorization"]="Bearer "+token; }
                try {
                    using(var response=(HttpWebResponse)request.GetResponse()) {
                        if((int)response.StatusCode>=300&&(int)response.StatusCode<400) { string location=response.Headers["Location"]; if(String.IsNullOrEmpty(location))throw new Exception("Missing update redirect."); uri=new Uri(uri,location); continue; }
                        if(response.StatusCode!=HttpStatusCode.OK||response.ContentLength>limit)throw new Exception("Unexpected update response size.");
                        using(var input=response.GetResponseStream()) using(var output=new FileStream(target,FileMode.CreateNew)) {
                            byte[] buffer=new byte[65536];long total=0;int n;
                            while((n=input.Read(buffer,0,buffer.Length))>0) { total+=n;if(total>limit)throw new Exception("Update exceeds the download size limit."); output.Write(buffer,0,n); if(progress!=null)progress(total); }
                            if(response.ContentLength>=0&&total!=response.ContentLength)throw new Exception("Update download was interrupted.");
                        }
                        return;
                    }
                } catch(WebException e) {
                    var response=e.Response as HttpWebResponse;
                    if(response!=null)using(response) {
                        if(response.StatusCode==HttpStatusCode.Unauthorized||response.StatusCode==HttpStatusCode.NotFound)throw new Exception("Private updates need GitHub access. Use GitHub access below with a token that can read this repository.");
                        if(response.StatusCode==HttpStatusCode.Forbidden)throw new Exception("GitHub refused this request. Check token permissions or try again after the API rate limit resets.");
                    }
                    throw new Exception("Update check could not connect. You can still play the installed build.");
                }
            }
            throw new Exception("Too many update redirects.");
        }
        public byte[] Bytes(string url,long limit,string stage) {
            string path=Path.Combine(stage,Guid.NewGuid().ToString("N")+".download"); Download(url,path,limit,null);return File.ReadAllBytes(path);
        }
        public sealed class Offer { public UpdateManifest manifest; public string packageApi; }
        internal static string Asset(Dictionary<string,object> release,string name) {
            if(!release.ContainsKey("assets"))return null;
            var matches=((System.Collections.IEnumerable)release["assets"]).Cast<Dictionary<string,object>>().Where(a=>Convert.ToString(a["name"])==name&&Convert.ToString(a["state"])=="uploaded").ToArray();
            if(matches.Length!=1)return null;
            long id=Convert.ToInt64(matches[0]["id"],CultureInfo.InvariantCulture);
            if(id<1)throw new Exception("Invalid GitHub release asset.");
            return "https://api.github.com/repos/"+UpdatePolicy.Repository+"/releases/assets/"+id.ToString(CultureInfo.InvariantCulture);
        }
        internal static Dictionary<string,object> Select(Dictionary<string,object>[] releases,string installed,string floor) {
            var candidates=new List<Dictionary<string,object>>();
            foreach(var r in releases) {
                if(Convert.ToBoolean(r["draft"]))continue;
                string tag=Convert.ToString(r["tag_name"]);Version version;
                try {version=UpdatePolicy.Number(tag);}catch {continue;}
                bool legacy=Asset(r,"Update.json")!=null&&Asset(r,"Update.sig")!=null;
                bool direct=Asset(r,"Update-v2.json")!=null&&Asset(r,"Update-v2.sig")!=null;
                if(version>UpdatePolicy.Number(installed)&&version>=UpdatePolicy.Number(floor)&&(legacy||direct))candidates.Add(r);
            }
            return candidates.OrderByDescending(r=>UpdatePolicy.Number(Convert.ToString(r["tag_name"]))).FirstOrDefault();
        }
        public Offer Find(string stage,string installed,string floor) {
            var bytes=Bytes("https://api.github.com/repos/"+UpdatePolicy.Repository+"/releases?per_page=100",4*1024*1024,stage);
            var releases=new JavaScriptSerializer {MaxJsonLength=4*1024*1024}.Deserialize<Dictionary<string,object>[]>(UpdatePolicy.Utf8.GetString(bytes));
            var release=Select(releases,installed,floor);if(release==null)return null;
            bool direct=Asset(release,"Update-v2.json")!=null&&Asset(release,"Update-v2.sig")!=null;
            var data=Bytes(Asset(release,direct?"Update-v2.json":"Update.json"),65536,stage);var sig=Bytes(Asset(release,direct?"Update-v2.sig":"Update.sig"),2048,stage);
            var manifest=UpdatePolicy.Verify(data,sig,Convert.ToString(release["tag_name"]),DateTime.UtcNow,UpdateKey.PublicXml);
            if(manifest.schema!=(direct?2:1))throw new Exception("Update metadata format does not match its asset name.");
            string package=Asset(release,manifest.asset);if(package==null)throw new Exception("The signed update package is missing.");
            return new Offer {manifest=manifest,packageApi=package};
        }
    }
    internal sealed class LauncherForm : StudioForm {
        public static bool PreviewMode;
        protected override bool ShowWithoutActivation {get{return PreviewMode;}}
        readonly UserPaths user; readonly UpdateSettings settings;
        readonly Label status=new Label(); readonly Button play,check,access; readonly CheckBox automatic=new CheckBox();
        bool busy,handoff; readonly string game;
        public LauncherForm(UserPaths context,string selected) : base(PreviewMode) {
            user=context;settings=UpdateStorage.Load(user);game=selected;Text="Play Balatro Together";
            SetHeading("YOUR TABLE IS WAITING", "Let's play.", "Your party. Your builds. One shared goal.\nWe'll keep your bundle ready for the next run.");
            var activity=new StudioPanel();activity.SetBounds(350,244,520,143);Controls.Add(activity);
            activity.Controls.Add(Studio.Label("SIGNED UPDATES",16,15,450,20,8,Studio.Teal,true));
            status.Text="Ready to play. We'll check your version before launching.";status.SetBounds(16,45,484,53);status.BackColor=Studio.Panel;status.ForeColor=Studio.Cream;status.Font=new Font("Segoe UI",11,FontStyle.Bold);activity.Controls.Add(status);
            Progress.SetBounds(16,114,486,9);activity.Controls.Add(Progress);
            automatic.Text="Keep Together up to date before playing";automatic.Checked=settings.automatic;automatic.SetBounds(354,403,510,27);automatic.ForeColor=Studio.Cream;automatic.CheckedChanged+=(sender,e)=>{settings.automatic=automatic.Checked;UpdateStorage.Save(user,settings);};Controls.Add(automatic);
            Controls.Add(Studio.Label("Private repo? Connect your own GitHub access once.\nOffline checks never prevent you from playing the installed build.",350,440,520,42,9,Studio.Muted,false));
            access=AddButton("GitHub access",350,516,150,false,()=>ConfigureAccess());
            check=AddButton("Check updates",510,516,162,false,async()=>await RunUpdate(false));
            play=AddButton("Play Together",682,516,188,true,()=>Play());AcceptButton=play;
            ReducedMotion=settings.reduced_motion;MotionChanged+=value=>{settings.reduced_motion=value;UpdateStorage.Save(user,settings);};
            FormClosing+=(sender,e)=>{if(busy&&!handoff)e.Cancel=true;};Shown+=async(sender,e)=>{if(!PreviewMode&&settings.automatic)await RunUpdate(true);};
        }
        void Report(string message) {if(InvokeRequired){BeginInvoke(new Action<string>(Report),message);return;}status.Text=message; var percent=Regex.Match(message,@" (\d+)%$");if(percent.Success)Progress.Target=Int32.Parse(percent.Groups[1].Value);}
        void Play() {
            if(busy)return;
            if(Detection.Running()){Report("Balatro is already open. No update was installed.");return;}
            string exe=Path.Combine(game,"Balatro.exe");
            if(!File.Exists(exe)||Paths.Hash(exe)!=Build.GameHash){Report("Game not found or unsupported. Run the installer and choose your Steam game.");return;}
            Process.Start(new ProcessStartInfo(exe,"--disable-console"){WorkingDirectory=game});Close();
        }
        void ConfigureAccess() {
            using(var form=new Form {Text="Connect GitHub",BackColor=Studio.Ink,ForeColor=Studio.Cream,Font=new Font("Segoe UI",10),ClientSize=new Size(600,370),StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false}) {
                var label=new Label {Text="Use your own GitHub token with read access to Krosoviblyat/BalatroTogether. Your GitHub account must already have repository access.\n\nOwner: fine-grained token, select this repository, Contents: Read-only. Invited collaborators may need a classic token with repo scope; that grants broader access. Never share an owner's token.\n\nSaved encrypted for this Windows account. Leave empty to forget it.",Location=new Point(24,24),Size=new Size(552,200),ForeColor=Studio.Cream};form.Controls.Add(label);
                var token=new TextBox {UseSystemPasswordChar=true,Location=new Point(24,238),Size=new Size(552,30),MaxLength=255,BackColor=Studio.Panel,ForeColor=Studio.Cream,BorderStyle=BorderStyle.FixedSingle};form.Controls.Add(token);
                var help=new LinkLabel {Text="Open GitHub token settings",Location=new Point(24,309),AutoSize=true,LinkColor=Studio.Teal,ActiveLinkColor=Studio.Cream};help.LinkClicked+=(s,e)=>Process.Start(new ProcessStartInfo("https://github.com/settings/tokens"){UseShellExecute=true});form.Controls.Add(help);
                var save=new StudioButton {Text="Save access",Primary=true,Location=new Point(413,292),Size=new Size(163,52)};save.Click+=(s,e)=>{try{UpdateStorage.SaveToken(user,token.Text);form.DialogResult=DialogResult.OK;form.Close();}catch(Exception error){MessageBox.Show(form,error.Message);}};form.Controls.Add(save);
                form.AcceptButton=save;
                using(var animation=new Timer {Interval=16}) {
                    animation.Tick+=(sender,e)=>save.Animate(.016f,ReducedMotion);animation.Start();
                    if(form.ShowDialog(this)==DialogResult.OK)Report("GitHub access updated. Click Check updates to test access.");
                }
            }
        }
        async Task RunUpdate(bool launchAfter) {
            if(busy)return;
            if(Detection.Running()){Report("Balatro is open. Close it before checking or installing updates.");return;}
            busy=true;play.Enabled=false;check.Enabled=false;access.Enabled=false;automatic.Enabled=false;Progress.Busy=true;Progress.Target=5;
            string stage=null;
            try {
                Report("Checking signed releases...");
                string root=Path.Combine(UpdateStorage.Root(user),"Updates");Paths.NoLinks(root);Directory.CreateDirectory(root);
                stage=Path.Combine(root,Guid.NewGuid().ToString("N"));Directory.CreateDirectory(stage);
                var client=new GitHubUpdates(UpdateStorage.Token(user));
                string floor=Build.Version;
                if(!String.IsNullOrEmpty(settings.highest_version)&&UpdatePolicy.Number(settings.highest_version)>UpdatePolicy.Number(floor))floor=settings.highest_version;
                var offer=await Task.Run(()=>client.Find(stage,Build.Version,floor));
                if(offer==null) {Report("You have the newest signed build. Ready to play.");busy=false;if(launchAfter)Play();return;}
                if(Detection.Running())throw new Exception("Balatro was opened. The update will wait until your next launch.");
                string zip=Path.Combine(stage,"update.zip");
                Report("Downloading "+offer.manifest.version+"...");
                int last=-1;
                await Task.Run(()=>client.Download(offer.packageApi,zip,offer.manifest.size,n=>{int percent=(int)(n*100/offer.manifest.size);if(percent!=last){last=percent;Report("Downloading "+offer.manifest.version+"  "+percent+"%");}}));
                string installer=await Task.Run(()=>UpdatePolicy.PrepareInstaller(zip,Path.Combine(stage,"Verified"),offer.manifest));
                if(Detection.Running())throw new Exception("Balatro was opened. No game files were changed. Close it and check updates again.");
                // High-water mark is committed only after successful installation by the new installer.
                Process.Start(new ProcessStartInfo(installer,"--update "+Paths.Quote(game)){UseShellExecute=true,WorkingDirectory=Path.GetDirectoryName(installer)});
                handoff=true;Close();
            } catch(Exception e) {Report(e is IOException?"Update download or staging failed. Your installed build is unchanged; you can still play.":e.Message);}
            finally {
                if(stage!=null&&!handoff)try{Paths.RemoveOwned(stage,Path.GetDirectoryName(stage));}catch{}
                busy=false;if(!IsDisposed){Progress.Busy=false;Progress.Target=0;play.Enabled=true;check.Enabled=true;access.Enabled=true;automatic.Enabled=true;}
            }
        }
    }
}
