-- Reproduce the exhausted-callback failure deterministically without desktop
-- access. Changing target PIDs must neither allocate callbacks nor hide others.
local original_require,original_jit=require,jit
local casts,enums,hidden,off=0,0,{},{}
local api={
    GetWindowThreadProcessId=function(hwnd,pid) pid[0]=hwnd end,
    IsWindowVisible=function() return 1 end,
    ShowWindow=function(hwnd,mode) assert(mode==0); hidden[hwnd]=(hidden[hwnd] or 0)+1 end,
    EnumWindows=function(callback,param)
        enums=enums+1
        callback(101,param); callback(202,param); callback(999,param)
        return 1
    end,
}
local ffi={cdef=function() end,load=function() return api end,new=function() return {[0]=0} end,
    cast=function(_,fn)
        casts=casts+1
        return setmetatable({free=function() end},{__call=function(_,...) return fn(...) end})
    end}
jit={os='Windows',off=function(fn) off[fn]=true end}
require=function(name) if name=='ffi' then return ffi end; return original_require(name) end
local process=dofile(ROOT..'/bots/process.lua')
require,jit=original_require,original_jit
for i=1,20000 do process.hide{{pid=i%2==0 and 101 or 202}} end
assert(casts==1,'Window polling allocates new LuaJIT callbacks')
assert(enums==20000 and hidden[101]==10000 and hidden[202]==10000)
assert(not hidden[999],'Unrelated desktop window hidden')
assert(off[process.hide],'C-to-Lua callback invocation must stay outside JIT traces')
process.hide({}); assert(enums==20000,'No desktop enumeration needed for an empty target set')
print('PASS 20,000 window polls reuse one callback and target only current companion PIDs')
return 1
