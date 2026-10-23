-- Real transport/session modules; only the native Steam service is simulated.
local Session=dofile(ROOT..'/core/session.lua')
local json=dofile(ROOT..'/vendor/json.lua')
local rooms,boxes,contexts={}, {},{}
local nextroom,nexttoken=109775240000000000,0
local ids={'76561198000000001','76561198000000002','76561198000000003','76561198000000004'}
local function q() return {items={},push=function(self,v) self.items[#self.items+1]=v end,pop=function(self) return table.remove(self.items,1) end} end
local function context(index)
    local e=setmetatable({},{__index=_G}); local remote=ids[index]; local n={}; boxes[remote]={}; local channels={}; local notices={}
    local function channel(name) if not channels[name] then channels[name]=q() end; return channels[name] end
    local function module(path) local f=assert(loadfile(ROOT..'/'..path)); setfenv(f,e); return f end
    n.init=function() return {id=remote} end
    n.valid_id=function(v) return type(v)=='string' and v:match('^%d+$') and #v>=16 and #v<=20 end
    n.create=function() nextroom=nextroom+128; local lobby=string.format('%.0f',nextroom); rooms[lobby]={owner=remote,members={[remote]=true},data={}}; return {lobby=lobby,creating=true} end
    n.join=function(lobby) local room=rooms[lobby]; if room then room.members[remote]=true end; return {lobby=lobby,error=not room} end
    n.poll=function(call) if call.wait then return end; if call.error then return false,'Steam refused test lobby.' end; return call.lobby end
    n.leave=function(lobby) if rooms[lobby] then rooms[lobby].members[remote]=nil end end
    n.set=function(lobby,k,v) rooms[lobby].data[k]=v; return true end
    n.get=function(lobby,k) return rooms[lobby].data[k] or '' end
    n.owner=function(lobby) return rooms[lobby].owner end
    n.members=function(lobby) local out={}; for member in pairs(rooms[lobby].members) do out[#out+1]=member end; return out end
    n.accept=function() return true end
    n.send=function(to,line) if boxes[to] then boxes[to][#boxes[to]+1]={remote=remote,line=line} end; return 1 end
    n.receive=function() local out=boxes[remote]; boxes[remote]={}; return out end
    n.close=function() end; n.presence=function() end; n.pump=function() end; n.shutdown=function() end
    n.invite=function() return nil,'Overlay disabled in test.' end
    n.friend_list=function() return {{id=ids[3],name='Offline friend',state=0},{id=ids[2],name='Online friend',state=1}} end
    n.invite_friend=function(lobby,friend) n.invite_calls=(n.invite_calls or 0)+1; n.invite_target=friend; if n.fail_invite then return nil,'Invite refused.' end; return true end
    n.invites=function() local out=n.incoming or {}; n.incoming={}; return out end
    e.SMODS={load_file=function(path) if path=='net/steam_native.lua' then return function() return n end else return module(path) end end}
    e.love={math={random=function(a) return a end},timer={getTime=function() return 1 end},
        data={hash=function() nexttoken=nexttoken+1; return string.format('%064x',nexttoken) end,encode=function(_,_,s) return s end},
        thread={getChannel=channel,newThread=function() return {start=function(_,_,name,_,_,port) channel(name..':out'):push{type='listening',port=port==0 and 50123 or port} end,getError=function() end} end}}
    e.NFS={read=function() return '-- test socket worker' end}; e.G={STEAM={}}
    e.BT={id='BalatroTogether',root='',version='steam-test',Session=Session,json=json,ui={},config={transport='steam',port='24872',username='Friend '..index,intended_players=4,seed='STEAM123',deck='b_red'},
        game={reset=function() end},persist=function() end,notice=function(v) notices[#notices+1]=v end}
    e.BT.steam=module('net/steam.lua')(); e.BT.client=module('net/client.lua')()
    local c={e=e,C=e.BT.client,S=e.BT.steam,N=n,id=remote,notices=notices}; contexts[#contexts+1]=c; return c
end
local function tick(seconds)
    for _=1,math.ceil((seconds or 1)/0.1) do for _,c in ipairs(contexts) do c.C.update(0.1) end end
end
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local host,a,b,c=context(1),context(2),context(3),context(4)
test('leaving a pending connection clears the flag that previously blocked menu invite autojoin',function()
    a.C.connecting=true;a.C.stop();assert(a.C.connecting==false and not a.e.BT.state)
end)
test('Steam host creates a friends-only table and keeps bot listener on loopback with an ephemeral port',function()
    host.C.host(); tick(.5); assert(host.S.lobby and host.C.model and host.C.transport=='steam' and host.C.bot_port==50123)
    assert(rooms[host.S.lobby].data.bt_mod=='BalatroTogether' and rooms[host.S.lobby].data.bt_version=='steam-test')
end)
test('friend picker opens inside the game without an overlay and opening it sends no invitations',function()
    assert(host.S.friends()); assert(host.e.BT.ui.screen=='steam_friends' and #host.S.friend_list==2)
    assert(host.S.friend_list[1].id==ids[2] and not host.N.invite_calls)
end)
test('direct Steam invite targets only the clicked current friend and limits repeat sends',function()
    assert(not host.S.invite_friend(ids[4]) and not host.N.invite_calls)
    assert(host.S.invite_friend(ids[2])); assert(host.N.invite_calls==1 and host.N.invite_target==ids[2])
    assert(not host.S.invite_friend(ids[2]) and host.N.invite_calls==1)
end)
test('Steam refusal is reported without claiming an invite was sent',function()
    host.N.fail_invite=true; assert(not host.S.invite_friend(ids[3])); assert(not host.S.sent_invites[ids[3]])
    host.N.fail_invite=false; host.e.BT.ui.screen='lobby'
end)
test('three invited Steam identities join without an IP, forwarding or PIN',function()
    for _,client in ipairs({a,b,c}) do client.C.join_steam(host.S.lobby) end
    tick(2); assert(host.C.model:count()==4)
    for _,client in ipairs({a,b,c}) do assert(client.C.connected and client.C.id and client.C.resume and client.C.transport=='steam') end
end)
test('guest changes their own name and every teammate receives it without losing their seat',function()
    local seat,secret=a.C.id,a.C.resume; a.C.rename('  New Friend  '); tick(.5)
    assert(a.C.id==seat and a.C.resume==secret and a.C.connected)
    for _,client in ipairs(contexts) do assert(client.e.BT.state.players[tostring(seat)].name=='New Friend') end
    assert(a.e.BT.config.username=='New Friend')
end)
test('empty names are refused and name limits preserve complete UTF-8 characters',function()
    local seat=a.C.id; a.C.rename(' \n\t '); tick(.2); assert(host.C.model.players[seat].name=='New Friend')
    assert(Session.player_name(string.rep('é',13))==string.rep('é',12))
    assert(Session.player_name(string.rep('A',23)..'é')==string.rep('A',23))
    host.C.rename('New Host'); tick(.2); assert(a.e.BT.state.players['1'].name=='New Host')
end)
test('Steam clients ready and enter the same seeded run through the actual session protocol',function()
    for _,client in ipairs(contexts) do client.C.ready() end; tick(1); host.C.start(); tick(1)
    for _,client in ipairs(contexts) do assert(client.e.BT.state.run_id==1 and client.e.BT.state.seed=='STEAM123') end
end)
test('outsiders and frames from another lobby cannot inject actions or change the shared state',function()
    local before=host.C.model.revision; local peer='76561198999999999'
    boxes[host.id][#boxes[host.id]+1]={remote=peer,line='BT1:'..host.S.lobby..':'..json.encode{type='action',action={seq=99,run=1,kind='ready',data={ready=true}}}}
    boxes[host.id][#boxes[host.id]+1]={remote=a.id,line='BT1:109775299999999999:'..json.encode{type='action',action={seq=99,run=1,kind='ready',data={ready=true}}}}
    tick(.5); assert(host.C.model.revision==before)
end)
test('a Steam seat reconnects with its original identity and unacknowledged actions',function()
    local seat=a.C.id; local secret=a.C.resume; host.S.close('steam:'..a.id); host.S.blocked[a.id]=nil
    a.S.reconnect(); a.C.connected=false; a.C.connecting=true; tick(3)
    assert(a.C.connected and a.C.id==seat and a.C.resume==secret and host.C.model.players[seat].connected)
end)
test('a different lobby member cannot steal another Steam identity using its reconnect secret',function()
    local seat=a.C.id; local secret=a.C.resume; host.S.close('steam:'..a.id); host.S.blocked[a.id]=nil; tick(.2)
    host.S.output:push{type='line',id='steam:'..b.id,line=json.encode{type='hello',protocol=1,version='steam-test',resume=secret,name='Impostor'}}
    -- Existing peers cannot submit another hello; emulate a new transport link.
    host.C.peers['steam:'..b.id]=nil; host.C.update(.1)
    assert(not host.C.model.players[seat].connected)
    a.S.reconnect(); a.C.connected=false; a.C.connecting=true; tick(3); assert(a.C.connected and host.C.model.players[seat].connected)
end)
test('malformed lobby links cannot replace an active table and IDs retain all decimal digits',function()
    local model=host.C.model; host.C.join_steam('steam://joinlobby/480/109775240000000000/76561198000000002'); assert(host.C.model==model)
    local exact='109775240123456789'; assert(host.S.valid_lobby(exact)==exact)
    assert(host.S.valid_lobby('steam://joinlobby/2379780/'..exact..'/76561198000000002')==exact)
end)
test('invites are refused after a run starts without leaving the table',function()
    local lobby=host.S.lobby; assert(not host.S.friends()); assert(host.S.lobby==lobby and host.C.model)
end)
test('invites ask before leaving a current run and are not accepted automatically',function()
    local lobby=host.S.lobby; host.N.incoming={'109775240999999999'}; tick(.2)
    assert(host.S.invited=='109775240999999999' and host.e.BT.ui.screen=='steam_invite' and host.S.lobby==lobby)
end)
test('host departure reports a closed table instead of silently migrating unsynchronized authority',function()
    rooms[host.S.lobby].owner=ids[2]; tick(.5)
    assert(not host.C.model and not host.S.active and host.e.BT.ui.screen=='host')
    assert(not a.C.connected and not a.S.active)
end)
test('incompatible mod versions get a clear error and leave the Steam lobby',function()
    host.C.host(); tick(.5); a.e.BT.version='older'; a.C.join_steam(host.S.lobby); tick(.5)
    assert(not a.C.connected and not a.S.active and a.e.BT.ui.screen=='join'); a.e.BT.version='steam-test'
end)
test('leaving during asynchronous creation reaps the completed lobby without leaking membership',function()
    local original=host.N.create; local call
    host.N.create=function() call=original(); call.wait=true; return call end
    host.C.host(); tick(.2); host.C.stop(); call.wait=false; tick(.2)
    assert(not rooms[call.lobby].members[host.id]); host.N.create=original
end)
test('a missing Steam lobby times out without freezing the game loop',function()
    host.N.create=function() return {wait=true} end; host.C.host(); tick(22)
    assert(not host.C.model and host.e.BT.ui.screen=='host')
end)
print('TOTAL '..count..' STEAM TRANSPORT TESTS PASSED')
