// Private fixture tests drive the production Windows forms; never a live install.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
namespace TogetherSetup {
    internal static partial class SetupFlowTests {
        public static int NetworkProbe(string parent) {
            System.Net.ServicePointManager.SecurityProtocol=System.Net.SecurityProtocolType.Tls12;
            Directory.CreateDirectory(parent);bool success=false;string message=null,version=null;
            try{var offer=new GitHubUpdates("").Find(parent,"0.8.0-dev","0.8.0-dev");success=offer!=null;if(success)version=offer.manifest.version;}
            catch(Exception e){message=e.Message;}
            File.WriteAllText(Path.Combine(parent,"unauthenticated-network-result.json"),new JavaScriptSerializer().Serialize(new {public_release_verified=success,version=version,message=message,network="Real unauthenticated GitHub API and signed release manifest requests; no token read or transmitted",game_files_changed=false}));
            return success?0:1;
        }
        sealed class FixtureClient:GitHubUpdates {
            readonly string list;readonly Dictionary<string,string> assets=new Dictionary<string,string>();
            public int Requests;public bool Fail;
            public FixtureClient(string release):base("") {
                var entries=new List<object>();long id=100;
                var m=new JavaScriptSerializer().Deserialize<UpdateManifest>(File.ReadAllText(Path.Combine(release,"Update-v2.json")));
                foreach(string name in new[]{"Update-v2.json","Update-v2.sig",m.asset}) {
                    assets.Add("https://api.github.com/repos/"+UpdatePolicy.Repository+"/releases/assets/"+id,Path.Combine(release,name));entries.Add(new {id=id++,name=name,state="uploaded"});
                }
                list=new JavaScriptSerializer().Serialize(new[]{new {tag_name="v"+m.version,draft=false,prerelease=true,assets=entries}});
            }
            public override void Download(string api,string target,long limit,Action<long> progress) {
                Requests++;if(Fail)throw new Exception("Public update download unavailable. No latest-version check completed.");
                if(api.EndsWith("/releases?per_page=100"))File.WriteAllText(target,list,UpdatePolicy.Utf8);
                else {string source;if(!assets.TryGetValue(api,out source))throw new Exception("Unexpected fixture request");File.Copy(source,target,false);}
                long length=new FileInfo(target).Length;if(length>limit)throw new Exception("Oversized fixture response");if(progress!=null)progress(length);
            }
        }
        sealed class Fixture {
            public UserPaths User;public string Root,Game,Metadata,Save;
            public Fixture(string parent,string name) {
                Root=Path.Combine(parent,name);Directory.CreateDirectory(Root);Game=Path.Combine(Root,"Game");Directory.CreateDirectory(Game);
                string owned=Path.Combine(Detection.Find(),"Balatro.exe");if(!File.Exists(owned)||Paths.Hash(owned)!=Build.GameHash)throw new Exception("Owned supported game unavailable for private fixture copy");
                File.Copy(owned,Path.Combine(Game,"Balatro.exe"),false);
                foreach(string runtime in GameFiles.Required)File.Copy(Path.Combine(Path.GetDirectoryName(owned),runtime),Path.Combine(Game,runtime),false);
                User=new UserPaths {Sid=System.Security.Principal.WindowsIdentity.GetCurrent().User.Value,Profile=Root,Local=Path.Combine(Root,"Local"),Roaming=Path.Combine(Root,"Roaming"),Desktop=Path.Combine(Root,"Desktop")};Directory.CreateDirectory(User.Desktop);
                string saves=Path.Combine(User.Roaming,"Balatro");Directory.CreateDirectory(Path.Combine(saves,"1"));Save=Path.Combine(saves,"1","save.jkr");File.WriteAllText(Save,"preserve unfinished party fixture");
                Metadata=Path.Combine(saves,"Mods","BalatroTogether","BalatroTogether.json");Directory.CreateDirectory(Path.GetDirectoryName(Metadata));File.WriteAllText(Metadata,"{\"id\":\"BalatroTogether\",\"version\":\"0.8.0-dev\"}");File.WriteAllText(Path.Combine(Path.GetDirectoryName(Metadata),"main.lua"),"OLD FIXTURE");
                UpdateStorage.Save(User,new UpdateSettings {game=Game,automatic=false,highest_version="0.8.0-dev"});
            }
            public string Version {get{return Convert.ToString(new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(Metadata))["version"]);}}
            public void Preserved(){Check(File.ReadAllText(Save)=="preserve unfinished party fixture","Native save changed");}
        }
        static void Check(bool value,string why){if(!value)throw new Exception(why);}
        static void Wait(Func<bool> done,string why,int seconds=90) {
            var watch=Stopwatch.StartNew();while(!done()){Application.DoEvents();Thread.Sleep(15);if(watch.Elapsed.TotalSeconds>seconds)throw new Exception("Timed out: "+why);}Application.DoEvents();
        }
        static IEnumerable<Control> All(Control parent){foreach(Control c in parent.Controls){yield return c;foreach(var child in All(c))yield return child;}}
        static T Field<T>(object o,string name){return (T)o.GetType().GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).GetValue(o);}
        static void Show(Form form){form.ShowInTaskbar=false;form.StartPosition=FormStartPosition.Manual;form.Location=new Point(-32000,-32000);form.Show();Application.DoEvents();}
        static void Engine(string exe,Fixture f,string stageName,bool shortcut) {
            var asm=Assembly.LoadFile(Path.GetFullPath(exe));var t=asm.GetType("TogetherSetup.Installer",true);
            object engine=Activator.CreateInstance(t,BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic,null,new object[]{f.Game,Path.Combine(f.User.Roaming,"Balatro"),Path.Combine(f.Root,stageName+"Backups"),Path.Combine(f.Root,stageName+"Stage"),Build.GameHash,new Func<bool>(()=>false),new Action<string>(_=>{})},null);
            t.GetMethod("Install").Invoke(engine,null);
            if(shortcut) {
                var context=Activator.CreateInstance(asm.GetType("TogetherSetup.UserPaths"),true);
                foreach(string name in new[]{"Sid","Profile","Local","Roaming","Desktop"})context.GetType().GetField(name).SetValue(context,typeof(UserPaths).GetField(name).GetValue(f.User));
                string backup=(string)t.GetField("Backup").GetValue(engine);
                asm.GetType("TogetherSetup.Detection").GetMethod("Shortcut").Invoke(null,new object[]{context,f.Game,backup});
            }
        }
        public static int Run(string release,string parent,string oldSetup) {
            Directory.CreateDirectory(parent);var checks=new List<string>();
            var factory=SetupUpdates.ClientFactory;var running=SetupUpdates.Running;var handoff=SetupUpdates.Handoff;string previous=SetupUpdates.TestCurrentVersion;
            bool oldSetupPreview=SetupForm.PreviewMode,oldLauncherPreview=LauncherForm.PreviewMode;
            try {
                SetupUpdates.Running=()=>false;SetupForm.PreviewMode=true;LauncherForm.PreviewMode=true;
                var old=new Fixture(parent,"old");Engine(oldSetup,old,"Old",false);
                Check(old.Version=="0.8.0-dev","The actual old EXE did not reproduce its bundled version");old.Preserved();checks.Add("Actual 0.8.0 EXE installs its embedded 0.8.0 payload; it is not a latest-release bootstrap");
                var f=new Fixture(parent,"online");var client=new FixtureClient(release);SetupUpdates.ClientFactory=_=>client;SetupUpdates.TestCurrentVersion="0.8.0-dev";
                int applied=0;SetupUpdates.Handoff=(exe,game)=>{Check(Paths.Equal(game,f.Game),"Wrong handoff game");Check(Paths.Hash(exe)==Paths.Hash(Path.Combine(release,"BalatroTogether-Setup-0.8.2-dev.exe")),"Wrong staged production installer");Engine(exe,f,"Remote",true);applied++;};
                using(var form=new SetupForm(f.User,f.Game,false)) {
                    Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Check & install latest")).PerformClick();Wait(()=>form.IsDisposed,"online setup handoff");
                }
                Check(applied==1&&client.Requests>=4&&f.Version=="0.8.2-dev","Online setup did not install the real newer payload");f.Preserved();checks.Add("Production setup button selects, downloads, verifies and hands off the real signed 0.8.2 EXE from a simulated 0.8.0 starting version");
                Check(File.Exists(Path.Combine(f.User.Desktop,"Play Balatro Together.lnk"))&&UpdateStorage.Load(f.User).highest_version=="0.8.2-dev","Actual child installer did not commit launcher/shortcut");checks.Add("Actual downloaded installer engine applies gameplay files, preserves saves, creates its launcher and records the installed update");
                var blocked=new Fixture(parent,"blocked");var denied=new FixtureClient(release){Fail=true};SetupUpdates.ClientFactory=_=>denied;SetupUpdates.Handoff=(exe,game)=>{throw new Exception("A failed check attempted handoff");};
                using(var form=new SetupForm(blocked.User,blocked.Game,false)) {
                    Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Check & install latest")).PerformClick();Wait(()=>!Field<bool>(form,"busy"),"authentication refusal");
                    Check(blocked.Version=="0.8.0-dev"&&Field<LinkLabel>(form,"offline").Visible&&Field<Label>(form,"status").Text.Contains("Update check failed"),"Failed check silently installed or claimed latest");
                    using(var bitmap=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height));bitmap.Save(Path.Combine(parent,"access-required.png"));}
                    checks.Add("Failed public download leaves old gameplay untouched and shows an explicit offline choice instead of false update success");
                    typeof(SetupForm).GetMethod("Start",BindingFlags.Instance|BindingFlags.NonPublic).Invoke(form,new object[]{false});Wait(()=>Field<bool>(form,"done"),"explicit offline install");
                    Check(Field<Label>(form,"result").Text.Contains("OFFLINE")&&Field<Label>(form,"result").Text.Contains("NOT checked")&&Field<Label>(form,"result").Text.Contains(InstalledBuild.GameplayVersion),"Offline install falsely claimed latest or hid gameplay version");blocked.Preserved();
                    checks.Add("Explicit offline choice installs the verified bundle and visibly says the latest release was not checked");form.Close();
                }
                var l=new Fixture(parent,"play");var playClient=new FixtureClient(release);SetupUpdates.ClientFactory=_=>playClient;SetupUpdates.Handoff=(exe,game)=>{Engine(exe,l,"Play",false);applied++;};
                using(var form=new LauncherForm(l.User,l.Game)) {
                    Show(form);((CheckBox)All(form).Single(c=>c is CheckBox&&c.Text.StartsWith("Keep Together"))).Checked=true;
                    ((Button)All(form).Single(c=>c is Button&&c.Text=="Play Together")).PerformClick();Wait(()=>form.IsDisposed,"Play update check");
                }
                Check(playClient.Requests>=4&&l.Version=="0.8.2-dev","Play did not check and apply newer gameplay");checks.Add("Production Play button performs its own online update check when automatic updates are enabled");
                var failedLaunch=new Fixture(parent,"launchfail");SetupUpdates.ClientFactory=_=>new FixtureClient(release){Fail=true};SetupUpdates.Handoff=(exe,game)=>{throw new Exception("Failed online check repaired silently");};
                using(var form=new LauncherForm(failedLaunch.User,failedLaunch.Game)) {
                    Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Check updates")).PerformClick();Wait(()=>!Field<bool>(form,"busy"),"launcher authentication refusal");
                    Check(failedLaunch.Version=="0.8.0-dev"&&Field<Label>(form,"status").Text.Contains("Public update download unavailable")&&Field<Button>(form,"play").Text=="Play installed","Launcher hid check failure behind offline repair");form.Close();
                }
                checks.Add("A failed launcher check cannot silently repair from an old embedded bundle");
                var settings=UpdateStorage.Load(blocked.User);settings.highest_version="9.0.0";UpdateStorage.Save(blocked.User,settings);bool refused=false;
                try{SetupUpdates.CanInstallBundle(blocked.User);}catch{refused=true;}Check(refused,"Recorded newer setup was downgraded");checks.Add("Setup respects actual installed version and the update high-water mark before installing its local bundle");
                File.WriteAllText(Path.Combine(parent,"setup-flow-results.json"),new JavaScriptSerializer().Serialize(new {passed=checks.Count,failed=0,checks=checks,network="Fixture GitHub responses carrying actual signed release bytes; no authenticated HTTP claimed",handoff="Production setup and launcher buttons; actual downloaded installer engine and shortcut commit; game launch intercepted",live_game_changed=false}));return 0;
            } catch(Exception e){File.WriteAllText(Path.Combine(parent,"setup-flow-results.json"),new JavaScriptSerializer().Serialize(new {passed=checks.Count,failed=1,error=e.ToString()}));return 1;}
            finally{SetupUpdates.ClientFactory=factory;SetupUpdates.Running=running;SetupUpdates.Handoff=handoff;SetupUpdates.TestCurrentVersion=previous;SetupForm.PreviewMode=oldSetupPreview;LauncherForm.PreviewMode=oldLauncherPreview;}
        }
    }
}
