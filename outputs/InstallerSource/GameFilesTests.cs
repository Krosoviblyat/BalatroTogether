using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Web.Script.Serialization;
using System.Windows.Forms;
namespace TogetherSetup {
    internal static class GameFilesTests {
        static void Check(bool value,string message){if(!value)throw new Exception(message);}
        static GameFilesException Refused(Action action){try{action();}catch(GameFilesException e){return e;}throw new Exception("Incomplete game was accepted");}
        static IEnumerable<Control> All(Control p){foreach(Control c in p.Controls){yield return c;foreach(var x in All(c))yield return x;}}
        static void Show(Form f){f.ShowInTaskbar=false;f.StartPosition=FormStartPosition.Manual;f.Location=new Point(-32000,-32000);f.Show();Application.DoEvents();}
        static T Field<T>(object o,string name){return (T)o.GetType().GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).GetValue(o);}
        static void Wait(Func<bool> done){var t=DateTime.UtcNow;while(!done()){Application.DoEvents();System.Threading.Thread.Sleep(15);if((DateTime.UtcNow-t).TotalSeconds>90)throw new Exception("Form test timed out");}}
        public static int Run(string output) {
            string root=Paths.Full(output);Directory.CreateDirectory(root);var checks=new List<string>();
            var running=SetupUpdates.Running;var launch=SetupUpdates.LaunchGame;var error=SetupUpdates.ShowGameError;var factory=SetupUpdates.ClientFactory;
            bool ps=SetupForm.PreviewMode,pl=LauncherForm.PreviewMode;
            try {
                SetupForm.PreviewMode=true;LauncherForm.PreviewMode=true;SetupUpdates.Running=()=>false;
                string owned=Detection.Find();GameFiles.Validate(owned,Build.GameHash);
                string game=Path.Combine(root,"Private Steam library with spaces","Balatro");Directory.CreateDirectory(game);
                File.Copy(Path.Combine(owned,"Balatro.exe"),Path.Combine(game,"Balatro.exe"));
                foreach(string name in GameFiles.Required)File.Copy(Path.Combine(owned,name),Path.Combine(game,name));
                GameFiles.Validate(game,Build.GameHash);checks.Add("Complete owned Windows game passes from a folder with spaces; files are copied only into private test paths");
                var user=new UserPaths {Sid=System.Security.Principal.WindowsIdentity.GetCurrent().User.Value,Profile=root,Roaming=Path.Combine(root,"Roaming"),Local=Path.Combine(root,"Local"),Desktop=Path.Combine(root,"Desktop")};Directory.CreateDirectory(user.Desktop);
                string saves=Path.Combine(user.Roaming,"Balatro");Directory.CreateDirectory(Path.Combine(saves,"1"));File.WriteAllText(Path.Combine(saves,"1","save.jkr"),"PRESERVE");
                Func<Installer> engine=()=>new Installer(game,saves,Path.Combine(root,"Backups"),Path.Combine(root,"Stage"),Build.GameHash,()=>false,_=>{});
                foreach(string name in GameFiles.Required) {
                    string file=Path.Combine(game,name);File.Delete(file);var e=Refused(()=>engine().Install());
                    Check(e.Files.Contains(name)&&e.Message.Contains("Verify integrity")&&e.Message.Contains(game),"No actionable file/path diagnosis");
                    Check(!Directory.Exists(Path.Combine(saves,"Mods"))&&!Directory.Exists(Path.Combine(root,"Backups"))&&!Directory.Exists(Path.Combine(root,"Stage"))&&!File.Exists(Path.Combine(game,"winmm.dll")),"Incomplete-game guard ran after changes");
                    Check(File.ReadAllText(Path.Combine(saves,"1","save.jkr"))=="PRESERVE","Save changed on refusal");File.Copy(Path.Combine(owned,name),file);
                    checks.Add("Missing "+name+" blocks before loader, mods, backups or staging changes");
                }
                string sdl=Path.Combine(game,"SDL2.dll");File.WriteAllText(sdl,"bad native DLL");Check(Refused(()=>GameFiles.Validate(game,Build.GameHash)).Files.Contains("SDL2.dll"),"Corrupt DLL accepted");File.Copy(Path.Combine(owned,"SDL2.dll"),sdl,true);checks.Add("Truncated/non-PE native DLL is rejected");
                using(var stream=File.Open(sdl,FileMode.Open,FileAccess.ReadWrite))using(var reader=new BinaryReader(stream))using(var writer=new BinaryWriter(stream)){stream.Position=0x3c;int offset=reader.ReadInt32();stream.Position=offset+4;writer.Write((ushort)0x14c);}
                Check(Refused(()=>GameFiles.Validate(game,Build.GameHash)).Files.Contains("SDL2.dll"),"Wrong architecture accepted");File.Copy(Path.Combine(owned,"SDL2.dll"),sdl,true);checks.Add("Wrong-architecture native DLL is rejected");
                foreach(string name in GameFiles.Required)File.Delete(Path.Combine(game,name));Check(Refused(()=>GameFiles.Validate(game,Build.GameHash)).Files.Length==GameFiles.Required.Length,"EXE-only folder not diagnosed");checks.Add("An EXE-only folder lists all missing runtime files");
                int network=0,launched=0,dialogs=0;string diagnosis=null;
                SetupUpdates.ClientFactory=_=>{network++;throw new Exception("Broken game should not check/download an update");};
                SetupUpdates.LaunchGame=_=>launched++;SetupUpdates.ShowGameError=(owner,message)=>{dialogs++;diagnosis=message;};
                using(var form=new SetupForm(user,game,false)) {
                    Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Check & install latest")).PerformClick();Wait(()=>!Field<bool>(form,"busy"));
                    Check(network==0&&dialogs==1&&diagnosis.Contains("SDL2.dll")&&diagnosis.Contains("love.dll")&&diagnosis.Contains("lua51.dll")&&Field<Label>(form,"status").Text.Contains("No installation changes"),"Production setup did not block clearly");
                    Check(All(form).Any(c=>c is LinkLabel&&c.Text=="Mods: "+Path.Combine(user.Roaming,"Balatro","Mods")),"Mods destination missing from setup");
                    using(var bitmap=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height));bitmap.Save(Path.Combine(root,"incomplete-game-setup.png"));}form.Close();
                }
                checks.Add("Production Install button stops before any network call and explains Steam repair plus the separate AppData mod destination");
                UpdateStorage.Save(user,new UpdateSettings {game=game,automatic=false,highest_version=Build.Version});
                using(var form=new LauncherForm(user,game)) {Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Play Together")).PerformClick();Wait(()=>!Field<bool>(form,"busy"));Check(launched==0&&dialogs==2&&Field<Label>(form,"status").Text.Contains("No game was launched"),"Launcher allowed broken native start");form.Close();}
                checks.Add("Production Play button refuses an EXE-only game without starting a native process");
                foreach(string name in GameFiles.Required)File.Copy(Path.Combine(owned,name),Path.Combine(game,name));engine().Install();
                System.Diagnostics.ProcessStartInfo info=null;SetupUpdates.LaunchGame=value=>{info=value;launched++;};
                using(var form=new LauncherForm(user,game)){Show(form);((Button)All(form).Single(c=>c is Button&&c.Text=="Play Together")).PerformClick();Wait(()=>form.IsDisposed);}
                Check(launched==1&&Paths.Equal(info.FileName,Path.Combine(game,"Balatro.exe"))&&Paths.Equal(info.WorkingDirectory,game)&&info.Arguments=="--disable-console","Wrong launch target/working directory");Check(File.ReadAllText(Path.Combine(saves,"1","save.jkr"))=="PRESERVE","Save changed");
                checks.Add("With complete game and installed mods, production Play targets the original game folder and sets that folder as its working directory; native launch is intercepted");
                File.WriteAllText(Path.Combine(root,"game-files-results.json"),new JavaScriptSerializer().Serialize(new {passed=checks.Count,failed=0,checks=checks,live_game_changed=false,game_launch="Intercepted; no native game process opened",redistribution="Runtime DLL copies stay inside private QA folders and are never packaged"}));return 0;
            } catch(Exception e){File.WriteAllText(Path.Combine(root,"game-files-results.json"),new JavaScriptSerializer().Serialize(new {passed=checks.Count,failed=1,error=e.ToString()}));return 1;}
            finally{SetupUpdates.Running=running;SetupUpdates.LaunchGame=launch;SetupUpdates.ShowGameError=error;SetupUpdates.ClientFactory=factory;SetupForm.PreviewMode=ps;LauncherForm.PreviewMode=pl;}
        }
    }
}
