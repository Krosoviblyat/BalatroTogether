local P={counter=0,applied=0}
local function me() return BT.state and BT.state.players[tostring(BT.client.id)] end
local function stable()
    if not BT.active() or not BT.client.connected or not BT.game.started or not G.GAME or not G.HUD then return false end
    -- Native game-over/win menus pause the event queue. A completed results
    -- overlay can still receive its final credit without unpausing the game.
    local ended=(BT.state.phase=='victory' or BT.state.phase=='defeat') and G.STATE_COMPLETE
        and (G.STATE==G.STATES.GAME_OVER or G.STATE==G.STATES.ROUND_EVAL) and G.OVERLAY_MENU
    if ended then return true end
    if G.SETTINGS.paused or G.OVERLAY_MENU or G.CONTROLLER.lock_input or BT.game.operation or BT.game.pending_play
        or G.CONTROLLER.locks.use or G.CONTROLLER.locks.toggle_shop then return false end
    for _,e in ipairs(G.E_MANAGER.queues.base or {}) do if not e.complete and e.blocking~=false then return false end end
    return true
end
function P.busy()
    local p=me()
    return P.pending~=nil or (p and (p.pot_credit or 0)>(p.pot_received or 0)) or false
end
function P.available()
    local p=me()
    return stable() and (G.STATE==G.STATES.SHOP or G.STATE==G.STATES.BLIND_SELECT)
        and (BT.state.phase=='prepare' or BT.state.phase=='shop') and p and not p.ready and not p.busy
        and not p.transferring and not P.busy() and not BT.donation.busy()
        and not (BT.dice and BT.dice.busy())
        and (p.activity=='shopping' or p.activity=='blind_select' or p.activity=='waiting')
end
local function money(amount)
    -- instant=true changes dollars synchronously; never queue a replayable credit.
    -- Retain the native money HUD, unlock and statistic behaviour.
    local before=G.GAME.dollars
    local ok,err=pcall(ease_dollars,amount,true)
    if not ok and G.GAME.dollars==before then return nil,err end
    return G.GAME.dollars==before+amount
end
function P.deposit(amount,scope)
    scope=scope or 'team'
    if scope~='team' and scope~='personal' then return end
    if not P.available() then BT.notice('Stay unready in the shop or between blinds to bet.'); return end
    if type(amount)~='number' or amount%1~=0 or amount<1 or amount>BT.Session.Pot.MAX_BET or amount>G.GAME.dollars then BT.notice('Bet whole dollars you can afford.'); return end
    if P.counter>=BT.Session.Pot.MAX_TX then BT.notice('This run has reached its transaction limit.'); return end
    local balance=G.GAME.dollars
    if not money(-amount) then BT.notice('The bet could not be debited.'); return end
    P.counter=P.counter+1; P.pending={tx=P.counter,amount=amount,scope=scope}
    if not BT.client.action('pot_deposit',{tx=P.counter,amount=amount,balance=balance,scope=scope}) then
        money(amount); P.pending=nil; P.counter=P.counter-1
    end
end
function P.split()
    if P.busy() or BT.donation.busy() then BT.notice('Wait for your transfer to finish.'); return end
    BT.client.action('pot_split',{})
end
function P.claim()
    if P.busy() or BT.donation.busy() then BT.notice('Wait for your transfer to finish.');return end
    BT.client.action('pot_claim',{})
end
function P.reset() P.run=nil; P.pending=nil; P.counter=0; P.applied=0; P.ack_at=-10 end
local function notify(kind,amount)
    if BT.ui and BT.ui.pot_event then BT.ui.pot_event(kind,amount) end
end
function P.update(dt)
    P.clock=(P.clock or 0)+dt
    local p=me(); if not p or not BT.active() or not BT.game.started then return end
    if P.run~=BT.state.run_id then
        P.run=BT.state.run_id; P.pending=nil; P.counter=p.pot_tx or 0; P.applied=0; P.ack_at=-10
    end
    if P.pending then
        local r=p.pot_receipt
        if r and r.tx==P.pending.tx then
            if r.status=='rejected' then
                if not stable() or not money(P.pending.amount) then return end
                BT.notice(r.error or 'Bet returned.'); notify('refund',P.pending.amount)
            else BT.notice('Bet $'..P.pending.amount..' into the '..(P.pending.scope or 'team')..' pot.'); notify('deposit',P.pending.amount) end
            P.pending=nil
        end
        return
    end
    local total=p.pot_credit or 0
    if total>P.applied and stable() then
        local amount=total-P.applied
        if money(amount) then P.applied=total; BT.notice('Collected $'..amount..' in pot winnings.'); notify('payout',amount) end
    end
    if P.applied==total and total>(p.pot_received or 0) and BT.client.connected and P.clock-P.ack_at>0.5 then
        P.ack_at=P.clock; BT.client.action('pot_received',{total=total})
    end
end
function P.install()
    for _,name in ipairs({'buy_from_shop','sell_card','use_card','reroll_shop','toggle_shop','select_blind','play_cards_from_highlighted','discard_cards_from_highlighted'}) do
        local original=G.FUNCS[name]
        if original then G.FUNCS[name]=function(...)
            if P.busy() then BT.notice('Finishing the pot transfer...'); return end
            return original(...)
        end end
    end
end
P.settled=stable
P.change_money=money
return P
