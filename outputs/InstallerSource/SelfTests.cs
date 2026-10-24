using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

namespace TogetherSetup {
    internal static class SelfTests {
        sealed class Fixture {
            public string Root,Game,Saves,Backups,Stage,Hash;
            public Fixture(string parent) {
                Root=Path.Combine(parent,Guid.NewGuid().ToString("N")); Game=Path.Combine(Root,"Steam library with spaces","Balatro"); Saves=Path.Combine(Root,"Roaming","Balatro"); Backups=Path.Combine(Root,"Roaming","BalatroTogether","Backups"); Stage=Path.Combine(Root,"Local","Staging");
                Directory.CreateDirectory(Game); Directory.CreateDirectory(Path.Combine(Saves,"1"));
                File.WriteAllText(Path.Combine(Game,"Balatro.exe"),"Synthetic owned-game fixture; never distributed as a game."); Hash=Paths.Hash(Path.Combine(Game,"Balatro.exe"));
                File.WriteAllText(Path.Combine(Saves,"1","save.jkr"),"preserve this unfinished run");
                Directory.CreateDirectory(Path.Combine(Saves,"Mods","UnrelatedMod")); File.WriteAllText(Path.Combine(Saves,"Mods","UnrelatedMod","keep.txt"),"untouched");
            }
            public Installer Engine(bool busy) { return new Installer(Game,Saves,Backups,Stage,Hash,()=>busy,s=>{}); }
            public void OldMods() {
                string bt=Path.Combine(Saves,"Mods","BalatroTogether"); Directory.CreateDirectory(bt);
                File.WriteAllText(Path.Combine(bt,"BalatroTogether.json"),"{\"id\":\"BalatroTogether\"}"); File.WriteAllText(Path.Combine(bt,"main.lua"),"OLD TOGETHER");
                string sm=Path.Combine(Saves,"Mods","OldSteamodded"); Directory.CreateDirectory(Path.Combine(sm,"src","preflight")); Directory.CreateDirectory(Path.Combine(sm,"lovely")); File.WriteAllText(Path.Combine(sm,"src","preflight","loader.lua"),"OLD SMODS");
                string conflict=Path.Combine(Saves,"Mods","ConflictingMod"); Directory.CreateDirectory(conflict); File.WriteAllText(Path.Combine(conflict,"metadata.json"),"{\"id\":\"Multiplayer\"}"); File.WriteAllText(Path.Combine(conflict,"keep.lua"),"old conflict");
            }
            public void AssertOriginals() {
                Check(Paths.Hash(Path.Combine(Game,"Balatro.exe"))==Hash,"Game executable changed");
                Check(File.ReadAllText(Path.Combine(Saves,"1","save.jkr"))=="preserve this unfinished run","Save changed");
                Check(File.ReadAllText(Path.Combine(Saves,"Mods","UnrelatedMod","keep.txt"))=="untouched","Unrelated mod changed");
            }
        }
        static void Check(bool value,string message) { if(!value)throw new Exception(message); }
        static void Reject(Action action,string expected) { try { action(); } catch(Exception e) { Check(e.Message.IndexOf(expected,StringComparison.OrdinalIgnoreCase)>=0,"Unexpected error: "+e.Message); return; } throw new Exception("Expected refusal: "+expected); }
        public static int Run(string folder) {
            string parent=Paths.Full(folder); Directory.CreateDirectory(parent); Paths.NoLinks(parent);
            var passed=new List<string>();
            Action<string,Action> test=(name,action)=>{action();passed.Add(name);};
            try {
                test("fresh install preserves game, saves and unrelated mods",()=>{
                    var f=new Fixture(parent); var e=f.Engine(false); e.Install(); f.AssertOriginals();
                    Check(Paths.Hash(Path.Combine(f.Game,"winmm.dll"))==Build.LovelyHash,"Wrong Lovely");
                    Check(File.Exists(Path.Combine(f.Saves,"Mods","BalatroTogether","game","donations.lua")),"Missing mod");
                    Check(File.Exists(Path.Combine(f.Saves,"Mods","smods-26.1002.0","src","preflight","loader.lua")),"Missing SMODS");
                    Check(File.Exists(Path.Combine(f.Saves,"Mods","Cryptid","Cryptid.lua")),"Missing Cryptid");
                    Check(File.Exists(Path.Combine(f.Saves,"Mods","Amulet","smods.lua")),"Missing Amulet");
                    Check(!File.Exists(Path.Combine(f.Saves,"Mods","Amulet","manifest.json")),"Thunderstore metadata installed as SMODS metadata");
                    Check(File.ReadAllText(Path.Combine(e.Backup,"Saves","1","save.jkr"))=="preserve this unfinished run","Missing save backup");
                });
                test("launcher detects an old mod and verifies the actual repaired installation",()=>{
                    var f=new Fixture(parent);f.OldMods();
                    string meta=Path.Combine(f.Saves,"Mods","BalatroTogether","BalatroTogether.json");
                    File.WriteAllText(meta,"{\"id\":\"BalatroTogether\",\"version\":\"0.6.1-dev\"}");
                    var user=new UserPaths {Roaming=Path.GetDirectoryName(f.Saves),Local=Path.Combine(f.Root,"Local")};
                    var before=InstalledBuild.Inspect(user);Check(before.NeedsRepair&&before.CanRepair(Build.Version),"Old installed mod incorrectly accepted");
                    var engine=f.Engine(false);engine.Install();var after=InstalledBuild.Inspect(user);
                    Check(!after.NeedsRepair&&after.Version==after.BundledVersion,"Repair did not update actual mod files");f.AssertOriginals();
                    Check(File.ReadAllText(Path.Combine(engine.Backup,"PreviousMods","BalatroTogether","main.lua"))=="OLD TOGETHER","Repair did not preserve the old mod");
                });
                test("updates quarantine old loaders, duplicate Together and conflicting mods",()=>{
                    var f=new Fixture(parent); f.OldMods(); var duplicate=Path.Combine(f.Saves,"Mods","RenamedTogether"); Directory.CreateDirectory(duplicate); File.WriteAllText(Path.Combine(duplicate,"metadata.json"),"{\"id\":\"BalatroTogether\"}");
                    var e=f.Engine(false); e.Install(); f.AssertOriginals();
                    Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods","BalatroTogether","main.lua"))=="OLD TOGETHER","Missing old mod backup");
                    Check(!Directory.Exists(Path.Combine(f.Saves,"Mods","OldSteamodded")) && !Directory.Exists(duplicate),"Duplicate loader remains");
                    Check(File.Exists(Path.Combine(e.Backup,"PreviousMods","ConflictingMod","keep.lua")),"Conflict backup missing");
                });
                test("failure after replacement rolls back every previous mod",()=>{
                    var f=new Fixture(parent); f.OldMods(); var e=f.Engine(false); e.AfterFirstReplacement=()=>{throw new Exception("injected copy failure");};
                    Reject(()=>e.Install(),"injected copy failure"); f.AssertOriginals();
                    Check(File.ReadAllText(Path.Combine(f.Saves,"Mods","BalatroTogether","main.lua"))=="OLD TOGETHER","Old mod not restored");
                    Check(File.Exists(Path.Combine(f.Saves,"Mods","OldSteamodded","src","preflight","loader.lua")),"Old loader not restored");
                    Check(File.Exists(Path.Combine(f.Saves,"Mods","ConflictingMod","keep.lua")),"Conflict not restored");
                    Check(!File.Exists(Path.Combine(f.Game,"winmm.dll")),"Unexpected DLL after failure");
                });
                test("repeat install remains verified and creates separate backups",()=>{ var f=new Fixture(parent); var first=f.Engine(false); first.Install(); var next=f.Engine(false); next.Install(); f.AssertOriginals(); Check(first.Backup!=next.Backup,"Backup collision"); });
                test("running game blocks before changes",()=>{var f=new Fixture(parent); Reject(()=>f.Engine(true).Install(),"Close Balatro"); f.AssertOriginals(); Check(!File.Exists(Path.Combine(f.Game,"winmm.dll")),"DLL written despite running game");});
                test("unknown DLL is never overwritten",()=>{var f=new Fixture(parent); string p=Path.Combine(f.Game,"winmm.dll"); File.WriteAllText(p,"unknown dll"); Reject(()=>f.Engine(false).Install(),"different winmm.dll"); Check(File.ReadAllText(p)=="unknown dll","Unknown DLL changed"); f.AssertOriginals();});
                test("existing version.dll requires review",()=>{var f=new Fixture(parent); File.WriteAllText(Path.Combine(f.Game,"version.dll"),"older loader"); Reject(()=>f.Engine(false).Install(),"version.dll");f.AssertOriginals();});
                test("wrong game build is rejected",()=>{var f=new Fixture(parent); File.AppendAllText(Path.Combine(f.Game,"Balatro.exe"),"changed"); Reject(()=>f.Engine(false).Install(),"game build differs");});
                test("unknown Together destination is preserved",()=>{var f=new Fixture(parent); var p=Path.Combine(f.Saves,"Mods","BalatroTogether"); Directory.CreateDirectory(p); File.WriteAllText(Path.Combine(p,"user.txt"),"keep");Reject(()=>f.Engine(false).Install(),"unknown files");Check(File.ReadAllText(Path.Combine(p,"user.txt"))=="keep","Unknown destination changed");});
                test("incomplete Steamodded destination is backed up and replaced automatically",()=>{
                    var f=new Fixture(parent); string p=Path.Combine(f.Saves,"Mods","smods-26.1002.0"); Directory.CreateDirectory(p); File.WriteAllText(Path.Combine(p,"user.txt"),"preserve incomplete loader");
                    var e=f.Engine(false); e.Install(); Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods","smods-26.1002.0","user.txt"))=="preserve incomplete loader","Incomplete loader lost");
                    Check(File.Exists(Path.Combine(p,"src","preflight","loader.lua")),"New loader missing"); f.AssertOriginals();
                });
                test("all old Steamodded folder versions and GitHub wrappers are quarantined",()=>{
                    var f=new Fixture(parent); var names=new[]{"Steamodded","SMODS","smods-main","Steamodded-0.9.8","smods-1.0.0-BETA-1221a","Steamodded-main (2)"};
                    foreach(string name in names) { string p=Path.Combine(f.Saves,"Mods",name); Directory.CreateDirectory(Path.Combine(p,"smods-main")); File.WriteAllText(Path.Combine(p,"smods-main","core.lua"),"OLD "+name); }
                    var e=f.Engine(false); e.Install();
                    foreach(string name in names) { Check(!Directory.Exists(Path.Combine(f.Saves,"Mods",name)),"Old loader remains: "+name); Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods",name,"smods-main","core.lua"))=="OLD "+name,"Wrapper backup incomplete"); }
                    f.AssertOriginals();
                });
                test("legacy single-file loaders and Cryptid Lua installs are preserved outside Mods",()=>{
                    var f=new Fixture(parent); var entries=new Dictionary<string,string>{{"Steamodded.lua","old single file"},{"Cryptid.lua","old cryptid"},{"Cryptid.json","{\"id\":\"Cryptid\",\"main_file\":\"Cryptid.lua\"}"},{"Steamodded.toml","legacy metadata"},{"custom-loader-name.lua","--- STEAMODDED HEADER\n--- MOD_ID: Steamodded\nold loader"},{"old-content.lua","--- STEAMODDED HEADER\n--- MOD_ID: Cryptid\nold content"}};
                    foreach(var pair in entries) File.WriteAllText(Path.Combine(f.Saves,"Mods",pair.Key),pair.Value);
                    var e=f.Engine(false); e.Install(); foreach(var pair in entries) { Check(!File.Exists(Path.Combine(f.Saves,"Mods",pair.Key)),"Old file remains"); Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods",pair.Key))==pair.Value,"Old file not backed up"); } f.AssertOriginals();
                });
                test("Cryptid versions and renamed metadata folders are quarantined without deleting cards",()=>{
                    var f=new Fixture(parent); var names=new[]{"Cryptid","Cryptid-main","Cryptid-0.5.4","RenamedContent"};
                    foreach(string name in names) { string p=Path.Combine(f.Saves,"Mods",name); Directory.CreateDirectory(p); File.WriteAllText(Path.Combine(p,"jokers.lua"),"keep old jokers"); }
                    File.WriteAllText(Path.Combine(f.Saves,"Mods","RenamedContent","Cryptid.json"),"{\"id\":\"Cryptid\"}");
                    var e=f.Engine(false); e.Install(); foreach(string name in names) { Check(!File.Exists(Path.Combine(f.Saves,"Mods",name,"jokers.lua")),"Old Cryptid remains"); Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods",name,"jokers.lua"))=="keep old jokers","Cryptid backup lost"); } f.AssertOriginals();
                });
                test("old Amulet and standalone Talisman are replaced with one matched Amulet",()=>{
                    var f=new Fixture(parent); var names=new[]{"Amulet","Amulet-3.0.0","Talisman","Talisman-main"};
                    foreach(string name in names) { string p=Path.Combine(f.Saves,"Mods",name); Directory.CreateDirectory(p); File.WriteAllText(Path.Combine(p,"old.txt"),name); }
                    var e=f.Engine(false); e.Install();
                    foreach(string name in names) { Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods",name,"old.txt"))==name,"Big number backup lost"); Check(!File.Exists(Path.Combine(f.Saves,"Mods",name,"old.txt")),"Old big number library remains"); }
                    Check(File.Exists(Path.Combine(f.Saves,"Mods","Amulet","big-num","omeganum.lua")),"Omega missing"); f.AssertOriginals();
                });
                test("renamed Amulet metadata and Talisman archives are detected",()=>{
                    var f=new Fixture(parent); string p=Path.Combine(f.Saves,"Mods","CustomBigNumbers"); Directory.CreateDirectory(p); File.WriteAllText(Path.Combine(p,"smods.json"),"{\"id\":\"Amulet\"}"); File.WriteAllText(Path.Combine(p,"old.txt"),"old math"); File.WriteAllText(Path.Combine(f.Saves,"Mods","Talisman-2.7.zip"),"old archive");
                    var e=f.Engine(false); e.Install(); Check(!Directory.Exists(p),"Renamed Amulet remains"); Check(File.Exists(Path.Combine(e.Backup,"PreviousMods","CustomBigNumbers","old.txt")),"Renamed backup missing"); Check(File.Exists(Path.Combine(e.Backup,"PreviousMods","Talisman-2.7.zip")),"Archive missing"); f.AssertOriginals();
                });
                test("dependency replacement failure restores prior Cryptid and Amulet",()=>{
                    var f=new Fixture(parent); foreach(string name in new[]{"Cryptid","Amulet"}) { string p=Path.Combine(f.Saves,"Mods",name); Directory.CreateDirectory(p); File.WriteAllText(Path.Combine(p,"old.txt"),name); }
                    var e=f.Engine(false); e.AfterFirstReplacement=()=>{throw new Exception("dependency failure");}; Reject(()=>e.Install(),"dependency failure");
                    foreach(string name in new[]{"Cryptid","Amulet"}) Check(File.ReadAllText(Path.Combine(f.Saves,"Mods",name,"old.txt"))==name,"Old dependency not restored"); f.AssertOriginals();
                });
                test("renamed legacy folder is identified by a bounded Steamodded header read",()=>{
                    var f=new Fixture(parent); string p=Path.Combine(f.Saves,"Mods","OldLoaderWithCustomName"); Directory.CreateDirectory(p);
                    File.WriteAllText(Path.Combine(p,"loader.lua"),"--- STEAMODDED HEADER\n--- MOD_ID: SMODS\n"+new string('x',12000));
                    var e=f.Engine(false); e.Install(); Check(!Directory.Exists(p),"Renamed loader remains"); Check(new FileInfo(Path.Combine(e.Backup,"PreviousMods","OldLoaderWithCustomName","loader.lua")).Length>12000,"Legacy file truncated"); f.AssertOriginals();
                });
                test("nested modpack wrappers retain unrelated files and preserve distinct backup paths",()=>{
                    var f=new Fixture(parent); var wrappers=new[]{"DownloadOne","DownloadTwo"};
                    foreach(string name in wrappers) { string p=Path.Combine(f.Saves,"Mods",name); Directory.CreateDirectory(Path.Combine(p,"smods-main")); Directory.CreateDirectory(Path.Combine(p,"Cryptid-main")); File.WriteAllText(Path.Combine(p,"smods-main","core.lua"),name); File.WriteAllText(Path.Combine(p,"Cryptid-main","content.lua"),name); File.WriteAllText(Path.Combine(p,"keep.txt"),"unrelated wrapper notes"); }
                    var e=f.Engine(false); e.Install(); foreach(string name in wrappers) { Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods",name,"smods-main","core.lua"))==name,"Nested loader collision"); Check(File.Exists(Path.Combine(e.Backup,"PreviousMods",name,"Cryptid-main","content.lua")),"Nested Cryptid missing"); Check(File.ReadAllText(Path.Combine(f.Saves,"Mods",name,"keep.txt"))=="unrelated wrapper notes","Unrelated wrapper changed"); } f.AssertOriginals();
                });
                test("archive copies are backed up and unrelated identified mod libraries remain untouched",()=>{
                    var f=new Fixture(parent); File.WriteAllText(Path.Combine(f.Saves,"Mods","smods-main.zip"),"archive bytes"); File.WriteAllText(Path.Combine(f.Saves,"Mods","Cryptid-0.5.zip"),"cryptid archive bytes");
                    string unrelated=Path.Combine(f.Saves,"Mods","AnotherMod"); Directory.CreateDirectory(Path.Combine(unrelated,"Cryptid")); File.WriteAllText(Path.Combine(unrelated,"metadata.json"),"{\"id\":\"AnotherMod\"}"); File.WriteAllText(Path.Combine(unrelated,"Cryptid","keep.lua"),"private compatibility library");
                    var e=f.Engine(false); e.Install(); Check(File.ReadAllText(Path.Combine(e.Backup,"PreviousMods","smods-main.zip"))=="archive bytes","Archive backup lost"); Check(File.Exists(Path.Combine(e.Backup,"PreviousMods","Cryptid-0.5.zip")),"Cryptid archive remains"); Check(File.ReadAllText(Path.Combine(unrelated,"Cryptid","keep.lua"))=="private compatibility library","Unrelated library changed"); f.AssertOriginals();
                });
                test("rollback restores legacy files and nested Steamodded and Cryptid after replacement failure",()=>{
                    var f=new Fixture(parent); string p=Path.Combine(f.Saves,"Mods","Wrapper","smods-main"); Directory.CreateDirectory(p); File.WriteAllText(Path.Combine(p,"old.lua"),"old loader");
                    File.WriteAllText(Path.Combine(f.Saves,"Mods","Cryptid.lua"),"old cryptid file"); var e=f.Engine(false); e.AfterFirstReplacement=()=>{throw new Exception("injected legacy cleanup failure");};
                    Reject(()=>e.Install(),"injected legacy cleanup failure"); Check(File.ReadAllText(Path.Combine(p,"old.lua"))=="old loader","Nested loader not restored"); Check(File.ReadAllText(Path.Combine(f.Saves,"Mods","Cryptid.lua"))=="old cryptid file","Legacy Cryptid not restored"); f.AssertOriginals();
                });
                test("absolute and traversal extraction targets are refused",()=>{Reject(()=>Paths.Within(Path.Combine(parent,"..","outside"),parent),"Unsafe destination");Reject(()=>Paths.Within(Path.GetPathRoot(parent),parent),"Unsafe destination");});
                test("current user folders validate before elevation context is accepted",()=>{var current=UserPaths.Current(); current.Validate(); current.Roaming=Path.GetPathRoot(current.Roaming); Reject(()=>current.Validate(),"could not be verified");});
                test("desktop shortcut installs the updating launcher without launching the game",()=>{
                    var f=new Fixture(parent); string desktop=Path.Combine(f.Root,"Desktop"), backup=Path.Combine(f.Root,"Backup"); Directory.CreateDirectory(desktop); Directory.CreateDirectory(backup);
                    var user=new UserPaths {Desktop=desktop,Local=Path.Combine(f.Root,"Local")}; Detection.Shortcut(user,f.Game,backup);
                    string path=Path.Combine(desktop,"Play Balatro Together.lnk"); Check(File.Exists(path),"Shortcut missing");
                    dynamic shell=Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell")); dynamic shortcut=shell.CreateShortcut(path);
                    Check(Paths.Equal((string)shortcut.TargetPath,Path.Combine(user.Local,"BalatroTogether","Launcher","Play Balatro Together.exe")),"Wrong shortcut target"); Check((string)shortcut.Arguments=="--play","Updater bypassed");
                    Detection.Shortcut(user,f.Game,backup); Check(File.Exists(Path.Combine(backup,"PreviousShortcut.lnk")),"Shortcut backup missing"); f.AssertOriginals();
                });
                File.WriteAllText(Path.Combine(parent,"results.json"),new JavaScriptSerializer().Serialize(new{passed=passed.Count,tests=passed,failed=0}),Encoding.UTF8);
                return 0;
            } catch(Exception e) { File.WriteAllText(Path.Combine(parent,"results.json"),new JavaScriptSerializer().Serialize(new{passed=passed.Count,tests=passed,failed=1,error=e.ToString()}),Encoding.UTF8); return 1; }
        }
    }
}
