local checks=0;local function test(n,f) f();checks=checks+1;print('PASS '..n) end
local function world(seed)
    local function card(key,kind)
        local c={config={center={key=key,kind=kind}},ability={}}
        function c:remove() self.removed=true end
        function c:set_cost() self.cost=self.config.center.key=='j_btogether_shroombo' and 20 or 4 end
        return c
    end
    G={GAME={round=1,dollars=25,pseudorandom={seed=seed or 'ZEROCREW'},banned_keys={},current_round={reroll_cost=5},
        round_resets={blind_states={Small='Defeated',Big='Upcoming'}}},FUNCS={},STATES={SHOP=5},STATE=5,
        P_CENTERS={p_buffoon_normal_1={key='p_buffoon_normal_1'},j_hanging_chad={},j_photograph={},j_btogether_shroombo={}},
        jokers={cards={}},shop_jokers={},shop_booster={},pack_cards={}}
    BT={compat={allowed=function() return true end}}
    Card={open=function() end};get_pack=function() return {key='native_pack'} end
    create_card=function(kind,area,legendary,rarity,skip,soulable,key) return card(key or 'native_card') end
    create_card_for_shop=function() return card('native_shop') end;create_shop_card_ui=function() end
    G.FUNCS.reroll_shop=function() end
    local m=dofile(ROOT..'/game/crew_route.lua');m.install()
    local function own(key) G.jokers.cards[#G.jokers.cards+1]=card(key) end
    local function second() G.GAME.round=2;G.GAME.round_resets.blind_states.Big='Defeated' end
    local function open(tag) local c=card('p_buffoon_normal_1','Buffoon');c.ability.booster_pos=1;c.from_tag=tag;G.GAME.PACK_INTERRUPT=5;Card.open(c);return c end
    local function generate() return create_card('Joker',G.pack_cards,nil,nil,true,true,nil,'buf') end
    return m,own,second,open,generate,card
end
test('Other native seeds keep their shop, pack and card generation',function()
    local m=world('OTHER');assert(not m.state());assert(create_card_for_shop(G.shop_jokers).config.center.key=='native_shop')
    assert(get_pack('shop_pack').key=='native_pack');assert(create_card('Joker',G.pack_cards).config.center.key=='native_card')
end)
test('Early native shop gives one full-price unedited starter, with native rerolls afterwards',function()
    local m=world();local c=create_card_for_shop(G.shop_jokers);assert(c.config.center.key=='j_hanging_chad' and c.cost==4 and not c.edition)
    assert(create_card_for_shop(G.shop_jokers).config.center.key=='native_shop');assert(m.state().starter_offered)
end)
test('A bought second-shop pack offers one synergy candidate only when the starter is retained',function()
    local m,own,second,open,generate=world();second();own('j_hanging_chad')
    assert(get_pack('shop_pack').key=='p_buffoon_normal_1' and get_pack('shop_pack').key=='native_pack')
    open();assert(generate().config.center.key=='j_photograph');assert(generate().config.center.key=='native_card')
    open();assert(generate().config.center.key=='native_card')
end)
test('Skipped blinds, tag packs, lost starter and unrelated areas cannot activate the pack route',function()
    local m,own,second,open,generate=world();second();open();assert(generate().config.center.key=='native_card')
    own('j_hanging_chad');open(true);assert(generate().config.center.key=='native_card')
    G.GAME.round_resets.blind_states.Small='Skipped';assert(not m.second_shop());open();assert(generate().config.center.key=='native_card')
end)
test('Pack candidate waits for its own native generator and respects bans and duplicate ownership',function()
    local m,own,second,open,generate=world();second();own('j_hanging_chad');open()
    assert(create_card('Joker',G.jokers,nil,nil,true,true,nil,'buf').config.center.key=='native_card')
    G.GAME.banned_keys.j_photograph=true;assert(generate().config.center.key=='native_card')
    G.GAME.banned_keys.j_photograph=nil;own('j_photograph');open();assert(generate().config.center.key=='native_card')
end)
test('Later reward needs a paid affordable reroll, retained combo, and an unspent one-time route',function()
    local m,own,second,open,generate=world();second();own('j_hanging_chad');open();generate();own('j_photograph');G.GAME.round=3
    G.GAME.dollars=24;G.FUNCS.reroll_shop();assert(not m.state().reward_pending)
    G.GAME.dollars=25;G.GAME.current_round.reroll_cost=0;G.FUNCS.reroll_shop();assert(not m.state().reward_pending)
    G.GAME.current_round.reroll_cost=5;G.FUNCS.reroll_shop();local c=create_card_for_shop(G.shop_jokers)
    assert(c.config.center.key=='j_btogether_shroombo' and c.cost==20 and not c.edition)
    G.FUNCS.reroll_shop();assert(create_card_for_shop(G.shop_jokers).config.center.key=='native_shop')
end)
test('Passed early windows stay native and saved state cannot replay a consumed reward',function()
    local m,own,second,open,generate=world();second();own('j_hanging_chad');open();generate();own('j_photograph')
    local stored=m.state();G.GAME.round=5;G.FUNCS.reroll_shop();assert(not stored.reward_pending)
    G.GAME.round=4;stored.reward_offered=true;G.FUNCS.reroll_shop();assert(m.state()==stored and not stored.reward_pending)
end)
print(checks..' optional run checks passed')
