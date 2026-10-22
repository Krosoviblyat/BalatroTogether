-- Fictional Balatro dollars only. Authoritative, bounded, replay-safe ledger.
local P={MAX_BET=10000,MAX_VOLUME=800000,MAX_TX=4096,MAX_CREDIT=4000000,TEAM_BONUS=0.375,PERSONAL_BONUS=0.15}
function P.empty() return {bank=0,wager=0,bets={},volume=0,settled=0,last=nil,splits=0} end
local function integer(n,lo,hi) return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi end
function P.pending(p) return (p.pot_credit or 0)>(p.pot_received or 0) end
local function between(m,p)
    return (m.phase=='prepare' or m.phase=='shop') and not p.ready and not p.busy and not p.transferring
        and not P.pending(p) and (p.activity=='shopping' or p.activity=='blind_select' or p.activity=='waiting')
        and not (m.Dice and m.Dice.pending(p))
end
function P.apply(m,id,kind,d)
    local p=m.players[id]; local pot=m.pot
    if kind=='pot_deposit' then
        if not integer(d.tx,1,P.MAX_TX) then return nil,'Invalid bet transaction.' end
        if d.tx<=(p.pot_tx or 0) then return true,'duplicate' end
        if d.tx~=(p.pot_tx or 0)+1 then return nil,'Missing bet transaction.' end
        p.pot_tx=d.tx
        local scope=d.scope or 'team'
        if scope=='personal' then p.personal_pot=p.personal_pot or P.empty();pot=p.personal_pot end
        local err
        if scope~='team' and scope~='personal' then err='Choose team or personal betting.'
        elseif not between(m,p) then err='Stay unready between blinds or in the shop to bet.'
        elseif not integer(d.amount,1,P.MAX_BET) or not (m.Numbers and m.Numbers.finite(d.balance) or type(d.balance)=='number' and d.balance==d.balance and math.abs(d.balance)<=1e9)
            or d.balance<d.amount then err='Bet whole dollars you can afford.'
        elseif pot.volume+d.amount>P.MAX_VOLUME then err='This run has reached its bet limit.' end
        p.pot_receipt={tx=d.tx,status=err and 'rejected' or 'deposited',error=err,scope=scope}
        if err then return nil,err end
        pot.volume=pot.volume+d.amount; pot.wager=pot.wager+d.amount
        pot.bets[tostring(id)]=(pot.bets[tostring(id)] or 0)+d.amount
        m:event(id,'pot','bet $'..d.amount..' into the '..scope..' pot')
        return true
    elseif kind=='pot_claim' then
        local own=p.personal_pot
        if m.phase~='prepare' and m.phase~='shop' and m.phase~='victory' and m.phase~='defeat' then return nil,'Collect between blinds.' end
        if p.busy or p.transferring or P.pending(p) or (m.Dice and m.Dice.pending(p)) then return nil,'Finish your transfer first.' end
        if not own or own.bank<1 then return nil,'Your personal pot has no saved winnings.' end
        local amount=own.bank;own.bank=0;own.splits=own.splits+1
        p.pot_credit=(p.pot_credit or 0)+amount;p.ready=false
        m:event(id,'pot','collected $'..amount..' from their personal pot');return true
    elseif kind=='pot_split' then
        if id~=1 then return nil,'Only the host can split the pot.' end
        if m.phase~='prepare' and m.phase~='shop' and m.phase~='victory' and m.phase~='defeat' then return nil,'Split winnings between blinds.' end
        if not m:all(function(q) return not q.transferring and not P.pending(q) and not (m.Dice and m.Dice.pending(q)) end) then return nil,'Wait for all transfers to finish.' end
        local seats={}
        for i=1,4 do local q=m.players[i]; if q and q.connected and not q.withdrawn then seats[#seats+1]=q end end
        local share=#seats>0 and math.floor(pot.bank/#seats) or 0
        if share<1 then return nil,'The pot needs at least $1 per connected player.' end
        pot.bank=pot.bank-share*#seats; pot.splits=pot.splits+1
        for _,q in ipairs(seats) do q.pot_credit=(q.pot_credit or 0)+share; q.ready=false end
        m:event(id,'pot','split $'..share..' each among '..#seats..' players')
        return true
    elseif kind=='pot_received' then
        if not integer(d.total,0,P.MAX_CREDIT) or d.total~=(p.pot_credit or 0) then return nil,'Stale pot payout receipt.' end
        p.pot_received=d.total; return true
    end
    return nil,'Unknown pot action.'
end
function P.settle(m)
    local function settle(pot,rate,id,scope)
        if not pot or pot.settled>=m.round then return end
        pot.settled=m.round
        local stake=pot.wager; local bonus=m.winner and math.floor(stake*rate) or 0
        if m.winner then pot.bank=pot.bank+stake+bonus end
        pot.last={round=m.round,won=m.winner==true,stake=stake,bonus=bonus,returned=m.winner and stake+bonus or 0}
        pot.wager=0;pot.bets={}
        if stake>0 then m:event(id,'pot',scope..(m.winner and (' won: $'..stake..' + $'..bonus..' bonus saved') or (' lost $'..stake))) end
    end
    settle(m.pot,P.TEAM_BONUS,1,'TEAM POT')
    for id,p in pairs(m.players) do settle(p.personal_pot,P.PERSONAL_BONUS,id,'PERSONAL POT') end
end
return P
