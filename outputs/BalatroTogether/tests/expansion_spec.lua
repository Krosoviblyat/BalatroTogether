local S=dofile(ROOT..'/core/session.lua')
S.Pot=dofile(ROOT..'/core/pot.lua');S.Dice=dofile(ROOT..'/core/dice.lua')
S.Dice.Physics=dofile(ROOT..'/core/dice_physics.lua');S.Dice.Wheel=dofile(ROOT..'/core/boss_wheel.lua')
S.Dice.Boss=dofile(ROOT..'/core/boss_rewards.lua');S.Dice.QTE=dofile(ROOT..'/core/wheel_qte.lua')
local count=0;local function test(name,fn) fn();count=count+1;print('PASS '..name) end
local function room()
    local m=S.new{intended=2};m:join('Guest','guest');m.phase='prepare';m.run_id=1;m.now=0
    for _,p in pairs(m.players) do p.activity='waiting' end
    return m
end
local function act(m,id,kind,data) return m:apply(id,{seq=m.players[id].ack+1,run=m.run_id,kind=kind,data=data or {}}) end
local function bet(m,id,n,scope) return act(m,id,'pot_deposit',{tx=(m.players[id].pot_tx or 0)+1,amount=n,balance=100,scope=scope}) end
test('personal and team pots settle independently at 15 and 37.5 percent',function()
    local m=room();assert(bet(m,1,40,'team'));assert(bet(m,1,40,'personal'));assert(bet(m,2,20,'personal'))
    m.round=1;m.winner=true;S.Pot.settle(m)
    assert(m.pot.bank==55 and m.players[1].personal_pot.bank==46 and m.players[2].personal_pot.bank==23)
    S.Pot.settle(m);assert(m.pot.bank==55 and m.players[1].personal_pot.bank==46)
    assert(not m:snapshot(2).players['1'].personal_pot and m:snapshot(2).players['2'].personal_pot.bank==23)
end)
test('personal collection credits only its owner and cannot be replayed or targeted at teammates',function()
    local m=room();assert(bet(m,1,40,'personal'));assert(bet(m,2,20,'personal'));m.round=1;m.winner=true;S.Pot.settle(m)
    assert(act(m,2,'pot_claim',{target=1}));assert(m.players[2].pot_credit==23 and m.players[1].personal_pot.bank==46)
    assert(not act(m,2,'pot_claim'));assert(not act(m,2,'ready',{ready=true,round=1,ante=1,index=1}))
    assert(act(m,2,'pot_received',{total=23}));assert(act(m,1,'pot_claim'));assert(m.players[1].pot_credit==46)
end)
test('losses burn only current wagers and restart clears both pot scopes',function()
    local m=room();m.pot.bank=10;assert(bet(m,2,20,'personal'));m.players[2].personal_pot.bank=30
    m.round=1;m.winner=false;S.Pot.settle(m)
    assert(m.pot.bank==10 and m.players[2].personal_pot.bank==30 and m.players[2].personal_pot.wager==0)
    assert(m:restart('AGAIN'));assert(m.pot.bank==0 and not m.players[2].personal_pot)
end)
test('default party continues through ante eight and forty-eight blind completions',function()
    local m=room();assert(m.endless)
    for round=1,48 do
        assert(m:set_proposal(1,{ante=m.ante,index=m.blind_index,key='bl_small',base=300}))
        for _,p in pairs(m.players) do p.ready=true end;m:begin_blind()
        for _,p in pairs(m.players) do p.entered=true;p.contribution=1000 end;m:advance();m.score=2000;m:advance()
        assert(m.phase=='shop' and m.winner)
        for _,p in pairs(m.players) do p.ready=true;p.shop_done=m.round;p.dice_gold=0;p.dice_red=0;p.dice_boss=0 end
        m:next_blind()
    end
    assert(m.ante==17 and m.blind_index==1 and m.completed_antes==16)
end)
local function challenge()
    local m=room();m.players[1].dice_boss=1;S.Dice.random=function() return 1 end
    assert(act(m,1,'dice_roll',{tx=1,die='boss',challenge=true}));return m,m.dice.rolls['1']
end
test('winning Space challenge deterministically lands on jackpot and pays once',function()
    local m,r=challenge();assert(r.status=='challenge' and m.players[1].dice_boss==0)
    assert(not act(m,1,'dice_finish',{roll=r.id}))
    for tap=1,32 do m.now=tap*0.15;assert(act(m,1,'dice_qte_tap',{roll=r.id,tap=tap})) end
    assert(r.status=='rolling' and r.face==100 and r.force==100 and r.challenge.won)
    assert(S.Dice.Wheel.face(r.pose.angle)==100)
    assert(act(m,1,'dice_finish',{roll=r.id}));local money=m.players[1].dice_credit
    assert(money==100 and act(m,1,'dice_finish',{roll=r.id}) and m.players[1].dice_credit==money)
end)
test('missed challenge expires on the host and retains a normal wheel payout',function()
    local m,r=challenge();local expected=S.Dice.Wheel.spin(1).face;assert(expected~=100)
    S.Dice.QTE.tick(m,8.01);assert(r.status=='rolling' and r.face==expected and not r.force and not r.challenge.won)
    assert(act(m,1,'dice_finish',{roll=r.id}));assert(not m.players[1].dice_rolling)
end)
test('repeated, cross-seat and too-fast taps cannot manufacture a QTE win',function()
    local m,r=challenge();m.now=0.2;assert(act(m,1,'dice_qte_tap',{roll=r.id,tap=1}))
    assert(act(m,1,'dice_qte_tap',{roll=r.id,tap=1}));assert(r.challenge.hits==1)
    assert(not act(m,2,'dice_qte_tap',{roll=r.id,tap=2}))
    for tap=2,100 do assert(act(m,1,'dice_qte_tap',{roll=r.id,tap=tap})) end
    assert(r.challenge.hits<=6 and r.status=='challenge')
    m.players[1].ready=false;assert(not act(m,1,'ready',{ready=true,round=0,ante=1,index=1}))
    assert(not m:restart('AGAIN'));S.Dice.QTE.tick(m,9);assert(r.status=='rolling')
end)
test('forced jackpot spins retain ordinary wheel physics and correct final pointer across seeds',function()
    for seed=1,200 do local r=S.Dice.Wheel.spin(seed,100);assert(r.face==100 and r.settled and r.duration>5 and r.travel>6*math.pi*2) end
end)
test('Cryptid setup defaults and host choices exist before any native deck apply',function()
    G={SETTINGS={profile=1},PROFILES={{last_choices={cry_edeck_ed='e_holo'}}},P_CENTERS={b_cry_antimatter={name='Antimatter'}}}
    SMODS={RunSelect={Setup={choices={}},Pages={cry_antimatter={set_default=function() return {b_checkered=true} end},cry_edeck_ed={set_default=function(_,value) return value or 'e_foil' end}}}}
    BT={Session=S};local c=dofile(ROOT..'/game/compat.lua')
    local choices=c.run_choices('b_cry_antimatter');assert(choices.cry_antimatter.b_checkered and choices.cry_edeck_ed=='e_holo')
    BT.state={setup_choices=choices};G.PROFILES[1].last_choices={cry_edeck_ed='e_foil'}
    c.prepare_run('b_cry_antimatter','SEED');assert(SMODS.RunSelect.Setup.choices.cry_antimatter.b_checkered)
    assert(G.PROFILES[1].last_choices.cry_edeck_ed=='e_holo' and G.PROFILES[1].last_choices.seed=='SEED')
end)
print('TOTAL '..count..' EXPANSION TESTS PASSED')
