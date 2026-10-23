local P=dofile(ROOT..'/net/steam_invites.lua')
local count=0
local function test(name,f) f(); count=count+1; print('PASS '..name) end
local lobby='109775240123456789'
local function fixture(options)
    options=options or {}; local incoming={}; local launch={}; local joins={}; local available=not options.offline
    local n={valid_id=function(s) return type(s)=='string' and s:match('^%d+$') and #s>=16 and #s<=20 end,
        init=function() if available then return {id='76561198000000001'} end end,
        pump=function() end,poll=function() end,invites=function() local q=incoming;incoming={};return q end,
        launch_args=function() local q=launch;launch={};return q end}
    local e=setmetatable({arg=options.args or {},G={STAGE='menu',STAGES={MAIN_MENU='menu',RUN='run'}},BT={id='BalatroTogether',ui={},client={}}},{__index=_G})
    e.SMODS={load_file=function(path)
        if path=='net/steam_native.lua' then return function() return n end end
        return assert(loadfile(ROOT..'/'..path))
    end}
    local f=assert(loadfile(ROOT..'/net/steam.lua'));setfenv(f,e);local s=f()
    e.BT.client.join_steam=function(id) joins[#joins+1]=id;s.invited=nil;s.call={};s.requested=id;s.active=true;s.started=s.clock end
    return {s=s,e=e,joins=joins,invite=function(v) incoming[#incoming+1]=v end,
        launch=function(v) launch[#launch+1]=v end,online=function() available=true end}
end
test('cold launch parses quoted Steam IDs without rounding',function()
    assert(P.command('"C:\\Program Files\\Balatro.exe" +connect_lobby "'..lobby..'"')==lobby)
    assert(P.command({[-2]='Balatro.exe',[3]='+connect_lobby',[4]=lobby})==lobby)
end)
test('only exact Balatro links and connect tokens are accepted',function()
    assert(P.command('steam://joinlobby/2379780/'..lobby..'/76561198000000001')==lobby)
    for _,bad in ipairs({'steam://joinlobby/480/'..lobby..'/76561198000000001',
        '"folder +connect_lobby '..lobby..'"','+connect_lobby '..lobby..';bad',
        'x+connect_lobby '..lobby,'+connect_lobby "'..lobby..'"junk','+connect_lobby "'..lobby}) do assert(not P.command(bad),bad) end
end)
test('accepted running-game invite joins directly from the menu',function()
    local c=fixture();c.invite(lobby);c.s.update(.1);assert(c.joins[1]==lobby)
end)
test('Steam launch API joins even when LOVE arguments are empty',function()
    local c=fixture();c.launch('+connect_lobby '..lobby);c.s.update(.1);assert(c.joins[1]==lobby)
end)
test('OS/LOVE cold launch arguments are retained until Steam comes online',function()
    local c=fixture{offline=true,args={'+connect_lobby',lobby}};c.s.update(.1);assert(#c.joins==0)
    c.online();c.s.update(.1);assert(c.joins[1]==lobby)
end)
test('a launch invite waits until the native menu is ready',function()
    local c=fixture{args={'+connect_lobby',lobby}};c.e.G.STAGE='loading';c.s.update(.1);assert(#c.joins==0)
    c.e.G.STAGE='menu';c.s.update(.1);assert(c.joins[1]==lobby)
end)
test('duplicate callbacks and launch strings do not restart an in-flight join',function()
    local c=fixture();c.invite(lobby);c.launch('+connect_lobby '..lobby);c.s.update(.1)
    -- Freeze transport polling; only exercise the invite path on the second update.
    c.s.failed=true;c.invite(lobby);c.s.update(.1);assert(#c.joins==1)
end)
test('a different invite asks before replacing an existing party',function()
    local c=fixture();c.e.BT.state={phase='lobby'};c.invite(lobby);c.s.update(.1)
    assert(#c.joins==0 and c.s.invited==lobby and c.e.BT.ui.screen=='steam_invite')
end)
test('a solo run is protected even without Together state',function()
    local c=fixture();c.e.G.STAGE='run';c.invite('+connect_lobby '..lobby);c.s.update(.1)
    assert(#c.joins==0 and c.e.BT.ui.screen=='steam_invite')
end)
test('late URL launch events join after startup argument scanning completed',function()
    local c=fixture();c.s.update(.1);assert(#c.joins==0)
    c.invite('+connect_lobby '..lobby);c.s.update(.1);assert(c.joins[1]==lobby)
end)
test('invalid Steam payloads cannot call the join transport',function()
    local c=fixture();c.invite('+connect_lobby 1234');c.launch('+connect_lobby '..lobby..'bad');c.s.update(.1);assert(#c.joins==0 and not c.s.invited)
end)
test('fresh invite wins over an old startup lobby',function()
    local c=fixture{args={'+connect_lobby',lobby}};c.invite('109775240123456799');c.s.update(.1)
    assert(c.joins[1]=='109775240123456799')
end)
-- Real FFI conversions and callbacks, with only Steam's C service replaced.
local ffi=require('ffi');local now,online,attempts=0,false,0
local game_calls,lobby_calls=0,0;local refuse=false;local command=''
local api=setmetatable({},{__index=function() return function() return ffi.cast('void *',1) end end})
api.SteamAPI_ISteamUtils_GetAppID=function() attempts=attempts+1;return 2379780 end
api.SteamAPI_ISteamUser_BLoggedOn=function() return online end
api.SteamAPI_ISteamUser_GetSteamID=function() return ffi.new('uint64_t',76561198)*1000000000+123456789 end
api.SteamAPI_ISteamFriends_GetFriendRelationship=function() return 3 end
api.SteamAPI_ISteamFriends_InviteUserToGame=function(_,_,connect) game_calls=game_calls+1;assert(connect=='+connect_lobby '..lobby);return not refuse end
api.SteamAPI_ISteamMatchmaking_InviteUserToLobby=function() lobby_calls=lobby_calls+1;return true end
api.SteamAPI_ISteamApps_GetLaunchCommandLine=function(_,buf,size) assert(#command<size);ffi.copy(buf,command);return #command end
local fakeffi=setmetatable({load=function() return api end},{__index=ffi})
local e=setmetatable({G={STEAM={}},love={timer={getTime=function() return now end}},require=function(name) if name=='ffi' then return fakeffi end;return require(name) end},{__index=_G})
local f=assert(loadfile(ROOT..'/net/steam_native.lua'));setfenv(f,e);local native=f()
test('temporary Steam-offline failure retries at a bounded interval',function()
    assert(not native.init() and attempts==1);online=true;now=1;assert(not native.init() and attempts==1)
    now=2;assert(native.init() and attempts==2 and not native.failure)
end)
test('explicit game invite carries lobby address and fallback sends only one invite',function()
    assert(native.invite_friend(lobby,'76561198000000002'));assert(game_calls==1 and lobby_calls==0)
    refuse=true;assert(native.invite_friend(lobby,'76561198000000002'));assert(game_calls==2 and lobby_calls==1)
end)
test('Steam launch API detects later parameters without repeatedly replaying old ones',function()
    native.checked_os=true;command='+connect_lobby '..lobby
    assert(native.launch_args()[1]==command);assert(#native.launch_args()==0)
    command='+connect_lobby 109775240123456799';assert(native.launch_args()[1]==command)
    native.shutdown()
end)
print('TOTAL '..count..' STEAM INVITE TESTS PASSED')
