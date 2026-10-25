local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
local function world(seed)
    local function card(key)
        local c={config={center={key=key,kind=key=='p_buffoon_normal_1' and 'Buffoon' or nil}},ability={}}
        function c:remove() self.removed=true end
        function c:set_edition(e) self.edition=e end
        function c:set_cost() return Card.set_cost(self) end
        return c
    end
    G={GAME={round=2,pseudorandom={seed=seed or 'THUNDRCK'},round_resets={blind_states={Small='Defeated',Big='Defeated'}}},FUNCS={},P_CENTERS={p_buffoon_normal_1={key='p_buffoon_normal_1'}}}
    G.shop_jokers={};G.shop_booster={};G.deck={cards={}};G.STATES={SHOP=5}
    CardArea={shuffle=function() end};Card={set_cost=function(c) c.cost=9 end,open=function() end,use_consumeable=function() end}
    G.FUNCS.reroll_shop=function() end
    get_pack=function() return {key='native_pack'} end
    create_card_for_shop=function() return card('native_shop') end
    create_shop_card_ui=function() end
    create_card=function(kind,area,legendary,rarity,skip,soulable,key) return card(key or 'native_legendary') end
    local m=dofile(ROOT..'/game/thundrck.lua');m.install()
    return m,card
end
test('Ordinary seeds pass through native pack, shop and Legendary selection',function()
    local m=world('OTHER');assert(not m.state());assert(get_pack('shop_pack').key=='native_pack')
    assert(create_card_for_shop(G.shop_jokers).config.center.key=='native_shop')
    assert(create_card('Joker',nil,true,nil,nil,nil,nil,'sou').config.center.key=='native_legendary')
end)
test('Second won-blind shop stocks one Buffoon Pack without altering other packs',function()
    local m=world();assert(get_pack('shop_pack').key=='p_buffoon_normal_1');assert(get_pack('shop_pack').key=='native_pack')
    assert(get_pack('spectral').key=='native_pack');G.GAME.round=1;assert(not m.second_shop())
end)
test('Reroll before opening a purchased Buffoon cannot offer the scripted Soul',function()
    local m=world();G.FUNCS.reroll_shop();assert(create_card_for_shop(G.shop_jokers).config.center.key=='native_shop')
    assert(not m.state().soul_offered)
end)
test('Purchased Buffoon then reroll offers exactly one marked native Soul',function()
    local m,card=world();local pack=card('p_buffoon_normal_1');pack.ability.booster_pos=1;G.GAME.PACK_INTERRUPT=5
    Card.open(pack);assert(m.state().buffoon_opened);G.FUNCS.reroll_shop()
    local soul=create_card_for_shop(G.shop_jokers);assert(soul.config.center.key=='c_soul' and soul.ability.bt_thundrck_soul)
    G.FUNCS.reroll_shop();assert(create_card_for_shop(G.shop_jokers).config.center.key=='native_shop')
    assert(m.state().soul_offered)
end)
test('Tag packs, destroyed packs and other Booster kinds cannot arm the reward',function()
    local m,card=world();local pack=card('p_buffoon_normal_1');pack.area=G.shop_booster;pack.from_tag=true;Card.open(pack)
    assert(not m.state().buffoon_opened);pack.from_tag=false;pack.cry_monopoly_destroyed=true;Card.open(pack)
    assert(not m.state().buffoon_opened);pack.cry_monopoly_destroyed=false;pack.config.center.kind='Arcana';Card.open(pack)
    assert(not m.state().buffoon_opened)
end)
test('Only the marked Soul summons Government Man once; other Souls remain native',function()
    local m,card=world();local ordinary=card('c_soul');Card.use_consumeable(ordinary)
    assert(create_card('Joker',nil,true,nil,nil,nil,nil,'sou').config.center.key=='native_legendary')
    ordinary.ability.bt_thundrck_soul=true;Card.use_consumeable(ordinary)
    assert(create_card('Joker',nil,true,nil,nil,nil,nil,'sou').config.center.key=='j_btogether_government_man')
    assert(m.state().soul_used and not m.state().soul_pending)
    Card.use_consumeable(ordinary);assert(create_card('Joker',nil,true,nil,nil,nil,nil,'sou').config.center.key=='native_legendary')
end)
test('Curated draw keeps every existing card exactly once and places a real Royal Flush at the draw end',function()
    local m=world();local cards={};local original={}
    for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do for rank=2,14 do
        local c={base={suit=suit},get_id=function() return rank end};cards[#cards+1]=c;original[c]=true
    end end
    assert(m.opening(cards,1));assert(#cards==52)
    local seen={};for _,c in ipairs(cards) do assert(original[c] and not seen[c]);seen[c]=true end
    for i=48,52 do assert(cards[i].base.suit=='Spades' and cards[i]:get_id()>=10) end
end)
test('Curated shop flags remain in native run state and later shop starts give a Negative Blueprint',function()
    local m=world();G.GAME.round=3
    local card=create_card_for_shop(G.shop_jokers);assert(card.config.center.key=='j_blueprint' and card.edition.negative)
    assert(create_card_for_shop(G.shop_jokers).config.center.key=='native_shop')
    local stored=G.GAME.bt_thundrck;assert(stored.shops['3']);assert(m.state()==stored)
end)
test('The starter Negative Abstract costs $1 through native price recalculation',function()
    local m=world();G.GAME.round=1
    local card=create_card_for_shop(G.shop_jokers);assert(card.config.center.key=='j_abstract')
    Card.set_cost(card);assert(card.cost==1 and card.sell_cost==1)
end)
print(count..' THUNDRCK checks passed')
