local B={started=false,round=0,hand=0,lastchips=0,status_at=0,refs={}}
local function active() return BT.active() and B.started end
function B.finish_round(...)
    -- Both native completion paths must skip the final victory overlay before
    -- the queued end-of-round event decides whether to show it.
    if BT.state.endless and BT.state.winner and BT.state.ante>=8 and BT.state.blind_index==3 then G.GAME.won=true end
    return B.refs.end_round(...)
end
local function me() return BT.state and BT.state.players[tostring(BT.client.id)] end
local function stable()
    return G and not G.SETTINGS.paused and not G.OVERLAY_MENU and not G.OVERLAY_TUTORIAL and not G.CONTROLLER.lock_input
        and G.E_MANAGER and not G.CONTROLLER.locks.use
end
function B.can_start_native()
    -- Starting clears native event queues. Let tutorials (including Cryptid's
    -- delayed Jimbo creation) and menu wipes finish before touching those queues.
    return stable() and not G.screenwipe and not G.CONTROLLER.locks.use
end
function B.reset()
    if BT.donation then BT.donation.reset() end
    if BT.pot then BT.pot.reset() end
    if BT.dice then BT.dice.reset() end
    B.started=false; B.round=0; B.hand=0; B.lastchips=0; B.operation=nil; B.pending_play=nil
    B.operation_done=false;B.score_fault=nil
    B.finished=0; B.shopready=nil; B.laststatus=nil; B.lastphase=nil; B.started_round=0
    B.evaluated_round=nil; B.entry_sent=nil; B.shop_sent_at=-10; B.cashout_requested=nil; B.mismatch=nil
    B.entry_pending=nil; B.entry_sent_at=-10; B.shop_pending=nil
    B.skip_applied=nil;B.skip_pending=nil;B.skip_ack=nil;B.skip_sent_at=-10
end
local labels={'Small','Big','Boss'}
local function settled()
    if not stable() or G.CONTROLLER.locks.toggle_shop then return false end
    for _,event in ipairs(G.E_MANAGER.queues.base or {}) do if not event.complete and event.blocking~=false then return false end end
    return true
end
function B.position()
    local index
    for i,label in ipairs(labels) do if G.GAME.blind_on_deck==label then index=i end end
    return {round=BT.state.round,ante=BT.numbers and BT.numbers.native(G.GAME.round_resets.ante) or G.GAME.round_resets.ante,index=index}
end
function B.effect_summary(ability)
    local fields={}; local a=ability or {}
    local labels={mult='Mult',x_mult='X Mult',t_mult='Hand Mult',t_chips='Hand Chips',h_mult='Held Mult',h_x_mult='Held X Mult',
        Xmult='X Mult',chips='Chips',chip_mod='Chips per hand',mult_mod='Mult gain',odds='Odds',dollars='Dollars'}
    for _,k in ipairs({'mult','x_mult','t_mult','t_chips','h_mult','h_x_mult','extra'}) do
        local value=a[k]
        if (type(value)=='number' or BT.numbers and BT.numbers.big(value)) and k~='extra' and value~=0 and not ((k=='x_mult' or k=='h_x_mult') and value==1) then fields[#fields+1]=(labels[k] or k)..' '..tostring(value)
        elseif k=='extra' and type(value)=='table' then
            local keys={}; for key,v in pairs(value) do if type(v)=='number' or BT.numbers and BT.numbers.big(v) then keys[#keys+1]=key end end; table.sort(keys)
            for _,key in ipairs(keys) do fields[#fields+1]=(labels[key] or key:gsub('_',' '))..' '..tostring(value[key]) end
        end
    end
    return table.concat(fields,' / '):sub(1,120)
end
local function cards(area,private)
    local result={}
    for i,c in ipairs(area and area.cards or {}) do
        if i>60 then break end
        local center=c.config and c.config.center or {}
        local edition=''
        for _,e in ipairs({'negative','polychrome','holo','foil'}) do if c.edition and c.edition[e] then edition=e end end
        if c.base and c.facing=='back' then
            result[#result+1]={key='',name='Face-down card',edition='',enhancement='',seal='',rank='?',suit='Hidden',selected=private and c.highlighted or false}
        else result[#result+1]={key=center.key or '',name=c.ability and c.ability.name or center.key or '',
            edition=edition,enhancement=center.key or '',seal=c.seal or '',
            rank=SMODS.has_no_rank and SMODS.has_no_rank(c) and 'Rankless' or c.base and tostring(c.base.value) or '',
            suit=SMODS.has_no_suit and SMODS.has_no_suit(c) and 'Suitless' or c.base and c.base.suit or '',
            selected=private and c.highlighted or false,debuff=c.debuff or false,effect=B.effect_summary(c.ability)}
        end
    end
    return result
end
local function status()
    local activity='waiting'
    if B.operation then activity=B.operation=='play' and 'calculating' or B.operation
    elseif me() and me().exhausted then activity='waiting'
    elseif G.STATE==G.STATES.SELECTING_HAND then
        activity='selecting'
        if G.jokers then for _,c in ipairs(G.jokers.cards) do
            if c.states and c.states.hover and c.states.hover.is then activity='jokers'; break end end end
    elseif G.STATE==G.STATES.SHOP then activity='shopping'
    elseif G.STATE==G.STATES.BLIND_SELECT then activity='blind_select'
    elseif G.STATE==G.STATES.ROUND_EVAL then activity='cashout'
    elseif G.STATE==G.STATES.HAND_PLAYED then activity='waiting'
    elseif G.booster_pack then activity='pack' end
    local deck={Spades=0,Hearts=0,Clubs=0,Diamonds=0}
    for _,c in ipairs(G.playing_cards or {}) do if c.base and deck[c.base.suit] and not (SMODS.has_no_suit and SMODS.has_no_suit(c)) then deck[c.base.suit]=deck[c.base.suit]+1 end end
    local position=B.position()
    return {activity=activity,native_safe=G.STATE==G.STATES.BLIND_SELECT and G.blind_select~=nil and settled() and not G.shop and not G.booster_pack and not G.CONTROLLER.locks.skip_blind,
        native_ante=position.ante,native_index=position.index,hands=G.GAME.current_round.hands_left,discards=G.GAME.current_round.discards_left,
        money=G.GAME.dollars,jokers=cards(G.jokers),consumables=cards(G.consumeables),deck=deck,
        reveal=BT.config.reveal_hand,inspect=BT.config.inspect,board=BT.config.reveal_hand and cards(G.hand,true) or {},
        played=cards(G.play),shop=cards(G.shop_jokers)}
end
function B.ready()
    if not active() then BT.client.ready(); return end
    if G.booster_pack or G.STATE~=G.STATES.BLIND_SELECT or not G.blind_select or not settled() then
        BT.notice('Finish your current action, leave the shop, and reach blind selection first.'); return
    end
    if BT.state.phase=='shop' then
        if not B.finish_shop(true) then BT.notice('Waiting for native shop completion at the matching next blind.'); end
    else BT.client.ready() end
end
function B.vote_skip(choice)
    if not active() or G.STATE~=G.STATES.BLIND_SELECT or not G.blind_select or not settled() then BT.notice('Reach blind selection before voting.');return end
    local position=B.position();position.choice=choice or 'yes'
    BT.client.action('status',status())
    BT.client.action('skip_vote',position)
end
function B.finish_shop(explicit)
    local s=BT.state; local p=me()
    if not s or s.phase~='shop' or B.finished~=B.round or B.round~=s.round or not p or not BT.client.connected
        or G.STATE~=G.STATES.BLIND_SELECT or not G.blind_select or G.shop or G.booster_pack or not settled()
        or B.shop_pending or (BT.donation and BT.donation.busy()) or (BT.pot and BT.pot.busy()) or (BT.dice and BT.dice.busy()) then return end
    local position=B.position(); local index=s.blind_index%3+1; local ante=s.ante+(s.blind_index==3 and 1 or 0)
    if position.ante~=ante or position.index~=index then return end
    local bot=BT.bots and BT.bots.config
    if p.ready or (p.shop_done==s.round and not explicit and not bot) or BT.client.clock-B.shop_sent_at<0.5 then return end
    local round,run=s.round,s.run_id
    B.shop_pending=round; B.shop_sent_at=BT.client.clock
    local sequence=BT.client.action('shop_done',position,function(ok)
        if not BT.state or BT.state.run_id~=run or B.round~=round then return end
        B.shop_pending=nil; if ok then B.shopready=round end
    end)
    if not sequence then B.shop_pending=nil end
    return sequence
end
function B.capture_score()
    if not active() or B.round~=BT.state.round or B.reported==B.hand then return true end
    if Talisman and Talisman.scoring_coroutine then return false end
    local amount=G.GAME.chips-B.lastchips
    local supported
    if BT.numbers then supported=BT.numbers.delta(amount)
    else supported=type(amount)=='number' and amount==amount and math.abs(amount)<=1e100 end
    if not supported then
        if B.score_fault~=B.hand then
            B.score_fault=B.hand
            if BT.diagnostics then BT.diagnostics.record('score-error','Unsupported native score delta',{
                chips=G.GAME.chips,previous=B.lastchips,delta=amount,hand=B.hand}) end
            BT.notice('Nonfinite or unsupported score. Report saved in TogetherReports; restore a checkpoint or restart.')
        end
        return false
    end
    B.lastchips=G.GAME.chips; B.reported=B.hand
    BT.client.action('score',{round=B.round,hand=B.hand,amount=amount,name=B.last_hand or 'Hand',boss_disabled=G.GAME.blind and G.GAME.blind.disabled==true})
    BT.client.action('idle',{round=B.round,exhausted=G.GAME.current_round.hands_left<1 or (#G.hand.cards==0 and #G.deck.cards==0)})
    B.operation=nil
    return true
end
local function wrap_action(name,activity,event)
    local ref=G.FUNCS[name]; if not ref then return end
    B.refs[name]=ref
    G.FUNCS[name]=function(e,...)
        if not active() then return ref(e,...) end
        if name=='use_card' and BT.compat and not BT.compat.allowed(e and e.config and e.config.ref_table and e.config.ref_table.config.center) then
            BT.notice('That card changes individual run progression and is unavailable in co-op.'); return
        end
        if name=='use_card' then
            local card=e and e.config and e.config.ref_table
            local phase=BT.state.phase
            local between=phase=='prepare' or phase=='skipping' or phase=='shop'
            local tag_pack=card and card.from_tag and card.ability and card.ability.set=='Booster'
            local pack_card=G.booster_pack and G.pack_cards and card and card.area==G.pack_cards
            -- Native pack tags call use_card from their queued animation while
            -- the party is still preparing/skipping. Dropping that call consumes
            -- the tag and strands its materialized pack. Pack choices must also
            -- retain their native path until every player finishes their pack.
            if between and (tag_pack or pack_card) then
                if me() and me().ready then BT.client.action('ready',{ready=false}) end
                return ref(e,...)
            end
        end
        if B.pending_play then return end
        if BT.state.phase=='blind' then
            if BT.Session.Harbinger.blocks(BT.state) then return end
            if not BT.client.connected or not stable() or B.operation or (me() and me().exhausted) or BT.state.score>=BT.state.target then return end
            local validator=activity=='play' and G.FUNCS.can_play or activity=='discarding' and G.FUNCS.can_discard
            if validator then local check={config={}}; validator(check); if not check.config.button then return end end
            local args={...}; B.pending_play=true
            local run_id=BT.state.run_id
            BT.client.action('busy',{round=B.round},function(ok)
                B.pending_play=nil
                if not ok or BT.state.run_id~=run_id then return end
                B.operation=activity; B.operation_done=false
                if activity=='play' then
                    B.waiting_hand=false
                    B.hand=B.hand+1
                    B.last_hand=G.FUNCS.get_poker_hand_info(G.hand.highlighted)
                elseif event then BT.client.action('event',{event=event,text=event=='discard' and ('discarded '..#G.hand.highlighted..' cards') or 'used a consumable'}) end
                ref(e,unpack(args))
                if activity~='play' then G.E_MANAGER:add_event(Event({trigger='immediate',func=function() B.operation_done=true; return true end})) end
            end)
        else
            if BT.state.phase=='shop' and not (me() and me().ready) then
                local r=ref(e,...)
                if event then BT.client.action('event',{event=event,text='used a consumable'}) end
                return r
            end
        end
    end
end
function B.install()
    B.refs.start_run=G.FUNCS.start_run
    G.FUNCS.start_run=function(e,args)
        if BT.active() and not B.internal_start then return BT.client.restart() end
        return B.refs.start_run(e,args)
    end
    wrap_action('play_cards_from_highlighted','play')
    wrap_action('discard_cards_from_highlighted','discarding','discard')
    wrap_action('use_card','consumable','consumable')
    B.refs.hand_played=Game.update_hand_played
    function Game:update_hand_played(dt)
        if not active() then return B.refs.hand_played(self,dt) end
        if self.buttons then self.buttons:remove(); self.buttons=nil end
        if not G.STATE_COMPLETE then
            G.STATE_COMPLETE=true
            -- Match the native event-queue boundary: calculations and chip easing
            -- are queued ahead of this event, not finished when this method runs.
            G.E_MANAGER:add_event(Event({trigger='immediate',func=function()
                if B.capture_score()==false then return false end
                B.waiting_hand=true
                if BT.state.phase=='blind' and BT.state.score<BT.state.target and G.GAME.current_round.hands_left>0
                    and not (me() and me().exhausted) then
                    B.waiting_hand=false; G.STATE=G.STATES.DRAW_TO_HAND; G.STATE_COMPLETE=false
                end
                return true
            end}))
        end
    end
    B.refs.end_round=end_round
    function end_round(...)
        if not active() then return B.refs.end_round(...) end
        if BT.state.winner~=nil then
            if B.finished==B.round then return end
            B.finished=B.round; G.STATE=G.STATES.NEW_ROUND; G.STATE_COMPLETE=true
            return B.finish_round(...)
        end
        if not B.exhaustion_sent then
            B.exhaustion_sent=true; BT.client.action('idle',{round=B.round,exhausted=true})
        end
    end
    B.refs.select_blind=G.FUNCS.select_blind
    G.FUNCS.select_blind=function(e) if active() then return B.ready() else return B.refs.select_blind(e) end end
    local cash=G.FUNCS.cash_out
    if cash then G.FUNCS.cash_out=function(e,...)
        if active() then
            if BT.state.phase~='shop' or B.finished~=B.round or G.STATE~=G.STATES.ROUND_EVAL or not G.round_eval or B.cashout_requested==B.round then return end
            B.cashout_requested=B.round; B.evaluated_round=B.round
        end
        return cash(e,...)
    end end
    B.refs.skip_blind=G.FUNCS.skip_blind
    if B.refs.skip_blind then G.FUNCS.skip_blind=function(e,...)
        if active() then return B.vote_skip('yes') end;return B.refs.skip_blind(e,...)
    end end
    for _,name in ipairs({'reroll_boss','can_reroll_boss'}) do
        local ref=G.FUNCS[name]
        if ref then G.FUNCS[name]=function(e,...)
            if active() then if e and e.config then e.config.button=nil end; BT.notice('Co-op uses shared blinds; skips and boss rerolls are disabled.'); return end
            return ref(e,...)
        end end
    end
    local buy=G.FUNCS.buy_from_shop
    G.FUNCS.buy_from_shop=function(e,...)
        if active() then
            local c=e and e.config and e.config.ref_table
            local key=c and c.config and c.config.center and c.config.center.key
            if BT.compat and not BT.compat.allowed(c and c.config.center) then BT.notice('That progression effect is unavailable in co-op.'); return end
            if BT.state.phase~='shop' or (me() and me().ready) then return end
            local r=buy(e,...)
            if r~=false then G.E_MANAGER:add_event(Event({trigger='immediate',func=function()
                if c and c.from_area and c.area~=c.from_area then
                    BT.client.action('event',{event='purchase',text='purchased a '..(c.ability and c.ability.set or 'shop item')})
                end
                return true
            end})) end
            return r
        end
        return buy(e,...)
    end
    local go=G.FUNCS.go_to_menu;B.refs.go_to_menu=go
    G.FUNCS.go_to_menu=function(...) if BT.state then BT.client.stop() end; return go(...) end
end
function B.update(dt)
    if not BT.state or BT.state.phase=='lobby' then return end
    if BT.state.phase=='resuming' and BT.save then BT.save.restore_native();return end
    if not B.started or B.run_id~=BT.state.run_id then
        if not B.can_start_native() then return end
        B.reset(); B.run_id=BT.state.run_id
        B.started=true; BT.ui.screen=nil
        local deck=BT.state.deck or 'b_red'
        if not BT.Session.valid_deck(deck) or not G.P_CENTERS[deck] then BT.notice('Host selected an unavailable deck.'); return end
        G.GAME.viewed_back=Back(G.P_CENTERS[deck])
        B.internal_start=true
        B.refs.start_run(nil,BT.compat and BT.compat.prepare_run(deck,BT.state.seed) or {stake=1,seed=BT.state.seed})
        B.internal_start=false
        return
    end
    if not G.GAME or not G.GAME.current_round or G.STAGE~=G.STAGES.RUN then return end
    if BT.state.phase=='skipping' then
        local order=BT.state.skip_order;local position=B.position()
        if order and G.STATE==G.STATES.BLIND_SELECT and settled() then
            if position.ante==order.ante and position.index==order.index and B.skip_applied~=order.id then
                local option=G.blind_select_opts and G.blind_select_opts[order.index==1 and 'small' or 'big']
                if option and option:get_UIE_by_ID('tag_container') then
                    B.skip_applied=order.id;B.refs.skip_blind({UIBox=option,config={}})
                end
            elseif position.ante==order.ante and position.index==order.index+1 and not G.CONTROLLER.locks.skip_blind and not B.skip_pending and B.skip_ack~=order.id and BT.client.clock-B.skip_sent_at>0.5 then
                B.skip_pending=true;local data={order=order.id,ante=position.ante,index=position.index}
                B.skip_sent_at=BT.client.clock
                if not BT.client.action('skip_done',data,function(ok) B.skip_pending=nil;if ok then B.skip_ack=order.id end end) then B.skip_pending=nil end
            end
        end
    end
    -- The host explicitly selects each blind identity; seed agreement alone is not authority.
    if BT.state.phase=='prepare' and G.STATE==G.STATES.BLIND_SELECT and G.blind_select then
        if settled() and G.GAME.round_resets.ante~=BT.state.ante and B.mismatch~=BT.state.round then
            B.mismatch=BT.state.round; BT.notice('Party and native blinds are out of sync. The host must Fast Restart this run.')
        end
        if BT.client.model and not BT.state.proposal and settled() then
            local index=BT.state.blind_index
            local label=({'Small','Big','Boss'})[index]
            local key=G.GAME.round_resets.blind_choices[label]
            local blind=G.P_BLINDS[key]
            if blind and G.GAME.round_resets.ante==BT.state.ante then BT.client.propose{key=key,ante=B.position().ante,index=index,
                base=get_blind_amount(G.GAME.round_resets.ante)*blind.mult*G.GAME.starting_params.ante_scaling,
                name=blind.name,boss=blind.boss~=nil} end
        end
    end
    if BT.state.phase=='starting' and B.started_round<BT.state.round and G.STATE==G.STATES.BLIND_SELECT and G.blind_select and settled() then
        B.round=BT.state.round; B.started_round=B.round; B.hand=0; B.reported=0; B.lastchips=0;B.score_fault=nil
        B.exhaustion_sent=false; B.operation=nil
        local proposal=BT.state.proposal
        local label=({'Small','Big','Boss'})[proposal.index]
        -- Steamodded uses blind_on_deck and Current states to classify a blind.
        -- Canonicalize the slot before native queued construction can rebuild UI.
        for i,name in ipairs(labels) do G.GAME.round_resets.blind_states[name]=i<proposal.index and (G.GAME.round_resets.blind_states[name]=='Skipped' and 'Skipped' or 'Defeated') or i==proposal.index and 'Select' or 'Upcoming' end
        G.GAME.round_resets.blind_choices[label]=proposal.key; G.GAME.blind_on_deck=label
        B.refs.select_blind({config={ref_table=G.P_BLINDS[proposal.key]},UIBox=G.blind_select})
    end
    if BT.state.phase=='starting' and B.started_round==BT.state.round and not (me() and me().entered) and not B.entry_pending
        and BT.client.connected and BT.client.clock-B.entry_sent_at>0.5
        and G.STATE==G.STATES.SELECTING_HAND and #G.hand.cards>0 and settled() then
        local position=B.position(); position.key=G.GAME.blind.config.blind.key
        local round,run=B.round,BT.state.run_id
        B.entry_pending=round; B.entry_sent_at=BT.client.clock
        local sequence=BT.client.action('entered',position,function(ok)
            if not BT.state or BT.state.run_id~=run or B.round~=round then return end
            B.entry_pending=nil; if ok then B.entry_sent=round end
        end)
        if not sequence then B.entry_pending=nil end
    end
    -- Replace individual threshold with the team target for presentation and
    -- native one-shot checks, without replacing a player's own chips.
    if B.round==BT.state.round and BT.state.target>0 and G.GAME.blind then
        G.GAME.blind.chips=BT.state.target; G.GAME.blind.chip_text=number_format(BT.state.target)
    end
    if B.operation and B.operation~='play' and B.operation_done and G.STATE==G.STATES.SELECTING_HAND and stable()
        and not G.CONTROLLER.locks.discard and not G.CONTROLLER.locks.use then
        B.operation=nil; BT.client.action('idle',{round=B.round,exhausted=false})
    end
    if B.waiting_hand and not B.operation and BT.state.phase=='blind' and not BT.Session.Harbinger.blocks(BT.state)
        and BT.state.score<BT.state.target and G.GAME.current_round.hands_left>0 and G.STATE==G.STATES.HAND_PLAYED then
        B.waiting_hand=false;G.STATE=G.STATES.DRAW_TO_HAND;G.STATE_COMPLETE=false
    end
    if BT.state.winner~=nil and B.finished~=B.round and B.round>0 and not B.operation
        and (G.STATE==G.STATES.SELECTING_HAND or G.STATE==G.STATES.HAND_PLAYED or G.STATE==G.STATES.NEW_ROUND) then
        B.finished=B.round; G.STATE=G.STATES.NEW_ROUND; G.STATE_COMPLETE=true
        B.finish_round()
    end
    if BT.state.phase=='shop' and B.finished==B.round and G.STATE==G.STATES.ROUND_EVAL and settled() then B.evaluated_round=B.round end
    if BT.state.phase=='shop' then B.finish_shop(false) end
    if BT.client.connected and BT.client.clock-B.status_at>0.5 then
        B.status_at=BT.client.clock
        local s=status(); local encoded=BT.json.encode(s)
        if encoded~=B.laststatus then B.laststatus=encoded; BT.client.action('status',s) end
    end
end
return B
