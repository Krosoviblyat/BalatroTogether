-- Free personal reward dice. Host physics determines the upward face.
local D={MAX_TX=4096,GOLD_PER_PIP=5,random=math.random}
function D.empty() return {wins=0,reward_round=0,counter=0,rolls={}} end
function D.pending(p) return p.dice_rolling or (p.dice_credit or 0)>(p.dice_received or 0)
    or #(p.dice_effects or {})>(p.dice_effect_received or 0) end
local function integer(n,lo,hi) return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi end
function D.reward(m)
    if not m.winner or m.dice.reward_round>=m.round then return end
    m.dice.reward_round=m.round
    m.dice.wins=m.dice.wins+1
    if m.blind_index==3 then
        for _,p in pairs(m.players) do if not p.withdrawn then p.dice_boss=(p.dice_boss or 0)+1 end end
        m:event(1,'dice','BOSS CONQUERED / WHEEL SPIN FOR EVERYONE')
    end
    if m.dice.wins%2~=0 then return end
    for _,p in pairs(m.players) do if not p.withdrawn then p.dice_gold=(p.dice_gold or 0)+1; p.dice_red=(p.dice_red or 0)+1 end end
    m:event(1,'dice','TWO BLINDS WON / GOLD D6 + RED D20 FOR EVERYONE')
end
function D.apply(m,id,kind,d)
    local p=m.players[id]
    if kind=='dice_roll' then
        if not integer(d.tx,1,D.MAX_TX) then return nil,'Invalid dice transaction.' end
        if d.tx<=(p.dice_tx or 0) then return true,'duplicate' end
        if d.tx~=(p.dice_tx or 0)+1 then return nil,'Missing dice transaction.' end
        p.dice_tx=d.tx
        local error
        if d.die~='gold' and d.die~='red' and d.die~='boss' then error='Choose a gold d6, red d20 or boss wheel.'
        elseif d.challenge and (d.die~='boss' or not D.QTE) then error='The challenge requires a boss wheel spin.'
        elseif (m.phase~='prepare' and m.phase~='shop' and not (m.phase=='victory' and d.die~='red')) or p.ready or p.busy or p.transferring or D.pending(p)
            or (m.Pot and m.Pot.pending(p)) then error='Stay unready between blinds or in the shop to roll.'
        elseif (p['dice_'..d.die] or 0)<1 then error=d.die=='boss' and 'Win a boss blind to earn a wheel spin.' or 'Win two team blinds to earn more dice.' end
        local result,seed
        if not error then
            for _=1,8 do
                seed=D.random(1,2147483646)
                if d.die=='boss' then result=D.Wheel.spin(seed)
                else result=D.Physics.simulate(seed,false,d.die) end
                if result.settled then break end
            end
            if not result or not result.settled then error='The die did not settle flat. Your reward die is kept.' end
        end
        p.dice_receipt={tx=d.tx,status=error and 'rejected' or 'rolling',error=error}
        if error then return nil,error end
        m.dice.counter=m.dice.counter+1
        local roll={id=m.run_id..':'..m.dice.counter,seat=id,tx=d.tx,round=m.round+1,seed=seed,die=d.die,
            face=result.face,payout=d.die=='gold' and result.face*D.GOLD_PER_PIP or 0,
            duration=result.duration,pose=result.pose,status='rolling',start=result.start,travel=result.travel}
        if d.die=='boss' then roll.reward=D.Boss.get(result.face); roll.payout=roll.reward.money or 0 end
        p['dice_'..d.die]=p['dice_'..d.die]-1
        m.dice.rolls[tostring(id)]=roll; p.dice_rolling=true; p.dice_receipt.roll=roll.id
        if d.challenge then D.QTE.begin(m,roll);p.dice_receipt.status='challenge' end
        m:event(id,'dice','used a '..(d.die=='gold' and 'GOLD D6' or d.die=='red' and 'RED D20' or 'BOSS WHEEL'))
        return true
    elseif kind=='dice_qte_tap' then
        if not D.QTE then return nil,'Wheel challenge unavailable.' end
        return D.QTE.tap(m,id,d)
    elseif kind=='dice_finish' then
        local roll=m.dice.rolls[tostring(id)]
        if not roll or d.roll~=roll.id then return nil,'Stale dice result.' end
        if roll.status=='challenge' then return nil,'Finish the Space challenge first.' end
        if roll.status=='settled' then return true,'duplicate' end
        roll.status='settled'; p.dice_rolling=false
        if roll.die=='gold' then p.dice_credit=(p.dice_credit or 0)+roll.payout
        elseif roll.die=='red' then p.dice_next_mult=(p.dice_next_mult or 0)+roll.face
        else
            local r=roll.reward; p.dice_credit=(p.dice_credit or 0)+(r.money or 0)
            for _,field in ipairs({'hands','discards','chips','mult'}) do p['dice_next_'..field]=(p['dice_next_'..field] or 0)+(r[field] or 0) end
            if r.levels or r.rerolls then
                p.dice_effects=p.dice_effects or {}
                p.dice_effects[#p.dice_effects+1]={id=roll.id,levels=r.levels or 0,rerolls=r.rerolls or 0}
            end
        end
        p.dice_receipt={tx=roll.tx,status='settled',roll=roll.id}
        m:event(id,'dice',roll.die=='gold' and ('GOLD '..roll.face..' / +$'..roll.payout) or roll.die=='red' and ('D20 '..roll.face..' / +'..roll.face..' MULT NEXT BLIND') or ('WHEEL '..roll.face..' / '..roll.reward.name))
        return true
    elseif kind=='dice_effects_received' then
        if not integer(d.total,0,D.MAX_TX) or d.total~=#(p.dice_effects or {}) then return nil,'Stale boss reward receipt.' end
        p.dice_effect_received=d.total; return true
    elseif kind=='dice_received' then
        if not integer(d.total,0,1000000) or d.total~=(p.dice_credit or 0) then return nil,'Stale dice payout receipt.' end
        p.dice_received=d.total; return true
    end
    return nil,'Unknown dice action.'
end
return D
