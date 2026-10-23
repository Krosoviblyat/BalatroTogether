local P={}
function P.position(m) return m.run_id..':'..m.ante..':'..m.blind_index..':'..m.round end
function P.safe(m)
    return m.phase=='prepare' and not m.skip_vote and not m.skip_order and m:all(function(p)
        return p.connected and p.native_safe and p.native_ante==m.ante and p.native_index==m.blind_index
            and not p.busy and not p.transferring and (not m.Pot or not m.Pot.pending(p)) and (not m.Dice or not m.Dice.pending(p))
    end)
end
function P.begin(m,id,leave)
    if id~=1 then return nil,'Only the host can save the party.' end
    if not P.safe(m) then return nil,'Everyone must finish their shop and transfers, then reach blind selection.' end
    m.checkpoint_serial=(m.checkpoint_serial or 0)+1
    m.checkpoint={id=m.party_id..'-'..m.run_id..'-'..m.checkpoint_serial,status='saving',position=P.position(m),uploads={},leave=leave==true}
    m.phase='saving';m.skip_vote=nil;m.save_leave_requested=nil
    for _,p in pairs(m.players) do p.ready=false end
    return true
end
function P.commit(m,when)
    if m.phase~='saving' or not m.checkpoint then return nil,'No party save is in progress.' end
    if not m:all(function(p) return p.connected and m.checkpoint.uploads[tostring(p.id)]~=nil end) then return nil,'Waiting for every player\'s build.' end
    m.checkpoint.status='saved';m.checkpoint.at=when;m.checkpoint_position=m.checkpoint.position;m.phase='prepare'
    if m.checkpoint.leave then m.saved_leave=m.checkpoint.id end
    m:changed();return true
end
function P.cancel(m,reason)
    if m.phase~='saving' then return end
    m.phase='prepare';m.checkpoint.status='failed';m.checkpoint.error=tostring(reason):sub(1,150)
    m.checkpoint_position=m.checkpoint.position;m:changed()
end
function P.advance(m)
    if m.phase~='resuming' or not m:all(function(p) return p.connected and p.restore_done==m.resume_checkpoint end) then return end
    m.phase='prepare';m.checkpoint_position=P.position(m);m.checkpoint.status='saved'
    for _,p in pairs(m.players) do p.ready=false end
    m:event(1,'milestone','Saved party restored / ready when you are');m:changed()
end
function P.apply(m,id,kind,d)
    if kind=='save_request' then
        if id~=1 or (m.phase~='shop' and m.phase~='prepare') then return nil,'Host can save after the blind, once everyone leaves their shops.' end
        m.save_leave_requested=d.leave==true; m.manual_save_requested=true;return true
    end
    if kind=='save_begin' then return P.begin(m,id,d.leave) end
    if kind=='restore_ready' then
        if m.phase~='resuming' or d.checkpoint~=m.resume_checkpoint or d.ante~=m.ante or d.index~=m.blind_index then return nil,'Restored run does not match the party checkpoint.' end
        m.players[id].restore_done=m.resume_checkpoint
        P.advance(m)
        return true
    end
    return nil,'Unknown save action.'
end
function P.restore(S,model)
    assert(type(model)=='table' and model.protocol==S.PROTOCOL and model.phase=='prepare' and S.valid_deck(model.deck),'Invalid party save')
    assert(type(model.players)=='table' and type(model.party_id)=='string' and model.party_id:match('^[0-9a-f]+$') and #model.party_id==32,'Invalid saved party')
    assert(type(model.checkpoint)=='table' and model.checkpoint.status=='saved','Incomplete checkpoint')
    local result=S.copy(model);setmetatable(result,S);result.phase='resuming';result.resume_checkpoint=result.checkpoint.id
    result.saved_leave=nil;result.save_leave_requested=nil;result.manual_save_requested=nil;result.skip_vote=nil;result.skip_order=nil;result.vote_clock=0
    for i,p in pairs(result.players) do
        assert(type(i)=='number' and i%1==0 and i>=1 and i<=4 and p.id==i and type(p.token)=='string','Invalid saved seat')
        p.connected=i==1;p.ready=false;p.busy=false;p.native_safe=false;p.restore_done=nil;p.activity='loading'
    end
    result:changed();return result
end
return P
