-- Windows child processes: original owned game, inherited loaders, isolated saves.
-- No shell, injected executable, external interpreter or network service.
local P={}
if not jit or jit.os~='Windows' then return P end
local ffi=require('ffi')
ffi.cdef[[
typedef struct { unsigned long cb; wchar_t *reserved,*desktop,*title; unsigned long x,y,w,h,xc,yc,fill,flags; unsigned short show,cb2; unsigned char *reserved2; void *inHandle,*outHandle,*errHandle; } BT_STARTUPINFOW;
typedef struct { void *process,*thread; unsigned long pid,tid; } BT_PROCESSINFO;
int __stdcall CreateProcessW(const wchar_t*,wchar_t*,void*,void*,int,unsigned long,void*,const wchar_t*,BT_STARTUPINFOW*,BT_PROCESSINFO*);
wchar_t* __stdcall GetEnvironmentStringsW(void);
int __stdcall FreeEnvironmentStringsW(wchar_t*);
int __stdcall MultiByteToWideChar(unsigned int,unsigned long,const char*,int,wchar_t*,int);
unsigned long __stdcall GetCurrentProcessId(void);
unsigned long __stdcall GetLastError(void);
unsigned long __stdcall WaitForSingleObject(void*,unsigned long);
void* __stdcall OpenProcess(unsigned long,int,unsigned long);
int __stdcall TerminateProcess(void*,unsigned int);
int __stdcall CloseHandle(void*);
int __stdcall EnumWindows(int (__stdcall *)(void*,intptr_t),intptr_t);
unsigned long __stdcall GetWindowThreadProcessId(void*,unsigned long*);
int __stdcall IsWindowVisible(void*);
int __stdcall ShowWindow(void*,int);
]]
local k=ffi.load('kernel32')
local user=ffi.load('user32')
local function wide(s)
    local n=k.MultiByteToWideChar(65001,0,s,#s,nil,0)
    local buffer=ffi.new('wchar_t[?]',n+1)
    k.MultiByteToWideChar(65001,0,s,#s,buffer,n); return buffer,n
end
local function environment(add)
    local env=k.GetEnvironmentStringsW(); assert(env~=nil,'Cannot read process environment')
    local chunks={}; local i=0
    while env[i]~=0 do
        local begin=i; while env[i]~=0 do i=i+1 end
        local chars={}; for j=begin,i-1 do chars[#chars+1]=env[j]<128 and string.char(env[j]) or '?' end
        local name=table.concat(chars):match('^([^=]+)=') or ''
        if not name:match('^BT_BOT_') and not name:match('^BT_LAB_') and not add[name] then
            chunks[#chunks+1]={ffi.string(env+begin,(i-begin+1)*2),(i-begin+1)}
        end
        i=i+1
    end
    k.FreeEnvironmentStringsW(env)
    for name,value in pairs(add) do local value,n=wide(name..'='..value); chunks[#chunks+1]={ffi.string(value,(n+1)*2),n+1} end
    local total=1; for _,v in ipairs(chunks) do total=total+v[2] end
    local result=ffi.new('wchar_t[?]',total); local offset=0
    for _,v in ipairs(chunks) do ffi.copy(result+offset,v[1],v[2]*2); offset=offset+v[2] end
    return result
end
function P.pid() return tonumber(k.GetCurrentProcessId()) end
-- LuaJIT has a finite callback slot table. Allocate one callback for this
-- module's lifetime; allocating/freeing a fresh Lua closure each frame can
-- still exhaust that table. EnumWindows calls this synchronously.
local hide_ids={}
local window_pid=ffi.new('unsigned long[1]')
local function visit_window(hwnd,_)
    user.GetWindowThreadProcessId(hwnd,window_pid)
    if hide_ids[tonumber(window_pid[0])] and user.IsWindowVisible(hwnd)~=0 then user.ShowWindow(hwnd,0) end
    return 1
end
if jit.off then jit.off(visit_window,true) end
local window_callback=ffi.cast('int (__stdcall *)(void*,intptr_t)',visit_window)
function P.hide(processes)
    local ids={}; for _,p in pairs(processes) do ids[p.pid]=true end
    if not next(ids) then return end
    hide_ids=ids
    user.EnumWindows(window_callback,0)
    hide_ids={}
end
-- A C call that re-enters Lua must not be compiled into a JIT trace.
if jit.off then jit.off(P.hide,true) end
local function copytree(source,target,mod)
    assert(NFS.createDirectory(target))
    for _,name in ipairs(NFS.getDirectoryItems(source)) do
        local info=NFS.getInfo(source..'/'..name)
        if name~='.git' and name~='__pycache__' then
            if info.type=='directory' then
                if not mod or ({core=true,net=true,game=true,ui=true,vendor=true,bots=true,assets=true})[name] then copytree(source..'/'..name,target..'/'..name,false) end
            elseif not mod or ({['main.lua']=true,['config.lua']=true,['BalatroTogether.json']=true,['lovely.toml']=true})[name] then
                assert(NFS.write(target..'/'..name,assert(NFS.read(source..'/'..name))))
            end
        end
    end
end
function P.spawn(config)
    local base=love.filesystem.getSourceBaseDirectory():gsub('/','\\')
    local exe=base..'\\Balatro.exe'
    if not NFS.getInfo(exe) then return nil,'Cannot find the owned Balatro.exe beside the running game.' end
    -- Lovely writes dumps/logs under Mods. Sharing that folder between native
    -- processes races its startup cleanup. Copy only the two required mods;
    -- never inherit test harnesses or unrelated mods into a companion.
    local relative='together-bots/'..config.identity..'/Mods'
    assert(love.filesystem.createDirectory(relative))
    local mods=love.filesystem.getSaveDirectory()..'/'..relative
    copytree(SMODS.path:gsub('/$',''),mods..'/Steamodded',false)
    copytree(BT.root:gsub('/$',''),mods..'/BalatroTogether',true)
    for _,id in ipairs({'Amulet','Cryptid'}) do
        local dependency=SMODS.Mods[id]
        if dependency and dependency.path and not dependency.disabled then copytree(dependency.path:gsub('/$',''),mods..'/'..id,false) end
    end
    local app=wide(exe); local command=wide('"'..exe..'" --disable-console'); local cwd=wide(base)
    local si=ffi.new('BT_STARTUPINFOW'); si.cb=ffi.sizeof(si); si.flags=1; si.show=0
    local pi=ffi.new('BT_PROCESSINFO')
    local env=environment{BT_BOT_CONFIG=BT.json.encode(config),BT_BOT_ID=config.identity,LOVELY_MOD_DIR=mods}
    if k.CreateProcessW(app,command,nil,nil,0,0x08000400,env,cwd,si,pi)==0 then return nil,'Bot launch failed (Windows '..tonumber(k.GetLastError())..').' end
    k.CloseHandle(pi.thread)
    return {handle=pi.process,pid=tonumber(pi.pid)}
end
function P.alive(p) return p and p.handle~=nil and k.WaitForSingleObject(p.handle,0)==258 end
function P.close(p)
    if p and p.handle~=nil then if P.alive(p) then k.TerminateProcess(p.handle,0) end; k.CloseHandle(p.handle); p.handle=nil end
end
function P.watch(pid) local h=k.OpenProcess(0x100000,0,pid); if h~=nil then return {handle=h} end end
function P.release(p) if p and p.handle~=nil then k.CloseHandle(p.handle); p.handle=nil end end
return P
