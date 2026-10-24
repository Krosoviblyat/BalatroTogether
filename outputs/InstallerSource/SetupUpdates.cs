// Shared online selection/download path used by setup and launcher. MIT.
using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace TogetherSetup {
    internal static class SetupUpdates {
        // Internal dependency seams for isolated production-form tests. No user
        // input or environment variable can enable these test overrides.
        internal static Func<string,GitHubUpdates> ClientFactory=token=>new GitHubUpdates(token);
        internal static Func<bool> Running=Detection.Running;
        internal static Action<string,string> Handoff=(installer,game)=>Process.Start(new ProcessStartInfo(installer,"--update "+Paths.Quote(game)){UseShellExecute=true,WorkingDirectory=Path.GetDirectoryName(installer)});
        internal static string TestCurrentVersion;
        internal sealed class Result { public GitHubUpdates Client; public GitHubUpdates.Offer Offer; public string Floor; }
        public static string Floor(UserPaths user,InstalledBuild installed,string current) {
            string floor=current;var settings=UpdateStorage.Load(user);
            foreach(string version in new[]{settings.highest_version,installed.Version}) {
                if(String.IsNullOrEmpty(version))continue;
                try{if(UpdatePolicy.Number(version)>UpdatePolicy.Number(floor))floor=version;}catch{}
            }
            return floor;
        }
        public static Result Check(UserPaths user,string stage) {
            var installed=InstalledBuild.Inspect(user);string current=TestCurrentVersion??Build.Version;
            string floor=Floor(user,installed,current);var client=ClientFactory(UpdateStorage.Token(user));
            return new Result {Client=client,Offer=client.Find(stage,current,floor),Floor=floor};
        }
        public static void CanInstallBundle(UserPaths user) {
            string floor=Floor(user,InstalledBuild.Inspect(user),Build.Version);
            if(UpdatePolicy.Number(floor)>UpdatePolicy.Number(Build.Version))throw new Exception("This setup is older than your recorded installation. Download the current setup; no older bundle was installed.");
        }
        public static string Download(Result result,string stage,Action<string> report) {
            var offer=result.Offer;if(offer==null)throw new Exception("No signed update was selected.");
            if(Running())throw new Exception("Balatro is open. No update was installed.");
            string package=Path.Combine(stage,"update.package");int last=-1;
            result.Client.Download(offer.packageApi,package,offer.manifest.size,n=>{
                int percent=(int)(n*100/offer.manifest.size);if(percent!=last){last=percent;report("Downloading "+offer.manifest.version+"  "+percent+"%");}
            });
            return UpdatePolicy.PrepareInstaller(package,Path.Combine(stage,"Verified"),offer.manifest);
        }
        public static void StartVerified(string installer,string game) {
            if(Running())throw new Exception("Balatro was opened. No game files were changed.");
            Handoff(installer,game);
        }
    }
}
