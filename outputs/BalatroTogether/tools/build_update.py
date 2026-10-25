"""Build a data-only mod update for the permanent launcher; no EXE compilation."""
from pathlib import Path,PurePosixPath
import argparse,hashlib,json,re,zipfile

def build(mod,base,out):
    version=json.loads((mod/'BalatroTogether.json').read_text(encoding='utf-8'))['version']
    assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-(?:dev|alpha|beta|rc)(?:\.[0-9]+)?)?',version)
    files={}
    with zipfile.ZipFile(base) as archive:
        for entry in archive.infolist():
            name=entry.filename;parts=PurePosixPath(name).parts
            assert not name.startswith('/') and '\\' not in name and ':' not in name and '..' not in parts
            if entry.is_dir() or name.startswith('Mods/BalatroTogether/') or name in {'SHA256SUMS.txt','BUNDLE-CONTENTS.json'}:continue
            assert not name.lower().endswith('.exe'),'Installer EXEs do not belong in data updates'
            if name.startswith('Game Folder/'):assert name=='Game Folder/winmm.dll','Never redistribute owned game files'
            files[name]=archive.read(entry)
    modfiles={}
    for path in sorted(mod.rglob('*')):
        if not path.is_file() or '__pycache__' in path.parts or 'test-output' in path.parts:continue
        relative=path.relative_to(mod).as_posix()
        assert path.suffix.lower() not in {'.exe','.dll','.jkr','.love','.pyc','.zip','.log'}
        if relative!='MANIFEST.sha256':modfiles[relative]=path.read_bytes()
    modfiles['MANIFEST.sha256']=''.join(hashlib.sha256(data).hexdigest()+'  '+name+'\n' for name,data in modfiles.items()).encode()
    for name,data in modfiles.items():files['Mods/BalatroTogether/'+name]=data
    files['BUNDLE-CONTENTS.json']=json.dumps({'version':version,'format':'signed-data','permanent_launcher':True},indent=2).encode()
    files['SHA256SUMS.txt']=''.join(hashlib.sha256(data).hexdigest()+'  '+name+'\n' for name,data in sorted(files.items())).encode()
    out.mkdir(parents=True,exist_ok=True);package=out/f'BalatroTogether-Update-{version}.zip'
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name,data in sorted(files.items()):
            entry=zipfile.ZipInfo(name,date_time=(2026,10,21,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o100644<<16;archive.writestr(entry,data)
    with zipfile.ZipFile(package) as archive:assert archive.testzip() is None
    print(json.dumps({'package':str(package),'version':version,'sha256':hashlib.sha256(package.read_bytes()).hexdigest(),'files':len(files),'installer_exes':0}))
    return package

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--base',required=True,type=Path);parser.add_argument('--out',required=True,type=Path);parser.add_argument('--mod',type=Path,default=Path(__file__).resolve().parents[1]);args=parser.parse_args();build(args.mod,args.base,args.out)
