local V={}
local function roster(m)
    local ids={};for i=1,4 do local p=m.players[i];if p and p.connected and not p.withdrawn and not p.bot then ids[#ids+1]=tostring(i) end end
    return table.concat(ids,':'),#ids
end
local function safe(m)
    return m:all(function(p) return p.connected and not p.busy and not p.transferring
        and (not m.Pot or not m.Pot.pending(p)) and (not m.Dice or not m.Dice.pending(p)) end)
end
function V.advance(m)
    if m.phase~='skipping' then return end
    local order=m.skip_order
    if not order or not m:all(function(p) return p.connected and p.skip_done==order.id end) then return end
    m.blind_index=order.index+1;m.phase='prepare';m.proposal=nil;m.last_skip=order;m.skip_order=nil;m.skip_vote=nil
    for _,p in pairs(m.players) do p.ready=false end
    m:event(1,'milestone','Blind skipped / every player kept their native tag');m:changed()
end
function V.tick(m,clock)
    m.vote_clock=clock
    local vote=m.skip_vote;if not vote then return end
    local signature=roster(m)
    if signature~=vote.roster or clock>=vote.deadline or m.phase~='prepare' then
        m.skip_vote=nil;m:event(1,'milestone','Skip vote ended / play the blind');m:changed()
    end
end
function V.apply(m,id,kind,d)
    local p=m.players[id]
    if kind=='skip_done' then
        local order=m.skip_order
        if m.phase~='skipping' or not order or d.order~=order.id or d.ante~=order.ante or d.index~=order.index+1 then return nil,'Wait for the native skip to finish.' end
        p.skip_done=order.id;V.advance(m);return true
    end
    if kind~='skip_vote' then return nil,'Unknown skip vote.' end
    if m.phase~='prepare' or m.blind_index==3 or (m.proposal and m.proposal.boss) then return nil,'Vote at Small or Big Blind selection. Boss Blinds are mandatory.' end
    if p.bot or d.ante~=m.ante or d.index~=m.blind_index or d.round~=m.round or not p.native_safe or p.native_ante~=m.ante or p.native_index~=m.blind_index then return nil,'Reach the matching native blind selection before voting.' end
    if d.choice~='yes' and d.choice~='no' then return nil,'Choose skip or play.' end
    if not safe(m) then return nil,'Wait for everyone to connect and finish transfers.' end
    local signature,n=roster(m);if n==0 then return nil,'A human player must vote.' end
    local vote=m.skip_vote
    if not vote or vote.roster~=signature then
        vote={roster=signature,votes={},yes=0,no=0,needed=math.floor(n/2)+1,total=n,deadline=(m.vote_clock or 0)+20,ante=m.ante,index=m.blind_index,round=m.round}
        m.skip_vote=vote;for _,q in pairs(m.players) do q.ready=false end
    end
    vote.votes[tostring(id)]=d.choice;vote.yes=0;vote.no=0
    for _,choice in pairs(vote.votes) do if choice=='yes' then vote.yes=vote.yes+1 else vote.no=vote.no+1 end end
    if vote.yes>=vote.needed then
        m.skip_counter=(m.skip_counter or 0)+1;m.skip_order={id=m.skip_counter,ante=m.ante,index=m.blind_index,round=m.round}
        m.skip_vote=nil;m.phase='skipping';for _,q in pairs(m.players) do q.ready=false;q.skip_done=nil end
        m:event(id,'milestone','Majority voted to skip / collecting native tags')
    elseif vote.no>vote.total-vote.needed then
        m.skip_vote=nil;m:event(id,'milestone','The table voted to play this blind')
    end
    return true
end
return V
