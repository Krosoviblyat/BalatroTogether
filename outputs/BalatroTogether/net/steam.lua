local S={clock=0,peers={},pending_leaves={},sent_invites={},friend_list={}}
local native=assert(SMODS.load_file('net/steam_native.lua',BT.id))()
local invites=assert(SMODS.load_file('net/steam_invites.lua',BT.id))()
local function queue()
    return {items={},push=function(self,v) if #self.items<256 then self.items[#self.items+1]=v end end,
        pop=function(self) return table.remove(self.items,1) end}
end
local function emit(event) if S.output then S.output:push(event) end end
local function key(remote) return S.hosting and ('steam:'..remote) or 1 end
function S.available() return native.init and native.init() end
function S.capabilities()
    local s=G and G.STEAM; local v=S.available()
    return {persona=s and s.user and s.user.getSteamID and s.friends and s.friends.getFriendPersonaName~=nil,
        overlay=s and s.friends and type(s.friends.activateGameOverlay)=='function',
        invites=v~=nil,matchmaking=v~=nil,avatars=false}
end
function S.name()
    local s=G and G.STEAM
    if not (s and s.user and s.user.getSteamID and s.friends and s.friends.getFriendPersonaName) then return end
    local ok,name=pcall(function() return s.friends.getFriendPersonaName(s.user.getSteamID()) end)
    if ok and type(name)=='string' and name~='' and name~='[unknown]' then return name:sub(1,40) end
end
function S.friends()
    if not (S.lobby and S.hosting and BT.client and BT.client.model and (BT.client.model.phase=='lobby' or BT.client.model.phase=='resuming')) then BT.notice('Open a Steam table before inviting friends.'); return end
    S.refresh_friends(); BT.ui.screen='steam_friends'; BT.ui.focus=nil; return true
end
function S.refresh_friends()
    local list=native.friend_list(); S.friend_list={}
    for _,friend in ipairs(list) do
        if native.valid_id(friend.id) and friend.id~=S.local_id then
            friend.name=BT.Session.player_name(friend.name or 'Steam friend',80)
            S.friend_list[#S.friend_list+1]=friend
        end
    end
    table.sort(S.friend_list,function(a,b)
        local ao,bo=a.state~=0,b.state~=0
        if ao~=bo then return ao end; return a.name:lower()<b.name:lower()
    end)
end
function S.invite_friend(friend)
    if not (S.active and S.hosting and S.lobby and BT.client and BT.client.model and (BT.client.model.phase=='lobby' or BT.client.model.phase=='resuming')) then BT.notice('Invites are available before the run or while restoring your party.'); return end
    local found=false; for _,entry in ipairs(S.friend_list or {}) do if entry.id==friend then found=true; break end end
    if not found or S.peers[friend] then BT.notice('Choose a friend who has not joined this table.'); return end
    if BT.client.model.phase=='lobby' and BT.client.model:count()>=BT.client.model.intended then BT.notice('Every intended seat is filled. Remove a bot or open a larger table first.'); return end
    if BT.client.model.phase=='resuming' then
        local reserved=false;for _,p in pairs(BT.client.model.players) do if p.steam_id==friend and not p.withdrawn and not p.connected then reserved=true end end
        if not reserved then BT.notice('This saved party reserves its original players\' seats.');return end
    end
    if S.sent_invites[friend] and S.clock-S.sent_invites[friend]<10 then BT.notice('Invite already sent. Give your friend a moment to accept it.'); return end
    local ok,err=native.invite_friend(S.lobby,friend)
    if not ok then BT.notice(err or 'Steam could not send the lobby invite.'); return end
    S.sent_invites[friend]=S.clock; BT.notice('Steam accepted the lobby invite. Your friend can accept it in Steam.'); return true
end
function S.valid_lobby(value)
    local lobby=invites.lobby(value)
    if lobby and native.valid_id and native.valid_id(lobby) then return lobby end
end
local function receive_invite(value)
    local lobby=S.valid_lobby(value) or S.valid_lobby(invites.command(value))
    if not lobby or lobby==S.lobby or (S.call and lobby==S.requested) or lobby==S.invited then return end
    S.invited=lobby; S.pending_invite=true
end
local function deliver_invite()
    if not S.pending_invite then return end
    local client=BT.client
    if not (client and BT.ui) then return end
    local in_run=G and G.STAGES and G.STAGE==G.STAGES.RUN
    local occupied=S.active or BT.state~=nil or client.connecting or client.connected or client.model~=nil or in_run
    -- During boot wait for the menu. Never replace a party or solo run silently.
    if not occupied and G and G.STAGES and G.STAGE~=G.STAGES.MAIN_MENU then return end
    S.pending_invite=nil; BT.ui.focus=nil; BT.ui.closing=false
    if occupied then BT.ui.screen='steam_invite' else client.join_steam(S.invited) end
end
local function begin(hosting,lobby)
    S.hosting=hosting; S.output=queue(); S.peers={}; S.blocked={}; S.lobby=nil; S.owner=nil; S.failed=false; S.friend_list={}; S.sent_invites={}
    S.active=true; S.started=S.clock; S.last_members=-1
    S.code=nil; S.code_ready=nil; S.code_call=nil; S.lookup_call=nil; S.lookup_code=nil; S.code_tries=0;S.joinable_state=nil
    S.call=hosting and native.create() or (lobby and native.join(lobby)); S.requested=lobby
    S.input={push=function(_,cmd)
        if cmd.type=='send' then S.send(cmd.id,cmd.line)
        elseif cmd.type=='close' then S.close(cmd.id)
        elseif cmd.type=='stop' then S.stop() end
    end}
    return S.input,S.output
end
function S.host() return begin(true) end
function S.join(lobby) return begin(false,lobby) end
function S.valid_code(value) return type(value)=='string' and value:match('^%d%d%d%d%d%d$') and value or nil end
function S.join_code(code)
    assert(S.valid_code(code),'Use a six-digit table code.')
    local input,output=begin(false);S.lookup_code=code;S.lookup_call=native.search(code)
    return input,output
end
function S.stop()
    if S.lobby then native.presence(nil); native.leave(S.lobby) end
    if S.call then S.pending_leaves[#S.pending_leaves+1]={call=S.call,hosting=S.hosting} end
    for remote in pairs(S.peers) do native.close(remote) end
    S.active=false; S.call=nil; S.lobby=nil; S.owner=nil; S.peers={}; S.output=nil; S.input=nil
    S.code=nil; S.code_ready=nil; S.code_call=nil; S.lookup_call=nil; S.lookup_code=nil
    S.invited=nil; S.pending_invite=nil
end
function S.is_peer(peer) return type(peer)=='string' and peer:match('^steam:%d+$')~=nil and S.peers[peer:sub(7)]~=nil end
function S.send(peer,line)
    if not S.active or not S.lobby or type(line)~='string' or #line>65536 then return end
    local recipients={}
    if peer==0 then for remote in pairs(S.peers) do recipients[#recipients+1]=remote end
    elseif S.hosting and S.is_peer(peer) then recipients[1]=peer:sub(7)
    elseif not S.hosting and peer==1 and S.owner then recipients[1]=S.owner end
    for _,remote in ipairs(recipients) do
        local result=native.send(remote,'BT1:'..S.lobby..':'..line)
        if result~=1 then emit{type='closed',id=key(remote),error='Steam connection interrupted (code '..result..').'}; S.peers[remote]=nil end
    end
end
function S.close(peer)
    local remote
    if S.hosting then remote=type(peer)=='string' and peer:match('^steam:(%d+)$') or nil else remote=S.owner end
    if remote then native.close(remote); S.peers[remote]=nil; S.blocked[remote]=true; emit{type='closed',id=key(remote),error='Closed by host.'} end
end
function S.reconnect()
    if S.owner then native.close(S.owner); S.peers[S.owner]=nil end
    S.last_members=-1; S.started=S.clock
end
local function fail(message) emit{type='error',error=message}; S.failed=true end
local function choose_code()
    S.code_tries=S.code_tries+1;S.code=string.format('%06d',love.math.random(100000,999999))
    if native.search then S.code_call=native.search(S.code) else S.code_ready=true end
end
local function metadata()
    if S.hosting then
        if not native.set(S.lobby,'bt_mod','BalatroTogether') or not native.set(S.lobby,'bt_version',BT.version) or not native.set(S.lobby,'bt_host',S.local_id) then fail('Steam could not publish this table. Try hosting again.'); return end
        S.owner=S.local_id; native.presence(S.lobby)
        if native.joinable then native.joinable(S.lobby,false) end
        choose_code();BT.notice('Opening a fresh six-digit table code...')
    else
        if native.get(S.lobby,'bt_mod')~='BalatroTogether' or native.get(S.lobby,'bt_version')~=BT.version then fail('All players need Balatro Together '..BT.version..'.'); return end
        S.owner=native.get(S.lobby,'bt_host')
        if not S.owner or S.owner==S.local_id or S.owner~=native.owner(S.lobby) then fail('That Steam table is no longer hosted. Ask for a fresh invite.'); return end
    end
end
local function refresh()
    if native.owner(S.lobby)~=S.owner then fail('The Steam host left the table. Ask them to host again.'); return end
    local present={}
    for _,remote in ipairs(native.members(S.lobby)) do
        if remote~=S.local_id and (S.hosting or remote==S.owner) then
            present[remote]=true
            if not S.peers[remote] and not S.blocked[remote] then
                native.accept(remote); native.send(remote,'BT1:'..S.lobby..':BTSTEAM1')
                S.peers[remote]={last=S.clock,window=S.clock,count=0}; emit{type='connected',id=key(remote)}
            end
        end
    end
    for remote in pairs(S.peers) do if not present[remote] then native.close(remote); S.peers[remote]=nil; emit{type='closed',id=key(remote),error='Player left the Steam table.'} end end
end
function S.update(dt)
    S.clock=S.clock+dt
    if BT.bots and BT.bots.config then return end
    local v=S.available(); if not v then return end; S.local_id=v.id
    native.pump()
    for i=#S.pending_leaves,1,-1 do
        local p=S.pending_leaves[i]; local lobby=native.poll(p.call,p.hosting)
        if lobby~=nil then if lobby then native.leave(lobby) end; table.remove(S.pending_leaves,i) end
    end
    if not S.checked_args then
        S.checked_args=true
        receive_invite(invites.command(arg or {}))
    end
    if native.launch_args and (not S.next_launch_check or S.clock>=S.next_launch_check) then
        S.next_launch_check=S.clock+1
        for _,value in ipairs(native.launch_args()) do receive_invite(value) end
    end
    -- A fresh accepted invite wins over an older cold-launch argument.
    for _,lobby in ipairs(native.invites()) do receive_invite(lobby) end
    deliver_invite()
    if not S.active or S.failed then return end
    if S.lookup_call then
        local matches,err=native.poll_search(S.lookup_call)
        if matches==nil then if S.clock-S.started>22 then fail('Code lookup timed out. Check Steam and try again.') end;return end
        S.lookup_call=nil
        if not matches then fail(err);return end
        local valid={}
        for _,lobby in ipairs(matches) do if S.valid_lobby(lobby) and native.get(lobby,'bt_mod')=='BalatroTogether' and native.get(lobby,'bt_code')==S.lookup_code then valid[#valid+1]=lobby end end
        if #valid==0 then fail('No open table has that code. Ask the host for their current six digits.');return end
        if #valid~=1 then fail('That code matched more than one table. Ask your host to make a fresh code.');return end
        if native.get(valid[1],'bt_version')~=BT.version then fail('That table uses another build. Everyone must update to '..BT.version..'.');return end
        S.requested=valid[1];S.call=native.join(valid[1]);S.started=S.clock
    end
    if S.call then
        local lobby,err=native.poll(S.call,S.hosting)
        if lobby==nil then if S.clock-S.started>20 then fail('Steam lobby request timed out. Check that Steam is online.') end; return end
        S.call=nil
        if not lobby then fail(err); return end
        S.lobby=lobby; metadata(); if S.failed then return end
    end
    if not S.lobby then return end
    if S.hosting and S.code_call then
        local matches,err=native.poll_search(S.code_call)
        if matches==nil then if S.clock-S.started>22 then fail('Steam could not register a table code. Try hosting again.') end;return end
        S.code_call=nil
        if not matches then fail(err);return end
        local collision=false;for _,lobby in ipairs(matches) do if lobby~=S.lobby then collision=true end end
        if collision then
            if S.code_tries>=8 then fail('Steam codes are busy. Try hosting again.');return end
            choose_code();return
        end
        if not native.set(S.lobby,'bt_code',S.code) then fail('Steam could not publish the table code.');return end
        S.code_ready=true
        if BT.client and BT.client.model then BT.client.model.room_code=S.code;BT.client.model:changed() end
        BT.notice('Your Steam table is open. Share code '..S.code..'.')
    end
    if S.hosting and S.code_ready and native.joinable then
        local phase=BT.client and BT.client.model and BT.client.model.phase
        local joinable=phase=='lobby' or phase=='resuming'
        if joinable~=S.joinable_state then native.joinable(S.lobby,joinable);S.joinable_state=joinable end
    end
    if S.clock-S.last_members>0.25 then S.last_members=S.clock; refresh(); if S.failed then return end end
    for _=1,4 do
        local packets=native.receive(); if #packets==0 then break end
        for _,packet in ipairs(packets) do
            local peer=S.peers[packet.remote]
            if not peer then refresh(); peer=S.peers[packet.remote] end
            local lobby,line=packet.line:match('^BT1:(%d+):(.*)$')
            if peer and lobby==S.lobby and #line<=65536 then
                peer.last=S.clock
                if S.clock-peer.window>=1 then peer.window=S.clock; peer.count=0 end
                peer.count=peer.count+1
                if peer.count>100 then S.close(key(packet.remote))
                elseif line~='BTSTEAM1' then emit{type='line',id=key(packet.remote),line=line} end
            end
        end
    end
    for remote,peer in pairs(S.peers) do
        if S.clock-peer.last>20 then native.close(remote); S.peers[remote]=nil; emit{type='closed',id=key(remote),error='Steam connection timed out.'} end
    end
    if not S.hosting and S.clock-S.started>25 and not (BT.client and BT.client.connected) then fail('Steam connection timed out. Ask the host to reopen the table and invite again.') end
end
function S.rotate_code()
    if not (S.hosting and S.lobby and S.code_ready and BT.client.model and (BT.client.model.phase=='lobby' or BT.client.model.phase=='resuming')) then return end
    S.code_ready=nil;S.started=S.clock;S.code_tries=0;S.joinable_state=nil
    if native.joinable then native.joinable(S.lobby,false) end
    BT.client.model.room_code=nil;BT.client.model:changed()
    choose_code()
end
function S.shutdown() S.stop(); if native.shutdown then native.shutdown() end end
return S
