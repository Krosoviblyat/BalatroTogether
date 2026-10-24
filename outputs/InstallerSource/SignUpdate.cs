// Maintainer-only signing utility. Never distribute a private key. MIT.
using System;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

internal static class SignUpdate {
    static readonly byte[] Entropy=Encoding.UTF8.GetBytes("BalatroTogether.Publisher.Signing.v1");
    static string KeyFile { get {return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"BalatroTogetherPublisher","signing-key.dpapi");} }
    static string Hash(byte[] data) {using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(data)).Replace("-","").ToLowerInvariant();}
    static int Main(string[] args) {
        try {
            if(args.Length==2&&args[0]=="--init") {
                Directory.CreateDirectory(Path.GetDirectoryName(KeyFile));
                using(var rsa=new RSACryptoServiceProvider(3072)) {
                    rsa.PersistKeyInCsp=false;
                    if(File.Exists(KeyFile))rsa.FromXmlString(Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(KeyFile),Entropy,DataProtectionScope.CurrentUser)));
                    else {using(var f=new FileStream(KeyFile,FileMode.CreateNew)) {byte[] key=ProtectedData.Protect(Encoding.UTF8.GetBytes(rsa.ToXmlString(true)),Entropy,DataProtectionScope.CurrentUser);f.Write(key,0,key.Length);}}
                    File.WriteAllText(args[1],"namespace TogetherSetup { internal static class UpdateKey { public const string PublicXml=@\""+rsa.ToXmlString(false).Replace("\"","\"\"")+"\"; } }\n",new UTF8Encoding(false));
                }
                Console.WriteLine("Public verification key exported; private key remains encrypted under this Windows account.");return 0;
            }
            if(args.Length==4&&args[0]=="--sign") {
                string package=args[1],version=args[2],output=args[3];
                bool direct=Path.GetExtension(package).Equals(".exe",StringComparison.OrdinalIgnoreCase);
                if(Path.GetFileName(package)!=(direct?"BalatroTogether-Setup-"+version+".exe":"BalatroTogether-"+version+"-Easy-Installer.zip"))throw new Exception("Package filename and version differ.");
                byte[] installer;
                if(direct)installer=File.ReadAllBytes(package);
                else using(var archive=ZipFile.OpenRead(package))using(var input=archive.GetEntry("Install Balatro Together.exe").Open())using(var buffer=new MemoryStream()){input.CopyTo(buffer);installer=buffer.ToArray();}
                var now=DateTime.UtcNow;
                byte[] manifest=new UTF8Encoding(false).GetBytes(new JavaScriptSerializer().Serialize(new {schema=direct?2:1,repository="Krosoviblyat/BalatroTogether",version=version,asset=Path.GetFileName(package),size=new FileInfo(package).Length,sha256=Hash(File.ReadAllBytes(package)),installer_sha256=Hash(installer),issued_utc=now.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"),expires_utc=now.AddDays(90).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")}));
                using(var rsa=new RSACryptoServiceProvider()) {
                    rsa.PersistKeyInCsp=false;rsa.FromXmlString(Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(KeyFile),Entropy,DataProtectionScope.CurrentUser)));
                    byte[] signature=rsa.SignData(manifest,CryptoConfig.MapNameToOID("SHA256"));
                    Directory.CreateDirectory(output);string name=direct?"Update-v2":"Update";File.WriteAllBytes(Path.Combine(output,name+".json"),manifest);File.WriteAllBytes(Path.Combine(output,name+".sig"),signature);
                }
                Console.WriteLine("Signed update metadata created. Publish it with the exact package on the matching release.");return 0;
            }
            Console.Error.WriteLine("Use --init <UpdateKey.cs> or --sign <Easy-Installer.zip> <version> <output directory>.");return 2;
        }catch {Console.Error.WriteLine("Signing failed. Check the local publisher key, package and output paths. No private key was printed.");return 1;}
    }
}
