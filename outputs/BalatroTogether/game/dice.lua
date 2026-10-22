local D={counter=0,applied=0,animations={},clock=0,ack_at=-10,finish_at=-10}
local function me() return BT.state and BT.state.players[tostring(BT.client.id)] end
function D.busy()
    local p=me()
    return D.pending~=nil or (p and BT.Session.Dice.pending(p)) or false
end
function D.available(kind)
    local p=me()
    local between=BT.pot.available() or ((kind=='gold' or kind=='boss') and BT.state and BT.state.phase=='victory' and BT.pot.settled()
        and p and not p.ready and not p.busy and not p.transferring and not BT.pot.busy() and not BT.donation.busy())
    return between and p and not D.busy() and (p['dice_'..(kind or 'gold')] or 0)>0
end
function D.roll(kind,challenge)
    if kind~='gold' and kind~='red' and kind~='boss' then return end
    if not D.available(kind) then BT.notice('Earn a wheel spin from boss wins, or a d6/d20 every two wins. Roll while unready.'); return end
    if D.counter>=BT.Session.Dice.MAX_TX then BT.notice('This run has reached its dice transaction limit.'); return end
    D.counter=D.counter+1; D.pending={tx=D.counter,die=kind}
    if not BT.client.action('dice_roll',{tx=D.counter,die=kind,challenge=challenge==true}) then D.pending=nil; D.counter=D.counter-1 end
end
function D.challenge()
    local s=BT.state;local r=s and s.dice and s.dice.rolls[tostring(BT.client.id)]
    return r and r.status=='challenge' and r or nil
end
function D.space(isrepeat)
    local r=D.challenge();if not r then return false end
    if isrepeat or D.space_down then return true end
    D.space_down=true
    if not BT.client.connected then return true end
    D.qte_press=(D.qte_id==r.id and D.qte_press or 0)+1;D.qte_id=r.id
    BT.client.action('dice_qte_tap',{roll=r.id,tap=D.qte_press})
    if BT.ui and BT.ui.qte_press then BT.ui.qte_press() end
    return true
end
function D.reset()
    D.run=nil; D.pending=nil; D.counter=0; D.applied=0; D.animations={}; D.ack_at=-10; D.finish_at=-10
    D.effect_applied=0; D.effect_steps={}; D.round_steps={}; D.effect_ack_at=-10
    D.space_down=false;D.qte_id=nil;D.qte_press=0
end
function D.apply_effects(p)
    local effects=p.dice_effects or {}
    if (D.effect_applied or 0)>=#effects or not BT.pot.settled() then return end
    local index=(D.effect_applied or 0)+1; local effect=effects[index]
    if effect.levels>0 and (not G.handlist or #G.handlist==0 or not G.GAME.hands) then return end
    local step=D.effect_steps[index] or {hands={}}; D.effect_steps[index]=step
    for _,name in ipairs(G.handlist or {}) do
        local hand=G.GAME.hands and G.GAME.hands[name]
        if hand and effect.levels>0 then
            step.hands[name]=step.hands[name] or hand.level+effect.levels
            local remaining=step.hands[name]-hand.level
            if remaining>0 then
                local ok=pcall(level_up_hand,nil,name,true,remaining)
                if not ok and hand.level<step.hands[name] then return end
            end
        end
    end
    if not step.rerolls then
        G.GAME.bt_boss_rerolls=(G.GAME.bt_boss_rerolls or 0)+effect.rerolls; step.rerolls=true
        if calculate_reroll_cost and G.GAME.current_round then calculate_reroll_cost(true) end
    end
    D.effect_applied=index
end
function D.apply_blind_bonus(p)
    local s=BT.state
    if not G.GAME.current_round or not G.STATES or G.STATE~=G.STATES.SELECTING_HAND or BT.game.round~=s.round
        or (s.phase~='starting' and s.phase~='blind') or not BT.pot.settled() then return end
    local step=D.round_steps[s.round] or {}; D.round_steps[s.round]=step
    for _,field in ipairs({'hands','discards'}) do
        local current=G.GAME.current_round[field..'_left']; local bonus=p['dice_active_'..field] or 0
        if not step[field] then step[field]=current+bonus end
        local remaining=step[field]-current
        if not step[field..'_done'] and remaining>0 then
            if field=='hands' then ease_hands_played(remaining,true) else ease_discard(remaining,true,true) end
        end
        step[field..'_done']=true
    end
end
local function reduced() return BT.config.reduced_motion or (BT.config.motion or 1)==0 end
function D.update(dt)
    D.clock=D.clock+dt
    local s=BT.state; local p=me()
    if not s or not p or not BT.active() or not BT.game.started then return end
    if D.run~=s.run_id then D.reset(); D.run=s.run_id; D.counter=p.dice_tx or 0 end
    for seat,roll in pairs(s.dice and s.dice.rolls or {}) do
        if roll.status=='challenge' then D.animations[seat]=nil
        else
        local a=D.animations[seat]
        if not a or a.id~=roll.id then
            local physics=roll.die=='boss' and BT.Session.Dice.Wheel.spin(roll.seed,roll.force) or BT.Session.Dice.Physics.simulate(roll.seed,true,roll.die)
            a={id=roll.id,elapsed=0,frames=physics.frames,frames2=physics.frames2,roll=roll,impacts=0}; D.animations[seat]=a
        end
        a.roll=roll; a.elapsed=math.min(roll.duration+1,a.elapsed+dt*(BT.config.motion or 1))
        if reduced() then a.elapsed=roll.duration+1 end
        a.pose=a.elapsed>=roll.duration and roll.pose or (roll.die=='boss' and BT.Session.Dice.Wheel.sample(roll,a.elapsed) or BT.Session.Dice.Physics.sample(a.frames,a.elapsed))
        if roll.pose2 then a.pose2=a.elapsed>=roll.duration and roll.pose2 or BT.Session.Dice.Physics.sample(a.frames2,a.elapsed) end
        if a.pose.impacts>a.impacts then
            a.impacts=a.pose.impacts
            if BT.ui and BT.ui.screen=='dice' and BT.config.sounds and not reduced() then pcall(play_sound,'card1',roll.die=='boss' and 1.5 or 0.75+math.min(0.65,a.impacts*0.025),roll.die=='boss' and 0.10 or 0.18) end
        end
        end
    end
    local pending=D.pending
    if pending then
        local receipt=p.dice_receipt
        if receipt and receipt.tx==pending.tx then
            if receipt.status=='rejected' then D.pending=nil; BT.notice(receipt.error or 'Roll rejected.'); return end
            local a=D.animations[tostring(BT.client.id)]
            if receipt.status=='challenge' then
                local roll=s.dice.rolls[tostring(BT.client.id)]
                if roll and D.qte_id~=roll.id then D.qte_id=roll.id;D.qte_press=roll.challenge.taps or 0 end
            elseif receipt.status=='rolling' and a and a.id==receipt.roll and a.elapsed>=a.roll.duration+0.3
                and BT.client.connected and D.clock-D.finish_at>0.5 then
                D.finish_at=D.clock; BT.client.action('dice_finish',{roll=receipt.roll})
            elseif receipt.status=='settled' then D.pending=nil end
        end
    end
    local total=p.dice_credit or 0
    if total>D.applied and BT.pot.settled() then
        local amount=total-D.applied
        if BT.pot.change_money(amount) then D.applied=total; BT.notice('Reward dice awarded $'..amount..'.') end
    end
    if D.applied==total and total>(p.dice_received or 0) and BT.client.connected and D.clock-D.ack_at>0.5 then
        D.ack_at=D.clock; BT.client.action('dice_received',{total=total})
    end
    D.apply_effects(p)
    if D.effect_applied==#(p.dice_effects or {}) and D.effect_applied>(p.dice_effect_received or 0)
        and BT.client.connected and D.clock-D.effect_ack_at>0.5 then
        D.effect_ack_at=D.clock; BT.client.action('dice_effects_received',{total=D.effect_applied})
    end
    D.apply_blind_bonus(p)
end
function D.bonus(field)
    local p=me()
    return BT.active() and BT.state.phase=='blind' and BT.game.round==BT.state.round and p and (p[field=='chips' and 'dice_active_chips' or 'dice_active_mult'] or 0) or 0
end
function D.install()
    for _,name in ipairs({'buy_from_shop','sell_card','use_card','reroll_shop','toggle_shop','select_blind','play_cards_from_highlighted','discard_cards_from_highlighted'}) do
        local original=G.FUNCS[name]
        if original then G.FUNCS[name]=function(...)
            if D.busy() then BT.notice('Finishing your reward die...'); return end
            return original(...)
        end end
    end
    local original=Blind.modify_hand
    function Blind:modify_hand(cards,poker,text,mult,chips,...)
        local bonus=D.bonus()
        local extra_chips=D.bonus('chips')
        local m,c,changed=original(self,cards,poker,text,mult+bonus,chips+extra_chips,...)
        return m,c,changed or bonus>0 or extra_chips>0
    end
    local calculate=calculate_reroll_cost
    if calculate then function calculate_reroll_cost(...)
        local result=calculate(...)
        if BT.active() and (G.GAME.bt_boss_rerolls or 0)>0 then G.GAME.current_round.reroll_cost=0 end
        return result
    end end
    local reroll=G.FUNCS.reroll_shop
    if reroll then G.FUNCS.reroll_shop=function(...)
        if BT.active() and (G.GAME.bt_boss_rerolls or 0)>0 then
            local p=me()
            if D.busy() or BT.pot.busy() or BT.donation.busy() or not BT.pot.settled() or not G.shop or G.STATE~=G.STATES.SHOP
                or not p or p.ready or G.CONTROLLER.locks.shop_reroll then return end
            if G.GAME.current_round.free_rerolls<=0 then
                G.GAME.bt_boss_rerolls=G.GAME.bt_boss_rerolls-1
                G.GAME.current_round.free_rerolls=G.GAME.current_round.free_rerolls+1
                calculate_reroll_cost(true)
            end
        end
        return reroll(...)
    end end
end
return D
