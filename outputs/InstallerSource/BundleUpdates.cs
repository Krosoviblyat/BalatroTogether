// Permanent launcher: signed data-only updates, no per-release installer EXE.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace TogetherSetup {
    internal sealed class DataManifest {
        public int schema;
        public string repository,version,asset,sha256,game_sha256,lovely_sha256,issued_utc,expires_utc;
        public long size;
    }
    internal sealed class VerifiedBundle {
        public DataManifest Manifest;
        public byte[] Metadata,Signature;
        public string Package;
    }
    internal static class BundleUpdates {
        internal static Action<Installer> ConfigureEngine;
        internal sealed class Receipt {public string metadata,signature;}
        const long MaxExtracted=1024L*1024*1024;
        static string ReceiptPath(UserPaths user){return Path.Combine(UpdateStorage.Root(user),"installed-bundle.json");}
        static string CachePath(UserPaths user,DataManifest manifest){return Path.Combine(UpdateStorage.Root(user),"Bundles",manifest.sha256+".zip");}
        static string Hash(Stream stream){using(var hash=SHA256.Create())return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-","").ToLowerInvariant();}
        public static DataManifest Verify(byte[] data,byte[] signature,string tag,DateTime now,string key,bool receipt=false) {
            if(data==null||data.Length==0||data.Length>65536||signature==null||signature.Length>2048)throw new Exception("Invalid bundle metadata size.");
            using(var rsa=new RSACryptoServiceProvider()){rsa.PersistKeyInCsp=false;rsa.FromXmlString(key);if(!rsa.VerifyData(data,CryptoConfig.MapNameToOID("SHA256"),signature))throw new Exception("Update bundle signature is invalid. No files were installed.");}
            var m=new JavaScriptSerializer().Deserialize<DataManifest>(UpdatePolicy.Utf8.GetString(data));
            if(m==null||m.schema!=3||m.repository!=UpdatePolicy.Repository||tag!="v"+m.version)throw new Exception("Bundle metadata does not match this release.");
            UpdatePolicy.Number(m.version);
            if(m.asset!="BalatroTogether-Update-"+m.version+".zip"||m.size<1||m.size>UpdatePolicy.MaxPackage)throw new Exception("Invalid update bundle.");
            foreach(string value in new[]{m.sha256,m.game_sha256,m.lovely_sha256})if(!Regex.IsMatch(value??"","^[a-f0-9]{64}$"))throw new Exception("Invalid bundle hash.");
            DateTime issued,expires;
            if(!DateTime.TryParseExact(m.issued_utc,"yyyy-MM-dd'T'HH:mm:ss'Z'",CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out issued)||
               !DateTime.TryParseExact(m.expires_utc,"yyyy-MM-dd'T'HH:mm:ss'Z'",CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal|DateTimeStyles.AdjustToUniversal,out expires)||
               expires<=issued||expires-issued>TimeSpan.FromDays(100)||(!receipt&&(issued>now.AddMinutes(5)||expires<=now)))throw new Exception("Bundle metadata has expired or the PC clock is incorrect.");
            return m;
        }
        public static void VerifyPackage(VerifiedBundle bundle) {
            Paths.NoLinks(bundle.Package);
            if(!File.Exists(bundle.Package)||new FileInfo(bundle.Package).Length!=bundle.Manifest.size||Paths.Hash(bundle.Package)!=bundle.Manifest.sha256)throw new Exception("Update bundle is incomplete or changed. No files were installed.");
        }
        static void CheckEntry(string name) {
            if(String.IsNullOrEmpty(name)||name.Contains("\\")||name.Contains(":")||name.StartsWith("/",StringComparison.Ordinal)||name.Split('/').Any(s=>s==".."||s=="."))throw new Exception("Unsafe path in update bundle.");
        }
        static string Version(string text) {
            var d=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(text);
            if(d==null||!d.ContainsKey("id")||Convert.ToString(d["id"])!="BalatroTogether"||!d.ContainsKey("version"))throw new Exception("Update bundle has no recognized Together metadata.");
            string result=Convert.ToString(d["version"]);UpdatePolicy.Number(result);return result;
        }
        public static Dictionary<string,string> Files(VerifiedBundle bundle) {
            VerifyPackage(bundle);var files=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);long length=0;
            using(var zip=ZipFile.OpenRead(bundle.Package)) {
                if(zip.Entries.Count>20000)throw new Exception("Too many bundle entries.");
                foreach(var entry in zip.Entries) {
                    CheckEntry(entry.FullName);if(!seen.Add(entry.FullName))throw new Exception("Duplicate bundle path.");
                    if(entry.FullName.EndsWith("/",StringComparison.Ordinal))continue;
                    length+=entry.Length;if(entry.Length>128L*1024*1024||length>MaxExtracted)throw new Exception("Expanded bundle is too large.");
                    if(entry.FullName.StartsWith("Mods/",StringComparison.Ordinal)||entry.FullName=="Game Folder/winmm.dll")using(var input=entry.Open())files.Add(entry.FullName,Hash(input));
                }
                var meta=zip.GetEntry("Mods/BalatroTogether/BalatroTogether.json");
                if(meta==null||meta.Length>65536)throw new Exception("Together metadata is missing from the bundle.");
                using(var reader=new StreamReader(meta.Open(),UpdatePolicy.Utf8))if(Version(reader.ReadToEnd())!=bundle.Manifest.version)throw new Exception("Bundle gameplay version differs from its signed release.");
            }
            string dll;if(!files.TryGetValue("Game Folder/winmm.dll",out dll)||dll!=bundle.Manifest.lovely_sha256)throw new Exception("Signed Lovely loader is missing or changed.");
            var names=files.Keys.Where(n=>n.StartsWith("Mods/",StringComparison.Ordinal)).Select(n=>n.Split('/')[1]).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
            if(!names.Contains("BalatroTogether")||!names.Contains("Amulet")||!names.Contains("Cryptid")||names.Count(n=>Regex.IsMatch(n,"^(?:smods|Steamodded)(?:[-_.][A-Za-z0-9.-]+)?$",RegexOptions.IgnoreCase))!=1)throw new Exception("Bundle components are incomplete.");
            return files;
        }
        public static string[] ModNames(string stage) {
            var names=Directory.GetDirectories(Path.Combine(stage,"Mods")).Select(Path.GetFileName).Where(n=>n=="BalatroTogether"||n=="Amulet"||n=="Cryptid"||Regex.IsMatch(n,"^(?:smods|Steamodded)(?:[-_.][A-Za-z0-9.-]+)?$",RegexOptions.IgnoreCase)).ToArray();
            if(names.Length!=4)throw new Exception("Expected four signed mod components.");return names;
        }
        public static string Extract(VerifiedBundle bundle,string parent) {
            var files=Files(bundle);Paths.NoLinks(parent);Directory.CreateDirectory(parent);string stage=Path.Combine(parent,Guid.NewGuid().ToString("N"));Directory.CreateDirectory(stage);
            try {
                using(var zip=ZipFile.OpenRead(bundle.Package))foreach(var entry in zip.Entries) {
                    if(!files.ContainsKey(entry.FullName))continue;
                    string target=Path.GetFullPath(Path.Combine(stage,entry.FullName.Replace('/',Path.DirectorySeparatorChar)));Paths.Within(target,stage);Paths.NoLinks(target);Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using(var input=entry.Open())using(var output=new FileStream(target,FileMode.CreateNew))input.CopyTo(output);
                    if(Paths.Hash(target)!=files[entry.FullName])throw new Exception("Extracted bundle file failed verification.");
                }
                ModNames(stage);return stage;
            }catch{Paths.RemoveOwned(stage,parent);throw;}
        }
        static VerifiedBundle Load(UserPaths user) {
            string path=ReceiptPath(user);Paths.NoLinks(path);if(!File.Exists(path))return null;if(new FileInfo(path).Length>262144)throw new Exception("Installed bundle receipt is invalid.");
            var receipt=new JavaScriptSerializer().Deserialize<Receipt>(File.ReadAllText(path,UpdatePolicy.Utf8));
            byte[] data=Convert.FromBase64String(receipt.metadata),sig=Convert.FromBase64String(receipt.signature);
            // Receipt verification authenticates an already installed build.
            // Fresh network metadata still enforces expiry on every check.
            var raw=new JavaScriptSerializer().Deserialize<DataManifest>(UpdatePolicy.Utf8.GetString(data));
            var m=Verify(data,sig,"v"+raw.version,DateTime.UtcNow,UpdateKey.PublicXml,true);
            return new VerifiedBundle{Manifest=m,Metadata=data,Signature=sig,Package=CachePath(user,m)};
        }
        public static InstalledBuild Inspect(UserPaths user) {
            if(!File.Exists(ReceiptPath(user)))return null;
            var result=new InstalledBuild();
            try {
                var bundle=Load(user);result.ReleaseVersion=bundle.Manifest.version;result.BundleHash=bundle.Manifest.sha256;result.BundledVersion=bundle.Manifest.version;
                string folder=Path.Combine(user.Roaming,"Balatro","Mods","BalatroTogether"),meta=Path.Combine(folder,"BalatroTogether.json");Paths.NoLinks(meta);
                if(!File.Exists(meta)){result.Problem="Together is missing from this Windows profile.";return result;}
                if(new FileInfo(meta).Length>65536)throw new Exception("Oversized installed metadata.");result.Version=Version(File.ReadAllText(meta,UpdatePolicy.Utf8));
                if(result.Version!=bundle.Manifest.version){result.Problem="Installed Together differs from its signed update receipt.";return result;}
                var files=Files(bundle);
                foreach(var file in files.Where(f=>f.Key.StartsWith("Mods/BalatroTogether/",StringComparison.Ordinal))) {
                    string target=Path.Combine(user.Roaming,"Balatro",file.Key.Replace('/',Path.DirectorySeparatorChar));Paths.Within(target,folder);Paths.NoLinks(target);
                    if(!File.Exists(target)||Paths.Hash(target)!=file.Value){result.Problem="Installed Together needs repair: "+Path.GetFileName(target);return result;}
                }
                return result;
            }catch(Exception error){result.Problem="Installed update needs online repair: "+error.Message;return result;}
        }
        public static void Install(VerifiedBundle bundle,UserPaths user,string game,Action<string> report) {
            string root=UpdateStorage.Root(user);Paths.NoLinks(root);Directory.CreateDirectory(root);string path=Path.Combine(root,"installation.lock");Paths.NoLinks(path);
            FileStream installationLock;
            try{installationLock=new FileStream(path,FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);}catch(IOException){throw new Exception("Another Together update is already installing. Wait for it to finish; no files were changed.");}
            using(installationLock)InstallLocked(bundle,user,game,report);
        }
        static void InstallLocked(VerifiedBundle bundle,UserPaths user,string game,Action<string> report) {
            VerifyPackage(bundle);if(SetupUpdates.Running())throw new Exception("Balatro is open. No update was installed.");
            string floor=SetupUpdates.Floor(user,InstalledBuild.Inspect(user),"0.0.0");
            if(UpdatePolicy.Number(bundle.Manifest.version)<UpdatePolicy.Number(floor))throw new Exception("A newer mod is already installed. Bundle downgrade refused.");
            if(bundle.Manifest.lovely_sha256!=Build.LovelyHash)throw new Exception("This bundle requires an unsupported loader. No files were changed.");
            string cache=CachePath(user,bundle.Manifest);Paths.NoLinks(cache);Directory.CreateDirectory(Path.GetDirectoryName(cache));
            if(!File.Exists(cache)||Paths.Hash(cache)!=bundle.Manifest.sha256) {
                string temp=cache+"."+Guid.NewGuid().ToString("N")+".tmp";File.Copy(bundle.Package,temp,false);
                if(Paths.Hash(temp)!=bundle.Manifest.sha256)throw new Exception("Update cache failed verification.");
                if(File.Exists(cache))File.Replace(temp,cache,null);else File.Move(temp,cache);
            }
            bundle.Package=cache;string receipt=ReceiptPath(user),settings=UpdateStorage.SettingsPath(user);
            byte[] previousReceipt=File.Exists(receipt)?File.ReadAllBytes(receipt):null,previousSettings=File.Exists(settings)?File.ReadAllBytes(settings):null;
            var engine=new Installer(game,Path.Combine(user.Roaming,"Balatro"),Path.Combine(user.Roaming,"BalatroTogether","Backups"),Path.Combine(UpdateStorage.Root(user),"BundleStaging"),bundle.Manifest.game_sha256,SetupUpdates.Running,report){Bundle=bundle};
            engine.CommitInstallation=()=>{
                Detection.Shortcut(user,game,engine.Backup);
                UpdateStorage.Atomic(receipt,UpdatePolicy.Utf8.GetBytes(new JavaScriptSerializer().Serialize(new Receipt{metadata=Convert.ToBase64String(bundle.Metadata),signature=Convert.ToBase64String(bundle.Signature)})));
                var saved=UpdateStorage.Load(user);if(String.IsNullOrEmpty(saved.highest_version)||UpdatePolicy.Number(saved.highest_version)<UpdatePolicy.Number(bundle.Manifest.version))saved.highest_version=bundle.Manifest.version;UpdateStorage.Save(user,saved);
            };
            if(ConfigureEngine!=null)ConfigureEngine(engine);
            try{engine.Install();}catch{
                if(previousReceipt==null){if(File.Exists(receipt))File.Delete(receipt);}else UpdateStorage.Atomic(receipt,previousReceipt);
                if(previousSettings==null){if(File.Exists(settings))File.Delete(settings);}else UpdateStorage.Atomic(settings,previousSettings);throw;
            }
        }
    }
}
