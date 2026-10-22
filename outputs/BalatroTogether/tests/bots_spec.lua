local A=dofile(ROOT..'/bots/strategy.lua')
local M=dofile(ROOT..'/core/session.lua')
local count=0
local function test(name,f) f(); count=count+1; print('PASS '..name) end
local function card(rank,suit,opts) local c={rank=rank,suit=suit or 'Spades',chips=rank==14 and 11 or math.min(rank,10),xmult=1,held_xmult=1}; for k,v in pairs(opts or {}) do c[k]=v end; return c end
local function ctx(t) local c={jokers={},hands={},discards_left=0,hands_left=4}; for k,v in pairs(t or {}) do c[k]=v end; return c end
test('bot compares expected scores rather than poker-hand rank',function()
    local hand={card(14),card(14,'Hearts'),card(2),card(4),card(6),card(8),card(10),card(12,'Clubs')}
    local p=A.best(hand,ctx{hands={Pair={chips=200,mult=10},Flush={chips=1,mult=1}}})
    assert(p.name=='Pair' and p.score==2220)
end)
test('bot preserves held steel instead of automatically playing five cards',function()
    local hand={card(14),card(14,'Hearts'),card(3,'Clubs',{held_xmult=1.5}),card(7,'Diamonds',{held_xmult=1.5})}
    local p=A.best(hand,ctx()); assert(p.name=='Pair' and #p.indices==2 and p.score==144)
end)
test('bot uses enhanced cards and joker-specific scoring',function()
    local p=A.best({card(14),card(12),card(4,'Hearts'),card(9,'Diamonds')},ctx{jokers={{key='j_half'},{key='j_scholar'}}})
    assert(p.name=='High Card' and p.indices[1]==1 and p.score==900)
end)
test('bot recognizes wheel straights and exact scoring subsets',function()
    local hand={card(14),card(2,'Clubs'),card(3),card(4,'Hearts'),card(5)}
    local name,ids=A.classify(hand,ctx()); assert(name=='Straight' and #ids==5)
    local _,pair=A.classify({card(9),card(9,'Hearts'),card(14,'Clubs'),card(5),card(2)},ctx()); assert(#pair==2)
end)
test('bot obeys Psychic and Eye restrictions',function()
    local hand={card(14),card(14,'Hearts'),card(3,'Clubs'),card(7,'Diamonds'),card(9)}
    local p=A.best(hand,ctx{psychic=true}); assert(#p.indices==5)
    p=A.best(hand,ctx{forbidden={Pair=true}}); assert(p.name~='Pair')
end)
test('bot discards toward a strong available draw without deck-order dependence',function()
    local hand={card(2),card(6),card(9),card(12),card(3,'Hearts'),card(4,'Clubs'),card(7,'Diamonds'),card(10,'Hearts')}
    local deck={}; for rank=2,14 do deck[#deck+1]=card(rank) end
    local p=A.plan(hand,deck,ctx{discards_left=3}); assert(p.kind=='discard' and p.expected>p.score*1.16)
    for _,i in ipairs(p.indices) do assert(hand[i].suit~='Spades') end
end)
test('bot takes guaranteed team win without wasting a discard',function()
    local p=A.plan({card(14),card(14,'Hearts'),card(4)}, {card(14)},ctx{discards_left=4,remaining_target=50}); assert(p.kind=='play')
end)
test('bot values useful scoring over unusable shop purchases',function()
    assert(A.shop_value({key='j_cavendish',set='Joker'},ctx())>A.shop_value({key='j_credit_card',set='Joker'},ctx()))
    assert(A.shop_value({key='j_obelisk',set='Joker'},ctx())<6)
end)
test('host seed and deck survive snapshots and fixed-seed restart',function()
    local m=M.new{intended=1,deck='b_checkered',seed='abc123'}; m.players[1].ready=true
    assert(m:start('RANDOM12')); assert(m.seed=='ABC123' and m:snapshot().deck=='b_checkered')
    assert(m:restart('OTHER123')); assert(m.seed=='ABC123' and m.deck=='b_checkered')
    assert(not pcall(M.new,{deck='b_fake'})); assert(not pcall(M.new,{seed='bad seed'}))
end)
test('bot flag and reservation reconnect survive party restart',function()
    local m=M.new{intended=2}; local id=m:join('Bot Ada','secret'); m.players[id].bot=true; m.players[id].connected=false
    assert(m:reconnect('secret')==2); for _,p in pairs(m.players) do p.ready=true end
    assert(m:start('BOTTEST1')); assert(m:restart('BOTTEST2')); assert(m:snapshot().players['2'].bot)
end)
print('TOTAL '..count..' BOT/SETUP TESTS PASSED')
return count
