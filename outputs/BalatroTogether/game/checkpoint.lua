local S={clock=0,outgoing={},buffers={},directory='together/party-saves'}
local Codec=assert(SMODS.load_file('core/save_codec.lua',BT.id))()
local json=assert(SMODS.load_file('core/save_json.lua',BT.id))()
local ledger=BT.Session.Save
local function hash(data) return love.data.encode('string','hex',love.data.hash('sha256',data)) end
local function stamp() return BT.compat and BT.compat.signature(true) or '' end
local function encode(data,limit) return Codec.encode(data,json,BT.numbers,limit) end
local function decode(data,limit) return Codec.decode(data,json,BT.numbers,limit) end
local function me() return BT.state and BT.state.players[tostring(BT.client.id)] end
local function fail(reason)
    reason=tostring(reason):sub(1,150)
    if BT.client.model then ledger.cancel(BT.client.model,reason);BT.client.resync()
    else BT.client.message(1,{type='checkpoint_failed',id=BT.state and BT.state.checkpoint and BT.state.checkpoint.id,error=reason}) end
    BT.notice('Party save failed: '..reason..'. Previous checkpoints are safe.')
end
local function send(peer,purpose,id,data)
    S.outgoing[peer]={peer=peer,purpose=purpose,id=id,data=data,hash=hash(data),total=math.max(1,math.ceil(#data/Codec.CHUNK)),index=1,next_at=0}
end
local function validated_native(data)
    local packet=decode(data);local n=packet.native
    assert(type(packet)=='table' and packet.schema==1 and type(n)=='table' and type(n.GAME)=='table' and type(n.cardAreas)=='table'
        and type(n.BLIND)=='table' and type(n.BACK)=='table' and type(n.VERSION)=='string' and type(n.STATE)=='number','Incomplete native run')
    assert(n.STATE==G.STATES.BLIND_SELECT and n.VERSION==G.VERSION,'This checkpoint needs the same Balatro version and blind selection')
    -- Native culling replaces live Back objects with a marker string. A deck
    -- preview is menu-only; retaining that truthy marker makes SMODS sprite
    -- loading prefer it over the actual Back reconstructed from n.BACK.
    n.GAME.viewed_back=nil
    return packet
end
local function restore_cursor(packet)
    local s=BT.state;local p=me();local b=BT.game
    b.started=true;b.run_id=s.run_id;b.round=s.round;b.finished=s.round;b.started_round=s.round;b.hand=0;b.reported=0;b.lastchips=G.GAME.chips or 0
    b.skip_applied=s.skip_counter;b.skip_sent_at=-10
    BT.pot.run=s.run_id;BT.pot.counter=p.pot_tx or 0;BT.pot.applied=p.pot_credit or 0
    BT.dice.run=s.run_id;BT.dice.counter=p.dice_tx or 0;BT.dice.applied=p.dice_credit or 0;BT.dice.silent_applied=p.dice_silent_credit or 0
    BT.dice.effect_applied=#(p.dice_effects or {})
    BT.donation.counter=packet.donation_counter or 0;BT.donation.received=packet.donation_received or {}
end
function S.refresh()
    local fs=love.filesystem;S.summary=nil;S.saved_file=nil
    if not fs or not fs.getDirectoryItems then return end
    local candidates={}
    for _,name in ipairs(fs.getDirectoryItems(S.directory) or {}) do if name:match('^%d+%-[0-9a-f%-]+%.btparty$') then candidates[#candidates+1]=name end end
    table.sort(candidates,function(a,b) return a>b end)
    for _,name in ipairs(candidates) do
        local path=S.directory..'/'..name;local info=fs.getInfo(path)
        if info and info.size<=22000000 then
            local data=fs.read(path);local digest,body
            if type(data)=='string' then digest,body=data:match('^BTPARTY1\n([0-9a-f]+)\n(.*)$') end
            if digest and #digest==64 and hash(body)==digest then
                local ok,value=pcall(decode,body,22000000)
                if ok and type(value)=='table' and value.schema==1 and value.model and value.builds and value.at then
                    S.summary={ante=value.model.ante,index=value.model.blind_index,players=value.model.intended,deck=value.model.deck,at=value.at,version=value.version,compatible=value.compat==stamp()}
                    S.saved_file=path;return
                end
            end
        end
    end
end
local function read_archive()
    assert(S.saved_file,'No saved party yet')
    local text=assert(love.filesystem.read(S.saved_file));local digest,body=text:match('^BTPARTY1\n([0-9a-f]+)\n(.*)$')
    assert(digest and hash(body)==digest,'Party save checksum failed')
    local archive=decode(body,22000000);assert(archive.schema==1 and archive.compat==stamp(),'Use the same Cryptid pack and gameplay settings as this save')
    return archive
end
local function write_archive(archive)
    -- Immutable generations: interrupted writes never replace the prior save.
    local fs=love.filesystem;assert(fs.createDirectory(S.directory),'Cannot create party save folder')
    local body=encode(archive,22000000);local bytes='BTPARTY1\n'..hash(body)..'\n'..body
    local name=string.format('%010d',archive.at)..'-'..archive.model.checkpoint.id..'.btparty'
    local path=S.directory..'/'..name;assert(not fs.getInfo(path),'Checkpoint already exists')
    assert(fs.write(path..'.part',bytes),'Cannot write party checkpoint')
    local folder=fs.getSaveDirectory();assert(os.rename(folder..'/'..path..'.part',folder..'/'..path),'Cannot commit party checkpoint')
    assert(fs.read(path)==bytes,'Party save verification failed')
    S.saved_file=path;S.summary={ante=archive.model.ante,index=archive.model.blind_index,players=archive.model.intended,deck=archive.model.deck,at=archive.at,version=archive.version,compatible=true}
    -- Retain three complete generations. Partial files are never considered.
    local files={};for _,file in ipairs(fs.getDirectoryItems(S.directory)) do if file:match('^%d+%-[0-9a-f%-]+%.btparty$') then files[#files+1]=file end end
    table.sort(files,function(a,b) return a>b end)
    for i=4,#files do fs.remove(S.directory..'/'..files[i]) end
end
function S.request(leave)
    if not BT.client.model then BT.notice('The host saves the whole party.');return end
    BT.client.action('save_request',{leave=leave==true},function(ok)
        if ok then BT.notice(leave and 'Save & Leave requested. Everyone finishes their shop first.' or 'Saving when everyone reaches blind selection.') end
    end)
end
function S.resume()
    if BT.state then BT.notice('Leave the current table before resuming a saved party.');return end
    local ok,archive=pcall(read_archive);if not ok then BT.notice(tostring(archive));return end
    if BT.compat then BT.compat.register_decks() end
    local identity=BT.steam.available();local host=archive.model.players[1]
    if host.steam_id and (not identity or identity.id~=host.steam_id) then BT.notice('This saved party belongs to its original Steam host.');return end
    local valid,model=pcall(ledger.restore,BT.Session,archive.model);if not valid then BT.notice('This party save cannot be restored: '..tostring(model));return end
    BT.client.host(archive.transport or 'steam');if not BT.client.model then return end
    S.loaded=archive;S.restore_id=nil;S.native_started=nil;S.restore_sent=nil;S.outgoing={};S.buffers={};S.uploaded=nil;S.upload_id=nil
    BT.client.restore_party(model);BT.ui.navigate('lobby');BT.notice('Saved party reopened. Share the new code with the original players.')
end
function S.welcome()
    local p=me();if not p or not BT.state.party_id then return end
    if BT.client.transport=='tcp' and not (BT.bots and BT.bots.config) then
        local value={address=BT.client.address,port=BT.client.port,token=BT.client.resume,party=BT.state.party_id}
        love.filesystem.createDirectory('together');love.filesystem.write('together/reconnect.json',json.encode(value))
    end
    S.restore_id=nil;S.native_started=nil;S.restore_sent=nil;S.restore_buffer=nil;S.upload_id=nil;S.restore_packet=nil;S.restore_error=nil;S.request_at=nil
end
function S.reconnect_token(address,port)
    local text=love.filesystem.read('together/reconnect.json');if not text or #text>2048 then return end
    local ok,v=pcall(json.decode,text)
    if ok and v.address==address and v.port==port and type(v.token)=='string' and #v.token==64 then return v.token end
end
function S.host_message(seat,peer,msg)
    local m=BT.client.model;if not m then return end
    local ok,err=pcall(function()
        if msg.type=='checkpoint_request' then
            assert(m.phase=='resuming' and msg.id==m.resume_checkpoint and S.loaded,'No saved build is waiting')
            local data=assert(S.loaded.builds[tostring(seat)],'The saved seat has no build');send(peer,'restore',m.resume_checkpoint,data)
        elseif msg.type=='checkpoint_failed' then
            if m.phase=='saving' and m.checkpoint.id==msg.id then ledger.cancel(m,msg.error or 'A teammate could not save their build') end
        else
            assert(m.phase=='saving' and msg.id==m.checkpoint.id and msg.purpose=='save','No checkpoint upload is expected')
            local buffer,data=Codec.add_chunk(S.buffers[seat],msg);S.buffers[seat]=buffer
            if data then
                assert(hash(data)==buffer.hash,'Build transfer checksum failed');validated_native(data)
                S.uploaded=S.uploaded or {};S.uploaded[tostring(seat)]=data
                m.checkpoint.uploads[tostring(seat)]=buffer.hash;m:changed()
            end
        end
    end)
    if not ok then fail(err) end
end
function S.client_message(msg)
    local s=BT.state
    if not s or s.phase~='resuming' or msg.purpose~='restore' or msg.id~=s.resume_checkpoint then return end
    local ok,err=pcall(function()
        local buffer,data=Codec.add_chunk(S.restore_buffer,msg);S.restore_buffer=buffer
        if data then assert(hash(data)==buffer.hash,'Restored build checksum failed');S.restore_packet=validated_native(data);S.restore_id=msg.id end
    end)
    if not ok then S.restore_error=tostring(err);BT.notice('Could not restore your build: '..tostring(err)) end
end
function S.restore_native()
    local s=BT.state;if not s or s.phase~='resuming' then return end
    if BT.client.model and S.loaded and S.restore_id~=s.resume_checkpoint then
        local data=S.loaded.builds['1'];local ok,packet=pcall(validated_native,data)
        if not ok then S.restore_error=tostring(packet);BT.notice('Could not restore host build: '..tostring(packet));return end
        S.restore_packet=packet;S.restore_id=s.resume_checkpoint
    end
    if not S.restore_packet or S.restore_id~=s.resume_checkpoint then
        if not BT.client.model and not S.restore_error and (not S.request_at or S.clock-S.request_at>8) then
            S.request_at=S.clock;BT.client.message(1,{type='checkpoint_request',id=s.resume_checkpoint})
        end
        return
    end
    if not S.native_started then
        if not BT.game.can_start_native() then return end
        BT.game.reset();BT.game.run_id=s.run_id;S.native_started=s.resume_checkpoint
        local options={savetext=S.restore_packet.native};BT.game.internal_start=true;BT.game.refs.start_run(nil,options);BT.game.internal_start=false
        return
    end
    if S.restore_sent then return end
    local ready=G.STAGE==G.STAGES.RUN and G.STATE==G.STATES.BLIND_SELECT and G.blind_select and not G.SETTINGS.paused
        and not G.OVERLAY_MENU and G.CONTROLLER and not G.CONTROLLER.lock_input and not G.CONTROLLER.locks.use
    if not ready then return end
    for _,event in ipairs(G.E_MANAGER.queues.base or {}) do if not event.complete and event.blocking~=false then return end end
    local position=BT.game.position()
    if position.ante~=s.ante or position.index~=s.blind_index then S.restore_error='Native blind position differs from the checkpoint';BT.notice(S.restore_error);return end
    restore_cursor(S.restore_packet);S.restore_sent=true
    if not BT.client.action('restore_ready',{checkpoint=s.resume_checkpoint,ante=position.ante,index=position.index},function(ok) if not ok then S.restore_sent=nil end end) then S.restore_sent=nil end
end
function S.update(dt)
    S.clock=S.clock+dt
    if not S.scanned then S.scanned=true;S.refresh() end
    local s=BT.state;local c=BT.client;local m=c.model
    if not s then S.upload_id=nil;S.restore_id=nil;S.native_started=nil;S.restore_sent=nil;S.restore_packet=nil;S.restore_error=nil;S.outgoing={};S.leave_at=nil;return end
    if S.was_resuming and s.phase~='resuming' then BT.ui.navigate(nil);BT.notice('Every saved build is restored. Ready when you are.');S.was_resuming=nil end
    if s.phase=='resuming' then
        S.was_resuming=true
        if m and BT.bots and BT.bots.resume_saved and c.bot_port then BT.bots.resume_saved() end
    end
    if m and m.phase=='prepare' and ledger.safe(m) and not (m.checkpoint and m.checkpoint.status=='saving')
        and (m.manual_save_requested or m.save_autos and m.checkpoint_position~=ledger.position(m)) then
        local leave=m.save_leave_requested==true;m.manual_save_requested=nil
        c.action('save_begin',{leave=leave});s=BT.state
    end
    if s.phase=='saving' then
        local checkpoint=s.checkpoint
        if S.upload_id~=checkpoint.id then
            S.upload_id=checkpoint.id;S.save_started=S.clock
            if m then S.buffers={};S.uploaded={} end
            local ok,data=pcall(function()
                assert(BT.game.started and G.STATE==G.STATES.BLIND_SELECT and not BT.game.operation,'Native game is not ready to save')
                save_run();assert(G.ARGS.save_run,'Native saving is disabled')
                return encode({schema=1,native=G.ARGS.save_run,donation_counter=BT.donation.counter,donation_received=BT.donation.received})
            end)
            if not ok then fail(data)
            elseif m then
                S.uploaded['1']=data;m.checkpoint.uploads['1']=hash(data);m:changed()
            else send(1,'save',checkpoint.id,data) end
        end
        if m and m.phase=='saving' then
            if not m:all(function(p) return p.connected end) or S.clock-S.save_started>40 then fail('A teammate disconnected or a build upload timed out')
            elseif m:all(function(p) return m.checkpoint.uploads[tostring(p.id)]~=nil end) then
                local ok,err=pcall(function()
                    local when=os.time();local model=BT.Session.copy(m);setmetatable(model,BT.Session)
                    assert(ledger.commit(model,when));model.saved_leave=nil;model.manual_save_requested=nil
                    write_archive({schema=1,version=BT.version,compat=stamp(),at=when,transport=c.transport,model=model,builds=S.uploaded})
                    assert(ledger.commit(m,when));c.resync();BT.notice('Party checkpoint saved / every build is safe.')
                end)
                if not ok then fail(err) end
            end
        end
    end
    for peer,stream in pairs(S.outgoing) do
        if S.clock>=stream.next_at then
            stream.next_at=S.clock+0.05
            for _=1,2 do
                if stream.index>stream.total then S.outgoing[peer]=nil;break end
                local i=stream.index;stream.index=i+1
                c.message(peer,{type='checkpoint_chunk',purpose=stream.purpose,id=stream.id,hash=stream.hash,total=stream.total,index=i,data=stream.data:sub((i-1)*Codec.CHUNK+1,i*Codec.CHUNK)})
            end
        end
    end
    if s.saved_leave then
        S.leave_at=S.leave_at or S.clock+(m and 1 or 0.35)
        if S.clock>=S.leave_at then
            if BT.game.refs.go_to_menu then c.stop();BT.game.refs.go_to_menu();BT.ui.navigate('home') end
        end
    end
end
function S.connection_reset()
    S.outgoing={};S.buffers={};S.loaded=nil;S.uploaded=nil;S.upload_id=nil;S.restore_id=nil;S.native_started=nil;S.restore_sent=nil
    S.restore_buffer=nil;S.restore_packet=nil;S.restore_error=nil;S.request_at=nil;S.leave_at=nil;S.was_resuming=nil
end
function S.install()
    for _,name in ipairs({'sell_card','buy_from_shop','use_card','reroll_shop','toggle_shop','select_blind','skip_blind','play_cards_from_highlighted','discard_cards_from_highlighted'}) do
        local original=G.FUNCS[name]
        if original then G.FUNCS[name]=function(...)
            local phase=BT.state and BT.state.phase
            if phase=='saving' or phase=='resuming' then return end
            return original(...)
        end end
    end
end
S.codec=Codec
return S
