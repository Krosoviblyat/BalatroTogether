local checks=0;local function test(n,f) f();checks=checks+1;print('PASS '..n) end
local function world()
    local d,e,rolls={},nil,0
    G={playing_cards={},deck={config={card_limit=52}},play={},hand={},P_CENTERS={},C={MULT={}}}
    local wins={}
    SMODS={Atlas=function() end,Joker=function(v) d=v end,Enhancement=function(v) e=v end,
        pseudorandom_probability=function(c,seed,n,den,id,fixed) assert(n==1 and den==4 and fixed);rolls=rolls+1;return wins[rolls] or false end,
        add_card=function(t)
            assert(t.area==G.deck and t.set=='Enhanced' and t.no_edition)
            local c={config={center={key=t.key}},ability={set='Enhanced',mult=2.5}}
            G.playing_cards[#G.playing_cards+1]=c;G.deck.config.card_limit=G.deck.config.card_limit+1;return c
        end}
    local reactions=0;playing_card_joker_effects=function(cards) assert(#cards==1);reactions=reactions+1 end
    local m=dofile(ROOT..'/game/shroombo.lua');m.install();G.P_CENTERS[m.FUNGUS]=e
    return m,d,e,wins,function() return rolls,reactions end
end
test('Shroombo is a native $20 Legendary with X1 base and native Fungus tooltip entry',function()
    local m,d=world();assert(d.rarity==4 and d.cost==20 and d.unlocked and d.blueprint_compat)
    assert(d.calculate(d,{}, {joker_main=true}).x_mult==1)
    local q={};assert(d.loc_vars(d,q,{}).vars[1]==1 and q[1]==G.P_CENTERS[m.FUNGUS])
end)
test('Fungus uses native rankless, suitless, always-score properties and +2.5 Mult',function()
    local m,d,e=world();assert(e.no_rank and e.no_suit and e.always_scores and e.replace_base_card and e.config.mult==2.5)
    assert(e.in_pool()==false and e.loc_vars(e,{}, {ability={mult=2.5}}).vars[1]==2.5)
end)
test('every scored card rolls independently; held/repetition-only/end contexts never roll',function()
    local m,d,e,wins,state=world();wins[1]=true;wins[3]=true;local c={}
    for i=1,4 do d.calculate(d,c,{individual=true,cardarea=G.play,other_card={}}) end
    d.calculate(d,c,{individual=true,cardarea=G.hand,other_card={}})
    d.calculate(d,c,{repetition=true,cardarea=G.play,other_card={}})
    d.calculate(d,c,{end_of_round=true})
    local rolls,reactions=state();assert(rolls==4 and reactions==2 and #G.playing_cards==2 and G.deck.config.card_limit==54)
    assert(d.calculate(d,c,{joker_main=true}).x_mult==2)
end)
test('XMult immediately follows real deck contents, copies, transfers, debuffs and removals',function()
    local m,d=world();local first=m.create();m.create();assert(m.mult()==2)
    first.debuff=true;assert(m.mult()==2)
    local transferred=table.remove(G.playing_cards,1);assert(m.mult()==1.5)
    table.insert(G.playing_cards,transferred);assert(m.mult()==2)
    first.config.center={key='m_bonus'};assert(m.mult()==1.5)
    G.playing_cards[1].removed=true;assert(m.mult()==1)
    G.playing_cards[1].removed=false;G.playing_cards[1].shattered=true;assert(m.mult()==1)
end)
test('Blueprint applies its own scored-card rolls and reads the current owner deck',function()
    local m,d,e,wins=world();wins[1]=true
    d.calculate(d,{}, {blueprint=true,blueprint_card={},individual=true,cardarea=G.play,other_card={}})
    assert(m.count()==1 and d.calculate(d,{}, {blueprint=true,joker_main=true}).x_mult==1.5)
end)
test('only Fungus playing cards enter escrow; unsupported enhancements and malformed seals are refused',function()
    local D=dofile(ROOT..'/core/donations.lua')
    local c={center='m_btogether_fungus',kind='Enhanced',name='Fungus Card',edition='foil',seal='Red',ability={set='Enhanced',name='Fungus Card',mult=2.5}}
    local v=assert(D.card(c));assert(v.seal=='Red' and v.ability.mult==2.5)
    c.center='m_bonus';assert(not D.card(c));c.center='m_btogether_fungus';c.seal={};assert(not D.card(c))
end)
test('bot planner scores Fungus without counting it toward pairs or suits',function()
    local A=dofile(ROOT..'/bots/strategy.lua');local f={rank=0,suit='',chips=0,mult=2.5,stone=true,rankless=true}
    local score,name=A.score({f,f},{},{jokers={}});assert(name=='High Card' and score==30)
    local p={rank=8,suit='Hearts',chips=8};local _,hand=A.score({p,p,f,f},{},{jokers={}});assert(hand=='Pair')
end)
print(checks..' Shroombo checks passed')
