using System;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
namespace TogetherSetup { internal static class GitHubAccess {
        public static bool Show(IWin32Window owner,UserPaths user,bool reducedMotion) {
            using(var form=new Form {Text="Connect GitHub",BackColor=Studio.Ink,ForeColor=Studio.Cream,Font=new Font("Segoe UI",10),ClientSize=new Size(600,370),StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false}) {
                var label=new Label {Text="Use your own GitHub token with read access to Krosoviblyat/BalatroTogether. Your GitHub account must already have repository access.\n\nOwner: fine-grained token, select this repository, Contents: Read-only. Invited collaborators may need a classic token with repo scope; that grants broader access. Never share an owner's token.\n\nSaved encrypted for this Windows account. Leave empty to forget it.",Location=new Point(24,24),Size=new Size(552,200),ForeColor=Studio.Cream};form.Controls.Add(label);
                var token=new TextBox {UseSystemPasswordChar=true,Location=new Point(24,238),Size=new Size(552,30),MaxLength=255,BackColor=Studio.Panel,ForeColor=Studio.Cream,BorderStyle=BorderStyle.FixedSingle};form.Controls.Add(token);
                var help=new LinkLabel {Text="Open GitHub token settings",Location=new Point(24,309),AutoSize=true,LinkColor=Studio.Red,ActiveLinkColor=Studio.Cream};help.LinkClicked+=(s,e)=>Process.Start(new ProcessStartInfo("https://github.com/settings/tokens"){UseShellExecute=true});form.Controls.Add(help);
                var save=new StudioButton {Text="Save access",Primary=true,Location=new Point(413,292),Size=new Size(163,52)};save.Click+=(s,e)=>{try{UpdateStorage.SaveToken(user,token.Text);form.DialogResult=DialogResult.OK;form.Close();}catch(Exception error){MessageBox.Show(form,error.Message);}};form.Controls.Add(save);
                form.AcceptButton=save;
                using(var animation=new Timer {Interval=16}) {
                    animation.Tick+=(sender,e)=>save.Animate(.016f,reducedMotion);animation.Start();
                    return form.ShowDialog(owner)==DialogResult.OK;
                }
            }
        }
} }
