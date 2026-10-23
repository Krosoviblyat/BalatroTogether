"""Package the installable Lua mod; no compiler or third-party dependency needed."""
import hashlib, json, pathlib, re, zipfile, tempfile, tomllib

root=pathlib.Path(__file__).resolve().parents[1]
meta=json.loads((root/'BalatroTogether.json').read_text(encoding='utf-8'))
version=meta['version']
assert re.fullmatch(r'[A-Za-z0-9.-]+',version)
required=['BalatroTogether.json',meta['main_file'],'config.lua','lovely.toml','net/steam_invites.lua','tests/steam_invites_spec.lua',
    'core/numbers.lua','game/compat.lua','CRYPTID.md','tests/cryptid_spec.lua','core/session.lua','core/wire.lua','net/client.lua','net/thread.lua','net/steam.lua','net/steam_native.lua',
    'core/admin.lua','game/admin.lua','ui/admin.lua','ADMIN.md',
    'core/wheel_qte.lua','tests/expansion_spec.lua','core/boss_wheel.lua','core/boss_rewards.lua','core/dice.lua','core/dice_physics.lua','game/dice.lua','ui/dice.lua','ui/dice_renderer.lua','DICE.md',
    'core/pot.lua','game/pot.lua','ui/pot.lua','BET_POT.md',
    'game/bridge.lua','core/donations.lua','game/donations.lua','ui/donations.lua','ui/motion.lua','DONATIONS.md',
    'ui/interface.lua','ui/layout.lua','assets/together-mark.svg','vendor/json.lua',
    'bots/controller.lua','bots/process.lua','bots/strategy.lua','BOTS.md',
    'README.md','INSTALL.md','UNINSTALL.md','TROUBLESHOOTING.md','CHANGELOG.md','KNOWN_ISSUES.md',
    'LICENSE','ATTRIBUTION.md','TEST_RESULTS.md','ARCHITECTURE.md']
for name in required: assert (root/name).is_file(),name
assert tomllib.loads((root/'lovely.toml').read_text())['manifest']['version']=='1.0.0'
assert hashlib.sha256((root/'vendor/json.lua').read_bytes()).hexdigest()=='0eaccda57fabc0330736de25f45cf589821a42b5e0fe02e4e3125f7dc0bf2b7e'
files={}
for path in sorted(root.rglob('*')):
    if not path.is_file() or '__pycache__' in path.parts or 'test-output' in path.parts: continue
    assert not path.is_symlink(),'No linked files in distribution'
    assert path.suffix.lower() not in {'.exe','.dll','.jkr','.love','.pyc','.zip','.log'},path
    relative=path.relative_to(root).as_posix()
    if path.suffix.lower()=='.json' and path.parent==root:
        assert relative=='BalatroTogether.json','Root JSON would be parsed as Steamodded metadata: '+relative
    if relative=='MANIFEST.sha256': continue
    files[relative]=path.read_bytes()
manifest=''.join(hashlib.sha256(data).hexdigest()+'  '+name+'\n' for name,data in files.items())
(root/'MANIFEST.sha256').write_text(manifest,encoding='utf-8',newline='\n')
files['MANIFEST.sha256']=manifest.encode()
target=root.parent/f'BalatroTogether-4Player-{version}.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for name,data in files.items():
        info=zipfile.ZipInfo('BalatroTogether/'+name,date_time=(2026,10,21,0,0,0))
        info.compress_type=zipfile.ZIP_DEFLATED; info.external_attr=0o100644<<16
        archive.writestr(info,data)
scratch=root.parents[1]/'work/package-validation'; scratch.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='mods-',dir=scratch) as folder:
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        for entry in archive.infolist():
            assert entry.filename.startswith('BalatroTogether/') and '..' not in pathlib.PurePosixPath(entry.filename).parts
        archive.extractall(folder)
    installed=pathlib.Path(folder)/'BalatroTogether'
    for name,data in files.items(): assert (installed/name).read_bytes()==data,name
    assert json.loads((installed/'BalatroTogether.json').read_text())['main_file']=='main.lua'
    assert (installed/'main.lua').is_file() and (installed/'lovely.toml').is_file()
digest=hashlib.sha256(target.read_bytes()).hexdigest()
target.with_suffix('.sha256').write_text(digest+'  '+target.name+'\n')
print(f'PASS archive CRC, safe paths, clean Mods extraction, {len(files)} byte-identical files, loader entry points')
print(target)
print(f'{target.stat().st_size:,} bytes; SHA256 {digest}')
