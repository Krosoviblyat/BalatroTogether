// Native WinForms render/smoke fixtures. Never launches or installs the game.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Web.Script.Serialization;
using System.Windows.Forms;
namespace TogetherSetup {
    internal static class UIShowcase {
        static void Bounds(Control parent) {
            foreach(Control child in parent.Controls) {
                if(child.Left<0||child.Top<0||child.Right>parent.ClientSize.Width||child.Bottom>parent.ClientSize.Height)throw new Exception("Control outside its panel: "+child.Text);
                Bounds(child);
            }
        }
        public static int Run(string folder) {
            Directory.CreateDirectory(folder);Paths.NoLinks(folder);
            try {
                SetupForm.PreviewMode=true;LauncherForm.PreviewMode=true;
                var user=new UserPaths {Local=Path.Combine(folder,"Profile"),Roaming=Path.Combine(folder,"Roaming"),Desktop=Path.Combine(folder,"Desktop")};
                var tests=new List<string>();
                using(var icon=Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location))using(var bitmap=icon.ToBitmap())bitmap.Save(Path.Combine(folder,"native-exe-icon.png"));
                tests.Add("Windows can extract the embedded user-supplied executable icon");
                using(var setup=new SetupForm(user,@"C:\Program Files (x86)\Steam\steamapps\common\Balatro",false))Capture(setup,folder,"setup",tests);
                using(var launcher=new LauncherForm(user,@"C:\Program Files (x86)\Steam\steamapps\common\Balatro"))Capture(launcher,folder,"launcher",tests);
                File.WriteAllText(Path.Combine(folder,"ui-results.json"),new JavaScriptSerializer().Serialize(new {passed=tests.Count,failed=0,tests=tests}));return 0;
            }catch(Exception e){File.WriteAllText(Path.Combine(folder,"ui-results.json"),new JavaScriptSerializer().Serialize(new {failed=1,error=e.ToString()}));return 1;}
        }
        static void Capture(StudioForm form,string folder,string name,List<string> tests) {
            form.ShowInTaskbar=false;form.StartPosition=FormStartPosition.Manual;form.Location=new Point(-32000,-32000);form.Show();Application.DoEvents();
            Bounds(form);tests.Add(name+": all controls fit their panels at 100% scale");
            foreach(Control child in form.Controls)if(child is Label&&child.Text=="come on in and join the coop fest!") {
                if(TextRenderer.MeasureText(child.Text,child.Font,new Size(child.Width,child.Height),TextFormatFlags.SingleLine|TextFormatFlags.NoPadding).Width>child.Width)throw new Exception("Welcome line is truncated");
                tests.Add(name+": complete coop fest welcome line fits without truncation");
            }
            if(form.AcceptButton==null)throw new Exception("Missing keyboard default action");tests.Add(name+": keyboard default action available");
            form.ReducedMotion=false;form.Progress.Busy=true;
            for(int i=0;i<50;i++) {
                form.Progress.Target=15+i*1.5f;form.Animate(1f/30);Application.DoEvents();
                using(var image=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(image,new Rectangle(0,0,image.Width,image.Height));image.Save(Path.Combine(folder,name+"-"+i.ToString("D2")+".png"));}
            }
            if(Paths.Hash(Path.Combine(folder,name+"-00.png"))==Paths.Hash(Path.Combine(folder,name+"-49.png")))throw new Exception("Animation frames did not change");
            tests.Add(name+": native animation produces distinct frames");
            form.ReducedMotion=true;float age=form.AnimationAge;form.Animate(.5f);if(form.AnimationAge!=age)throw new Exception("Reduced motion did not stop decorative animation");tests.Add(name+": reduced motion freezes decorative animation");
            form.Progress.Busy=false;form.Progress.Target=0;form.Animate(.1f);
            using(var image=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(image,new Rectangle(0,0,image.Width,image.Height));image.Save(Path.Combine(folder,name+"-still.png"));}
            form.Close();
        }
    }
}
