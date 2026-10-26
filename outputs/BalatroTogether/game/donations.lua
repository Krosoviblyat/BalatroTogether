local D={counter=0,received={},clock=0}
local schema=BT.Session.Donations
local function me() return BT.state and BT.state.players[tostring(BT.client.id)] end
function D.busy() return D.pending~=nil end
local function request()
    D.counter=D.counter+1
    return BT.state.run_id..':'..BT.client.id..':'..D.counter
end
local function area_for(kind) return kind=='Enhanced' and G.deck or kind=='Joker' and G.jokers or G.consumeables end
local function owns_playing(c)
    for _,card in ipairs(G.playing_cards or {}) do if card==c then return true end end
    return false
end
local function settled()
    if not BT.active() or not BT.client.connected or not BT.game.started or not G.GAME or G.SETTINGS.paused
        or G.OVERLAY_MENU or G.CONTROLLER.lock_input or BT.game.operation or BT.game.pending_play
        or G.CONTROLLER.locks.use or G.CONTROLLER.locks.toggle_shop then return false end
    if G.STATE~=G.STATES.SHOP and G.STATE~=G.STATES.BLIND_SELECT then return false end
    if BT.state.phase~='prepare' and BT.state.phase~='shop' then return false end
    for _,event in ipairs(G.E_MANAGER.queues.base or {}) do if not event.complete and event.blocking~=false then return false end end
    return true
end
function D.available()
    local p=me()
    return settled() and p and not p.ready and not p.withdrawn and not D.busy()
        and not (BT.pot and BT.pot.busy())
        and not (BT.dice and BT.dice.busy())
        and (p.activity=='shopping' or p.activity=='blind_select' or p.activity=='waiting')
end
function D.eligible(c)
    local center=c and c.config and c.config.center
    local supported=center and (not center.mod or center.mod.id=='Cryptid' or BT.compat and BT.compat.center and BT.compat.center(center))
    local fungus=BT.shroombo and BT.shroombo.is_fungus(c) and owns_playing(c)
    if fungus and (c.removed or c.getting_sliced or c.shattered or c.destroyed or not c.area) then return false,'That Fungus Card is being removed.' end
    if not supported or not fungus and not ({Joker=true,Tarot=true,Planet=true,Spectral=true,Code=true})[center.set] then return false,'Share supported Jokers, consumables and owned Fungus Cards.' end
    if c.cry_storage or c.edition and c.edition.cry_double_sided then return false,'Cards with attached storage or a second face stay with their owner.' end
    if c.config.cry_multiply then return false,'Wait for this card\'s temporary Multiply effect to expire before donating.' end
    if BT.compat and not BT.compat.allowed(center) then return false,'This progression effect is unavailable in co-op.' end
    if not fungus and c.area~=area_for(center.set) then return false,'Only cards you own can be donated.' end
    if c.ability.eternal then return false,'Eternal cards cannot be donated.' end
    if c.debuff then return false,'Wait until this card is no longer debuffed.' end
    return true
end
function D.pack(c)
    local ok,err=D.eligible(c); if not ok then return nil,err end
    local edition=''; for _,key in ipairs({'negative','polychrome','holo','foil'}) do if c.edition and c.edition[key] then edition=key; break end end
    if c.edition and type(c.edition.type)=='string' and c.edition.type:match('^cry_') then edition=c.edition.type end
    local data,message=schema.card{center=c.config.center.key,kind=c.ability.set,name=c.ability.name,ability=c.ability,
        edition=edition,edition_data=edition:match('^cry_') and c.edition or nil,seal=c.seal,pinned=c.pinned,effect=BT.game.effect_summary(c.ability)}
    if not data then return nil,message end
    local encoded,value=pcall(BT.json.encode,data)
    if not encoded or #value>16000 then return nil,'This card has too much custom state to transfer.' end
    return data
end
function D.space(card)
    if card.kind=='Enhanced' then return card.center=='m_btogether_fungus' and G.deck~=nil end
    local area=area_for(card.kind)
    return area and #area.cards<area.config.card_limit+(card.edition=='negative' and 1 or 0)
end
local function restore(pending)
    local c=pending.original
    if c and not c.removed then
        c.states.visible=pending.visible
        if BT.government then BT.government.restore(c) else c:add_to_deck() end
        if pending.playing then
            G.playing_card=(G.playing_card or #G.playing_cards)+1;c.playing_card=G.playing_card
            table.insert(G.playing_cards,c);G.deck.config.card_limit=G.deck.config.card_limit+1
        end
        pending.area:emplace(c)
    end
end
local function notify(kind,card)
    if BT.ui and BT.ui.donation_event then BT.ui.donation_event(kind,card) end
    BT.notice(kind=='donated' and ('Donated '..card.name..' to the team.') or ('Received '..card.name..'.'))
end
function D.offer(c,target)
    if not D.available() then BT.notice('Donate between blinds or in the shop, while unready and after animations finish.'); return end
    local data,err=D.pack(c); if not data then BT.notice(err); return end
    local area=c.area
    local pending={kind='offer',request=request(),card=data,original=c,area=area,visible=c.states.visible}
    -- Escrow first. The host cannot publish the card while it is still owned.
    area:remove_card(c); c:remove_from_deck(); c.states.visible=false
    if data.kind=='Enhanced' then
        for i,card in ipairs(G.playing_cards) do if card==c then table.remove(G.playing_cards,i);break end end
        G.deck.config.card_limit=G.deck.config.card_limit-1;pending.playing=true
    end
    D.pending=pending
    local seq=BT.client.action('donation_offer',{request=pending.request,card=data,target=target or 0})
    if not seq then restore(pending); D.pending=nil end
end
function D.claim(item)
    if not D.available() then BT.notice('Take cards between blinds or in the shop, while unready.'); return end
    if not item or item.status~='available' then return end
    if not D.space(item.card) then BT.notice('Make room in your '..(item.card.kind=='Joker' and 'joker' or 'consumable')..' inventory first.'); return end
    local tx=request(); D.pending={kind='claim',request=tx,item=item.id,card=item.card}
    if not BT.client.action('donation_claim',{request=tx,item=item.id}) then D.pending=nil end
end
local function merge(defaults,source)
    for key,value in pairs(source) do
        local original=defaults[key]
        local numeric=BT.numbers and BT.numbers.finite(original) and BT.numbers.finite(value)
        if original~=nil and type(original)~=type(value) and not numeric then error('Incompatible native card field: '..tostring(key)) end
        if type(value)=='table' and type(original)=='table' then merge(original,value) else defaults[key]=value end
    end
end
function D.receive(data,itemid)
    if D.received[itemid] then return true end
    local valid,err=schema.card(data); if not valid then return nil,err end
    local center=G.P_CENTERS[valid.center]
    local supported=center and (not center.mod or center.mod.id=='Cryptid' or BT.compat and BT.compat.center and BT.compat.center(center))
    if not supported or center.set~=valid.kind or center.name~=valid.ability.name then return nil,'That card is unavailable or incompatible.' end
    if valid.edition:match('^cry_') and not G.P_CENTERS['e_'..valid.edition] then return nil,'That Cryptid edition is unavailable.' end
    if valid.seal and not (G.P_SEALS and G.P_SEALS[valid.seal]) then return nil,'That playing-card seal is unavailable.' end
    if not D.space(valid) then return nil,'Inventory is full.' end
    local area=area_for(valid.kind); local c
    local playing=valid.kind=='Enhanced';local deck_limit=playing and G.deck.config.card_limit
    local ok,message=pcall(function()
        c=Card(area.T.x,area.T.y,G.CARD_W,G.CARD_H,playing and G.P_CARDS.S_2 or G.P_CARDS.empty,center,
            {bypass_discovery_center=true,bypass_discovery_ui=true,bypass_lock=true})
        if valid.edition~='' then c:set_edition({[valid.edition]=true},true,true) end
        if valid.edition_data then merge(c.edition,valid.edition_data) end
        if valid.seal then c:set_seal(valid.seal,true,true) end
        -- Steamodded folds an edition's slot bonus into ability.card_limit.
        -- Apply the edition before restoring that saved total, not after it.
        merge(c.ability,valid.ability)
        c.ability.queue_negative_removal=nil; c.added_to_deck=false; c.debuff=false; c.pinned=valid.pinned
        c:set_cost()
        if playing then SMODS.add_to_deck(c,{set='Enhanced',area=area});playing_card_joker_effects({c})
        else c:add_to_deck();area:emplace(c);G.GAME.used_jokers[valid.center]=true end
        c.bt_donation_received=itemid
    end)
    if not ok then
        if c and not c.removed then pcall(function() c:remove() end) end
        if playing then G.deck.config.card_limit=deck_limit end
        return nil,tostring(message)
    end
    D.received[itemid]=true
    return true
end
function D.reset()
    if D.pending and D.pending.original and not D.pending.original.removed then
        -- Leaving/restarting abandons the old escrow. Never restore an object
        -- whose deposit might already have been accepted by the host.
        pcall(function() D.pending.original:remove() end)
    end
    D.pending=nil; D.received={}; D.counter=0
end
function D.update(dt)
    D.clock=D.clock+dt
    local p=me(); if not p then return end
    local pending=D.pending
    if pending then
        local receipt=p.donation_receipt
        if not receipt or receipt.request~=pending.request then return end
        if receipt.status=='rejected' then
            if pending.kind=='offer' then restore(pending) end
            D.pending=nil; BT.notice(receipt.error or 'Donation was rejected.'); return
        end
        if pending.kind=='offer' and receipt.status=='deposited' then
            if pending.original and not pending.original.removed then pending.original:remove() end
            D.pending=nil; notify('donated',pending.card); return
        end
        if receipt.status=='claimed' or receipt.status=='cancelled' then
            D.pending=nil
            if receipt.status=='claimed' then notify('received',pending.card) end
            return
        end
        if pending.kind=='claim' and receipt.status=='reserved' and settled() and not pending.stage then
            local item
            for _,value in ipairs(BT.state.donations and BT.state.donations.items or {}) do if value.id==pending.item then item=value end end
            if not item or not item.payload then return end
            local ok,err=D.receive(item.payload,item.id)
            local kind=ok and 'donation_commit' or 'donation_cancel'
            if BT.client.action(kind,{request=pending.request,item=item.id}) then pending.stage=kind end
            if not ok then BT.notice(err or 'Donation could not be delivered; it remains in the box.') end
        end
        return
    end
    -- Bots only take cards explicitly addressed to their seat. They never
    -- race humans for Everyone donations.
    if BT.bots and BT.bots.config and settled() then
        for _,item in ipairs(BT.state.donations and BT.state.donations.items or {}) do
            if item.target==BT.client.id and item.status=='available' and D.space(item.card) then
                if p.ready then BT.client.action('ready',{ready=false}) else D.claim(item) end
                return
            end
        end
    end
end
function D.install()
    for _,name in ipairs({'buy_from_shop','sell_card','use_card','reroll_shop','toggle_shop','select_blind','play_cards_from_highlighted','discard_cards_from_highlighted'}) do
        local original=G.FUNCS[name]
        if original then G.FUNCS[name]=function(...)
            if D.busy() then BT.notice('Finishing the donation transfer...'); return end
            return original(...)
        end end
    end
end
return D
