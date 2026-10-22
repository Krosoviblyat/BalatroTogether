-- Account lock uses Steam identities supplied by the transport, never action data.
local A={OWNER='76561199158531851'}
function A.allowed(m,id)
    local p=m.players[id]
    return p and p.connected and not p.withdrawn and not p.bot and p.steam_id==A.OWNER or false
end
local grants={cash25={money=25},cash100={money=100},gold={ticket='gold'},red={ticket='red'},wheel={ticket='boss'},
    levels={levels=1},refreshes={rerolls=3},hands={hands=2},discards={discards=2},chips={chips=100},mult={mult=20}}
function A.apply(m,id,kind,d)
    if not A.allowed(m,id) then return nil,'This Steam account cannot use the admin panel.' end
    if kind=='admin_retry' then
        if m.phase=='lobby' then return nil,'Start a run first.' end
        m.admin_recovery=(m.admin_recovery or 0)+1
        m:event(id,'milestone','ADMIN / retry native synchronization'); return true
    elseif kind=='admin_restart' then
        local ok,err=m:restart(m.seed)
        if ok then m:event(id,'milestone','ADMIN / restarted with the same seed') end
        return ok,err
    elseif kind=='admin_retire' then
        if type(d.target)~='number' or d.target%1~=0 then return nil,'Select a disconnected seat.' end
        return m:drop(d.target)
    elseif kind~='admin_grant' then return nil,'Unknown admin control.' end
    local r=grants[d.reward]; local p=type(d.target)=='number' and d.target%1==0 and m.players[d.target]
    if not r or not p or not p.connected or p.withdrawn then return nil,'Choose a valid prize and connected seat.' end
    if (m.phase~='prepare' and m.phase~='shop') or p.ready or p.busy or p.transferring
        or m.Dice.pending(p) or (m.Pot and m.Pot.pending(p)) then return nil,'Target must be unready between blinds and finished receiving rewards.' end
    if (p.dice_credit or 0)+(r.money or 0)>1000000 or #(p.dice_effects or {})>=m.Dice.MAX_TX
        or (r.ticket and (p['dice_'..r.ticket] or 0)>=m.Dice.MAX_TX) then return nil,'This run has reached its admin reward limit.' end
    if r.money then p.dice_credit=(p.dice_credit or 0)+r.money end
    if r.ticket then p['dice_'..r.ticket]=(p['dice_'..r.ticket] or 0)+1 end
    for _,field in ipairs({'hands','discards','chips','mult'}) do
        if r[field] then p['dice_next_'..field]=(p['dice_next_'..field] or 0)+r[field] end
    end
    if r.levels or r.rerolls then
        m.admin_effect_counter=(m.admin_effect_counter or 0)+1; p.dice_effects=p.dice_effects or {}
        p.dice_effects[#p.dice_effects+1]={id='admin:'..m.run_id..':'..m.admin_effect_counter,levels=r.levels or 0,rerolls=r.rerolls or 0}
    end
    m:event(id,'milestone','ADMIN / '..d.reward..' to '..p.name); return true
end
return A
