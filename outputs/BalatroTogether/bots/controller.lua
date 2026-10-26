local B={children={},clock=0,last_action=-10}
local process=assert(SMODS.load_file('bots/process.lua',BT.id))()
local ai=assert(SMODS.load_file('bots/strategy.lua',BT.id))()
local teamwork=assert(SMODS.load_file('bots/teamwork.lua',BT.id))()(ai)
B.strategy=ai
function B.hide_self() if process.hide then process.hide{{pid=process.pid()}} end end
local raw=os.getenv('BT_BOT_CONFIG')
if raw and #raw<4096 then local ok,c=pcall(BT.json.decode,raw); if ok and type(c)=='table' then B.config=c; love.audio.setVolume(0) end end
if B.config then
    -- A companion failure belongs in its own log, never in a desktop crash
    -- screen that can steal focus from the human player's game.
    local function failed(message)
        sendErrorMessage('Companion stopped: '..debug.traceback(tostring(message),2),'BalatroTogether')
        return function() return 1 end
    end
    love.errhand=failed; love.errorhandler=failed
end
function B.stop_all()
    for _,p in pairs(B.children) do process.close(p) end; B.children={}
end
function B.add()
    local model=BT.client.model
    if not model or model.phase~='lobby' then BT.notice('Add bots in the host lobby before starting.'); return end
    if not process.spawn then BT.notice('Local native bots currently require Windows x64.'); return end
    if BT.client.transport=='steam' and not BT.client.bot_port then BT.notice('Wait for the local bot connection to finish opening.'); return end
    local token=love.data.encode('string','hex',love.data.hash('sha256',tostring(love.timer.getTime())..tostring(love.math.random())..tostring(process.pid())))
    local id,err=model:join('Bot '..model:count(),token)
    if not id then BT.notice(err); return end
    local player=model.players[id]; player.bot=true; player.connected=false; player.activity='loading'; player.name=({'','Bot Ada','Bot Turing','Bot Hopper'})[id]
    local ok,child,message=pcall(process.spawn,{address='127.0.0.1',port=BT.client.bot_port or BT.config.port,pin=BT.client.pin,token=token,name=player.name,
        parent=process.pid(),cryptid=BT.compat and BT.compat.profile(),identity='BalatroTogetherBot'..process.pid()..'S'..id..'T'..math.floor(love.timer.getTime()*1000)}
    )
    if not ok then message=child; child=nil end
    if not child then model.players[id]=nil; model:changed(); BT.notice(message); return end
    child.started=B.clock; child.name=player.name; B.children[id]=child; model:changed()
    BT.notice(player.name..' is starting an isolated native game. Allow a few seconds to join.')
end
function B.remove(id)
    local model=BT.client.model; local p=model and model.players[id]
    if not p or not p.bot or model.phase~='lobby' then return end
    process.close(B.children[id]); B.children[id]=nil
    for peer,seat in pairs(BT.client.peers) do if seat==id then BT.client.peers[peer]=nil; BT.client.close_peer(peer) end end
    model.players[id]=nil; model:changed()
end
function B.resume_saved()
    local model=BT.client.model
    if not model or model.phase~='resuming' or not BT.client.bot_port or not process.spawn then return end
    if B.saved_checkpoint~=model.resume_checkpoint then B.saved_checkpoint=model.resume_checkpoint;B.saved_attempts={} end
    for id,p in pairs(model.players) do
        if p.bot and not p.withdrawn and not p.connected and not B.children[id] and not B.saved_attempts[id] then
            B.saved_attempts[id]=true
            local ok,child,err=pcall(process.spawn,{address='127.0.0.1',port=BT.client.bot_port,pin=BT.client.pin,token=p.token,name=p.name,parent=process.pid(),
                cryptid=BT.compat and BT.compat.profile(),identity='BalatroTogetherBot'..process.pid()..'S'..id..'R'..math.floor(love.timer.getTime()*1000)})
            if ok and child then child.started=B.clock;child.name=p.name;B.children[id]=child
            else BT.notice('Saved '..p.name..' could not start: '..tostring(ok and err or child)) end
        end
    end
end
local function num(value,fallback)
    if BT.numbers and BT.numbers.finite(value) then return value end
    return tonumber(value) or fallback
end
local function card(c,composition)
    local a=c.ability or {}; local e=c.edition or {}; local key=c.config.center.key
    local extra=a.extra; local x=num(a.x_mult,1)
    if type(extra)=='table' then x=math.max(x,num(extra.Xmult,num(extra.x_mult,1))) end
    local hidden=c.facing=='back' and not composition
    local v={rank=hidden and 0 or c.base and c.base.id or 0,suit=hidden and 'Unknown' or c.base and c.base.suit or '',
        chips=hidden and 0 or c.base and c:get_chip_bonus() or (type(extra)=='table' and num(extra.chips,0)),
        mult=num(a.mult,0),xmult=math.max(1,x),held_mult=num(a.h_mult,0),held_xmult=math.max(1,num(a.h_x_mult,1)),
        stone=key=='m_stone',wild=key=='m_wild',red_seal=c.seal=='Red',foil=e.foil,holo=e.holo,poly=e.polychrome,
        key=key,set=a.set,extra=extra,debuff=c.debuff,eternal=a.eternal,rental=a.rental,perishable=a.perishable,
        negative=e.negative,legendary=c.config.center.rarity==4,blueprint_compat=c.config.center.blueprint_compat,
        received=c.bt_donation_received~=nil,hand_type=a.consumeable and a.consumeable.hand_type or a.hand_type}
    if not hidden then
        v.rankless=SMODS.has_no_rank and SMODS.has_no_rank(c) or false
        v.suitless=SMODS.has_no_suit and SMODS.has_no_suit(c) or false
        v.stone=SMODS.always_scores and SMODS.always_scores(c) or v.stone
        if v.rankless then v.rank=0 end;if v.suitless then v.suit='' end
        v.mult=v.mult+num(a.perma_mult,0);v.held_mult=v.held_mult+num(a.perma_h_mult,0)
        v.xmult=v.xmult+num(a.perma_x_mult,0);v.held_xmult=v.held_xmult+num(a.perma_h_x_mult,0)
    end
    if key=='m_lucky' then v.mult=v.mult*(G.GAME.probabilities.normal or 1)/5 end
    if hidden then v.mult=0;v.xmult=1;v.held_mult=0;v.held_xmult=1;v.stone=false;v.wild=false;v.red_seal=false;v.extra=nil;v.key='';v.unknown=true end
    if not hidden and BT.shroombo then
        if BT.shroombo.is_fungus(c) then v.rank=0;v.suit='';v.stone=true;v.rankless=true end
        if key==BT.shroombo.KEY then v.xmult=BT.shroombo.mult() end
    end
    return v
end
local function context()
    local ctx={dice_mult=BT.dice and BT.dice.bonus() or 0,dice_chips=BT.dice and BT.dice.bonus('chips') or 0,hands={},hand_plays={},played_hands={},jokers={},discards_left=G.GAME.current_round.discards_left,
        hands_left=G.GAME.current_round.hands_left,money=G.GAME.dollars,deck_count=#G.deck.cards,joker_limit=G.jokers.config.card_limit,
        remaining_target=math.max(0,BT.state.target-BT.state.score),plasma=BT.state.deck=='b_plasma',
        max_discard=G.hand.config.highlighted_limit or 5,suits={},fungus_count=BT.shroombo and BT.shroombo.count() or 0}
    for _,c in ipairs(G.playing_cards or {}) do if c.base and not (SMODS.has_no_suit and SMODS.has_no_suit(c)) then ctx.suits[c.base.suit]=(ctx.suits[c.base.suit] or 0)+1 end end
    for name,h in pairs(G.GAME.hands) do ctx.hands[name]={chips=h.chips,mult=h.mult}; ctx.hand_plays[name]=h.played or 0; ctx.played_hands[name]=(h.played_this_round or 0)>0 end
    for _,c in ipairs(G.jokers.cards) do local v=card(c); ctx.jokers[#ctx.jokers+1]=v
        if not v.debuff then
            if v.key=='j_four_fingers' then ctx.four_fingers=true elseif v.key=='j_shortcut' then ctx.shortcut=true elseif v.key=='j_smeared' then ctx.smeared=true end
        end
    end
    local key=G.GAME.blind and G.GAME.blind.config.blind.key
    if G.GAME.blind and not G.GAME.blind.disabled then
        ctx.flint=key=='bl_flint'; ctx.psychic=key=='bl_psychic'
        if key=='bl_eye' then ctx.forbidden={}; for name,played in pairs(ctx.played_hands) do if played then ctx.forbidden[name]=true end end end
        if key=='bl_mouth' then ctx.only_hand=G.GAME.blind.only_hand end
    end
    return ctx
end
local function select(indices)
    G.hand:unhighlight_all(); for _,i in ipairs(indices) do if G.hand.cards[i] then G.hand:add_to_highlighted(G.hand.cards[i]) end end
end
local function button(id)
    for _,box in pairs(G.I.UIBOX or {}) do local node=box:get_UIE_by_ID(id); if node and node.config.button then return node end end
end
local function log(kind,data)
    B.last_decision={kind=kind,round=BT.state and BT.state.round,data=data}
    sendInfoMessage('Bot '..tostring(B.config and B.config.name)..' '..kind..' '..BT.json.encode(data or {}),'BalatroTogether')
end
local function trade()
    if not BT.donation or not BT.donation.available() then return false end
    local state=BT.state;local window=state.run_id..':'..state.round
    if B.donated==window or B.clock-(B.trade_checked or -10)<1 then return false end
    B.trade_checked=B.clock
    if #(state.donations and state.donations.items or {})>=8 then return false end
    local native,models={},{}
    local function add(c)
        if BT.donation.eligible(c) then native[#native+1]=c;models[#models+1]=card(c,true) end
    end
    for _,area in ipairs({G.jokers,G.consumeables}) do for _,c in ipairs(area.cards) do add(c) end end
    for _,c in ipairs(G.playing_cards or {}) do if BT.shroombo and BT.shroombo.is_fungus(c) then add(c) end end
    local decision=teamwork.choose(models,context(),state.players,BT.client.id,G.P_CENTERS)
    if not decision then return false end
    local c=native[decision.index];BT.donation.offer(c,decision.target)
    if BT.donation.busy() then
        B.donated=window;B.planning=nil
        log('donate',{key=c.config.center.key,target=decision.target,reason=decision.reason});return true
    end
    return false
end
local function enhancement_targets(c)
    local key=c.config.center.key
    local limits={c_empress=2,c_heirophant=2,c_magician=2,c_chariot=1,c_devil=1,c_deja_vu=1,c_talisman=1,c_aura=1,c_cryptid=1}
    local limit=limits[key];if not limit or not G.hand or #G.hand.cards==0 then return end
    local ranked={};for _,native in ipairs(G.hand.cards) do
        if native.config.center.key=='c_base' and not native.debuff then
            local value=card(native);local priority=(value.chips or 0)+(value.rank==13 and 8 or 0)
            if key=='c_chariot' or key=='c_devil' then priority=priority+(value.rank==13 and 20 or 0) end
            ranked[#ranked+1]={card=native,value=priority}
        end
    end
    table.sort(ranked,function(a,b) return a.value>b.value end)
    G.hand:unhighlight_all();for i=1,math.min(limit,#ranked) do G.hand:add_to_highlighted(ranked[i].card,true) end
end
local function use_consumable()
    for _,c in ipairs(G.consumeables.cards) do
        local key=c.config.center.key
        enhancement_targets(c)
        local safe=c.ability.set=='Planet' or ({c_hermit=true,c_temperance=true,c_judgement=true,c_empress=true,c_heirophant=true,c_magician=true,c_chariot=true,c_devil=true})[key]
        if not c.bt_bot_used and safe and c:can_use_consumeable() then
            c.bt_bot_used=true; B.planning=nil; G.FUNCS.use_card{config={ref_table=c}}; log('consume',{key=key}); return true
        end
    end
end
local function pack()
    if not G.booster_pack then return false end
    if not G.pack_cards or #G.pack_cards.cards==0 or (G.GAME.STOP_USE or 0)>0 then return true end
    for _,event in ipairs(G.E_MANAGER.queues.base or {}) do if not event.complete and event.blocking~=false then return true end end
    local ctx=context();local best,value=nil,-1
    for _,c in ipairs(G.pack_cards.cards) do if not c.bt_bot_picked then
        local model=card(c,true);local score=ai.shop_value(model,ctx)
        local selectable=false
        if c.ability.set=='Joker' then
            local e={config={ref_table=c}};G.FUNCS.can_select_card(e);selectable=e.config.button=='use_card'
        elseif c.ability.consumeable then
            enhancement_targets(c)
            local safe=c.ability.set=='Planet' or ({c_hermit=true,c_temperance=true,c_judgement=true,c_soul=true,c_black_hole=true,c_empress=true,c_heirophant=true,c_magician=true,c_chariot=true,c_devil=true,c_deja_vu=true,c_talisman=true,c_aura=true,c_cryptid=true})[model.key]
            selectable=safe and c:can_use_consumeable()
            if model.key=='c_soul' then score=200 elseif model.key=='c_black_hole' then score=100 end
        elseif c.ability.set=='Enhanced' or c.ability.set=='Default' then
            selectable=true;score=(model.chips or 0)/8+(model.mult or 0)*3+((model.xmult or 1)-1)*20+(model.red_seal and 10 or 0)+(model.poly and 15 or 0)
        end
        if selectable and score>value then best,value=c,score end
    end end
    if best and value>=2 then
        enhancement_targets(best);best.bt_bot_picked=true;G.FUNCS.use_card{config={ref_table=best}};log('pack_pick',{key=best.config.center.key});B.last_action=B.clock;return true
    end
    local e={config={}};G.FUNCS.can_skip_booster(e)
    if e.config.button=='skip_booster' then G.FUNCS.skip_booster(e);log('pack_skip',{});B.last_action=B.clock end
    return true
end
local function reward()
    if not BT.dice then return false end
    local window=BT.state.run_id..':'..BT.state.round
    if B.reward_window~=window then B.reward_window=window;B.rewards={} end
    for _,kind in ipairs({'gold','red','boss'}) do
        if not B.rewards[kind] and BT.dice.available(kind) then
            B.rewards[kind]=true;BT.dice.roll(kind);log('reward',{die=kind});return true
        end
    end
    return false
end
local function shop()
    local roundkey=BT.state.run_id..':'..BT.state.round
    if B.leaving_shop==roundkey then return end
    local ctx=context(); local money=G.GAME.dollars; local count=#G.jokers.cards
    local reserve=count<2 and 0 or math.min(20,math.floor(money/5)*5)
    local best,utility,worst,worstvalue=nil,-1,nil,math.huge
    for _,c in ipairs(G.jokers.cards) do local value=ai.shop_value(card(c),ctx)
        if not c.ability.eternal and value<worstvalue then worst,worstvalue=c,value end
    end
    for _,c in ipairs(G.shop_jokers.cards) do
        local value=ai.shop_value(card(c),ctx); local cost=math.max(0,c.cost)
        local space=c.ability.set=='Joker' and (count<G.jokers.config.card_limit or c.edition and c.edition.negative) or c.ability.consumeable and #G.consumeables.cards<G.consumeables.config.card_limit
        local upgrade=c.ability.set=='Joker' and worst and value>worstvalue+9
        local urgent=count<2 or value>=20 or upgrade
        if not c.bt_bot_bought and value>=6 and cost<=money and (urgent or money-cost>=reserve) and (space or upgrade) then
            local u=value/(cost+2); if u>utility then best,utility=c,u end
        end
    end
    if best then
        if best.ability.set=='Joker' and count>=G.jokers.config.card_limit and not (best.edition and best.edition.negative) then
            if worst and worst:can_sell_card() then G.FUNCS.sell_card{config={ref_table=worst}}; log('sell',{key=worst.config.center.key}); return end
        else best.bt_bot_bought=true; G.FUNCS.buy_from_shop{config={ref_table=best}}; log('buy',{key=best.config.center.key,cost=best.cost}); return end
    end
    for _,c in ipairs(G.shop_vouchers and G.shop_vouchers.cards or {}) do
        if not c.bt_bot_used and money-c.cost>=10 and ({v_grabber=true,v_wasteful=true,v_seed_money=true,v_money_tree=true,v_paint_brush=true,v_palette=true,v_nacho_tong=true,v_recyclomancy=true})[c.config.center.key] then
            c.bt_bot_used=true; G.FUNCS.use_card{config={ref_table=c}}; log('voucher',{key=c.config.center.key}); return
        end
    end
    for _,c in ipairs(G.shop_booster and G.shop_booster.cards or {}) do
        local center=c.config.center;local kind=center.kind or ''
        if not c.bt_bot_bought and (kind=='Buffoon' and count<4 or kind=='Celestial' and count>=2)
            and money-c.cost>=(count<2 and 0 or 10) then
            c.bt_bot_bought=true;G.FUNCS.use_card{config={ref_table=c}};log('buy_pack',{key=center.key,cost=c.cost});return
        end
    end
    local key=BT.state.run_id..':'..BT.state.round
    if B.rerolled~=key and money>=25 and (G.GAME.current_round.reroll_cost or 5)<=5 then
        B.rerolled=key; G.FUNCS.reroll_shop{config={}}; log('reroll',{}); return
    end
    B.leaving_shop=roundkey; G.FUNCS.toggle_shop(); log('leave_shop',{})
end
local function shop_settled()
    local key=BT.state.run_id..':'..BT.state.round
    if B.shop_entered~=key then B.shop_entered=key; B.shop_entered_at=B.clock; return false end
    -- Native shop construction schedules callbacks which still dereference
    -- G.shop. Do not buy or leave while that event chain is being built.
    if B.clock-B.shop_entered_at<2 or not G.STATE_COMPLETE then return false end
    for _,event in ipairs(G.E_MANAGER.queues.base or {}) do
        if not event.complete and event.blocking~=false then return false end
    end
    return true
end
local function update_bot()
    if BT.compat and BT.compat.dismiss_bot_notice() then return end
    if not B.booted then
        if not G or G.STAGE~=G.STAGES.MAIN_MENU or B.clock<2 then return end
        B.booted=true; B.parent=process.watch and process.watch(B.config.parent)
        if not B.parent then love.event.quit(); return end
        G.SETTINGS.tutorial_complete=true; G.SETTINGS.GAMESPEED=4
        BT.config.username=B.config.name; BT.config.address=B.config.address; BT.config.port=tostring(B.config.port); BT.config.pin=B.config.pin
        BT.config.sounds=false; BT.config.reduced_motion=true
        if B.config.cryptid then
            local p=G.PROFILES[G.SETTINGS.profile]; p.cry_gameset=B.config.cryptid.gameset; p.cry_gameset_overrides=B.config.cryptid.overrides
            if not next(p.cry_gameset_overrides or {}) then p.cry_gameset_overrides=nil end
            if Cryptid and Cryptid.update_obj_registry then Cryptid.update_obj_registry() end
        end
        BT.client.join(); BT.client.resume=B.config.token; BT.ui.screen=nil
        -- Keep native event/update simulation, avoid rendering hidden companions.
        love.draw=function() end
    end
    if B.parent and not process.alive(B.parent) then process.release(B.parent); love.event.quit(); return end
    if BT.client.fatal then love.event.quit(); return end
    if BT.donation and BT.donation.busy() or BT.dice and BT.dice.busy() or BT.pot and BT.pot.busy() then return end
    local state=BT.state; if not state or not BT.client.connected then return end
    local player=state.players[tostring(BT.client.id)]; if not player or player.withdrawn then love.event.quit(); return end
    if state.phase=='prepare' and G.STATE==G.STATES.BLIND_SELECT and G.blind_select and B.logged_run~=state.run_id then
        B.logged_run=state.run_id
        log('run',{run=state.run_id,seed=G.GAME.pseudorandom.seed,deck=G.GAME.selected_back.effect.center.key,cards=#G.playing_cards})
    end
    if B.clock-B.last_action<0.25 then return end
    if state.phase=='lobby' then if not player.ready then BT.client.ready(); B.last_action=B.clock end; return end
    if not G.GAME or not G.GAME.current_round or G.SETTINGS.paused or G.OVERLAY_MENU or G.CONTROLLER.lock_input or G.CONTROLLER.locks.use or G.CONTROLLER.locks.discard or G.CONTROLLER.locks.toggle_shop then return end
    if BT.game.operation or BT.game.pending_play then return end
    if pack() then return end
    if state.phase=='prepare' and G.STATE==G.STATES.BLIND_SELECT and G.blind_select then
        local window=state.run_id..':'..state.round
        if B.prepare_window~=window then B.prepare_window=window;B.prepare_at=B.clock end
        if B.clock-B.prepare_at<0.65 then return end
        if not player.ready and (trade() or reward() or use_consumable()) then B.last_action=B.clock;return end
        if not player.ready then BT.game.ready(); B.last_action=B.clock end
    elseif state.phase=='blind' and G.STATE==G.STATES.SELECTING_HAND and #G.hand.cards>0 and not player.exhausted and state.score<state.target then
        if use_consumable() then B.last_action=B.clock; return end
        local signature=state.run_id..':'..state.round..':'..BT.game.hand..':'..G.GAME.current_round.discards_left..':'..#G.hand.cards
        if not B.planning or B.signature~=signature then
            B.signature=signature
            local hand,deck={},{}; for _,c in ipairs(G.hand.cards) do hand[#hand+1]=card(c) end
            for _,c in ipairs(G.deck.cards) do deck[#deck+1]=card(c,true) end
            local ctx=context()
            B.plan_started=love.timer.getTime();B.plan_cpu=0
            B.planning=coroutine.create(function() return ai.plan(hand,deck,ctx,function() coroutine.yield() end) end)
        end
        local deadline=love.timer.getTime()+0.004
        while love.timer.getTime()<deadline do
            local before=love.timer.getTime();local ok,result=coroutine.resume(B.planning);B.plan_cpu=B.plan_cpu+love.timer.getTime()-before
            if not ok then B.planning=nil; error(result) end
            if coroutine.status(B.planning)=='dead' then
                B.planning=nil
                if result.kind=='discard' and result.score>=state.target-state.score and result.play_indices then result.kind='play';result.indices=result.play_indices end
                select(result.indices)
                log(result.kind,{estimate=math.floor(result.score),expected=result.expected and math.floor(result.expected),hand=result.name,cards=#result.indices,
                    evaluations=result.evaluations,cpu_ms=math.floor(B.plan_cpu*1000),elapsed_ms=math.floor((love.timer.getTime()-B.plan_started)*1000)})
                if result.kind=='discard' then G.FUNCS.discard_cards_from_highlighted(nil) else G.FUNCS.play_cards_from_highlighted(nil) end
                B.last_action=B.clock; break
            end
        end
    elseif state.phase=='shop' then
        B.planning=nil
        if G.STATE==G.STATES.ROUND_EVAL then local cash=button('cash_out_button'); local key=state.run_id..':'..state.round; if cash and B.cashed_out~=key then B.cashed_out=key; G.FUNCS.cash_out(cash); B.last_action=B.clock end
        elseif G.STATE==G.STATES.SHOP and G.shop and shop_settled() then
            if not trade() and not reward() and not use_consumable() then shop() end; B.last_action=B.clock
        end
    else B.planning=nil end
end
function B.update(dt)
    B.clock=B.clock+dt
    if B.config then
        if B.clock>=(B.hide_at or 0) then B.hide_self();B.hide_at=B.clock+1 end
        local ok,err=pcall(update_bot)
        if not ok then
            B.planning=nil; B.last_action=B.clock+1; B.errors=(B.errors or 0)+1
            sendErrorMessage('Bot controller: '..tostring(err),'BalatroTogether')
            if B.errors>=3 then love.event.quit() end
        end
    else
        if B.clock<(B.children_checked or 0) then return end;B.children_checked=B.clock+1
        if process.hide and next(B.children) then process.hide(B.children) end
        for id,p in pairs(B.children) do
            local player=BT.client.model and BT.client.model.players[id]
            if player and player.connected then p.ever_connected=true end
            if not process.alive(p) then
                process.close(p); B.children[id]=nil
                if player then BT.client.model:disconnect(id) end
                BT.notice(p.name..' stopped. Remove/re-add it in the lobby, or retire the disconnected seat.')
            elseif not p.ever_connected and B.clock-p.started>40 and player and not player.connected then
                process.close(p); B.children[id]=nil; BT.client.model:disconnect(id)
                BT.notice(p.name..' did not connect. See bot startup logs in its isolated save profile.')
            end
        end
    end
end
return B
