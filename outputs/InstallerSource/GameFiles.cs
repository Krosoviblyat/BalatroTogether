// Validate the user's own game; never distribute or download its runtime files.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
namespace TogetherSetup {
    internal sealed class GameFilesException:Exception {
        public readonly string[] Files;
        public GameFilesException(string folder,string[] files):base(
            "Balatro's own game files are missing or invalid:\n"+String.Join(", ",files)+
            "\n\nSelected folder:\n"+folder+
            "\n\nIn Steam: Balatro > Properties > Installed Files > Verify integrity of game files. Then use Browse to locate the full game folder and select its Balatro.exe in setup. Do not move Balatro.exe by itself.\n\nThe mod installer supplies winmm.dll here and the mods in your Windows AppData folder. It cannot replace missing Balatro runtime files.") {Files=files;}
    }
    internal static class GameFiles {
        internal static readonly string[] Required={"SDL2.dll","love.dll","lua51.dll","OpenAL32.dll","mpg123.dll","msvcp120.dll","msvcr120.dll","luasteam.dll","steam_api64.dll"};
        static bool Native64(string path) {
            if(!File.Exists(path))return false;Paths.NoLinks(path);
            using(var stream=File.OpenRead(path))using(var reader=new BinaryReader(stream)) {
                if(stream.Length<256||reader.ReadUInt16()!=0x5a4d)return false;
                stream.Position=0x3c;int offset=reader.ReadInt32();if(offset<64||offset>stream.Length-26)return false;
                stream.Position=offset;if(reader.ReadUInt32()!=0x4550||reader.ReadUInt16()!=0x8664)return false;
                stream.Position=offset+24;return reader.ReadUInt16()==0x20b;
            }
        }
        public static void Validate(string folder,string expectedHash) {
            Paths.NoLinks(folder);string exe=Path.Combine(folder,"Balatro.exe");
            if(!File.Exists(exe))throw new Exception("Choose the Steam folder containing Balatro.exe.");
            if(Paths.Hash(exe)!=expectedHash)throw new Exception("This package supports Balatro 1.0.1o-FULL for Windows x64. The selected game build differs; automatic installation stopped.");
            var missing=new List<string>();foreach(string name in Required)if(!Native64(Path.Combine(folder,name)))missing.Add(name);
            if(missing.Count>0)throw new GameFilesException(Paths.Full(folder),missing.ToArray());
        }
        public static bool Complete(string folder) {
            try{Validate(folder,Build.GameHash);return true;}catch{return false;}
        }
        public static ProcessStartInfo Launch(string folder) {
            Validate(folder,Build.GameHash);
            return new ProcessStartInfo(Path.Combine(Paths.Full(folder),"Balatro.exe"),"--disable-console"){WorkingDirectory=Paths.Full(folder),UseShellExecute=true};
        }
    }
}
