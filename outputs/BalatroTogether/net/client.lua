local C={pending={},callbacks={},sequence=0,clock=0,last_ping=0,last_snapshot=-1,peers={},hellos={}}
local function token()
    local bytes={}; for i=1,32 do bytes[i]=string.char(love.math.random(0,255)) end
    return love.data.encode('string','hex',love.data.hash('sha256',table.concat(bytes)))
end
local function raw(id,t)
    if not C.input then return end
    local ok,line=pcall(BT.json.encode,t)
    if ok and #line<=65536 then
        if C.transport=='steam' and (not C.model or id==0 or (BT.steam.is_peer and BT.steam.is_peer(id))) then BT.steam.send(id,line) end
        if C.transport~='steam' or (C.model and type(id)=='number') then C.input:push{type='send',id=id,line=line} end
    end
end
function C.close_peer(id)
    if type(id)=='string' and BT.steam.close then BT.steam.close(id)
    elseif C.input then C.input:push{type='close',id=id} end
end
local function model_state(seat)
    local state=C.model:snapshot(seat); state.room_pin=C.pin; return state
end
local function snapshot()
    if C.model then BT.state=model_state(1); C.last_snapshot=C.model.revision end
end
function C.resync()
    if C.model then snapshot() else raw(1,{type='resync'}) end
end
local ack
local function receive_state(state)
    if type(state)~='table' or state.protocol~=1 or type(state.revision)~='number' then return end
    if BT.state and state.revision<BT.state.revision then return end
    BT.state=state; C.connected=true; C.last_received=C.clock
    if type(state.room_pin)=='string' and state.room_pin:match('^%d%d%d%d%d%d$') then C.pin=state.room_pin; BT.config.pin=C.pin end
    local p=state.players[tostring(C.id)]
    if p then
        local confirmed={}; for seq in pairs(C.pending) do if seq<=p.ack then confirmed[#confirmed+1]=seq end end
        table.sort(confirmed)
        for _,seq in ipairs(confirmed) do
            local action=C.pending[seq]
            local ok=action.kind~='busy' or (p.busy and state.round==action.data.round)
            if action.run~=state.run_id then C.pending[seq]=nil; C.callbacks[seq]=nil
            else ack(seq,ok,ok and nil or 'The blind closed before this action was accepted.') end
        end
    end
end
ack=function(seq,ok,err)
    C.pending[seq]=nil
    local f=C.callbacks[seq]; C.callbacks[seq]=nil
    if not ok then BT.notice(err or 'Action rejected by host') end
    if f then f(ok,err) end
end
function C.action(kind,data,callback)
    if not C.connected then BT.notice('Connection interrupted — waiting to reconnect.'); return end
    local n=0; for _ in pairs(C.pending) do n=n+1 end
    if n>=128 then BT.notice('Network queue is full; waiting for the host.'); return end
    C.sequence=C.sequence+1
    local action={seq=C.sequence,run=BT.state and BT.state.run_id or 0,kind=kind,data=data or {}}
    if C.model then
        local ok,err=C.model:apply(1,action); snapshot()
        if callback then callback(ok,err) end
        if not ok then BT.notice(err) end
    else
        C.pending[action.seq]=action; C.callbacks[action.seq]=callback
        raw(1,{type='action',action=action})
    end
    return action.seq
end
local function spawn(mode,address,port)
    C.generation=(C.generation or 0)+1
    C.channel='bt:'..tostring(love.timer.getTime())..':'..C.generation
    C.input=love.thread.getChannel(C.channel..':in'); C.output=love.thread.getChannel(C.channel..':out')
    local source=assert(NFS.read(BT.root..'net/thread.lua'))
    C.thread=love.thread.newThread(source)
    C.thread:start(BT.root,C.channel,mode,address,port)
end
function C.stop(keep)
    if C.input then C.input:push{type='stop'} end
    if BT.steam.stop and not keep then BT.steam.stop() end
    C.input=nil; C.output=nil; C.thread=nil; C.connected=false; C.reconnecting=false; C.connecting=false
    if not keep then
        if BT.save and BT.save.connection_reset then BT.save.connection_reset() end
        if BT.bots then BT.bots.stop_all() end
        C.model=nil; C.id=nil; C.pending={}; C.callbacks={}; C.sequence=0; C.peers={}; C.hellos={}
        BT.state=nil; BT.game.reset(); C.resume=nil; C.retry_at=nil; C.fatal=false
        C.sent_revision=nil; C.sent_at=nil
        C.transport=nil; C.bot_port=nil; C.last_hello=nil
    end
end
function C.resolve_pin(value)
    if value==nil or value=='' then return string.format('%06d',love.math.random(100000,999999)) end
    if type(value)~='string' or not value:match('^%d%d%d%d%d%d$') then return nil,'Choose exactly 6 digits for the room PIN, or leave it blank for random.' end
    return value
end
function C.set_pin(value)
    if not C.model then BT.notice('Only the host can change the room PIN.'); return nil end
    local pin,err=C.resolve_pin(value); if not pin then BT.notice(err); return nil end
    C.pin=pin; BT.config.pin=pin; BT.config.host_pin=value or ''; BT.persist()
    C.model:changed(); snapshot(); BT.notice('Room PIN updated. Share the new PIN with joining friends.'); return true
end
function C.host(transport)
    if BT.compat then BT.compat.register_decks() end
    transport=transport or BT.config.transport or 'tcp'
    if transport=='steam' then local available,err=BT.steam.available(); if not available then BT.notice(err or 'Steam networking is unavailable. Open Balatro through Steam.'); return end end
    local port=transport=='steam' and 0 or tonumber(BT.config.port)
    if transport~='steam' and (not port or port%1~=0 or port<1024 or port>65535) then BT.notice('Port must be 1024–65535.'); return end
    local pin,err=C.resolve_pin(transport=='steam' and '' or BT.config.host_pin); if not pin then BT.notice(err); return end
    local seed=tostring(BT.config.seed or ''):upper()
    if seed~='' and (not seed:match('^[A-Z0-9]+$') or #seed>8) then BT.notice('Seed must be 1-8 letters/digits, or blank for random.'); return end
    C.stop(); C.transport=transport; C.pin=pin; BT.config.pin=pin; BT.persist()
    C.compat=BT.compat and BT.compat.signature()
    C.resume=token(); C.id=1; C.sequence=0
    C.model=BT.Session.new{intended=BT.config.intended_players,scaling=BT.config.scaling,name=BT.config.username,token=C.resume,seed=seed,deck=BT.config.deck or 'b_red',party_id=token():sub(1,32),save_autos=BT.Session.Save~=nil}
    C.model.setup_choices=BT.compat and BT.compat.run_choices(C.model.deck)
    C.model.players[1].steam_name=BT.steam.name()
    local identity=BT.steam.available and BT.steam.available()
    if type(identity)=='table' then C.model.players[1].steam_id=identity.id end
    C.hosting=true; C.connected=true; C.last_snapshot=-1; snapshot()
    if transport=='steam' then BT.steam.host(); spawn('host','127.0.0.1',0)
    else C.bot_port=port; spawn('host','*',port) end
    BT.ui.screen='lobby'
    BT.notice(transport=='steam' and 'Opening your Steam table...' or ('Hosting TCP port '..port..'. Share your reachable IP and the room PIN.'))
end
function C.join()
    C.stop()
    local port=tonumber(BT.config.port)
    if not port or port%1~=0 or port<1024 or port>65535 or BT.config.address=='' then BT.notice('Enter a valid address and port.'); return end
    C.transport='tcp'; C.hosting=false; C.address=BT.config.address; C.port=port; C.pin=BT.config.pin
    if BT.save and BT.save.reconnect_token then C.resume=BT.save.reconnect_token(C.address,C.port) end
    C.connecting=true; C.retry_at=nil; C.retry_attempt=0
    spawn('join',C.address,C.port); BT.ui.screen='lobby'; BT.notice('Connecting…')
end
function C.join_steam(value)
    if BT.steam.valid_code and BT.steam.valid_code(value) then return C.join_code(value) end
    local lobby=BT.steam.valid_lobby(value)
    if not lobby then BT.notice('Paste a valid Steam table link or lobby ID.'); return end
    local available,err=BT.steam.available(); if not available then BT.notice(err or 'Open Balatro through Steam while signed in.'); return end
    C.stop(); C.transport='steam'; C.hosting=false; C.address=lobby; C.connecting=true; C.retry_at=nil; C.retry_attempt=0
    C.input,C.output=BT.steam.join(lobby); BT.ui.screen='lobby'; BT.steam.invited=nil; BT.notice('Joining your friend through Steam...')
end
function C.join_code(value)
    local code=BT.steam.valid_code(value)
    if not code then BT.notice('Enter the host\'s current six-digit table code.');return end
    local available,err=BT.steam.available();if not available then BT.notice(err or 'Open Steam while signed in.');return end
    C.stop();C.transport='steam';C.hosting=false;C.connecting=true;C.retry_attempt=0;C.retry_at=nil
    C.input,C.output=BT.steam.join_code(code);BT.config.room_code='';BT.config.steam_lobby=''
    BT.ui.screen='lobby';BT.ui.focus=nil;BT.notice('Finding table '..code..' through Steam...')
end
local function newseed()
    local alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; local seed=''
    for _=1,8 do local n=love.math.random(1,#alphabet); seed=seed..alphabet:sub(n,n) end
    return seed
end
function C.start()
    if not C.model then return end
    if C.transport=='steam' and not BT.steam.lobby then BT.notice('Wait for the Steam table to finish opening.'); return end
    local ok,err=C.model:start(newseed())
    if not ok then BT.notice(err) else snapshot(); BT.ui.screen=nil end
end
function C.restart()
    if not C.model then BT.notice('Only the host can restart the party run.'); return end
    if BT.pot and BT.pot.busy() then BT.notice('Finish the pot transfer first.'); return end
    if BT.dice and BT.dice.busy() then BT.notice('Finish your reward die first.'); return end
    if C.clock-(C.last_restart or -10)<2 then return end
    local ok,err=C.model:restart(newseed())
    if ok then C.last_restart=C.clock; snapshot(); BT.ui.screen=nil; BT.notice('Party restarted - '..BT.Session.deck_name(C.model.deck)..' / seed '..C.model.seed)
    else BT.notice(err) end
end
function C.ready()
    if BT.donation and BT.donation.busy() then BT.notice('Finish the donation transfer first.'); return end
    if BT.pot and BT.pot.busy() then BT.notice('Finish the pot transfer first.'); return end
    if BT.dice and BT.dice.busy() then BT.notice('Finish your reward die first.'); return end
    local p=BT.state and BT.state.players[tostring(C.id)]
    if p then
        local data=BT.state.phase=='prepare' and BT.game.position() or {}
        data.ready=not p.ready; C.action('ready',data)
    end
end
function C.rename(value)
    local name=BT.Session.player_name(value)
    if name=='' then BT.notice('Enter a display name.'); return end
    return C.action('rename',{name=name},function(ok)
        if ok then BT.config.username=name; BT.persist(); BT.ui.screen='lobby'; BT.ui.focus=nil; BT.notice('Display name updated.') end
    end)
end
function C.propose(data)
    if C.model then local ok,err=C.model:set_proposal(1,data); if ok then C.model:advance(); snapshot() else BT.notice(err) end end
end
function C.drop(id)
    if C.model then local ok,err=C.model:drop(id); snapshot(); if not ok then BT.notice(err) end end
end
local function reject(id,text)
    raw(id,{type='error',error=text,fatal=true})
    -- Let the queued rejection flush before closing the socket.
    C.hellos[id]={expires=C.clock+0.3,rejected=true}
end
local function host_line(id,msg)
    if msg.type=='hello' then
        if C.peers[id] then return end
        if msg.protocol~=1 or msg.version~=BT.version then reject(id,'All players need Balatro Together '..BT.version); return end
        if msg.compat~=C.compat then reject(id,'Mod pack or Cryptid rules differ. Use the same installer and Cryptid gameset/settings.'); return end
        local seat,err
        if C.model.phase=='resuming' and type(id)=='string' and BT.steam.is_peer(id) then
            for i,p in pairs(C.model.players) do if p.steam_id==id:sub(7) and not p.bot and not p.connected and not p.withdrawn then seat=C.model:reconnect(p.token);break end end
            if not seat then reject(id,'This saved party reserves seats for its original players.');return end
        elseif type(msg.resume)=='string' and #msg.resume==64 then
            for _,p in pairs(C.model.players) do
                if p.token==msg.resume and p.steam_id and (type(id)~='string' or id:sub(7)~=p.steam_id) then reject(id,'This seat belongs to another Steam player.'); return end
            end
            seat,err=C.model:reconnect(msg.resume)
            if not seat and C.transport=='steam' and C.model.phase=='lobby' and BT.steam.is_peer(id) then seat,err=C.model:join(msg.name,token(),msg.steam_name) end
            if not seat and C.transport~='steam' and C.model.phase=='lobby' and msg.pin==C.pin then seat,err=C.model:join(msg.name,token(),msg.steam_name) end
        else
            if not (C.transport=='steam' and BT.steam.is_peer(id)) and msg.pin~=C.pin then reject(id,'Incorrect room PIN.'); return end
            seat,err=C.model:join(msg.name,token(),msg.steam_name)
        end
        if not seat then reject(id,err); return end
        if type(id)=='string' then
            local remote=id:sub(7); local p=C.model.players[seat]
            if p.steam_id and p.steam_id~=remote then reject(id,'This seat belongs to another Steam player.'); return end
            p.steam_id=remote
        end
        C.peers[id]=seat; C.hellos[id]=nil
        raw(id,{type='welcome',id=seat,resume=C.model.players[seat].token,state=model_state(seat)})
        snapshot()
    elseif C.peers[id] then
        if BT.save and (msg.type=='checkpoint_chunk' or msg.type=='checkpoint_request' or msg.type=='checkpoint_failed') then
            BT.save.host_message(C.peers[id],id,msg)
        elseif msg.type=='action' then
            local ok,err=C.model:apply(C.peers[id],msg.action)
            raw(id,{type='ack',seq=type(msg.action)=='table' and msg.action.seq or 0,ok=ok==true,error=err})
        elseif msg.type=='ping' then raw(id,{type='pong'})
        elseif msg.type=='resync' then raw(id,{type='state',state=model_state(C.peers[id])}) end
    else reject(id,'Join the lobby before sending actions.') end
end
local function client_line(msg)
    if msg.type=='welcome' then
        C.id=msg.id; C.resume=msg.resume; C.connecting=false; C.retry_attempt=0; C.retry_at=nil
        receive_state(msg.state)
        local own=BT.state and BT.state.players[tostring(C.id)]
        if own then C.sequence=math.max(C.sequence,own.ack or 0) end
        if BT.save then BT.save.welcome() end
        local seqs={}; for seq in pairs(C.pending) do seqs[#seqs+1]=seq end; table.sort(seqs)
        for _,seq in ipairs(seqs) do raw(1,{type='action',action=C.pending[seq]}) end
        BT.notice('Connected to seat '..tostring(C.id))
    elseif msg.type=='state' then receive_state(msg.state)
    elseif msg.type=='checkpoint_chunk' and BT.save then BT.save.client_message(msg)
    elseif msg.type=='ack' then ack(msg.seq,msg.ok,msg.error)
    elseif msg.type=='error' then
        BT.notice(msg.error)
        if msg.fatal then C.retry_at=nil; C.resume=nil; C.connected=false; C.connecting=false; C.fatal=true; BT.ui.screen='join'; if C.transport=='steam' then BT.steam.stop() end end
    end
end
function C.update(dt)
    C.clock=C.clock+dt
    if C.model and BT.Session.Vote then BT.Session.Vote.tick(C.model,C.clock) end
    if C.model and C.model.dice and BT.Session.Dice.QTE then BT.Session.Dice.QTE.tick(C.model,C.clock) end
    if BT.steam.update then
        BT.steam.update(dt)
        if C.output and BT.steam.output and C.output~=BT.steam.output then
            for _=1,128 do local event=BT.steam.output:pop(); if not event then break end; C.output:push(event) end
        end
    end
    if C.output then
        local output=C.output
        for _=1,128 do
            if C.output~=output then break end
            local event=output:pop(); if not event then break end
            if event.type=='line' then
                -- Guard parser nesting to avoid a stack overflow on hostile input.
                local depth,quoted,escape=0,false,false
                for i=1,#event.line do
                    local c=event.line:sub(i,i)
                    if quoted then if escape then escape=false elseif c=='\\' then escape=true elseif c=='"' then quoted=false end
                    elseif c=='"' then quoted=true elseif c=='{' or c=='[' then depth=depth+1
                    elseif c=='}' or c==']' then depth=depth-1 end
                    if depth>24 then break end
                end
                local ok,msg=false,nil
                if depth<=24 then ok,msg=pcall(BT.json.decode,event.line) end
                if ok and type(msg)=='table' then
                    if C.model then host_line(event.id,msg) else client_line(msg) end
                else C.close_peer(event.id) end
            elseif event.type=='listening' then
                C.bot_port=event.port or C.bot_port
            elseif event.type=='connected' then
                if C.model then C.hellos[event.id]={expires=C.clock+8}
                else raw(1,{type='hello',protocol=1,version=BT.version,pin=C.pin,name=BT.config.username,steam_name=BT.steam.name(),resume=C.resume,compat=BT.compat and BT.compat.signature()}) end
            elseif event.type=='closed' then
                if C.model then
                    if C.peers[event.id] then C.model:disconnect(C.peers[event.id]); C.peers[event.id]=nil; snapshot() end
                    C.hellos[event.id]=nil
                elseif not C.fatal then
                    C.connected=false; C.connecting=false
                    if C.resume then C.retry_at=C.clock+2; BT.notice('Connection lost. Reconnecting; keep this game open.')
                    else BT.notice(event.error or 'Connection closed.') end
                end
            elseif event.type=='error' then
                BT.notice(event.error)
                if C.model then C.stop(); BT.ui.screen='host'
                else C.connected=false; C.connecting=false
                    if C.transport=='steam' then BT.steam.stop(); C.retry_at=nil; C.fatal=true; BT.ui.screen='join'
                    elseif C.resume and not C.fatal then C.retry_at=C.clock+math.min(15,2^(C.retry_attempt or 1))
                    else BT.ui.screen='join' end end
            end
        end
    end
    if C.thread then local err=C.thread:getError(); if err then BT.notice('Networking worker: '..err); C.stop() end end
    if C.model then
        for id,h in pairs(C.hellos) do if C.clock>h.expires and C.input then C.close_peer(id); C.hellos[id]=nil end end
        if C.model.revision~=C.last_snapshot then snapshot() end
        if C.clock-(C.sent_at or -1)>0.1 and C.sent_revision~=C.model.revision then
            for id,seat in pairs(C.peers) do raw(id,{type='state',state=model_state(seat)}) end
            C.sent_revision=C.model.revision; C.sent_at=C.clock
        end
    elseif C.retry_at and C.clock>=C.retry_at and not C.fatal then
        C.retry_attempt=(C.retry_attempt or 0)+1; C.retry_at=nil
        if C.transport=='steam' then BT.steam.reconnect()
        else C.stop(true); spawn('join',C.address,C.port) end
        C.connecting=true
    end
    if C.transport=='steam' and not C.model and C.connecting and BT.steam.owner and C.clock-(C.last_hello or -10)>2 then
        C.last_hello=C.clock; raw(1,{type='hello',protocol=1,version=BT.version,name=BT.config.username,steam_name=BT.steam.name(),resume=C.resume,compat=BT.compat and BT.compat.signature()})
    end
    if C.connected and C.clock-C.last_ping>3 then
        C.last_ping=C.clock
        if C.model then raw(0,{type='pong'}) else raw(1,{type='ping'}) end
    end
end
function C.message(id,message) raw(id,message) end
function C.restore_party(model)
    C.model=model;C.resume=model.players[1].token;C.sequence=model.players[1].ack or 0
    C.connected=true;C.id=1;C.hosting=true;C.sent_revision=nil;C.last_snapshot=-1;snapshot()
end
return C
