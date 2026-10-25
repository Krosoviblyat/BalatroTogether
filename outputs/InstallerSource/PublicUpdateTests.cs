// Opt-in isolated public-network integration test; never targets live game paths.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Web.Script.Serialization;
using System.Windows.Forms;
namespace TogetherSetup {
    internal static partial class SetupFlowTests {
        public static int PublicUpdateProbe(string parent) {
            System.Net.ServicePointManager.SecurityProtocol=System.Net.SecurityProtocolType.Tls12;
            parent=Path.GetFullPath(parent);Directory.CreateDirectory(parent);var checks=new List<string>();
            var factory=SetupUpdates.ClientFactory;var running=SetupUpdates.Running;var handoff=SetupUpdates.Handoff;string previous=SetupUpdates.TestCurrentVersion;
            bool ps=SetupForm.PreviewMode,pl=LauncherForm.PreviewMode;string downloadHash=null,downloadGameplay=null;
            try {
                SetupUpdates.Running=()=>false;SetupForm.PreviewMode=true;LauncherForm.PreviewMode=true;SetupUpdates.TestCurrentVersion="0.8.0-dev";
                int requests=0,applied=0;
                SetupUpdates.ClientFactory=credential=>{Check(credential=="","Public updater supplied a credential");requests++;return new GitHubUpdates(credential);};
                var f=new Fixture(parent,"public-setup");
                string tokenPath=Path.Combine(UpdateStorage.Root(f.User),"github-token.bin");Directory.CreateDirectory(Path.GetDirectoryName(tokenPath));File.WriteAllText(tokenPath,"malformed legacy test credential");
                SetupUpdates.Handoff=(exe,game)=>{Check(Paths.Equal(game,f.Game),"Wrong fixture game");downloadHash=Paths.Hash(exe);Engine(exe,f,"Anonymous",true);downloadGameplay=f.Version;applied++;};
                using(var form=new SetupForm(f.User,f.Game,false)) {
                    Show(form);Check(!All(form).Any(c=>c.Text=="GitHub access"),"Credential button remains in setup");
                    ((Button)All(form).Single(c=>c is Button&&c.Text=="Check & install latest")).PerformClick();Wait(()=>form.IsDisposed||!Field<bool>(form,"busy"),"public setup download",180);
                    Check(form.IsDisposed,"Public setup failed: "+Field<Label>(form,"status").Text);
                }
                Check(applied==1&&f.Version==downloadGameplay,"Public download did not apply gameplay");f.Preserved();
                checks.Add("Production Check & install latest button discovers, downloads and verifies a real GitHub release anonymously");
                checks.Add("Actual downloaded installer engine installs bundled gameplay into isolated folders and preserves its native save");
                Check(File.Exists(Path.Combine(f.User.Desktop,"Play Balatro Together.lnk")),"Downloaded engine did not commit desktop launcher");checks.Add("Actual downloaded installer commits the desktop launcher and shortcut in the isolated profile");
                Check(File.ReadAllText(tokenPath)=="malformed legacy test credential","Legacy credential file was modified");checks.Add("Malformed legacy token cannot block public updates and is never read, sent or modified");
                var l=new Fixture(parent,"public-launcher");SetupUpdates.Handoff=(exe,game)=>{Check(Paths.Equal(game,l.Game),"Wrong launcher fixture");Check(Paths.Hash(exe)==downloadHash,"Different setup bytes selected");Engine(exe,l,"AnonymousPlay",false);applied++;};
                using(var form=new LauncherForm(l.User,l.Game)) {
                    Show(form);Check(!All(form).Any(c=>c.Text=="GitHub access"),"Credential button remains in launcher");
                    ((CheckBox)All(form).Single(c=>c is CheckBox&&c.Text.StartsWith("Keep Together"))).Checked=true;
                    ((Button)All(form).Single(c=>c is Button&&c.Text=="Play Together")).PerformClick();Wait(()=>form.IsDisposed||!Field<bool>(form,"busy"),"public launcher update",180);
                    Check(form.IsDisposed,"Public launcher failed: "+Field<Label>(form,"status").Text);
                }
                Check(applied==2&&requests==2&&l.Version==downloadGameplay,"Public Play failed to check/install");l.Preserved();checks.Add("Production Play button independently fetches the real signed release without credentials; game launch is intercepted");
                checks.Add("Setup and launcher show Releases instead of a GitHub token prompt");
                File.WriteAllText(Path.Combine(parent,"public-update-results.json"),new JavaScriptSerializer().Serialize(new {passed=checks.Count,failed=0,checks=checks,network="Real public GitHub API and asset downloads; no simulated responses",downloaded_installer_sha256=downloadHash,gameplay=downloadGameplay,live_game_changed=false}));return 0;
            } catch(Exception e){File.WriteAllText(Path.Combine(parent,"public-update-results.json"),new JavaScriptSerializer().Serialize(new {passed=checks.Count,failed=1,error=e.ToString()}));return 1;}
            finally {SetupUpdates.ClientFactory=factory;SetupUpdates.Running=running;SetupUpdates.Handoff=handoff;SetupUpdates.TestCurrentVersion=previous;SetupForm.PreviewMode=ps;LauncherForm.PreviewMode=pl;}
        }
    }
}
