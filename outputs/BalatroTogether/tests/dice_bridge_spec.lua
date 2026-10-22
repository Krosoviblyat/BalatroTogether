local S=dofile(ROOT..'/core/session.lua'); S.Dice=dofile(ROOT..'/core/dice.lua'); S.Dice.Physics=dofile(ROOT..'/core/dice_physics.lua')
local m,D,hold,changes
local function setup()
    m=S.new{intended=1}; m.phase='shop'; m.run_id=1; m.players[1].activity='shopping'; m.players[1].dice_gold=1; m.players[1].dice_red=1
    S.Dice.random=function() return 74743 end
    changes={}; hold=false; G={GAME={dollars=4},FUNCS={buy_from_shop=function() return true end}}
    BT={Session=S,state=m:snapshot(),active=function() return true end,config={motion=1,reduced_motion=false,sounds=false},game={started=true,round=0},ui={},donation={busy=function() return false end},notice=function() end}
    BT.pot={available=function() return true end,busy=function() return false end,settled=function() return true end,
        change_money=function(amount) G.GAME.dollars=G.GAME.dollars+amount; changes[#changes+1]=amount; return true end}
    BT.client={id=1,connected=true,action=function(kind,data)
        if not BT.client.connected or (hold and kind=='dice_received') then return end
        m:apply(1,{seq=m.players[1].ack+1,run=m.run_id,kind=kind,data=data}); BT.state=m:snapshot(); return m.players[1].ack
    end}
    Blind={modify_hand=function(self,cards,poker,text,mult,chips) return mult,chips,false end}
    D=dofile(ROOT..'/game/dice.lua'); BT.dice=D; D.install(); D.update(.01)
end
local count=0; local function test(name,fn) setup(); fn(); count=count+1; print('PASS '..name) end
local function tick(n) for _=1,n or 100 do D.update(.1) end end
test('free gold die animates before granting its native dollars exactly once despite delayed receipts',function()
    D.roll('gold'); assert(G.GAME.dollars==4 and D.busy()); hold=true; tick()
    local payout=m.dice.rolls['1'].payout; assert(G.GAME.dollars==4+payout and #changes==1 and D.busy())
    tick(); assert(#changes==1); hold=false; tick(); assert(not D.busy() and #changes==1)
end)
test('reduced motion resolves the same physical face without movement or lost rewards',function()
    BT.config.reduced_motion=true; D.roll('red'); tick(4)
    local r=m.dice.rolls['1']; assert(r.status=='settled' and m.players[1].dice_next_mult==r.face and #changes==0 and not D.busy())
end)
test('a temporary disconnect during the roll delays completion and native spending until reconnect',function()
    D.roll('gold'); BT.client.connected=false; tick(); assert(G.GAME.dollars==4 and G.FUNCS.buy_from_shop()==nil)
    BT.client.connected=true; tick(); assert(G.GAME.dollars>4 and G.FUNCS.buy_from_shop()==true)
end)
test('the native Mult hook adds the reward before blind modifiers and stops outside the rewarded blind',function()
    m.phase='blind'; m.players[1].dice_active_mult=13; BT.state=m:snapshot(); BT.game.round=m.round
    local mult,chips,changed=Blind.modify_hand({},nil,nil,'High Card',2,5); assert(mult==15 and chips==5 and changed)
    BT.state.phase='shop'; mult=Blind.modify_hand({},nil,nil,'High Card',2,5); assert(mult==2)
    BT.state.phase='blind'; BT.game.round=999; mult=Blind.modify_hand({},nil,nil,'High Card',2,5); assert(mult==2)
end)
test('a fresh party run clears old animation, delivery and Mult state',function()
    D.roll('gold'); assert(m:restart('NEW')==nil); tick(); assert(m:restart('NEW')); BT.state=m:snapshot(); G.GAME.dollars=4; D.update(1)
    assert(not D.busy() and next(D.animations)==nil and G.GAME.dollars==4 and D.bonus()==0)
end)
test('d20 number textures and meshes tolerate the Steamodded nil-backbuffer query',function()
    local H=S.Dice.Physics; local calls=0
    local noop=function() end
    local g=setmetatable({getCanvas=function() error('loader nil backbuffer') end,
        newCanvas=function() return {} end,newFont=function() return {} end,
        newMesh=function() return {setTexture=noop,setVertices=noop} end,
        draw=function() calls=calls+1 end},{__index=function() return noop end})
    local R=dofile(ROOT..'/ui/dice_renderer.lua')(H,g,noop)
    R.warm(); local r=H.simulate(74743,false,'red'); R.die(r.pose,'red',425,478,48)
    assert(calls>0)
end)
test('boss hand upgrades survive partial native delivery and never duplicate banked refreshes',function()
    G.handlist={'Pair','High Card'}; G.GAME.hands={Pair={level=1},['High Card']={level=1}}
    local fail=true
    level_up_hand=function(_,name,_,n) if name=='High Card' and fail then error('transient') end; G.GAME.hands[name].level=G.GAME.hands[name].level+n end
    local p={dice_effects={{levels=3,rerolls=6}}}; D.apply_effects(p)
    assert(G.GAME.hands.Pair.level==4 and G.GAME.hands['High Card'].level==1 and not G.GAME.bt_boss_rerolls)
    fail=false; D.apply_effects(p); D.apply_effects(p)
    assert(G.GAME.hands.Pair.level==4 and G.GAME.hands['High Card'].level==4 and G.GAME.bt_boss_rerolls==6)
end)
test('boss hand and discard bonuses apply once per blind while scoring adds chips and Mult',function()
    G.STATES={SELECTING_HAND=1}; G.STATE=1; G.GAME.current_round={hands_left=5,discards_left=3}
    ease_hands_played=function(n) G.GAME.current_round.hands_left=G.GAME.current_round.hands_left+n end
    ease_discard=function(n) G.GAME.current_round.discards_left=G.GAME.current_round.discards_left+n end
    m.phase='blind'; local p=m.players[1]; p.dice_active_hands=3; p.dice_active_discards=3; p.dice_active_chips=400; p.dice_active_mult=100
    BT.state=m:snapshot(); BT.game.round=m.round
    D.apply_blind_bonus(p); D.apply_blind_bonus(p); assert(G.GAME.current_round.hands_left==8 and G.GAME.current_round.discards_left==6)
    local mult,chips=Blind.modify_hand({},nil,nil,'Pair',2,10); assert(mult==102 and chips==410)
    G.GAME.current_round.hands_left=7; D.apply_blind_bonus(p); assert(G.GAME.current_round.hands_left==7)
end)
test('banked refreshes preserve native freebies and do not inflate the next paid cost',function()
    G.STATES={SHOP=5}; G.STATE=5; G.shop={}; G.CONTROLLER={locks={}}
    G.GAME.current_round={free_rerolls=1,reroll_cost=0,reroll_cost_increase=0}; G.GAME.bt_boss_rerolls=2
    calculate_reroll_cost=function(skip)
        local r=G.GAME.current_round; if r.free_rerolls>0 then r.reroll_cost=0; return end
        if not skip then r.reroll_cost_increase=r.reroll_cost_increase+1 end
        r.reroll_cost=5+r.reroll_cost_increase
    end
    G.FUNCS.reroll_shop=function()
        local r=G.GAME.current_round; G.GAME.dollars=G.GAME.dollars-r.reroll_cost
        local free=r.free_rerolls>0; r.free_rerolls=math.max(0,r.free_rerolls-1); calculate_reroll_cost(free)
    end
    D.install(); G.FUNCS.reroll_shop(); assert(G.GAME.bt_boss_rerolls==2)
    G.FUNCS.reroll_shop(); G.FUNCS.reroll_shop()
    assert(G.GAME.bt_boss_rerolls==0 and G.GAME.dollars==4 and G.GAME.current_round.reroll_cost==5)
end)
print('TOTAL '..count..' NATIVE REWARD DICE BRIDGE TESTS PASSED')
