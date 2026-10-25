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
    // The launcher EXE version is not evidence that its mod was installed.
    // Check the original user's Mods against this EXE's embedded payload.
    internal sealed class InstalledBuild {
        public string Version, BundledVersion, Problem, ReleaseVersion, BundleHash;
        public bool NewerMod;
        public bool NeedsRepair {get{return Problem!=null;}}
        public bool CanRepair(string floor) {
            return NeedsRepair&&!NewerMod&&UpdatePolicy.Number(Build.Version)>=UpdatePolicy.Number(floor);
        }
        static readonly object gate=new object();
        static Dictionary<string,string> expected; static string bundled;
        static string StreamHash(Stream stream) {using(var hash=SHA256.Create())return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-","").ToLowerInvariant();}
        static void ReadBundle() {
            lock(gate) {
                if(expected!=null)return;
                var files=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
                using(var input=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip")) {
                    if(input==null||StreamHash(input)!=Build.PayloadHash)throw new Exception("The embedded repair package failed verification. Download the full installer again.");
                    input.Position=0;
                    using(var zip=new ZipArchive(input,ZipArchiveMode.Read)) {
                        var meta=zip.GetEntry("Mods/BalatroTogether/BalatroTogether.json");
                        if(meta==null)throw new Exception("The repair package has no Together metadata.");
                        using(var stream=meta.Open())using(var reader=new StreamReader(stream,UpdatePolicy.Utf8))bundled=Metadata(reader.ReadToEnd());
                        foreach(var entry in zip.Entries) {
                            const string prefix="Mods/BalatroTogether/";
                            if(!entry.FullName.StartsWith(prefix,StringComparison.Ordinal)||entry.FullName.EndsWith("/",StringComparison.Ordinal))continue;
                            string relative=entry.FullName.Substring(prefix.Length);
                            if(relative.Split('/').Any(part=>part==".."||part==".")||relative.Contains("\\")||relative.Contains(":"))throw new Exception("Invalid repair package path.");
                            using(var stream=entry.Open())files.Add(relative,StreamHash(stream));
                        }
                    }
                }
                if(files.Count==0)throw new Exception("The repair package is empty.");
                expected=files;
            }
        }
        static string Metadata(string text) {
            var meta=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(text);
            if(meta==null||!meta.ContainsKey("id")||Convert.ToString(meta["id"])!="BalatroTogether"||!meta.ContainsKey("version"))throw new Exception("Unrecognized Together metadata.");
            string version=Convert.ToString(meta["version"]);UpdatePolicy.Number(version);return version;
        }
        public static string GameplayVersion { get {ReadBundle();return bundled;} }
        public static InstalledBuild Inspect(UserPaths user) {
            var received=BundleUpdates.Inspect(user);if(received!=null)return received;
            ReadBundle();
            var result=new InstalledBuild {BundledVersion=bundled};
            string folder=Path.Combine(user.Roaming,"Balatro","Mods","BalatroTogether"),meta=Path.Combine(folder,"BalatroTogether.json");
            Paths.NoLinks(meta);
            if(!File.Exists(meta)){result.Problem="Together is not installed in this Windows profile.";return result;}
            try {
                if(new FileInfo(meta).Length>65536)throw new Exception("Oversized metadata.");
                result.Version=Metadata(File.ReadAllText(meta,UpdatePolicy.Utf8));
            }catch(ArgumentException){result.Problem="Together metadata needs repair.";return result;}
             catch(InvalidOperationException){result.Problem="Together metadata needs repair.";return result;}
             catch(Exception error){if(error is IOException||error is UnauthorizedAccessException)throw;result.Problem="Together metadata needs repair.";return result;}
            result.NewerMod=UpdatePolicy.Number(result.Version)>UpdatePolicy.Number(bundled);
            if(result.NewerMod){result.Problem="A newer mod has no signed installation receipt. Check updates to verify it.";return result;} // Never replace a newer mod with an older embedded one.
            if(result.Version!=bundled){result.Problem="Installed Together "+result.Version+" differs from bundled "+bundled+".";return result;}
            foreach(var file in expected) {
                string target=Path.Combine(folder,file.Key.Replace('/',Path.DirectorySeparatorChar));Paths.Within(target,folder);Paths.NoLinks(target);
                if(!File.Exists(target)||Paths.Hash(target)!=file.Value){result.Problem="Installed Together files need repair: "+file.Key;break;}
            }
            return result;
        }
        public string StageRepair(string stage,string floor) {
            if(!CanRepair(floor))throw new Exception("This launcher cannot safely repair that build. Download the current full installer.");
            string target=Path.Combine(stage,"Verified");Paths.NoLinks(target);Directory.CreateDirectory(target);
            string source=Assembly.GetExecutingAssembly().Location,exe=Path.Combine(target,"Install Balatro Together.exe");
            File.Copy(source,exe,false);
            if(Paths.Hash(exe)!=Paths.Hash(source))throw new Exception("Embedded repair installer staging failed verification.");
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
        // Public releases never read or transmit a saved token. Keep the constructor
        // shape for existing test fixtures and source compatibility.
        public GitHubUpdates(string credential) { }
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
                request.CachePolicy=new System.Net.Cache.RequestCachePolicy(System.Net.Cache.RequestCacheLevel.NoCacheNoStore);
                request.Headers[HttpRequestHeader.CacheControl]="no-cache, no-store";
                request.UserAgent="BalatroTogether-Updater/"+Build.Version; request.Accept=api.Contains("/assets/")?"application/octet-stream":"application/vnd.github+json";
                if(uri.Host=="api.github.com") { request.Headers["X-GitHub-Api-Version"]="2026-03-10"; }
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
                        if(response.StatusCode==HttpStatusCode.Unauthorized||response.StatusCode==HttpStatusCode.NotFound)throw new Exception("The public release could not be found. Open Releases to check availability; no GitHub login is required.");
                        if(response.StatusCode==HttpStatusCode.Forbidden)throw new Exception("GitHub is rate-limiting downloads or refused the request. Try again later or download setup from Releases. No token is needed.");
                    }
                    throw new Exception("Update check could not connect. You can still play the installed build.");
                }
            }
            throw new Exception("Too many update redirects.");
        }
        public byte[] Bytes(string url,long limit,string stage) {
            string path=Path.Combine(stage,Guid.NewGuid().ToString("N")+".download"); Download(url,path,limit,null);return File.ReadAllBytes(path);
        }
        public sealed class Offer {
            public UpdateManifest manifest;public DataManifest bundle;public byte[] metadata,signature;public string packageApi;
            public string Version {get{return bundle!=null?bundle.version:manifest.version;}}
        }
        internal static Dictionary<string,object> Newest(Dictionary<string,object>[] releases,string floor) {
            var candidates=releases.Where(r=>!Convert.ToBoolean(r["draft"])).Where(r=>{try{UpdatePolicy.Number(Convert.ToString(r["tag_name"]));return true;}catch{return false;}}).OrderByDescending(r=>UpdatePolicy.Number(Convert.ToString(r["tag_name"]))).ToArray();
            if(candidates.Length==0)throw new Exception("GitHub has no published versioned update. No older build was installed.");
            var latest=candidates[0];string tag=Convert.ToString(latest["tag_name"]);
            if(UpdatePolicy.Number(tag)<UpdatePolicy.Number(floor))throw new Exception("GitHub's newest release is older than this installation. Downgrade refused.");
            bool data=Asset(latest,"Update-v3.json")!=null&&Asset(latest,"Update-v3.sig")!=null;
            bool direct=Asset(latest,"Update-v2.json")!=null&&Asset(latest,"Update-v2.sig")!=null;
            bool legacy=Asset(latest,"Update.json")!=null&&Asset(latest,"Update.sig")!=null;
            if(!data&&!direct&&!legacy)throw new Exception("Newest GitHub release "+tag+" is missing its signed update files. No older build was installed.");
            return latest;
        }
        public Offer Latest(string stage,string floor) {
            var bytes=Bytes("https://api.github.com/repos/"+UpdatePolicy.Repository+"/releases?per_page=100",4*1024*1024,stage);
            var list=new JavaScriptSerializer{MaxJsonLength=4*1024*1024}.Deserialize<Dictionary<string,object>[]>(UpdatePolicy.Utf8.GetString(bytes));
            var release=Newest(list,floor);string tag=Convert.ToString(release["tag_name"]);
            if(Asset(release,"Update-v3.json")!=null&&Asset(release,"Update-v3.sig")!=null) {
                byte[] data=Bytes(Asset(release,"Update-v3.json"),65536,stage),signature=Bytes(Asset(release,"Update-v3.sig"),2048,stage);
                var manifest=BundleUpdates.Verify(data,signature,tag,DateTime.UtcNow,UpdateKey.PublicXml);
                string package=Asset(release,manifest.asset);if(package==null)throw new Exception("Newest GitHub release is missing its signed data bundle. No older build was installed.");
                return new Offer{bundle=manifest,metadata=data,signature=signature,packageApi=package};
            }
            bool direct=Asset(release,"Update-v2.json")!=null&&Asset(release,"Update-v2.sig")!=null;
            byte[] oldData=Bytes(Asset(release,direct?"Update-v2.json":"Update.json"),65536,stage),oldSig=Bytes(Asset(release,direct?"Update-v2.sig":"Update.sig"),2048,stage);
            var old=UpdatePolicy.Verify(oldData,oldSig,tag,DateTime.UtcNow,UpdateKey.PublicXml);
            if(old.schema!=(direct?2:1))throw new Exception("Update metadata format does not match its asset name.");
            string oldPackage=Asset(release,old.asset);if(oldPackage==null)throw new Exception("Newest signed update package is missing.");
            return new Offer{manifest=old,packageApi=oldPackage};
        }
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
        readonly Label status=new Label(),versions=new Label(); readonly Button play,check,access;
        bool busy,handoff,offlineAvailable; readonly string game;string latestVersion;
        public LauncherForm(UserPaths context,string selected) : base(PreviewMode) {
            user=context;settings=UpdateStorage.Load(user);game=selected;Text="Zero Crew | Play Balatro Together";
            SetHeading("by Mind_the_assassin", "come on in and join the coop fest!", "this is a full installer thats packaged with cryptid! crazy ik lmao dont worry about manually installing steammodded or lovely i got you on that as well");
            var activity=new StudioPanel();activity.SetBounds(350,266,520,123);Controls.Add(activity);
            activity.Controls.Add(Studio.Label("SIGNED UPDATES",16,15,450,20,8,Studio.Red,true));
            status.Text="Ready to play. We'll check your version before launching.";status.SetBounds(16,45,484,53);status.BackColor=Studio.Panel;status.ForeColor=Studio.Cream;status.Font=new Font("Segoe UI",11,FontStyle.Bold);activity.Controls.Add(status);
            Progress.SetBounds(16,103,486,9);activity.Controls.Add(Progress);
            Controls.Add(Studio.Label("Checks GitHub on opening and before Play.",354,403,510,27,10,Studio.Cream,false));
            versions.Text="Installed mod: checking / Latest mod: checking GitHub";versions.SetBounds(350,440,520,22);versions.ForeColor=Studio.Cream;versions.Font=new Font("Segoe UI",9);Controls.Add(versions);
            Controls.Add(Studio.Label("Public signed updates / no GitHub account or token needed.",350,469,520,25,9,Studio.Muted,false));
            access=AddButton("Releases",350,516,150,false,()=>Process.Start(new ProcessStartInfo("https://github.com/"+UpdatePolicy.Repository+"/releases"){UseShellExecute=true}));
            check=AddButton("Check updates",510,516,162,false,async()=>await RunUpdate(false));
            play=AddButton("Play Together",682,516,188,true,async()=>await Play());AcceptButton=play;
            ReducedMotion=settings.reduced_motion;MotionChanged+=value=>{settings.reduced_motion=value;UpdateStorage.Save(user,settings);};
            FormClosing+=(sender,e)=>{if(busy&&!handoff)e.Cancel=true;};Shown+=async(sender,e)=>{if(!PreviewMode)await RunUpdate(false);};
        }
        void Report(string message) {if(InvokeRequired){BeginInvoke(new Action<string>(Report),message);return;}status.Text=message; var percent=Regex.Match(message,@" (\d+)%$");if(percent.Success)Progress.Target=Int32.Parse(percent.Groups[1].Value);}
        void ShowInstalled(InstalledBuild installed) {
            versions.Text="Installed mod: "+(installed.Version??"missing")+" / Latest mod: "+(latestVersion??"not checked")+(installed.NeedsRepair?" / repair needed":"");
        }
        async Task Play() {
            if(busy)return;
            if(!offlineAvailable)await RunUpdate(true);else await LaunchInstalled();
        }
        async Task LaunchInstalled(bool fromUpdate=false) {
            if(busy&&!fromUpdate)return;
            busy=true;play.Enabled=false;check.Enabled=false;
            try {
                if(SetupUpdates.Running()){Report("Balatro is already open. No update was installed.");return;}
                var launch=GameFiles.Launch(game);
                Report("Verifying installed Together files...");
                var installed=await Task.Run(()=>InstalledBuild.Inspect(user));ShowInstalled(installed);
                if(installed.NeedsRepair)throw new Exception("Installed files need repair. Click Check updates while connected; no older bundled mod was installed.");
                if(SetupUpdates.Running()){Report("Balatro was opened. No game files were changed.");return;}
                SetupUpdates.LaunchGame(launch);busy=false;Close();
            }catch(GameFilesException error){Report("Balatro game files need repair in Steam. No game was launched.");SetupUpdates.ShowGameError(this,error.Message);}
            catch(Exception error){Report(error.Message);}
            finally{busy=false;if(!IsDisposed){play.Enabled=true;check.Enabled=true;}}
        }
        async Task RunUpdate(bool launchAfter,bool online=true) {
            if(busy)return;
            if(SetupUpdates.Running()){Report("Balatro is open. Close it before checking or installing updates.");return;}
            busy=true;offlineAvailable=false;play.Text="Play Together";play.Enabled=false;check.Enabled=false;access.Enabled=false;Progress.Busy=true;Progress.Target=5;
            string stage=null;
            try {
                GameFiles.Validate(game,Build.GameHash);
                Report("Checking the installed mod and signed releases...");
                string root=Path.Combine(UpdateStorage.Root(user),"Updates");Paths.NoLinks(root);Directory.CreateDirectory(root);
                stage=Path.Combine(root,Guid.NewGuid().ToString("N"));Directory.CreateDirectory(stage);
                var installed=await Task.Run(()=>InstalledBuild.Inspect(user));ShowInstalled(installed);
                // A failed online check must never silently repair/install an
                // old embedded copy and present it as the latest release.
                var selection=online?await Task.Run(()=>SetupUpdates.Check(user,stage)):null;
                if(selection!=null&&selection.Offer!=null) {
                    latestVersion=selection.Offer.Version;ShowInstalled(installed);
                    if(selection.Offer.bundle!=null) {
                        if(installed.BundleHash==selection.Offer.bundle.sha256&&!installed.NeedsRepair) {
                            Report("Latest mod "+latestVersion+" is installed and verified.");if(launchAfter)await LaunchInstalled(true);return;
                        }
                        Report("Installing latest mod "+latestVersion+" from GitHub...");
                        await Task.Run(()=>SetupUpdates.InstallBundle(selection,stage,user,game,Report));
                        installed=await Task.Run(()=>InstalledBuild.Inspect(user));ShowInstalled(installed);
                        if(installed.NeedsRepair||installed.Version!=latestVersion)throw new Exception("Installed files did not match the latest release. Play was stopped.");
                        Report("Latest mod "+latestVersion+" installed and verified.");if(launchAfter)await LaunchInstalled(true);return;
                    }
                    if(SetupUpdates.SameInstaller(selection.Offer))selection.Offer=null;
                }
                string floor=selection!=null?selection.Floor:SetupUpdates.Floor(user,installed,Build.Version);
                string installer;
                if(selection==null||selection.Offer==null) {
                    if(installed.NeedsRepair) {
                        Report(online?"Latest check succeeded. Repairing the verified bundled gameplay...":"Offline repair only; latest version was not checked.");
                        installer=await Task.Run(()=>installed.StageRepair(stage,floor));
                    } else {
                        Report(online?"Latest check succeeded. Gameplay "+installed.Version+" is verified.":"Online updates are off. Gameplay "+installed.Version+" is verified locally.");
                        if(launchAfter)await LaunchInstalled(true);return;
                    }
                } else installer=await Task.Run(()=>SetupUpdates.Download(selection,stage,Report));
                if(SetupUpdates.Running())throw new Exception("Balatro was opened. No game files were changed. Close it and check updates again.");
                // High-water mark is committed only after successful installation by the new installer.
                SetupUpdates.StartVerified(installer,game);
                handoff=true;Close();
            } catch(GameFilesException e) {
                offlineAvailable=false;Report("Balatro game files need repair in Steam. No update was installed.");SetupUpdates.ShowGameError(this,e.Message);
            } catch(Exception e) {
                offlineAvailable=true;play.Text="Play installed";
                Report((e is IOException?"Update staging failed; installed build unchanged.":e.Message)+" Play installed skips the update check.");
            }
            finally {
                if(stage!=null&&!handoff)try{Paths.RemoveOwned(stage,Path.GetDirectoryName(stage));}catch{}
                busy=false;if(!IsDisposed){Progress.Busy=false;Progress.Target=0;play.Enabled=true;check.Enabled=true;access.Enabled=true;}
            }
        }
    }
}
