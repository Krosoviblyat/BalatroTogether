local S=dofile(ROOT..'/core/session.lua'); S.Pot=dofile(ROOT..'/core/pot.lua'); S.Dice=dofile(ROOT..'/core/dice.lua'); S.Dice.Physics=dofile(ROOT..'/core/dice_physics.lua')
S.Dice.Wheel=dofile(ROOT..'/core/boss_wheel.lua')
S.Dice.Boss=dofile(ROOT..'/core/boss_rewards.lua')
local H=S.Dice.Physics; local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function new()
    local m=S.new{intended=2}; m:join('Guest','guest'); m.phase='shop'; m.run_id=1
    for _,p in pairs(m.players) do p.activity='shopping' end
    S.Dice.random=function() return 74743 end
    return m
end
local function act(m,id,kind,data) return m:apply(id,{seq=m.players[id].ack+1,run=m.run_id,kind=kind,data=data or {}}) end
local function roll(m,id,kind) return act(m,id,'dice_roll',{tx=(m.players[id].dice_tx or 0)+1,die=kind}) end
local function finish(m,id) return act(m,id,'dice_finish',{roll=m.dice.rolls[tostring(id)].id}) end
test('two won blinds award each player one gold d6 and red d20 exactly once',function()
    local m=new(); m.winner=true; m.round=1; S.Dice.reward(m); assert(m.dice.wins==1 and not m.players[1].dice_gold)
    S.Dice.reward(m); assert(m.dice.wins==1)
    m.round=2; S.Dice.reward(m); for _,p in pairs(m.players) do assert(p.dice_gold==1 and p.dice_red==1) end
    m.round=3; m.winner=false; S.Dice.reward(m); assert(m.dice.wins==2)
end)
test('a gold reward consumes one owned die and credits five dollars per upward pip',function()
    local m=new(); m.players[2].dice_gold=2; assert(roll(m,2,'gold')); local r=m.dice.rolls['2']
    assert(m.players[2].dice_gold==1 and r.face==H.face(r.pose.q,'gold') and not m.players[2].dice_credit)
    assert(finish(m,2)); assert(m.players[2].dice_credit==r.face*5)
    assert(finish(m,2)); assert(m.players[2].dice_credit==r.face*5)
end)
test('a red d20 grants its face as next-blind Mult without affecting money or the pot',function()
    local m=new(); m.players[1].dice_red=2; assert(roll(m,1,'red')); local face=m.dice.rolls['1'].face; assert(finish(m,1))
    assert(m.players[1].dice_next_mult==face and not m.players[1].dice_credit and m.pot.bank==0)
    assert(roll(m,1,'red')); assert(finish(m,1)); assert(m.players[1].dice_next_mult==face*2)
end)
test('earned Mult activates once at blind start and expires at the following blind',function()
    local m=new(); m.phase='prepare'; m.players[1].dice_next_mult=13
    m.proposal={base=100}; for _,p in pairs(m.players) do p.ready=true end
    m:begin_blind(); assert(m.players[1].dice_active_mult==13 and m.players[1].dice_next_mult==0)
    m.phase='prepare'; for _,p in pairs(m.players) do p.ready=true end; m:begin_blind(); assert(m.players[1].dice_active_mult==0)
end)
test('replayed roll actions and transaction IDs cannot spend another die or grant another reward',function()
    local m=new(); m.players[1].dice_gold=2; assert(roll(m,1,'gold')); local ack=m.players[1].ack
    assert(m:apply(1,{seq=ack,run=1,kind='dice_roll',data={tx=1,die='gold'}})); assert(act(m,1,'dice_roll',{tx=1,die='gold'}))
    assert(m.players[1].dice_gold==1 and m.dice.counter==1)
end)
test('unearned, invalid, ready and mid-hand reward rolls are refused without spending dice',function()
    local m=new(); assert(not roll(m,1,'gold')); m.players[1].dice_red=1; m.players[1].ready=true
    assert(not roll(m,1,'red')); m.players[1].ready=false; m.phase='blind'; assert(not roll(m,1,'red'))
    m.phase='shop'; assert(not roll(m,1,'invalid')); assert(m.players[1].dice_red==1)
end)
test('a resolving die and undelivered gold payout hold ready and restart barriers',function()
    local m=new(); m.players[2].dice_gold=1; assert(roll(m,2,'gold')); assert(not act(m,2,'ready',{ready=true})); assert(not m:restart('NEW'))
    assert(finish(m,2)); assert(not m:restart('NEW')); assert(act(m,2,'dice_received',{total=m.players[2].dice_credit})); assert(m:restart('NEW'))
    assert(m.dice.wins==0 and not m.players[2].dice_gold and not m.players[2].dice_next_mult)
end)
test('reconnect retains the same rolling die and credits only its original seat',function()
    local m=new(); m.players[2].dice_gold=1; assert(roll(m,2,'gold')); local r=m.dice.rolls['2']; m:disconnect(2); assert(m:reconnect('guest')==2)
    assert(m.dice.rolls['2'].id==r.id); assert(not act(m,1,'dice_finish',{roll=r.id})); assert(finish(m,2))
    assert(m.players[2].dice_credit==r.payout and not m.players[1].dice_credit)
end)
test('unsettled physical throws retry within a fixed bound and preserve the owned die',function()
    local m=new(); m.players[1].dice_gold=1; local simulate=H.simulate; local attempts=0
    H.simulate=function() attempts=attempts+1; return {settled=false} end
    assert(not roll(m,1,'gold')); assert(attempts==8 and m.players[1].dice_gold==1 and not m.players[1].dice_rolling)
    H.simulate=simulate
end)
test('d6 and d20 physics replay exactly with bounded poses and produce their resting top face',function()
    assert(#H.shapes.red.faces==20 and #H.shapes.red.vertices==12)
    for _,kind in ipairs({'gold','red'}) do
        local seen={}; local failed=0
        for i=1,240 do
            local r=H.simulate(i*74743,true,kind)
            if not r.settled then failed=failed+1 else
                assert(r.face>=1 and r.face<=(kind=='gold' and 6 or 20)); seen[r.face]=true
                local v,up=H.face(r.pose.q,kind); assert(v==r.face and up>0.998)
                local first=H.sample(r.frames,0); local last=H.sample(r.frames,r.duration+1)
                assert(first.z>3 and math.abs(last.x-r.pose.x)<0.00001 and math.abs(last.y-r.pose.y)<0.00001)
                local other=H.simulate(i*74743,false,kind); assert(other.face==r.face and other.pose.q[1]==r.pose.q[1])
                assert(math.abs(r.pose.x)<H.LENGTH and math.abs(r.pose.y)<H.WIDTH and r.duration<=10 and r.impacts>0)
            end
        end
        local n=0; for _ in pairs(seen) do n=n+1 end
        assert(n==(kind=='gold' and 6 or 20) and failed<12)
    end
end)
test('every boss wheel face maps to one positive bounded reward and returned rewards are copies',function()
    local B=S.Dice.Boss; assert(#B.tiers==21)
    for face=1,100 do
        local r=B.get(face); local total=0
        for _,key in ipairs({'money','rerolls','levels','hands','discards','chips','mult'}) do
            local n=r[key] or 0; assert(n>=0 and n%1==0); total=total+n
        end
        assert(total>0 and #B.describe(r)>0); r.name='mutated'; assert(B.get(face).name~='mutated')
    end
    assert(not B.get(0) and not B.get(101) and not B.get(1.5) and not B.get('100'))
end)
test('boss wins award a personal wheel spin independently of the two-win pair and never on a loss',function()
    local m=new(); m.winner=true; m.round=1; m.blind_index=1; S.Dice.reward(m); assert(not m.players[1].dice_boss)
    m.round=2; m.blind_index=2; S.Dice.reward(m); assert(m.players[1].dice_gold==1 and not m.players[1].dice_boss)
    m.round=3; m.blind_index=3; S.Dice.reward(m); S.Dice.reward(m)
    assert(m.players[1].dice_boss==1 and m.players[2].dice_boss==1 and m.players[1].dice_gold==1)
    m.round=6; m.winner=false; S.Dice.reward(m); assert(m.players[1].dice_boss==1)
end)
test('wheel replay slows to rest and its pointer selects all 100 positive slots',function()
    local W=S.Dice.Wheel; local seen={}
    for seed=1,1600 do
        local r=W.spin(seed*74743); seen[r.face]=true; assert(r.face==W.face(r.pose.angle))
        local a=W.sample(r,0); local b=W.sample(r,1); local c=W.sample(r,2); local d=W.sample(r,3)
        assert(b.angle>a.angle and b.angle-a.angle>c.angle-b.angle and c.angle-b.angle>d.angle-c.angle)
        assert(W.sample(r,r.duration+1).angle==r.pose.angle and r.duration<7)
        assert(W.spin(seed*74743).face==r.face)
    end
    for face=1,100 do assert(seen[face]) end
end)
test('boss jackpot delivers all effects once to its owner and blocks progress until native effects arrive',function()
    local m=new(); m.players[2].dice_boss=1; S.Dice.random=function() return 147 end
    assert(roll(m,2,'boss')); local r=m.dice.rolls['2']; assert(r.face==100 and r.start and r.travel and m.players[2].dice_boss==0)
    assert(not act(m,1,'dice_finish',{roll=r.id})); assert(finish(m,2)); assert(finish(m,2))
    local p=m.players[2]; assert(p.dice_credit==100 and p.dice_next_mult==100 and p.dice_next_chips==400)
    assert(p.dice_next_hands==3 and p.dice_next_discards==3 and #p.dice_effects==1)
    assert(p.dice_effects[1].levels==3 and p.dice_effects[1].rerolls==6 and not m.players[1].dice_credit)
    assert(act(m,2,'dice_received',{total=100})); assert(not m:restart('NEW'))
    assert(not act(m,2,'dice_effects_received',{total=99})); assert(act(m,2,'dice_effects_received',{total=1})); assert(m:restart('NEW'))
end)
test('all temporary boss wheel effects activate together and expire at the next blind',function()
    local m=new(); m.phase='prepare'; m.proposal={base=100}
    for _,k in ipairs({'hands','discards','chips','mult'}) do m.players[1]['dice_next_'..k]=3 end
    for _,p in pairs(m.players) do p.ready=true end; m:begin_blind()
    for _,k in ipairs({'hands','discards','chips','mult'}) do assert(m.players[1]['dice_active_'..k]==3 and m.players[1]['dice_next_'..k]==0) end
    m.phase='prepare'; for _,p in pairs(m.players) do p.ready=true end; m:begin_blind()
    for _,k in ipairs({'hands','discards','chips','mult'}) do assert(m.players[1]['dice_active_'..k]==0) end
end)
print('TOTAL '..count..' REWARD DICE/PHYSICS TESTS PASSED')
