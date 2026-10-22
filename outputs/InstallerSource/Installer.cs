// Original Balatro Together installer. MIT; see LICENSE.txt.
// C# 5 / .NET Framework 4.8. Installs only the embedded, checksummed payload.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Balatro Together Installer")]
[assembly: AssemblyProduct("Balatro Together")]
[assembly: AssemblyCompany("Balatro Together contributors")]
[assembly: AssemblyVersion("0.6.2.0")]
[assembly: AssemblyFileVersion("0.6.2.0")]

namespace TogetherSetup {
    internal sealed class UserPaths {
        public string Sid, Profile, Roaming, Local, Desktop;
        public static UserPaths Current() {
            return new UserPaths { Sid=WindowsIdentity.GetCurrent().User.Value,
                Profile=Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                Roaming=Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                Local=Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                Desktop=Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory) };
        }
        public void Validate() {
            if (!Regex.IsMatch(Sid ?? "", @"^S-1-5-[0-9-]+$")) throw new Exception("Invalid user profile.");
            using (var key=Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"+Sid)) {
                if (key==null || !Paths.Equal(Profile,Environment.ExpandEnvironmentVariables((string)key.GetValue("ProfileImagePath")))) throw new Exception("The original Windows profile could not be verified.");
            }
            using (var key=Registry.Users.OpenSubKey(Sid+@"\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders")) {
                foreach (var pair in new [] {new[]{"AppData",Roaming,@"AppData\Roaming"},new[]{"Local AppData",Local,@"AppData\Local"},new[]{"Desktop",Desktop,"Desktop"}}) {
                    string expected=key==null ? null : key.GetValue(pair[0],null,RegistryValueOptions.DoNotExpandEnvironmentNames) as string;
                    expected=expected==null ? Path.Combine(Profile,pair[2]) : expected.Replace("%USERPROFILE%",Profile);
                    expected=Environment.ExpandEnvironmentVariables(expected);
                    if (!Paths.Equal(pair[1],expected)) throw new Exception("The original user's folder location could not be verified: "+pair[0]);
                }
            }
        }
    }
    internal static class Paths {
        public static string Full(string p) { return Path.GetFullPath(p).TrimEnd(Path.DirectorySeparatorChar); }
        public static bool Equal(string a,string b) { return a!=null && b!=null && String.Equals(Full(a),Full(b),StringComparison.OrdinalIgnoreCase); }
        public static void Within(string path,string root) {
            if (!Full(path).StartsWith(Full(root)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new Exception("Unsafe destination path.");
        }
        public static void NoLinks(string path) {
            string current=Full(path);
            while (!String.IsNullOrEmpty(current)) {
                if ((File.Exists(current)||Directory.Exists(current)) && (File.GetAttributes(current)&FileAttributes.ReparsePoint)!=0) throw new Exception("A linked folder needs manual installation: "+current);
                current=Path.GetDirectoryName(current);
            }
        }
        public static void CopyTree(string source,string target,Func<string,bool> skip) {
            NoLinks(source); NoLinks(target); Directory.CreateDirectory(target);
            foreach (string p in Directory.GetFileSystemEntries(source)) {
                if (skip!=null && skip(Path.GetFileName(p))) continue;
                NoLinks(p); string dest=Path.Combine(target,Path.GetFileName(p));
                if (Directory.Exists(p)) CopyTree(p,dest,null); else File.Copy(p,dest,false);
            }
        }
        public static void RemoveOwned(string path,string parent) {
            Within(path,parent); NoLinks(path);
            if (!Directory.Exists(path)) return;
            foreach (string p in Directory.GetFileSystemEntries(path)) {
                NoLinks(p); if (Directory.Exists(p)) RemoveOwned(p,path); else { File.SetAttributes(p,FileAttributes.Normal); File.Delete(p); }
            }
            Directory.Delete(path);
        }
        public static string Hash(string file) { using (var f=File.OpenRead(file)) using (var h=SHA256.Create()) return BitConverter.ToString(h.ComputeHash(f)).Replace("-","").ToLowerInvariant(); }
        public static void CheckWrite(string dir) {
            NoLinks(dir); string p=Path.Combine(dir,".bt-install-check-"+Guid.NewGuid().ToString("N")+".tmp");
            using (var f=new FileStream(p,FileMode.CreateNew,FileAccess.Write,FileShare.None)) f.WriteByte(0);
            File.Delete(p);
        }
        public static void Move(string source,string target) {
            // Windows scanners can briefly hold a newly copied source directory.
            for(int attempt=0;;attempt++) {
                NoLinks(source); NoLinks(target);
                try { if(File.Exists(source)) File.Move(source,target); else Directory.Move(source,target); return; }
                catch(IOException) { if(attempt>=6 || Directory.Exists(target) || File.Exists(target)) throw; }
                catch(UnauthorizedAccessException) { if(attempt>=6 || Directory.Exists(target) || File.Exists(target)) throw; }
                System.Threading.Thread.Sleep(80*(attempt+1));
            }
        }
        public static string Quote(string s) { return "\""+s.Replace("\"", "\\\"")+"\""; }
    }
    internal static class Payload {
        public static string Extract(string parent) {
            Directory.CreateDirectory(parent); Paths.NoLinks(parent);
            string stage=Path.Combine(parent,Guid.NewGuid().ToString("N")); Directory.CreateDirectory(stage);
            using (var input=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip")) {
                if (input==null) throw new Exception("The installer payload is missing.");
                using (var h=SHA256.Create()) { string hash=BitConverter.ToString(h.ComputeHash(input)).Replace("-","").ToLowerInvariant(); if (hash!=Build.PayloadHash) throw new Exception("The installer payload failed its integrity check. Download it again."); }
                input.Position=0;
                using (var archive=new ZipArchive(input,ZipArchiveMode.Read)) foreach (var e in archive.Entries) {
                    if (!e.FullName.StartsWith("Mods/") && e.FullName!="Game Folder/winmm.dll") continue;
                    if (e.FullName.EndsWith("/")) continue;
                    string target=Path.GetFullPath(Path.Combine(stage,e.FullName.Replace('/',Path.DirectorySeparatorChar)));
                    Paths.Within(target,stage); Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using (var output=new FileStream(target,FileMode.CreateNew)) using (var f=e.Open()) f.CopyTo(output);
                }
            }
            return stage;
        }
    }
    internal sealed class Installer {
        public string Backup;
        public readonly string Game, Saves, BackupRoot, StageRoot;
        readonly string expectedGame; readonly Func<bool> running; readonly Action<string> progress;
        public Action AfterFirstReplacement;
        public Installer(string game,string saves,string backupRoot,string stageRoot,string gameHash,Func<bool> busy,Action<string> report) {
            Game=Paths.Full(game); Saves=Paths.Full(saves); BackupRoot=Paths.Full(backupRoot); StageRoot=Paths.Full(stageRoot); expectedGame=gameHash; running=busy; progress=report;
        }
        static IEnumerable<string> ModIds(string folder) {
            var ids=new List<string>();
            foreach (string f in Directory.GetFiles(folder,"*.json",SearchOption.TopDirectoryOnly)) {
                Paths.NoLinks(f);
                if (new FileInfo(f).Length>65536) continue;
                try { var d=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(f)); if (d!=null && d.ContainsKey("id")) ids.Add(Convert.ToString(d["id"])); } catch (ArgumentException) { } catch (InvalidOperationException) { }
            }
            return ids;
        }
        static bool FamilyName(string name,string family) {
            // Recognize release ZIP/folder suffixes and renamed Windows copies.
            // These entries are preserved in full, even if incomplete/corrupt.
            return Regex.IsMatch(name,"^(?:"+family+")(?:$|[-_. (])",RegexOptions.IgnoreCase|RegexOptions.CultureInvariant);
        }
        static string Prefix(string path) {
            Paths.NoLinks(path);
            using(var reader=new StreamReader(path,true)) { char[] buffer=new char[8192]; int n=reader.Read(buffer,0,buffer.Length); return new string(buffer,0,n); }
        }
        static bool LegacyId(string path,HashSet<string> ids) {
            string text=Prefix(path);
            var match=Regex.Match(text,@"(?im)^\s*-{2,}\s*MOD_ID\s*:\s*([A-Za-z0-9_]+)\s*$");
            return match.Success && ids.Contains(match.Groups[1].Value);
        }
        static bool OldLoader(string folder,IEnumerable<string> ids) {
            if (ids.Any(id=>id.Equals("Steamodded",StringComparison.OrdinalIgnoreCase)||id.Equals("SMODS",StringComparison.OrdinalIgnoreCase))) return true;
            if (FamilyName(Path.GetFileName(folder),"Steamodded|smods")) return true;
            // Current layout plus older releases predating src/preflight.
            if (Directory.Exists(Path.Combine(folder,"lovely")) && (File.Exists(Path.Combine(folder,@"src\preflight\loader.lua")) || File.Exists(Path.Combine(folder,@"src\core.lua")))) return true;
            return false;
        }
        static bool LegacyFolder(string folder,HashSet<string> ids) {
            foreach(string file in Directory.GetFiles(folder,"*.lua",SearchOption.TopDirectoryOnly)) {
                if(LegacyId(file,ids)) return true;
            }
            return false;
        }
        static void FindOldMods(string folder,List<string> targets,HashSet<string> conflicts,HashSet<string> legacyIds,int depth) {
            Paths.NoLinks(folder); string name=Path.GetFileName(folder);
            if(FamilyName(name,"Steamodded|smods|Cryptid|Amulet|Talisman")) { targets.Add(folder); return; }
            var ids=ModIds(folder).ToArray();
            if(name.Equals("BalatroTogether",StringComparison.OrdinalIgnoreCase) && !ids.Contains("BalatroTogether",StringComparer.OrdinalIgnoreCase)) throw new Exception("The BalatroTogether destination contains unknown files. Automatic installation stopped.");
            if(OldLoader(folder,ids) || FamilyName(name,"Cryptid|Amulet|Talisman") || ids.Any(id=>conflicts.Contains(id)) || LegacyFolder(folder,legacyIds)) { targets.Add(folder); return; }
            // Unpack wrappers can put a loader/mod two directories below Mods.
            // Do not descend into an unrelated identified mod's own libraries.
            if(depth>=2 || ids.Length>0) return;
            foreach(string child in Directory.GetDirectories(folder)) {
                if(Path.GetFileName(child).StartsWith(".",StringComparison.Ordinal)) continue;
                FindOldMods(child,targets,conflicts,legacyIds,depth+1);
            }
        }
        public void Install() {
            string stage=null, mods=Path.Combine(Saves,"Mods"); bool dllCreated=false;
            var moved=new List<KeyValuePair<string,string>>(); var created=new List<string>();
            try {
                progress("Checking the game and package...");
                if (running()) throw new Exception("Close Balatro and its bot windows, then click Install again. Your current game has not been changed.");
                Paths.NoLinks(Game); Paths.NoLinks(Saves); Paths.NoLinks(BackupRoot); Paths.NoLinks(StageRoot);
                string exe=Path.Combine(Game,"Balatro.exe");
                if (!File.Exists(exe)) throw new Exception("Choose the Steam folder containing Balatro.exe.");
                if (Paths.Hash(exe)!=expectedGame) throw new Exception("This package supports Balatro 1.0.1o-FULL for Windows x64. The selected game build differs; automatic installation stopped.");
                string dll=Path.Combine(Game,"winmm.dll");
                if (File.Exists(Path.Combine(Game,"version.dll"))) throw new Exception("An older loader or another version.dll is already installed. Use the manual guide to identify and back it up before installing.");
                if (File.Exists(dll) && Paths.Hash(dll)!=Build.LovelyHash) throw new Exception("A different winmm.dll is already present. It has not been overwritten. Identify it using the manual guide first.");
                if (!File.Exists(dll)) Paths.CheckWrite(Game);
                Directory.CreateDirectory(Saves); Paths.CheckWrite(Saves);
                var targets=new List<string>();
                var conflicts=new HashSet<string>(new[]{"BalatroTogether","Multiplayer","MultiplayerAPI","BalatroCoop","Talisman","Amulet","Cryptid","Cryptlib","cdataman"},StringComparer.OrdinalIgnoreCase);
                var legacyIds=new HashSet<string>(conflicts,StringComparer.OrdinalIgnoreCase); legacyIds.Add("Steamodded"); legacyIds.Add("SMODS");
                if (Directory.Exists(mods)) foreach (string dir in Directory.GetDirectories(mods)) {
                    if(Path.GetFileName(dir).StartsWith(".",StringComparison.Ordinal)) continue;
                    FindOldMods(dir,targets,conflicts,legacyIds,0);
                }
                if (Directory.Exists(mods)) foreach (string file in Directory.GetFiles(mods)) {
                    string ext=Path.GetExtension(file); string name=Path.GetFileNameWithoutExtension(file);
                    bool lua=ext.Equals(".lua",StringComparison.OrdinalIgnoreCase), archive=ext.Equals(".zip",StringComparison.OrdinalIgnoreCase);
                    bool metadata=ext.Equals(".json",StringComparison.OrdinalIgnoreCase)||ext.Equals(".toml",StringComparison.OrdinalIgnoreCase);
                    if ((lua||archive||metadata) && (FamilyName(name,"Steamodded|smods|Cryptid|Amulet|Talisman") || (lua&&LegacyId(file,legacyIds)))) { Paths.NoLinks(file); targets.Add(file); }
                }
                stage=Payload.Extract(StageRoot);
                Backup=Path.Combine(BackupRoot,DateTime.Now.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N").Substring(0,8)); Directory.CreateDirectory(Backup);
                progress("Backing up your saves and existing mods...");
                Paths.CopyTree(Saves,Path.Combine(Backup,"Saves"),n=>n.Equals("Mods",StringComparison.OrdinalIgnoreCase)||n.Equals("together-bots",StringComparison.OrdinalIgnoreCase));
                string previous=Path.Combine(Backup,"PreviousMods"); Directory.CreateDirectory(previous);
                if (running()) throw new Exception("Balatro was opened during installation. Close it and try again.");
                foreach (string dir in targets) {
                    Paths.Within(dir,mods); string dest=Path.Combine(previous,dir.Substring(mods.Length+1)); Paths.Within(dest,previous); Paths.NoLinks(dir);
                    Directory.CreateDirectory(Path.GetDirectoryName(dest));
                    Paths.Move(dir,dest); moved.Add(new KeyValuePair<string,string>(dir,dest));
                }
                Directory.CreateDirectory(mods);
                foreach (string name in new[]{"smods-26.1002.0","Amulet","Cryptid","BalatroTogether"}) {
                    progress("Installing "+(name=="BalatroTogether" ? "Balatro Together" : name.StartsWith("smods-") ? "Steamodded" : name)+"...");
                    string dest=Path.Combine(mods,name), temp=Path.Combine(mods,".bt-install-"+Guid.NewGuid().ToString("N"));
                    created.Add(temp); Paths.CopyTree(Path.Combine(stage,"Mods",name),temp,null); Paths.Move(temp,dest); created.Remove(temp); created.Add(dest);
                    if (AfterFirstReplacement!=null) { var hook=AfterFirstReplacement; AfterFirstReplacement=null; hook(); }
                }
                progress("Installing Lovely and verifying every file...");
                if (!File.Exists(dll)) { using (var input=File.OpenRead(Path.Combine(stage,@"Game Folder\winmm.dll"))) using (var output=new FileStream(dll,FileMode.CreateNew)) { dllCreated=true; input.CopyTo(output); } }
                if (Paths.Hash(dll)!=Build.LovelyHash) throw new Exception("Lovely verification failed.");
                foreach (string name in new[]{"smods-26.1002.0","Amulet","Cryptid","BalatroTogether"}) {
                    string src=Path.Combine(stage,"Mods",name), dst=Path.Combine(mods,name);
                    foreach (string f in Directory.GetFiles(src,"*",SearchOption.AllDirectories)) { string rel=f.Substring(src.Length+1); if (Paths.Hash(f)!=Paths.Hash(Path.Combine(dst,rel))) throw new Exception("Installed file verification failed: "+rel); }
                }
                File.WriteAllText(Path.Combine(Backup,"INSTALLATION.json"),new JavaScriptSerializer().Serialize(new { version=Build.Version,game=Game,saves=Saves,previousMods=targets,verified=true }));
                progress("Installation complete.");
            } catch (Exception original) {
                var errors=new List<string>();
                foreach (string dir in created.AsEnumerable().Reverse()) try { Paths.RemoveOwned(dir,mods); } catch (Exception e) { errors.Add(e.Message); }
                foreach (var pair in moved.AsEnumerable().Reverse()) try { Paths.Within(pair.Key,mods); Paths.Within(pair.Value,Path.Combine(Backup,"PreviousMods")); Paths.NoLinks(pair.Key); if (!Directory.Exists(pair.Key) && !File.Exists(pair.Key)) Paths.Move(pair.Value,pair.Key); else errors.Add("Restore manually from "+pair.Value); } catch (Exception e) { errors.Add(e.Message); }
                if (dllCreated) try { string dll=Path.Combine(Game,"winmm.dll"); if (Paths.Hash(dll)==Build.LovelyHash) File.Delete(dll); else errors.Add("Review new Lovely file manually."); } catch (Exception e) { errors.Add(e.Message); }
                if (errors.Count>0) throw new Exception(original.Message+"\nSome files need manual restoration from "+Backup+": "+String.Join("; ",errors));
                throw;
            } finally { if (stage!=null) try { Paths.RemoveOwned(stage,StageRoot); } catch { } }
        }
    }
    internal static class Detection {
        public static bool Running() { foreach (var p in Process.GetProcessesByName("Balatro")) { p.Dispose(); return true; } return false; }
        public static string Find() {
            var roots=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var key in new[]{@"HKEY_CURRENT_USER\Software\Valve\Steam",@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam",@"HKEY_LOCAL_MACHINE\SOFTWARE\Valve\Steam"}) {
                object value=Registry.GetValue(key,key.Contains("CURRENT_USER") ? "SteamPath" : "InstallPath",null); if (value is string) roots.Add((string)value);
            }
            roots.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),"Steam"));
            foreach (string root in roots.ToArray()) {
                string vdf=Path.Combine(root,@"steamapps\libraryfolders.vdf");
                if (File.Exists(vdf)) foreach (Match m in Regex.Matches(File.ReadAllText(vdf),"\"path\"\\s+\"([^\"]+)\"")) roots.Add(m.Groups[1].Value.Replace(@"\\",@"\"));
            }
            foreach (string root in roots) { string path=Path.Combine(root,@"steamapps\common\Balatro"); if (File.Exists(Path.Combine(path,"Balatro.exe"))) return path; }
            return "";
        }
        public static void Shortcut(UserPaths user,string game,string backup) {
            string launcher=UpdateStorage.InstallLauncher(user,game);
            Paths.NoLinks(user.Desktop); if (!Directory.Exists(user.Desktop)) return;
            string path=Path.Combine(user.Desktop,"Play Balatro Together.lnk");
            Type type=Type.GetTypeFromProgID("WScript.Shell"); dynamic shell=Activator.CreateInstance(type);
            Paths.NoLinks(path);
            if (File.Exists(path)) { dynamic old=shell.CreateShortcut(path); if (!Paths.Equal((string)old.TargetPath,Path.Combine(game,"Balatro.exe"))&&!Paths.Equal((string)old.TargetPath,launcher)) { path=Path.Combine(user.Desktop,"Play Balatro Together (Co-op).lnk"); if(File.Exists(path)) return; } else File.Copy(path,Path.Combine(backup,"PreviousShortcut.lnk"),false); }
            dynamic shortcut=shell.CreateShortcut(path); shortcut.TargetPath=launcher; shortcut.Arguments="--play"; shortcut.WorkingDirectory=Path.GetDirectoryName(launcher); shortcut.Description="Check updates and play Balatro Together"; shortcut.Save();
        }
    }
    internal sealed class SetupForm : Form {
        public static bool PreviewMode;
        protected override bool ShowWithoutActivation { get { return PreviewMode; } }
        readonly UserPaths user; readonly TextBox path=new TextBox(); readonly Label status=new Label(); readonly Label result=new Label();
        readonly Button install=new Button(), browse=new Button(), play=new Button(); readonly ProgressBar bar=new ProgressBar();
        bool busy, elevate, done;
        public SetupForm(UserPaths context,string selected,bool auto) {
            user=context; Text="Install Balatro Together"; ClientSize=new Size(620,405); FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false; StartPosition=FormStartPosition.CenterScreen;
            BackColor=Color.FromArgb(17,27,35); ForeColor=Color.FromArgb(239,238,216); Font=new Font("Segoe UI",10);
            var title=new Label {Text="Balatro Together",Font=new Font("Segoe UI",25,FontStyle.Bold),Location=new Point(28,24),AutoSize=true}; Controls.Add(title);
            Controls.Add(new Label {Text="Cryptid co-op / signed automatic updates  |  "+Build.Version+"  |  Setup 6",Location=new Point(30,78),Size=new Size(560,24),ForeColor=Color.FromArgb(52,214,180)});
            Controls.Add(new Label {Text="1. Close Balatro.   2. Click Install.   3. Play.",Location=new Point(30,122),Size=new Size(555,25)});
            path.SetBounds(30,167,450,27); path.Text=selected; path.ReadOnly=true; Controls.Add(path);
            browse.Text="Find game..."; browse.SetBounds(490,165,100,31); browse.Click+=(s,e)=>{using(var f=new OpenFileDialog {Filter="Balatro|Balatro.exe",Title="Choose Balatro.exe in your Steam library"}) if(f.ShowDialog()==DialogResult.OK) path.Text=Path.GetDirectoryName(f.FileName);}; Controls.Add(browse);
            result.SetBounds(30,212,560,53); result.Font=new Font("Segoe UI",9); result.Text="Lovely, Steamodded, Amulet and Cryptid are included. Previous Together and dependency versions move into a backup; your saves are preserved."; Controls.Add(result);
            status.SetBounds(30,276,560,24); status.Text=String.IsNullOrEmpty(selected)?"Game not found automatically - click Find game.":"Balatro found. Ready to install."; Controls.Add(status);
            bar.SetBounds(30,307,560,8); Controls.Add(bar);
            install.Text="Install"; install.SetBounds(380,341,210,42); install.BackColor=Color.FromArgb(52,214,180); install.ForeColor=Color.FromArgb(17,27,35); install.FlatStyle=FlatStyle.Flat; install.Font=new Font("Segoe UI",12,FontStyle.Bold); install.Click+=(s,e)=>Start(); Controls.Add(install);
            play.Text="Play Balatro Together"; play.SetBounds(30,341,240,42); play.Enabled=false; play.Click+=(s,e)=>{if(Detection.Running()) { MessageBox.Show("Balatro is already open."); return; } if(new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)){MessageBox.Show(this,"Installation is complete. Close this window and use the Play Balatro Together shortcut on your desktop under your normal Windows account.");return;} string launcher=Path.Combine(UpdateStorage.Root(user),"Launcher","Play Balatro Together.exe"); Process.Start(new ProcessStartInfo(launcher,"--play") {WorkingDirectory=Path.GetDirectoryName(launcher)});Close();}; Controls.Add(play);
            FormClosing+=(s,e)=>{if(busy)e.Cancel=true;}; if(auto)Shown+=(s,e)=>Start();
        }
        void Report(string text) { if(InvokeRequired) { BeginInvoke(new Action<string>(Report),text); return; } status.Text=text; }
        async void Start() {
            if(busy)return;
            if(done) { Close(); return; }
            if(String.IsNullOrWhiteSpace(path.Text)) { MessageBox.Show(this,"Click Find game and choose Balatro.exe from your Steam library.","Find Balatro"); return; }
            if(elevate) {
                try { string context=Convert.ToBase64String(Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(user)));
                    Process.Start(new ProcessStartInfo(Assembly.GetExecutingAssembly().Location,"--continue "+Paths.Quote(path.Text)+" "+context) {UseShellExecute=true,Verb="runas"}); Close();
                } catch { Report("Permission was not granted. No installation changes were made."); } return;
            }
            busy=true; install.Enabled=false; browse.Enabled=false; bar.Style=ProgressBarStyle.Marquee;
            var engine=new Installer(path.Text,Path.Combine(user.Roaming,"Balatro"),Path.Combine(user.Roaming,@"BalatroTogether\Backups"),Path.Combine(user.Local,@"BalatroTogether\InstallerStaging"),Build.GameHash,Detection.Running,Report);
            try {
                await Task.Run(()=>engine.Install());
                Detection.Shortcut(user,path.Text,engine.Backup);
                result.Text="Installed and verified. Use Play Balatro Together for automatic updates.\nBackup: "+engine.Backup; play.Enabled=true; done=true; install.Text="Done"; install.Enabled=true;
            } catch(UnauthorizedAccessException) {
                if(new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) MessageBox.Show(this,"Windows denied access. Use the manual guide for this folder.","Installation stopped");
                else { elevate=true; install.Text="Continue"; result.Text="Windows needs administrator access to the game folder. Continue opens the normal Windows permission prompt and keeps your original user profile."; }
                install.Enabled=true; browse.Enabled=true; Report("No installation was completed.");
            } catch(Exception e) { Report("Installation stopped."); install.Enabled=true; browse.Enabled=true; MessageBox.Show(this,e.Message,"Balatro Together",MessageBoxButtons.OK,MessageBoxIcon.Information); }
            finally {busy=false;bar.Style=ProgressBarStyle.Continuous;bar.Value=play.Enabled?100:0;}
        }
    }
    internal static class Program {
        [STAThread] static int Main(string[] args) {
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            try {
                if(args.Length>0 && args[0]=="--self-test") return SelfTests.Run(args[1]);
                if(args.Length==2 && args[0]=="--updater-self-test")return UpdaterTests.Run(args[1]);
                if(args.Length==2 && args[0]=="--verify-update")return UpdaterTests.VerifyRelease(args[1]);
                UserPaths user=UserPaths.Current(); string game=Detection.Find(); bool auto=false;
                System.Net.ServicePointManager.SecurityProtocol=System.Net.SecurityProtocolType.Tls12;
                if(args.Length==2&&args[0]=="--launcher-preview") {
                    LauncherForm.PreviewMode=true;
                    var preview=new LauncherForm(new UserPaths {Local=Path.Combine(Path.GetDirectoryName(Path.GetFullPath(args[1])),"PreviewProfile")},game);
                    preview.ShowInTaskbar=false;preview.StartPosition=FormStartPosition.Manual;preview.Location=new Point(-32000,-32000);preview.Show();Application.DoEvents();
                    using(var bitmap=new Bitmap(preview.Width,preview.Height)){preview.DrawToBitmap(bitmap,new Rectangle(0,0,preview.Width,preview.Height));bitmap.Save(args[1]);}preview.Close();preview.Dispose();return 0;
                }
                if(args.Length==1&&args[0]=="--play") {
                    if(new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator))throw new Exception("Open Play Balatro Together normally from your desktop, without Run as administrator. Only installation needs elevation.");
                    var settings=UpdateStorage.Load(user);if(!String.IsNullOrEmpty(settings.game))game=settings.game;
                    using(var mutex=new System.Threading.Mutex(false,"Local\\BalatroTogether.Launcher."+user.Sid)) {
                        bool owned=false;try{try{owned=mutex.WaitOne(0);}catch(System.Threading.AbandonedMutexException){owned=true;}if(!owned)return 0;Application.Run(new LauncherForm(user,game));}finally{if(owned)mutex.ReleaseMutex();}
                    }
                    return 0;
                }
                if(args.Length==2&&args[0]=="--update"){game=args[1];auto=true;}
                if(args.Length==3 && args[0]=="--continue") { user=new JavaScriptSerializer().Deserialize<UserPaths>(Encoding.UTF8.GetString(Convert.FromBase64String(args[2]))); user.Validate(); game=args[1]; auto=true; }
                SetupForm.PreviewMode=args.Length==2 && args[0]=="--preview";
                var form=new SetupForm(user,game,auto);
                if(SetupForm.PreviewMode) { form.ShowInTaskbar=false; form.StartPosition=FormStartPosition.Manual; form.Location=new Point(-32000,-32000); form.Show(); Application.DoEvents(); using(var bitmap=new Bitmap(form.Width,form.Height)) { form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height)); bitmap.Save(args[1]); } form.Close(); form.Dispose(); return 0; }
                Application.Run(form); return 0;
            } catch(Exception e) { MessageBox.Show(e.Message,"Installer could not start"); return 1; }
        }
    }
}
