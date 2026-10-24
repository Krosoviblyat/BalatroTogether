using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

namespace TogetherSetup {
    internal static class UpdaterTests {
        public static int VerifyRelease(string folder) {
            try {
                string name=File.Exists(Path.Combine(folder,"Update-v2.json"))?"Update-v2":"Update";
                var bytes=File.ReadAllBytes(Path.Combine(folder,name+".json"));var sig=File.ReadAllBytes(Path.Combine(folder,name+".sig"));
                var decoded=new JavaScriptSerializer().Deserialize<UpdateManifest>(UpdatePolicy.Utf8.GetString(bytes));
                var m=UpdatePolicy.Verify(bytes,sig,"v"+decoded.version,DateTime.UtcNow,UpdateKey.PublicXml);
                string package=Path.Combine(folder,m.asset);Paths.Within(package,folder);
                string exe=UpdatePolicy.PrepareInstaller(package,Path.Combine(folder,"Verify-"+Guid.NewGuid().ToString("N")),m);
                File.WriteAllText(Path.Combine(folder,"verification-result.json"),new JavaScriptSerializer().Serialize(new {verified=true,version=m.version,package_sha256=Paths.Hash(package),installer_sha256=Paths.Hash(exe)}));
                return 0;
            } catch(Exception e){File.WriteAllText(Path.Combine(folder,"verification-result.json"),new JavaScriptSerializer().Serialize(new {verified=false,error=e.Message}));return 1;}
        }
        static void Check(bool value,string reason) {if(!value)throw new Exception(reason);}
        static void Reject(Action action) {try{action();}catch{return;}throw new Exception("Expected refusal");}
        static byte[] Encode(UpdateManifest m) {return UpdatePolicy.Utf8.GetBytes(new JavaScriptSerializer().Serialize(m));}
        static string Hash(byte[] b) {using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
        public static int Run(string parent) {
            Paths.NoLinks(parent);Directory.CreateDirectory(parent);string root=Path.Combine(parent,Guid.NewGuid().ToString("N"));Directory.CreateDirectory(root);
            var tests=new List<string>();Action<string,Action> test=(name,action)=>{action();tests.Add(name);};
            try {
                using(var rsa=new RSACryptoServiceProvider(2048)) {
                    rsa.PersistKeyInCsp=false;string key=rsa.ToXmlString(false);var now=DateTime.UtcNow;
                    var m=new UpdateManifest {schema=1,repository=UpdatePolicy.Repository,version="0.6.3-dev",asset="BalatroTogether-0.6.3-dev-Easy-Installer.zip",size=10,sha256=new string('a',64),installer_sha256=new string('b',64),issued_utc=now.AddMinutes(-1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"),expires_utc=now.AddDays(90).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")};
                    Func<UpdateManifest> verify=()=>{var bytes=Encode(m);return UpdatePolicy.Verify(bytes,rsa.SignData(bytes,CryptoConfig.MapNameToOID("SHA256")),"v"+m.version,now,key);};
                    test("valid RSA SHA256 manifest accepted",()=>Check(verify().version==m.version,"Version changed"));
                    test("tampered manifest refused before parsing",()=>{var b=Encode(m);var sig=rsa.SignData(b,CryptoConfig.MapNameToOID("SHA256"));b[5]^=1;Reject(()=>UpdatePolicy.Verify(b,sig,"v"+m.version,now,key));});
                    test("tampered signature refused",()=>{var b=Encode(m);var sig=rsa.SignData(b,CryptoConfig.MapNameToOID("SHA256"));sig[0]^=1;Reject(()=>UpdatePolicy.Verify(b,sig,"v"+m.version,now,key));});
                    test("wrong signing key refused",()=>{using(var other=new RSACryptoServiceProvider(2048)){other.PersistKeyInCsp=false;var b=Encode(m);Reject(()=>UpdatePolicy.Verify(b,other.SignData(b,CryptoConfig.MapNameToOID("SHA256")),"v"+m.version,now,key));}});
                    test("release tag mismatch refused",()=>{var b=Encode(m);Reject(()=>UpdatePolicy.Verify(b,rsa.SignData(b,CryptoConfig.MapNameToOID("SHA256")),"v0.9.0",now,key));});
                    test("other repository refused",()=>{m.repository="someone/else";Reject(()=>verify());m.repository=UpdatePolicy.Repository;});
                    test("unknown schema refused",()=>{m.schema=3;Reject(()=>verify());m.schema=1;});
                    test("expired metadata refused",()=>{var old=m.expires_utc;m.expires_utc=now.AddSeconds(-1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'");Reject(()=>verify());m.expires_utc=old;});
                    test("future metadata refused",()=>{var old=m.issued_utc;m.issued_utc=now.AddHours(1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'");Reject(()=>verify());m.issued_utc=old;});
                    test("unbounded expiry refused",()=>{var old=m.expires_utc;m.expires_utc=now.AddYears(1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'");Reject(()=>verify());m.expires_utc=old;});
                    test("unsafe package name refused",()=>{var old=m.asset;m.asset="../update.zip";Reject(()=>verify());m.asset=old;});
                    test("oversize and zero packages refused",()=>{m.size=UpdatePolicy.MaxPackage+1;Reject(()=>verify());m.size=0;Reject(()=>verify());m.size=10;});
                    test("invalid hash refused",()=>{var old=m.sha256;m.sha256="not-a-hash";Reject(()=>verify());m.sha256=old;});
                    test("oversize metadata refused",()=>Reject(()=>UpdatePolicy.Verify(new byte[65537],new byte[256],"v0.6.3-dev",now,key)));
                    test("semantic version ordering handles numeric segments and prereleases",()=>{Check(UpdatePolicy.Number("0.6.10-dev")>UpdatePolicy.Number("0.6.9-dev"),"Lexical sorting");Check(UpdatePolicy.Number("0.6.3")>UpdatePolicy.Number("0.6.3-rc.9"),"Stable ordering");Check(UpdatePolicy.Number("0.6.3-dev.2")>UpdatePolicy.Number("0.6.3-dev.1"),"Serial ordering");});
                    test("malformed versions refused",()=>{foreach(var v in new[]{"1.2","../x","1.02.3","1.2.3-unknown","1.2.3-dev.100000"})Reject(()=>UpdatePolicy.Number(v));});
                    byte[] executable=Encoding.ASCII.GetBytes("MZ synthetic installer; never executed");string zip=Path.Combine(root,"fixture.zip");
                    using(var z=ZipFile.Open(zip,ZipArchiveMode.Create)) {using(var s=z.CreateEntry("Install Balatro Together.exe").Open())s.Write(executable,0,executable.Length);using(var s=z.CreateEntry("../../escape.exe").Open())s.WriteByte(0);}
                    m.size=new FileInfo(zip).Length;m.sha256=Paths.Hash(zip);m.installer_sha256=Hash(executable);
                    test("verified package extracts only the expected installer",()=>{string target=Path.Combine(root,"Verified");string exe=UpdatePolicy.ExtractInstaller(zip,target,m);Check(File.ReadAllBytes(exe).SequenceEqual(executable),"Wrong installer");Check(Directory.GetFiles(target).Length==1&&!File.Exists(Path.Combine(root,"escape.exe")),"Archive traversal");});
                    test("truncated package refused",()=>{string p=Path.Combine(root,"partial.zip");File.WriteAllBytes(p,File.ReadAllBytes(zip).Take(30).ToArray());Reject(()=>UpdatePolicy.ExtractInstaller(p,Path.Combine(root,"Partial"),m));Check(!Directory.Exists(Path.Combine(root,"Partial")),"Extraction started before verification");});
                    test("corrupt package refused",()=>{string p=Path.Combine(root,"corrupt.zip");var b=File.ReadAllBytes(zip);b[5]^=1;File.WriteAllBytes(p,b);Reject(()=>UpdatePolicy.VerifyPackage(p,m));});
                    test("wrong inner installer hash refused",()=>{var old=m.installer_sha256;m.installer_sha256=new string('c',64);Reject(()=>UpdatePolicy.ExtractInstaller(zip,Path.Combine(root,"BadExe"),m));m.installer_sha256=old;});
                    test("duplicate installer entries refused",()=>{string p=Path.Combine(root,"dupe.zip");using(var z=ZipFile.Open(p,ZipArchiveMode.Create)){z.CreateEntry("Install Balatro Together.exe");z.CreateEntry("Install Balatro Together.exe");}var old=m.sha256;var size=m.size;m.sha256=Paths.Hash(p);m.size=new FileInfo(p).Length;Reject(()=>UpdatePolicy.ExtractInstaller(p,Path.Combine(root,"Duplicate"),m));m.sha256=old;m.size=size;});
                    string standalone=Path.Combine(root,"standalone.exe");File.WriteAllBytes(standalone,executable);
                    m.schema=2;m.asset="BalatroTogether-Setup-"+m.version+".exe";m.size=executable.Length;m.sha256=Hash(executable);m.installer_sha256=m.sha256;
                    test("signed standalone installer accepted and staged without ZIP extraction",()=>{verify();string exe=UpdatePolicy.PrepareInstaller(standalone,Path.Combine(root,"Standalone"),m);Check(File.ReadAllBytes(exe).SequenceEqual(executable),"Wrong standalone bytes");});
                    test("standalone hash fields must agree",()=>{m.installer_sha256=new string('d',64);Reject(()=>verify());m.installer_sha256=m.sha256;});
                    test("standalone corruption refused before staging",()=>{File.AppendAllText(standalone,"bad");Reject(()=>UpdatePolicy.PrepareInstaller(standalone,Path.Combine(root,"StandaloneBad"),m));Check(!Directory.Exists(Path.Combine(root,"StandaloneBad")),"Corrupt installer staged");});
                    test("schema two cannot name a ZIP",()=>{m.asset="BalatroTogether-"+m.version+"-Easy-Installer.zip";Reject(()=>verify());});
                }
                test("redirect policy forbids plaintext and lookalike credential hosts",()=>{foreach(var url in new[]{"http://api.github.com/x","https://api.github.com.evil.test/x","https://evil.test/x","https://api.github.com:444/x","https://user:password@api.github.com/x"})Check(!GitHubUpdates.AssetHost(new Uri(url)),"Unsafe host accepted");Check(GitHubUpdates.AssetHost(new Uri("https://release-assets.githubusercontent.com/file")),"Asset host rejected");});
                var releases=new JavaScriptSerializer().Deserialize<Dictionary<string,object>[]>("[{\"tag_name\":\"v0.6.3-dev\",\"draft\":false,\"prerelease\":true,\"assets\":[{\"id\":12,\"name\":\"Update.json\",\"state\":\"uploaded\"},{\"id\":13,\"name\":\"Update.sig\",\"state\":\"uploaded\"}]},{\"tag_name\":\"v0.6.4-dev\",\"draft\":true,\"assets\":[]},{\"tag_name\":\"v0.6.5-dev\",\"draft\":false,\"assets\":[]}]");
                test("published prereleases selected and draft or unsigned releases ignored",()=>Check(GitHubUpdates.Select(releases,"0.6.2-dev","0.6.2-dev")==releases[0],"Wrong release"));
                test("equal and older releases do not reinstall",()=>Check(GitHubUpdates.Select(releases,"0.6.3-dev","0.6.3-dev")==null,"Reinstall loop"));
                test("high water mark blocks rollback but permits repair to its exact version",()=>{Check(GitHubUpdates.Select(releases,"0.6.1-dev","0.6.4-dev")==null,"Rollback accepted");Check(GitHubUpdates.Select(releases,"0.6.1-dev","0.6.3-dev")==releases[0],"Repair blocked");});
                test("private assets use authenticated API IDs rather than supplied download URLs",()=>Check(GitHubUpdates.Asset(releases[0],"Update.json")=="https://api.github.com/repos/"+UpdatePolicy.Repository+"/releases/assets/12","Untrusted asset URL"));
                test("v2-only releases selected by new launchers",()=>{var copy=new JavaScriptSerializer().Deserialize<Dictionary<string,object>[]>(new JavaScriptSerializer().Serialize(releases).Replace("Update.json","Update-v2.json").Replace("Update.sig","Update-v2.sig"));Check(GitHubUpdates.Select(copy,"0.6.2-dev","0.6.2-dev")==copy[0],"V2 update ignored");});
                var user=new UserPaths {Local=Path.Combine(root,"Local")};
                test("tokens encrypted with current-user DPAPI and removable",()=>{string token="synthetic_read_token_1234567890";UpdateStorage.SaveToken(user,token);Check(UpdateStorage.Token(user)==token,"DPAPI round trip");string raw=Encoding.UTF8.GetString(File.ReadAllBytes(Path.Combine(UpdateStorage.Root(user),"github-token.bin")));Check(!raw.Contains(token),"Plaintext token on disk");UpdateStorage.SaveToken(user,"");Check(UpdateStorage.Token(user)=="","Token retained");});
                test("settings survive atomic replacement",()=>{UpdateStorage.Save(user,new UpdateSettings {game="fixture",automatic=false,highest_version="0.6.3-dev"});UpdateStorage.Save(user,new UpdateSettings {game="fixture2",automatic=true,highest_version="0.6.4-dev"});Check(UpdateStorage.Load(user).game=="fixture2"&&UpdateStorage.Load(user).automatic,"Settings replacement failed");});
                test("launcher replacement preserves update preference and high water mark",()=>{var settings=UpdateStorage.Load(user);settings.automatic=false;settings.highest_version="9.0.0";UpdateStorage.Save(user,settings);string exe=UpdateStorage.InstallLauncher(user,"fixture game");UpdateStorage.InstallLauncher(user,"fixture game");Check(File.Exists(exe)&&UpdateStorage.Load(user).highest_version=="9.0.0"&&!UpdateStorage.Load(user).automatic,"Launcher replacement lost settings");});
                string bundle=Payload.Extract(Path.Combine(root,"Bundle"));
                Func<UserPaths> fixture=()=>{
                    string folder=Path.Combine(root,Guid.NewGuid().ToString("N"));
                    var context=new UserPaths {Local=Path.Combine(folder,"Local"),Roaming=Path.Combine(folder,"Roaming")};
                    Paths.CopyTree(Path.Combine(bundle,"Mods","BalatroTogether"),Path.Combine(context.Roaming,"Balatro","Mods","BalatroTogether"),null);return context;
                };
                Func<UserPaths,string> metadata=context=>Path.Combine(context.Roaming,"Balatro","Mods","BalatroTogether","BalatroTogether.json");
                Action<UserPaths,string> version=(context,value)=>File.WriteAllText(metadata(context),"{\"id\":\"BalatroTogether\",\"version\":\""+value+"\"}",Encoding.UTF8);
                test("actual installed mod files are verified independently of launcher version",()=>{
                    var context=fixture();var state=InstalledBuild.Inspect(context);Check(!state.NeedsRepair&&state.Version=="0.7.1-dev"&&state.BundledVersion=="0.7.1-dev","Current bundle not recognized");
                });
                test("new launcher plus old mod requires repair rather than reporting up to date",()=>{
                    var context=fixture();version(context,"0.6.1-dev");var state=InstalledBuild.Inspect(context);
                    Check(state.NeedsRepair&&state.Version=="0.6.1-dev"&&state.CanRepair(Build.Version),"Old mod was missed by the launcher");
                });
                test("same-version damaged and missing runtime files require repair",()=>{
                    var context=fixture();string file=Path.Combine(Path.GetDirectoryName(metadata(context)),"main.lua");File.AppendAllText(file,"changed");
                    Check(InstalledBuild.Inspect(context).NeedsRepair,"Damaged runtime trusted");File.Delete(file);Check(InstalledBuild.Inspect(context).NeedsRepair,"Missing runtime trusted");
                });
                test("missing and malformed mod metadata do not count as installed",()=>{
                    var context=fixture();File.WriteAllText(metadata(context),"{broken");Check(InstalledBuild.Inspect(context).NeedsRepair,"Malformed metadata trusted");
                    File.Delete(metadata(context));Check(InstalledBuild.Inspect(context).NeedsRepair,"Missing metadata trusted");
                });
                test("newer gameplay builds are never overwritten by an older embedded mod",()=>{
                    var context=fixture();version(context,"9.0.0");var state=InstalledBuild.Inspect(context);
                    Check(state.NewerMod&&!state.CanRepair(Build.Version),"Newer gameplay would be downgraded");
                });
                test("embedded repair respects the committed launcher high-water mark",()=>{
                    var context=fixture();version(context,"0.6.1-dev");var state=InstalledBuild.Inspect(context);
                    Check(!state.CanRepair("9.0.0"),"Old embedded package bypassed rollback floor");
                    Reject(()=>state.StageRepair(Path.Combine(root,"BlockedRepair"),"9.0.0"));
                });
                test("offline repair stages this exact verified full installer without GitHub credentials",()=>{
                    var context=fixture();version(context,"0.6.1-dev");var state=InstalledBuild.Inspect(context);
                    Check(UpdateStorage.Token(context)=="","Unexpected fixture credentials");
                    string staged=state.StageRepair(Path.Combine(root,"OfflineRepair"),Build.Version);
                    Check(Paths.Hash(staged)==Paths.Hash(System.Reflection.Assembly.GetExecutingAssembly().Location),"Repair did not stage the full installer");
                });
                Paths.RemoveOwned(bundle,Path.Combine(root,"Bundle"));
                Write(parent,tests,0,null);return 0;
            }catch(Exception e){Write(parent,tests,1,e.ToString());return 1;}
        }
        static void Write(string parent,List<string> tests,int failed,string error) {File.WriteAllText(Path.Combine(parent,"updater-results.json"),new JavaScriptSerializer().Serialize(new {passed=tests.Count,failed=failed,tests=tests,error=error}),Encoding.UTF8);}
    }
}
