// ICO format builder, MIT. Input artwork is user-supplied; its rights remain
// with its original rights holder and are not licensed by this source file.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.IO.Compression;
internal static class BrandIcon {
    static int Main(string[] args) {
        int[] sizes={16,24,32,48,64,128,256};var images=new List<byte[]>();
        using(var source=Image.FromFile(args[0]))foreach(int size in sizes) {
            using(var bitmap=new Bitmap(size,size,PixelFormat.Format32bppArgb))using(var g=Graphics.FromImage(bitmap))using(var buffer=new MemoryStream()) {
                g.Clear(Color.White);g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.PixelOffsetMode=PixelOffsetMode.HighQuality;
                float scale=Math.Min((float)size/source.Width,(float)size/source.Height);float width=source.Width*scale,height=source.Height*scale;
                g.DrawImage(source,(size-width)/2,(size-height)/2,width,height);bitmap.Save(buffer,ImageFormat.Png);images.Add(buffer.ToArray());
            }
        }
        using(var output=new BinaryWriter(File.Create(args[1]))) {
            output.Write((ushort)0);output.Write((ushort)1);output.Write((ushort)sizes.Length);int offset=6+16*sizes.Length;
            for(int i=0;i<sizes.Length;i++){output.Write((byte)(sizes[i]==256?0:sizes[i]));output.Write((byte)(sizes[i]==256?0:sizes[i]));output.Write((byte)0);output.Write((byte)0);output.Write((ushort)1);output.Write((ushort)32);output.Write(images[i].Length);output.Write(offset);offset+=images[i].Length;}
            foreach(var image in images)output.Write(image);
        }
        if(args.Length==3) {
            if(File.Exists(args[2]))File.Delete(args[2]);
            using(var archive=ZipFile.Open(args[2],ZipArchiveMode.Create))foreach(string source in Directory.GetFiles(Path.GetDirectoryName(Path.GetFullPath(args[0])))) {
                string ext=Path.GetExtension(source).ToLowerInvariant();
                if(ext==".cs"||ext==".cmd"||ext==".md"||ext==".txt"||ext==".ico"||ext==".jpg"||ext==".manifest")archive.CreateEntryFromFile(source,"InstallerSource/"+Path.GetFileName(source));
            }
        }
        return 0;
    }
}
