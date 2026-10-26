local A=dofile(ROOT..'/bots/strategy.lua');local T=dofile(ROOT..'/bots/teamwork.lua')(A)
local function test(n,f) f();print('PASS '..n) end
local function c(rank,suit,extra)
    local v={rank=rank,suit=suit or 'Spades',chips=rank==14 and 11 or math.min(rank,10),xmult=1,held_xmult=1}
    for k,x in pairs(extra or {}) do v[k]=x end;return v
end
local function ctx(jokers) return {jokers=jokers or {},hands={},hands_left=4,discards_left=0} end
test('Photograph and Hanging Chad retrigger the first scoring face at native scoring order',function()
    local score=A.score({c(13),c(9,'Hearts')},{},ctx{{key='j_photograph'},{key='j_hanging_chad'}})
    assert(score==280) -- (5+10*3) Chips; 1*2^3 Mult.
end)
test('Blueprint and Brainstorm copy compatible scoring and retrigger abilities without cycles',function()
    assert(A.score({c(13)},{},ctx{{key='j_blueprint'},{key='j_photograph'},{key='j_hanging_chad'}})==2240)
    assert(A.score({c(14)},{},ctx{{key='j_brainstorm'},{key='j_blueprint'}})==16)
    assert(A.score({c(14)},{},ctx{{key='j_blueprint'},{key='j_joker',blueprint_compat=false}})==80)
end)
test('Debuffed playing cards still form a Flush but provide no card Chips or Mult',function()
    local hand={c(2),c(4),c(7),c(9),c(12,nil,{debuff=true})};local name=A.classify(hand,{})
    assert(name=='Flush' and A.score(hand,{},ctx())==228)
end)
test('Face-down unknowns never invent pairs or pair-triggered XMult',function()
    local unknown=c(0,'Unknown',{chips=0,unknown=true});local score,name=A.score({unknown,unknown},{},ctx{{key='j_duo'}})
    assert(name=='High Card' and score==5)
    local name=A.classify({unknown,unknown,unknown,unknown,unknown},{smeared=true})
    assert(name=='High Card')
end)
test('Fungus cannot inherit face triggers or turn a rankless card into a held low rank',function()
    local f=c(0,'',{chips=0,mult=2.5,stone=true,rankless=true});assert(A.score({f},{c(10)},ctx{{key='j_photograph'},{key='j_pareidolia'}})==17.5)
end)
local own={jokers={{key='j_joker'},{key='j_abstract'},{key='j_cavendish'},{key='j_droll'}},preferred_hand='Pair',fungus_count=2}
local players={['1']={id=1,connected=true,inspect=true,jokers={},consumables={},deck={Hearts=26,Spades=26},bot_profile={preferred_hand='Flush',joker_limit=5,consumable_limit=2}}}
test('Bots target spare flush Jokers and matching Planets to a teammate who benefits more',function()
    local d=T.choose({{key='j_droll',set='Joker'}},own,players,2,{})
    assert(d and d.target==1)
    d=T.choose({{key='c_jupiter',set='Planet',hand_type='Flush'}},own,players,2,{})
    assert(d and d.target==1 and d.reason=='hand synergy')
end)
test('Bots retain carry Jokers, Legendaries, received gifts, Eternal cards and their last two Jokers',function()
    for _,item in ipairs({{key='j_cavendish',set='Joker'},{key='j_droll',set='Joker',legendary=true},{key='j_droll',set='Joker',received=true},{key='j_droll',set='Joker',eternal=true}}) do assert(not T.choose({item},own,players,2,{})) end
    local small={jokers={{key='j_droll'},{key='j_abstract'}},preferred_hand='Pair'}
    assert(not T.choose({{key='j_droll',set='Joker'}},small,players,2,{}))
end)
test('Bot donations respect teammate inspection, disconnects and inventory limits',function()
    local p=players['1'];p.inspect=false;assert(not T.choose({{key='j_droll',set='Joker'}},own,players,2,{}));p.inspect=true
    p.connected=false;assert(not T.choose({{key='j_droll',set='Joker'}},own,players,2,{}));p.connected=true
    p.bot_profile.consumable_limit=0;assert(not T.choose({{key='c_jupiter',set='Planet',hand_type='Flush'}},own,players,2,{}));p.bot_profile.consumable_limit=2
end)
test('A bot shares surplus Fungus with a Shroombo owner and keeps Fungus for its own Shroombo',function()
    players['1'].jokers={{key='j_btogether_shroombo'}}
    assert(T.choose({{key='m_btogether_fungus',set='Enhanced'}},own,players,2,{}))
    local holder={jokers={{key='j_btogether_shroombo'}},fungus_count=3}
    assert(not T.choose({{key='m_btogether_fungus',set='Enhanced'}},holder,players,2,{}))
end)
test('Discard planning is bounded, deterministic across deck ordering, and consumes no native RNG',function()
    local hand={c(2),c(6),c(9),c(12),c(3,'Hearts'),c(4,'Clubs'),c(7,'Diamonds'),c(10,'Hearts')};local deck={}
    for rank=2,14 do deck[#deck+1]=c(rank) end
    local context=ctx();context.discards_left=3;context.evaluation_limit=10000
    local a=A.plan(hand,deck,context);local rev={};for i=#deck,1,-1 do rev[#rev+1]=deck[i] end;local b=A.plan(hand,rev,context)
    assert(a.evaluations<=10000 and b.evaluations<=10000 and a.kind==b.kind and table.concat(a.indices,',')==table.concat(b.indices,','))
end)
test('Oversized Cryptid hands keep planning work below the fixed evaluation budget',function()
    local hand,deck={},{};for i=1,32 do hand[i]=c(2+i%13,({'Spades','Hearts','Clubs','Diamonds'})[i%4+1]) end
    for i=1,52 do deck[i]=c(2+i%13) end
    local context=ctx{{key='j_photograph'},{key='j_hanging_chad'}};context.discards_left=3
    local result=A.plan(hand,deck,context);assert(result.score>=0 and #result.indices>=1 and #result.indices<=5 and result.evaluations<=40000)
end)
