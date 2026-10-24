"""Run actual Lua 5.1/LuaJIT code. Development-only dependency: lupa 2.8."""
import pathlib, sys
root = pathlib.Path(__file__).resolve().parents[1]
try:
    from lupa.luajit21 import LuaRuntime
except ImportError:
    from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ROOT = root.as_posix()
compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); assert(f,e); return true end')
files=list(root.rglob('*.lua'))
for path in files:
    compile_lua(path.read_text(encoding='utf-8'), path.relative_to(root).as_posix())
print(f'LuaJIT/Lua 5.1 syntax: {len(files)} files PASS', flush=True)
lua.execute((root/'tests/session_spec.lua').read_text(encoding='utf-8'))
lua2 = LuaRuntime(unpack_returned_tuples=True)
lua2.globals().ROOT = root.as_posix()
lua2.execute((root/'tests/bridge_spec.lua').read_text(encoding='utf-8'))
lua3 = LuaRuntime(unpack_returned_tuples=True)
lua3.globals().ROOT = root.as_posix()
lua3.execute((root/'tests/bots_spec.lua').read_text(encoding='utf-8'))
lua4 = LuaRuntime(unpack_returned_tuples=True)
lua4.globals().ROOT = root.as_posix()
lua4.execute((root/'tests/process_spec.lua').read_text(encoding='utf-8'))
lua5 = LuaRuntime(unpack_returned_tuples=True)
lua5.globals().ROOT = root.as_posix()
lua5.execute((root/'tests/donations_spec.lua').read_text(encoding='utf-8'))
lua6 = LuaRuntime(unpack_returned_tuples=True)
lua6.globals().ROOT = root.as_posix()
lua6.execute((root/'tests/donation_bridge_spec.lua').read_text(encoding='utf-8'))
lua7 = LuaRuntime(unpack_returned_tuples=True)
lua7.globals().ROOT = root.as_posix()
lua7.execute((root/'tests/pin_spec.lua').read_text(encoding='utf-8'))
lua8 = LuaRuntime(unpack_returned_tuples=True)
lua8.globals().ROOT = root.as_posix()
lua8.execute((root/'tests/steam_spec.lua').read_text(encoding='utf-8'))
lua9 = LuaRuntime(unpack_returned_tuples=True)
lua9.globals().ROOT = root.as_posix()
lua9.execute((root/'tests/handshake_spec.lua').read_text(encoding='utf-8'))
for suite in ('party_spec.lua','steam_code_spec.lua','steam_invites_spec.lua','pot_spec.lua','pot_bridge_spec.lua','dice_spec.lua','dice_bridge_spec.lua','admin_spec.lua','expansion_spec.lua','harbinger_spec.lua'):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().ROOT = root.as_posix()
    runtime.execute((root/'tests'/suite).read_text(encoding='utf-8'))

amulet=next((p/'work/upstream-Amulet' for p in root.parents if (p/'work/upstream-Amulet').is_dir()),root/'missing-amulet')
if amulet.is_dir():
    runtime=LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().ROOT=root.as_posix()
    runtime.globals().AMULET_ROOT=amulet.as_posix()
    runtime.execute((root/'tests/cryptid_spec.lua').read_text(encoding='utf-8'))
else:
    print('SKIP pinned Amulet integration tests: unpack its source in work/upstream-Amulet')
