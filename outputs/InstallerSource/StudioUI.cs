// Original code-drawn interface and animation. MIT. No game art is used.
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Windows.Forms;

namespace TogetherSetup {
    internal static class Studio {
        public static readonly Color Ink=Color.FromArgb(13,24,28),Felt=Color.FromArgb(20,45,44),Panel=Color.FromArgb(26,42,46),Cream=Color.FromArgb(246,239,211),Muted=Color.FromArgb(154,180,175),Teal=Color.FromArgb(56,221,177),Gold=Color.FromArgb(255,189,80);
        public static GraphicsPath Round(RectangleF r,float radius) {
            var p=new GraphicsPath();float d=radius*2;
            p.AddArc(r.X,r.Y,d,d,180,90);p.AddArc(r.Right-d,r.Y,d,d,270,90);p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);p.AddArc(r.X,r.Bottom-d,d,d,90,90);p.CloseFigure();return p;
        }
        public static void Fill(Graphics g,Color color,RectangleF bounds,float radius) {using(var path=Round(bounds,radius))using(var brush=new SolidBrush(color))g.FillPath(brush,path);}
        public static void Stroke(Graphics g,Color color,RectangleF bounds,float radius) {using(var path=Round(bounds,radius))using(var pen=new Pen(color))g.DrawPath(pen,path);}
        public static Label Label(string text,int x,int y,int width,int height,float size,Color color,bool bold) {
            return new Label {Text=text,Location=new Point(x,y),Size=new Size(width,height),ForeColor=color,BackColor=Color.Transparent,Font=new Font("Segoe UI",size,bold?FontStyle.Bold:FontStyle.Regular)};
        }
        public static Color Blend(Color a,Color b,float value) {value=Math.Max(0,Math.Min(1,value));return Color.FromArgb((int)(a.R+(b.R-a.R)*value),(int)(a.G+(b.G-a.G)*value),(int)(a.B+(b.B-a.B)*value));}
        public static void WriteManualBundle(string target) {
            Paths.NoLinks(target);
            using(var input=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))using(var source=Assembly.GetExecutingAssembly().GetManifestResourceStream("setup-source.zip")) {
                using(var hash=SHA256.Create()){if(BitConverter.ToString(hash.ComputeHash(input)).Replace("-","").ToLowerInvariant()!=Build.PayloadHash)throw new Exception("The embedded bundle failed verification.");}input.Position=0;
                if(source==null)throw new Exception("The installer source bundle is missing.");
                using(var output=new ZipArchive(new FileStream(target,FileMode.CreateNew),ZipArchiveMode.Create)) {
                    using(var entry=output.CreateEntry("Manual Install.zip").Open())input.CopyTo(entry);
                    using(var originals=new ZipArchive(source,ZipArchiveMode.Read))foreach(var entry in originals.Entries)using(var from=entry.Open())using(var to=output.CreateEntry(entry.FullName).Open())from.CopyTo(to);
                }
            }
        }
        public static void ExportManual(IWin32Window owner) {
            using(var dialog=new SaveFileDialog {Title="Save manual installation, licenses and source bundle",FileName="BalatroTogether-Manual-Licenses-Sources.zip",Filter="ZIP bundle|*.zip",OverwritePrompt=true}) {
                if(dialog.ShowDialog(owner)!=DialogResult.OK)return;
                string temp=null;
                try {
                    Paths.NoLinks(dialog.FileName);temp=dialog.FileName+"."+Guid.NewGuid().ToString("N")+".tmp";
                    WriteManualBundle(temp);
                    if(File.Exists(dialog.FileName))File.Replace(temp,dialog.FileName,null);else File.Move(temp,dialog.FileName);
                    MessageBox.Show(owner,"Saved. The bundle includes manual installation files, third-party licenses and exact dependency sources.","Bundle exported");
                }catch(Exception e){MessageBox.Show(owner,e.Message,"Export stopped");}
                finally{if(temp!=null&&File.Exists(temp))File.Delete(temp);}
            }
        }
    }
    internal sealed class StudioButton : Button {
        public bool Primary;
        public Color Accent=Studio.Teal;
        float hover,press;bool over,down;
        public StudioButton() {SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true);FlatStyle=FlatStyle.Flat;FlatAppearance.BorderSize=0;BackColor=Studio.Ink;ForeColor=Studio.Cream;Font=new Font("Segoe UI",11,FontStyle.Bold);Cursor=Cursors.Hand;AccessibleRole=AccessibleRole.PushButton;}
        protected override void OnMouseEnter(EventArgs e){over=true;base.OnMouseEnter(e);}
        protected override void OnMouseLeave(EventArgs e){over=false;down=false;base.OnMouseLeave(e);}
        protected override void OnMouseDown(MouseEventArgs e){if(e.Button==MouseButtons.Left)down=true;base.OnMouseDown(e);}
        protected override void OnMouseUp(MouseEventArgs e){down=false;base.OnMouseUp(e);}
        protected override void OnKeyDown(KeyEventArgs e){if(e.KeyCode==Keys.Space||e.KeyCode==Keys.Enter)down=true;base.OnKeyDown(e);}
        protected override void OnKeyUp(KeyEventArgs e){down=false;base.OnKeyUp(e);}
        protected override void OnLostFocus(EventArgs e){down=false;base.OnLostFocus(e);}
        public void Animate(float dt,bool reduced) {
            float h=Enabled&&(over||Focused)?1:0,p=Enabled&&down?1:0;
            float old=hover+press;float amount=reduced?1:Math.Min(1,dt*15);hover+=(h-hover)*amount;press+=(p-press)*amount;
            if(Math.Abs(old-hover-press)>.001f)Invalidate();
        }
        protected override void OnPaint(PaintEventArgs e) {
            var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;
            g.Clear(Parent is StudioPanel?Studio.Panel:BackColor);
            float lift=hover*2-press*3;var box=new RectangleF(1,3-lift,Width-3,Height-9);
            Studio.Fill(g,Color.FromArgb(5,13,16),new RectangleF(box.X,box.Y+5,box.Width,box.Height),10);
            Color fill=Primary?Accent:Studio.Panel;
            if(!Enabled)fill=Color.FromArgb(33,47,48);
            fill=Studio.Blend(fill,Primary?Color.White:Color.FromArgb(52,79,78),hover*.12f);
            Studio.Fill(g,fill,box,10);Studio.Stroke(g,Enabled?Studio.Blend(fill,Studio.Cream,.15f+hover*.15f):Color.FromArgb(46,60,60),box,10);
            var text=Rectangle.Round(box);text.Offset(0,-1);
            TextRenderer.DrawText(g,Text,Font,text,!Enabled?Color.FromArgb(110,132,128):Primary?Studio.Ink:Studio.Cream,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.NoPrefix);
            if(Focused&&ShowFocusCues){text.Inflate(-6,-6);ControlPaint.DrawFocusRectangle(g,text,Studio.Cream,fill);}
        }
    }
    internal sealed class StudioPanel : Panel {
        public StudioPanel(){DoubleBuffered=true;BackColor=Studio.Panel;}
        protected override void OnPaintBackground(PaintEventArgs e) {e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;e.Graphics.Clear(Studio.Ink);Studio.Fill(e.Graphics,Studio.Panel,new RectangleF(0,0,Width-1,Height-1),14);Studio.Stroke(e.Graphics,Color.FromArgb(46,66,66),new RectangleF(0,0,Width-1,Height-1),14);}
    }
    internal sealed class StudioProgress : Control {
        public bool Busy;public float Target;float current,phase;
        public StudioProgress(){SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true);AccessibleRole=AccessibleRole.ProgressBar;Height=9;BackColor=Studio.Panel;}
        public void Animate(float dt,bool reduced){float old=current;current+=(Target-current)*(reduced?1:Math.Min(1,dt*8));if(!reduced)phase=(phase+dt*.55f)%1;if(Math.Abs(old-current)>.001f||(Busy&&!reduced))Invalidate();}
        protected override void OnPaint(PaintEventArgs e) {
            var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;g.Clear(BackColor);
            Studio.Fill(g,Color.FromArgb(11,26,29),new RectangleF(0,0,Width-1,Height-1),4);
            if(current>.1f)Studio.Fill(g,Studio.Teal,new RectangleF(0,0,Math.Max(8,(Width-1)*current/100),Height-1),4);
            if(Busy) {float width=Width*.24f;float x=(Width+width)*phase-width;var clip=g.Save();g.SetClip(new Rectangle(0,0,Width,Height));Studio.Fill(g,Color.FromArgb(82,Studio.Cream),new RectangleF(x,0,width,Height-1),4);g.Restore(clip);}
        }
    }
    internal class StudioForm : Form {
        readonly Timer clock=new Timer {Interval=16};readonly Stopwatch elapsed=new Stopwatch();
        double previous;float age;bool reduce;
        readonly CheckBox motion=new CheckBox();
        public bool ReducedMotion {get{return reduce;}set{reduce=value;motion.Checked=value;Invalidate(true);}}
        public event Action<bool> MotionChanged;
        public readonly StudioProgress Progress=new StudioProgress();
        protected StudioForm(bool preview) {
            ClientSize=new Size(920,620);AutoScaleMode=AutoScaleMode.None;FormBorderStyle=FormBorderStyle.None;StartPosition=FormStartPosition.CenterScreen;MaximizeBox=false;
            BackColor=Studio.Ink;ForeColor=Studio.Cream;Font=new Font("Segoe UI",10);DoubleBuffered=true;
            try{Icon=Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);}catch{}
            var close=new StudioButton {Text="×",AccessibleName="Close window"};close.SetBounds(863,18,35,37);close.Click+=(s,e)=>Close();Controls.Add(close);
            var minimize=new StudioButton {Text="−",AccessibleName="Minimize window"};minimize.SetBounds(821,18,35,37);minimize.Click+=(s,e)=>WindowState=FormWindowState.Minimized;Controls.Add(minimize);
            motion.Text="Reduced motion";motion.SetBounds(32,571,160,25);motion.ForeColor=Studio.Muted;motion.BackColor=Studio.Ink;motion.Font=new Font("Segoe UI",9);motion.CheckedChanged+=(s,e)=>{reduce=motion.Checked;if(MotionChanged!=null)MotionChanged(reduce);Invalidate(true);};Controls.Add(motion);
            Controls.Add(Studio.Label("SETUP + UPDATES   /   "+Build.Version,350,576,440,20,8,Studio.Muted,false));
            clock.Tick+=(s,e)=>{double now=elapsed.Elapsed.TotalSeconds;Animate((float)Math.Min(.05,Math.Max(0,now-previous)));previous=now;};
            Shown+=(s,e)=>{if(!preview){elapsed.Start();clock.Start();}};
        }
        public StudioButton AddButton(string text,int x,int y,int width,bool primary,Action action) {
            var b=new StudioButton {Text=text,Primary=primary};b.SetBounds(x,y,width,54);b.Click+=(s,e)=>action();Controls.Add(b);return b;
        }
        protected void SetHeading(string eyebrow,string title,string subtitle) {
            Controls.Add(Studio.Label(eyebrow,350,104,515,22,9,Studio.Teal,true));
            Controls.Add(Studio.Label(title,346,130,530,50,28,Studio.Cream,true));
            Controls.Add(Studio.Label(subtitle,350,186,514,46,10,Studio.Muted,false));
        }
        public void Animate(float dt) {
            if(!reduce)age+=dt;
            foreach(Control c in Controls)AnimateControl(c,dt);
            if(!reduce)Invalidate(new Rectangle(18,90,300,465));
        }
        void AnimateControl(Control c,float dt) {var button=c as StudioButton;if(button!=null)button.Animate(dt,reduce);var progress=c as StudioProgress;if(progress!=null)progress.Animate(dt,reduce);foreach(Control child in c.Controls)AnimateControl(child,dt);}
        public float AnimationAge {get{return age;}}
        protected override bool ProcessCmdKey(ref Message message,Keys keyData){if(keyData==Keys.Escape){Close();return true;}return base.ProcessCmdKey(ref message,keyData);}
        protected override void Dispose(bool disposing){if(disposing){clock.Stop();clock.Dispose();if(Icon!=null)Icon.Dispose();}base.Dispose(disposing);}
        protected override void WndProc(ref Message m) {
            base.WndProc(ref m);
            if(m.Msg==0x84&&m.Result==(IntPtr)1){int packed=unchecked((int)m.LParam.ToInt64());var point=PointToClient(new Point((short)(packed&65535),(short)((packed>>16)&65535)));if(point.Y>=0&&point.Y<80&&point.X<810)m.Result=(IntPtr)2;}
        }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;
            using(var gradient=new LinearGradientBrush(new Rectangle(18,88,298,468),Studio.Felt,Color.FromArgb(13,32,34),70))using(var shape=Studio.Round(new RectangleF(18,88,298,468),18))g.FillPath(gradient,shape);
            Studio.Stroke(g,Color.FromArgb(42,70,65),new RectangleF(18,88,298,468),18);
            using(var pen=new Pen(Color.FromArgb(25,100,149,128)))for(int row=0;row<15;row++)for(int col=0;col<8;col++){int x=33+col*37,y=104+row*31;g.DrawPolygon(pen,new[]{new Point(x,y-3),new Point(x+3,y),new Point(x,y+3),new Point(x-3,y)});}
            Studio.Fill(g,Studio.Teal,new RectangleF(32,25,33,42),5);
            using(var f=new Font("Segoe UI",18,FontStyle.Bold))TextRenderer.DrawText(g,"♦",f,new Rectangle(33,27,32,36),Studio.Ink,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
            using(var f=new Font("Segoe UI",12,FontStyle.Bold))TextRenderer.DrawText(g,"BALATRO TOGETHER",f,new Point(78,31),Studio.Cream);
            using(var f=new Font("Segoe UI",8))TextRenderer.DrawText(g,"ONE TABLE. EVERYONE IN.",f,new Point(79,53),Studio.Muted);
            using(var f=new Font("Segoe UI",10,FontStyle.Bold))TextRenderer.DrawText(g,"YOUR NEXT RUN",f,new Point(42,119),Studio.Teal);
            using(var f=new Font("Segoe UI",27,FontStyle.Bold))TextRenderer.DrawText(g,"Better\ntogether.",f,new Rectangle(38,144,263,100),Studio.Cream,TextFormatFlags.WordBreak);
            float enter=(float)(1-Math.Exp(-age*6)*Math.Cos(age*9));if(reduce)enter=1;
            for(int i=0;i<3;i++) {
                float wave=reduce?0:(float)Math.Sin(age*1.35+i*.8)*5;
                var state=g.Save();g.TranslateTransform(113+i*47,332+wave+(1-enter)*45);g.RotateTransform(-16+i*16+(reduce?0:(float)Math.Sin(age*.8+i)*1.5f));
                Studio.Fill(g,Color.FromArgb(6,22,23),new RectangleF(-49,-61,100,134),10);
                Color card=i==1?Studio.Teal:i==2?Studio.Gold:Studio.Cream;
                Studio.Fill(g,card,new RectangleF(-50,-68,100,132),9);Studio.Stroke(g,Studio.Blend(card,Color.White,.3f),new RectangleF(-45,-63,90,122),6);
                using(var ink=new SolidBrush(Studio.Ink)) {
                    using(var f=new Font("Segoe UI",13,FontStyle.Bold))g.DrawString(new[]{"A","B","T"}[i],f,ink,new PointF(-39,-57));
                    using(var f=new Font("Segoe UI",38,FontStyle.Bold))using(var align=new StringFormat {Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center})g.DrawString(new[]{"♠","♦","♥"}[i],f,ink,new RectangleF(-46,-38,92,92),align);
                }
                g.Restore(state);
            }
            using(var f=new Font("Segoe UI",11,FontStyle.Bold))TextRenderer.DrawText(g,"THE WHOLE PARTY, INCLUDED.",f,new Point(42,445),Studio.Cream);
            using(var f=new Font("Segoe UI",9))TextRenderer.DrawText(g,"Lovely · Steamodded\nCryptid · Amulet · Together",f,new Rectangle(42,477,245,53),Studio.Muted,TextFormatFlags.WordBreak);
            Studio.Stroke(g,Color.FromArgb(62,85,80),new RectangleF(0,0,Width-1,Height-1),9);
        }
    }
}
