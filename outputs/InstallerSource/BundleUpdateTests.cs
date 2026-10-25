// Isolated production-form tests for the permanent launcher and future ZIPs.
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace TogetherSetup {
    internal static partial class SetupFlowTests {
        sealed class BundleClient:GitHubUpdates {
            public string List;public bool Fail,Incomplete;public int Requests;
            readonly Dictionary<string,string> assets=new Dictionary<string,string>();
            public readonly DataManifest Manifest;
            public BundleClient(string release):base("") {
                Manifest=new JavaScriptSerializer().Deserialize<DataManifest>(File.ReadAllText(Path.Combine(release,"Update-v3.json")));
                var entries=new List<object>();long id=1000;
                foreach(string name in new[]{"Update-v3.json","Update-v3.sig",Manifest.asset}){assets.Add("https://api.github.com/repos/"+UpdatePolicy.Repository+"/releases/assets/"+id,Path.Combine(release,name));entries.Add(new{id=id++,name=name,state="uploaded"});}
                List=new JavaScriptSerializer().Serialize(new[]{new{tag_name="v"+Manifest.version,draft=false,prerelease=true,assets=entries}});
            }
            public override void Download(string api,string target,long limit,Action<long> progress) {
                Requests++;if(Fail)throw new Exception("Synthetic network failure");
                if(api.EndsWith("/releases?per_page=100"))File.WriteAllText(target,Incomplete?"[{\"tag_name\":\"v99.0.0\",\"draft\":false,\"assets\":[]}]":List,UpdatePolicy.Utf8);
                else {string source;if(!assets.TryGetValue(api,out source))throw new Exception("Unexpected bundle fixture URL");File.Copy(source,target,false);}
                long length=new FileInfo(target).Length;if(length>limit)throw new Exception("Oversized response");if(progress!=null)progress(length);
            }
        }
        static VerifiedBundle ReadTestBundle(string folder) {
            byte[] data=File.ReadAllBytes(Path.Combine(folder,"Update-v3.json")),signature=File.ReadAllBytes(Path.Combine(folder,"Update-v3.sig"));
            var raw=new JavaScriptSerializer().Deserialize<DataManifest>(UpdatePolicy.Utf8.GetString(data));
            var manifest=BundleUpdates.Verify(data,signature,"v"+raw.version,DateTime.UtcNow,UpdateKey.PublicXml);
            return new VerifiedBundle{Manifest=manifest,Metadata=data,Signature=signature,Package=Path.Combine(folder,manifest.asset)};
        }
        static void MustReject(Action action){bool rejected=false;try{action();}catch{rejected=true;}Check(rejected,"Invalid bundle was accepted");}
        public static int BundleNetworkProbe(string parent) {
            parent=Path.GetFullPath(parent);Directory.CreateDirectory(parent);var checks=new List<string>();
            var factory=SetupUpdates.ClientFactory;var running=SetupUpdates.Running;var handoff=SetupUpdates.Handoff;var launch=SetupUpdates.LaunchGame;string test=SetupUpdates.TestCurrentVersion;
            bool ps=SetupForm.PreviewMode,pl=LauncherForm.PreviewMode;
            try {
                SetupForm.PreviewMode=true;LauncherForm.PreviewMode=true;SetupUpdates.Running=()=>false;SetupUpdates.TestCurrentVersion=null;int requests=0,launched=0;
                SetupUpdates.ClientFactory=credential=>{Check(credential=="","Credential sent to public updater");requests++;return new GitHubUpdates("");};
                SetupUpdates.Handoff=(exe,game)=>{throw new Exception("The permanent launcher attempted an installer EXE download/handoff");};SetupUpdates.LaunchGame=_=>launched++;
                var f=new Fixture(parent,"public-data");string own=Paths.Hash(Assembly.GetExecutingAssembly().Location);
                using(var form=new SetupForm(f.User,f.Game,false)) {
                    Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Check & install latest")).PerformClick();Wait(()=>!Field<bool>(form,"busy"),"public data setup",240);
                    Check(Field<bool>(form,"done"),"Public data install failed: "+Field<Label>(form,"status").Text);Check(Field<Label>(form,"result").Text.Contains("Latest mod: "+f.Version),"GitHub gameplay version is not visible");
                    using(var bitmap=new System.Drawing.Bitmap(form.Width,form.Height)){form.DrawToBitmap(bitmap,new System.Drawing.Rectangle(0,0,form.Width,form.Height));bitmap.Save(Path.Combine(parent,"installed-latest.png"));}
                }
                var installed=InstalledBuild.Inspect(f.User);Check(installed.BundleHash!=null&&!installed.NeedsRepair,"Signed data receipt did not verify");f.Preserved();checks.Add("Production Install fetches and applies the newest real public signed data ZIP without an installer handoff");
                checks.Add("Installed files and saved native run verify against the signed cached package");
                string binary=Path.Combine(UpdateStorage.Root(f.User),"Launcher","Play Balatro Together.exe");Check(Paths.Hash(binary)==own,"Permanent binary changed");checks.Add("Desktop launcher is the same permanent binary; installed/latest gameplay versions are shown separately");
                using(var form=new LauncherForm(f.User,f.Game)){Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Play Together")).PerformClick();Wait(()=>form.IsDisposed||!Field<bool>(form,"busy"),"public data Play",240);Check(launched==1,"Checked gameplay did not reach intercepted launch: "+(form.IsDisposed?"closed":Field<Label>(form,"status").Text));}
                Check(requests==2&&Paths.Hash(binary)==own,"Play skipped a fresh check or changed the binary");checks.Add("Production Play independently rechecks GitHub, verifies the same data release and reaches intercepted game launch");
                checks.Add("No new installer EXE is needed or launched for normal updates");
                File.WriteAllText(Path.Combine(parent,"public-update-results.json"),new JavaScriptSerializer().Serialize(new{passed=checks.Count,failed=0,checks=checks,gameplay=f.Version,bundle_sha256=installed.BundleHash,permanent_launcher_sha256=own,network="Real anonymous GitHub release/metadata/ZIP downloads",live_game_changed=false,game_launch="Intercepted in isolated fixture"}));return 0;
            }catch(Exception error){File.WriteAllText(Path.Combine(parent,"public-update-results.json"),new JavaScriptSerializer().Serialize(new{passed=checks.Count,failed=1,error=error.ToString()}));return 1;}
            finally{SetupUpdates.ClientFactory=factory;SetupUpdates.Running=running;SetupUpdates.Handoff=handoff;SetupUpdates.LaunchGame=launch;SetupUpdates.TestCurrentVersion=test;SetupForm.PreviewMode=ps;LauncherForm.PreviewMode=pl;}
        }
        public static int BundleProbe(string current,string future,string parent) {
            parent=Path.GetFullPath(parent);Directory.CreateDirectory(parent);var checks=new List<string>();
            var factory=SetupUpdates.ClientFactory;var running=SetupUpdates.Running;var handoff=SetupUpdates.Handoff;var launch=SetupUpdates.LaunchGame;var configure=BundleUpdates.ConfigureEngine;string test=SetupUpdates.TestCurrentVersion;
            bool ps=SetupForm.PreviewMode,pl=LauncherForm.PreviewMode;
            try {
                SetupForm.PreviewMode=true;LauncherForm.PreviewMode=true;SetupUpdates.Running=()=>false;SetupUpdates.TestCurrentVersion=null;
                SetupUpdates.Handoff=(exe,game)=>{throw new Exception("A data update attempted to execute another installer");};
                var now=ReadTestBundle(current);var next=ReadTestBundle(future);
                Check(UpdatePolicy.Number(next.Manifest.version)>UpdatePolicy.Number(Build.Version),"Future fixture does not exceed permanent launcher build");
                var modified=(byte[])now.Metadata.Clone();modified[5]^=1;MustReject(()=>BundleUpdates.Verify(modified,now.Signature,"v"+now.Manifest.version,DateTime.UtcNow,UpdateKey.PublicXml));checks.Add("Tampered data metadata is rejected by the original publisher key");
                MustReject(()=>BundleUpdates.Verify(now.Metadata,now.Signature,"v0.0.1",DateTime.UtcNow,UpdateKey.PublicXml));checks.Add("Bundle tag mismatch is rejected");
                MustReject(()=>BundleUpdates.Verify(now.Metadata,now.Signature,"v"+now.Manifest.version,DateTime.UtcNow.AddDays(101),UpdateKey.PublicXml));
                BundleUpdates.Verify(now.Metadata,now.Signature,"v"+now.Manifest.version,DateTime.UtcNow.AddDays(101),UpdateKey.PublicXml,true);checks.Add("Fresh network metadata enforces expiry while signed installed receipts remain usable offline");
                string bad=Path.Combine(parent,"corrupt.zip");File.Copy(now.Package,bad);File.AppendAllText(bad,"bad");MustReject(()=>BundleUpdates.VerifyPackage(new VerifiedBundle{Manifest=now.Manifest,Package=bad}));checks.Add("Corrupt ZIP is rejected before installation");
                string unsafeZip=Path.Combine(parent,"unsafe.zip");using(var zip=ZipFile.Open(unsafeZip,ZipArchiveMode.Create)){zip.CreateEntry("Mods/../../outside.lua");}
                var unsafeMeta=new DataManifest{size=new FileInfo(unsafeZip).Length,sha256=Paths.Hash(unsafeZip)};MustReject(()=>BundleUpdates.Files(new VerifiedBundle{Manifest=unsafeMeta,Package=unsafeZip}));checks.Add("Archive traversal is rejected before staging mod files");
                var client=new BundleClient(current);SetupUpdates.ClientFactory=_=>client;
                string scratch=Path.Combine(parent,"selection");Directory.CreateDirectory(scratch);
                client.Incomplete=true;MustReject(()=>client.Latest(scratch,"0.0.0"));client.Incomplete=false;checks.Add("Incomplete newest release fails explicitly instead of selecting an older signed release");
                var versions=new JavaScriptSerializer().Deserialize<Dictionary<string,object>[]>(client.List).ToList();versions.Add(new Dictionary<string,object>{{"tag_name","launcher"},{"draft",false},{"assets",new object[0]}});versions.Add(new Dictionary<string,object>{{"tag_name","v99.0.0"},{"draft",true},{"assets",new object[0]}});
                Check(Convert.ToString(GitHubUpdates.Newest(versions.ToArray(),"0.0.0")["tag_name"])=="v"+now.Manifest.version,"Permanent download tag interfered with release selection");checks.Add("Permanent launcher tag and draft releases do not interfere with newest gameplay selection");
                var f=new Fixture(parent,"fresh");
                using(var form=new SetupForm(f.User,f.Game,false)) {
                    Show(form);Check(!All(form).Any(c=>c.Text.StartsWith("Setup "+Build.Version)||c.Text.StartsWith("Launcher "+Build.Version)),"Launcher build number remains in UI");
                    ((Button)All(form).Single(c=>c is Button&&c.Text=="Check & install latest")).PerformClick();Wait(()=>!Field<bool>(form,"busy"),"data setup",180);
                    Check(Field<bool>(form,"done"),"Bundle setup failed: "+Field<Label>(form,"status").Text);Check(Field<Label>(form,"result").Text.Contains("Latest mod: "+now.Manifest.version),"Latest gameplay version was not shown");
                }
                f.Preserved();Check(f.Version==now.Manifest.version&&!InstalledBuild.Inspect(f.User).NeedsRepair,"Installed data build failed verification");checks.Add("Production setup installs a signed ZIP, preserves saves, verifies gameplay and shows the GitHub version without another EXE");
                string launcher=Path.Combine(UpdateStorage.Root(f.User),"Launcher","Play Balatro Together.exe"),launcherHash=Paths.Hash(launcher);
                Check(launcherHash==Paths.Hash(Assembly.GetExecutingAssembly().Location),"Different launcher binary was installed");checks.Add("First installation commits the same permanent launcher and desktop shortcut");
                var nextClient=new BundleClient(future);SetupUpdates.ClientFactory=_=>nextClient;
                using(var form=new LauncherForm(f.User,f.Game)) {
                    Show(form);Check(!All(form).Any(c=>c is CheckBox&&c.Text.StartsWith("Keep Together")),"Update opt-out remains in permanent launcher");
                    ((Button)All(form).Single(c=>c is Button&&c.Text=="Check updates")).PerformClick();Wait(()=>!Field<bool>(form,"busy"),"future data update",180);
                    Check(f.Version==next.Manifest.version,"Permanent launcher did not install the future ZIP: "+Field<Label>(form,"status").Text);
                }
                Check(Paths.Hash(launcher)==launcherHash&&!InstalledBuild.Inspect(f.User).NeedsRepair,"Future update changed launcher or failed integrity");f.Preserved();checks.Add("Unchanged launcher installs and verifies a future gameplay version greater than its own internal build");
                int launched=0;SetupUpdates.LaunchGame=_=>launched++;
                using(var form=new LauncherForm(f.User,f.Game)) {
                    Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Play Together")).PerformClick();Wait(()=>form.IsDisposed||!Field<bool>(form,"busy"),"checked future Play",180);Check(launched==1,"Verified future gameplay did not launch: "+(form.IsDisposed?"closed":Field<Label>(form,"status").Text)+" / requests "+nextClient.Requests);
                }
                Check(nextClient.Requests>=7,"Play did not make a fresh GitHub check");checks.Add("Play always rechecks GitHub and can launch a future verified mod with the permanent binary");
                string file=Path.Combine(Path.GetDirectoryName(f.Metadata),"main.lua");File.AppendAllText(file,"-- damaged");Check(InstalledBuild.Inspect(f.User).NeedsRepair,"Corrupt future build was trusted");
                using(var form=new LauncherForm(f.User,f.Game)){Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Check updates")).PerformClick();Wait(()=>!Field<bool>(form,"busy"),"same-version repair",180);Check(!InstalledBuild.Inspect(f.User).NeedsRepair,"Future build was not repaired");}
                checks.Add("Same-version damage in a future mod is repaired from its signed ZIP without reverting to embedded files");
                string metadataBefore=File.ReadAllText(f.Metadata),saveBefore=File.ReadAllText(f.Save);BundleUpdates.ConfigureEngine=engine=>engine.AfterFirstReplacement=()=>{throw new Exception("Synthetic replacement failure");};
                MustReject(()=>BundleUpdates.Install(next,f.User,f.Game,_=>{}));BundleUpdates.ConfigureEngine=null;
                Check(File.ReadAllText(f.Metadata)==metadataBefore&&File.ReadAllText(f.Save)==saveBefore&&!InstalledBuild.Inspect(f.User).NeedsRepair,"Failed ZIP application did not roll back");checks.Add("Failed data installation restores previous mod files, receipt and saves");
                SetupUpdates.Running=()=>true;MustReject(()=>BundleUpdates.Install(next,f.User,f.Game,_=>{}));SetupUpdates.Running=()=>false;f.Preserved();checks.Add("Running-game guard blocks data updates before changing game files");
                MustReject(()=>new BundleClient(current).Latest(scratch,next.Manifest.version));MustReject(()=>BundleUpdates.Install(now,f.User,f.Game,_=>{}));Check(f.Version==next.Manifest.version,"Direct bundle application downgraded the mod");checks.Add("Signed bundle high-water mark is checked again at installation and refuses a downgrade");
                using(var held=new FileStream(Path.Combine(UpdateStorage.Root(f.User),"installation.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None))MustReject(()=>BundleUpdates.Install(next,f.User,f.Game,_=>{}));
                Check(f.Version==next.Manifest.version,"Concurrent update changed installed files");checks.Add("Concurrent launcher copies cannot install over one another");
                var blocked=new Fixture(parent,"failed-check");SetupUpdates.ClientFactory=_=>new BundleClient(current){Fail=true};
                using(var form=new SetupForm(blocked.User,blocked.Game,false)){Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Check & install latest")).PerformClick();Wait(()=>!Field<bool>(form,"busy"),"failed latest check");Check(!Field<bool>(form,"done")&&!Field<LinkLabel>(form,"offline").Visible&&blocked.Version=="0.8.0-dev","Failed network check offered or installed a stale bundle");}
                checks.Add("Failed latest check does not install an old embedded build or expose an offline install shortcut");
                File.WriteAllText(Path.Combine(parent,"bundle-results.json"),new JavaScriptSerializer().Serialize(new{passed=checks.Count,failed=0,checks=checks,current=now.Manifest.version,future=next.Manifest.version,launcher_sha256=launcherHash,network="Signed local fixtures through production forms; no live game touched",live_game_changed=false}));return 0;
            }catch(Exception error){File.WriteAllText(Path.Combine(parent,"bundle-results.json"),new JavaScriptSerializer().Serialize(new{passed=checks.Count,failed=1,checks=checks,error=error.ToString()}));return 1;}
            finally{SetupUpdates.ClientFactory=factory;SetupUpdates.Running=running;SetupUpdates.Handoff=handoff;SetupUpdates.LaunchGame=launch;SetupUpdates.TestCurrentVersion=test;BundleUpdates.ConfigureEngine=configure;SetupForm.PreviewMode=ps;LauncherForm.PreviewMode=pl;}
        }
    }
}
