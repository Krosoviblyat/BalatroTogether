local S=dofile(ROOT..'/core/session.lua')
local passed=0
local function test(name,fn) fn(); passed=passed+1; print('PASS '..name) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function room(n)
    local s=S.new{intended=n,name='Host'}
    for i=2,n do assert(s:join('Player '..i,'token'..i)) end
    return s
end
local function act(s,id,kind,data)
    if kind=='ready' and data and data.ready then
        if s.phase=='prepare' then data.round=s.round; data.ante=s.ante; data.index=s.blind_index
        elseif s.phase=='shop' then kind='shop_done'; data={round=s.round,ante=s.ante+(s.blind_index==3 and 1 or 0),index=s.blind_index%3+1} end
    end
    return s:apply(id,{seq=s.players[id].ack+1,run=s.run_id,kind=kind,data=data or {}})
end
local function enter(s)
    for id,p in pairs(s.players) do if not p.withdrawn then assert(act(s,id,'entered',{round=s.round,ante=s.ante,index=s.blind_index,key=s.proposal.key})) end end
end
local function start(n)
    local s=room(n)
    for i=1,n do assert(act(s,i,'ready',{ready=true})) end
    assert(s:start('COOPTEST'))
    assert(s:set_proposal(1,{key='bl_small',base=300,ante=1,index=1}))
    for i=1,n do assert(act(s,i,'ready',{ready=true})) end
    eq(s.phase,'starting'); enter(s); eq(s.phase,'blind'); return s
end
test('all intended seats and ready states required',function()
    local s=room(3); s.intended=4; assert(not s:start('COOPTEST'))
    assert(s:join('Fourth','token4')); assert(not s:join('Fifth','token5'))
    assert(not s:start('COOPTEST'))
    for i=1,4 do act(s,i,'ready',{ready=true}) end
    assert(s:start('COOPTEST')); assert(not s:join('Late','late'))
end)
test('1–4 players target scales consistently',function()
    for n=1,4 do local s=start(n); eq(s:count(),n); eq(s.target,math.ceil(300*n^1.08)) end
end)
test('simultaneous four hand contributions sum exactly once',function()
    local s=start(4); s.target=100000
    for i=1,4 do assert(act(s,i,'busy',{round=1})) end
    local amounts={20000,35000,15000,30000}
    for i=1,4 do
        local action={seq=s.players[i].ack+1,run=s.run_id,kind='score',data={round=1,hand=1,amount=amounts[i],name='Full House'}}
        assert(s:apply(i,action)); assert(s:apply(i,action)); eq(s.players[i].contribution,amounts[i])
    end
    eq(s.score,100000); eq(s.phase,'blind')
    for i=1,3 do act(s,i,'idle',{round=1}); eq(s.phase,'blind') end
    act(s,4,'idle',{round=1}); eq(s.phase,'shop'); eq(s.lifetime_score,100000)
end)
test('stale round, repeated hand, nonfinite and unsolicited scores rejected',function()
    local s=start(4)
    assert(not act(s,2,'score',{round=1,hand=1,amount=500}))
    act(s,2,'busy',{round=1})
    for _,amount in ipairs({math.huge,-math.huge,0/0,1e101,-1e101}) do assert(not act(s,2,'score',{round=1,hand=1,amount=amount})) end
    assert(not act(s,2,'score',{round=0,hand=1,amount=500}))
    assert(act(s,2,'score',{round=1,hand=1,amount=200}))
    assert(not act(s,2,'score',{round=1,hand=1,amount=200})); eq(s.score,200)
end)
test('sequence gaps fail; rejected action is acknowledged so later commands can proceed',function()
    local s=start(4); local ack=s.players[2].ack
    assert(not s:apply(2,{seq=ack+2,run=s.run_id,kind='status',data={}})); eq(s.players[2].ack,ack)
    assert(not act(s,2,'nonsense',{})); eq(s.players[2].ack,ack+1)
    assert(act(s,2,'status',{money=5})); eq(s.players[2].money,5)
end)
test('private hand and reconnect secrets do not leak into snapshots',function()
    local s=start(4)
    act(s,2,'status',{reveal=false,board={{rank='Ace',suit='Spades'}},jokers={{key='j_joker',name='Joker'}}})
    local snap=s:snapshot(); eq(snap.players['2'].token,nil); eq(#snap.players['2'].board,0); eq(#snap.players['2'].jokers,1)
    act(s,2,'status',{reveal=true,board={{rank='Ace',suit='Spades'}}}); eq(#s:snapshot().players['2'].board,1)
    act(s,2,'status',{inspect=false,reveal=true,board={{rank='Ace'}},jokers={{key='j_joker'}}})
    eq(#s:snapshot().players['2'].board,0); eq(#s:snapshot().players['2'].jokers,0)
end)
test('public bot build summaries sanitize values and follow teammate inspection privacy',function()
    local s=start(4)
    act(s,2,'status',{bot_profile={preferred_hand='Flush',joker_limit=0,consumable_limit=3},
        jokers={{key='j_joker',score_mult=24,score_chips=math.huge,score_xmult=0/0}}})
    local p=s:snapshot().players['2']
    eq(p.bot_profile.preferred_hand,'Flush');eq(p.bot_profile.joker_limit,0);eq(p.bot_profile.consumable_limit,3)
    eq(p.jokers[1].score_mult,24);eq(p.jokers[1].score_chips,0);eq(p.jokers[1].score_xmult,1)
    act(s,2,'status',{inspect=false,bot_profile={preferred_hand='Flush',joker_limit=10001,consumable_limit=-1}})
    eq(s.players[2].bot_profile.joker_limit,5);eq(s.players[2].bot_profile.consumable_limit,2)
    eq(s:snapshot().players['2'].bot_profile,nil)
end)

test('one exhausted player does not end the team blind',function()
    local s=start(4); act(s,2,'idle',{round=1,exhausted=true}); eq(s.phase,'blind')
    for _,i in ipairs({1,3,4}) do act(s,i,'idle',{round=1,exhausted=true}) end
    eq(s.phase,'defeat'); eq(s.winner,false)
end)
test('disconnect pauses completion; token reconnect and replay are safe',function()
    local s=start(4); s.target=100
    act(s,2,'busy',{round=1}); act(s,2,'score',{round=1,hand=1,amount=120})
    s:disconnect(3); act(s,2,'idle',{round=1}); eq(s.phase,'blind')
    assert(not s:reconnect('bad')); eq(s:reconnect('token3'),3)
    s:advance(); eq(s.phase,'shop'); eq(s.score,120)
    assert(not s:reconnect('token3'))
end)
test('retiring disconnected seat releases barrier without lowering current target',function()
    local s=start(4); local target=s.target
    s:disconnect(3); assert(not s:drop(2)); assert(s:drop(3)); eq(s.target,target); eq(s:count(),3)
    assert(not s:reconnect('token3'))
end)
test('independent shopping waits for all; only host chooses valid next blind',function()
    local s=start(4); s.target=10; act(s,1,'busy',{round=1}); act(s,1,'score',{round=1,hand=1,amount=10}); act(s,1,'idle',{round=1})
    for i=1,3 do act(s,i,'ready',{ready=true}); eq(s.phase,'shop') end
    act(s,4,'ready',{ready=true}); eq(s.phase,'prepare'); eq(s.blind_index,2)
    assert(not s:set_proposal(2,{key='bl_big',base=500,ante=1,index=2}))
    assert(not s:set_proposal(1,{key='bl_big',base=500,ante=2,index=2}))
    assert(s:set_proposal(1,{key='bl_big',base=500,ante=1,index=2}))
end)
test('24 complete simulated blinds end in one coherent four-player victory',function()
    local s=start(4);s.endless=false
    for round=1,24 do
        eq(s.round,round); eq(s.phase,'blind')
        for i=1,4 do act(s,i,'busy',{round=round}) end
        for i=1,4 do act(s,i,'score',{round=round,hand=1,amount=s.target/4,name='Flush'}); act(s,i,'idle',{round=round}) end
        if round<24 then
            eq(s.phase,'shop'); for i=1,4 do act(s,i,'ready',{ready=true}) end
            eq(s.phase,'prepare')
            assert(s:set_proposal(1,{key='bl_small',base=300*(round+1),ante=s.ante,index=s.blind_index}))
            for i=1,4 do act(s,i,'ready',{ready=true}) end
            enter(s)
        end
    end
    eq(s.phase,'victory'); eq(s.completed_antes,8)
    for i=1,4 do eq(s.players[i].hands_played,24) end
end)
test('seeded randomized simultaneous ordering preserves accounting',function()
    math.randomseed(1701)
    for trial=1,150 do
        local s=start(4); s.target=1e12
        local totals={0,0,0,0}
        for hand=1,5 do
            local order={1,2,3,4}; for i=4,2,-1 do local j=math.random(i); order[i],order[j]=order[j],order[i] end
            for _,i in ipairs(order) do
                local amount=math.random(0,1000000); totals[i]=totals[i]+amount
                assert(act(s,i,'busy',{round=1})); assert(act(s,i,'score',{round=1,hand=hand,amount=amount})); act(s,i,'idle',{round=1})
            end
        end
        eq(s.score,totals[1]+totals[2]+totals[3]+totals[4])
    end
end)
local W=dofile(ROOT..'/core/wire.lua'); local json=dofile(ROOT..'/vendor/json.lua')
test('fast party restart keeps identities and ordering but isolates prior-run traffic',function()
    local s=start(4); act(s,2,'busy',{round=1})
    local oldrun=s.run_id; local oldack=s.players[2].ack; local token=s.players[2].token
    assert(s:restart('FRESHRUN')); eq(s.run_id,oldrun+1); eq(s.phase,'prepare'); eq(s.round,0)
    eq(s.score,0); eq(s.lifetime_score,0); eq(s.players[2].token,token); eq(s.players[2].ack,oldack)
    assert(not s:apply(2,{seq=oldack+1,run=oldrun,kind='score',data={round=1,hand=1,amount=999999}}))
    eq(s.score,0); assert(act(s,2,'ready',{ready=true}))
    assert(s:set_proposal(1,{key='bl_small',base=300,ante=1,index=1}))
    for _,id in ipairs({1,3,4}) do assert(act(s,id,'ready',{ready=true})) end
    enter(s)
    eq(s.round,1); eq(s.phase,'blind'); eq(s.players[2].completed,0)
    s:disconnect(4); assert(not s:restart('NEXTSEED'))
end)

test('a slow native entrant blocks all play and cannot miss a fast teammate blind',function()
    local s=room(2); for i=1,2 do act(s,i,'ready',{ready=true}) end
    s:start('SLOWTEST'); s:set_proposal(1,{key='bl_small',base=300,ante=1,index=1})
    for i=1,2 do act(s,i,'ready',{ready=true}) end
    eq(s.phase,'starting'); assert(act(s,1,'entered',{round=1,ante=1,index=1,key='bl_small'}))
    assert(not act(s,1,'busy',{round=1})); eq(s.phase,'starting')
    assert(not act(s,2,'entered',{round=1,ante=1,index=2,key='bl_small'}))
    assert(act(s,2,'entered',{round=1,ante=1,index=1,key='bl_small'})); eq(s.phase,'blind')
end)

test('plain ready, stale shop completion and wrong native ante cannot advance the party',function()
    local s=start(2); s.target=1; act(s,1,'busy',{round=1}); act(s,1,'score',{round=1,hand=1,amount=2}); act(s,1,'idle',{round=1})
    local function raw(id,kind,data) return s:apply(id,{seq=s.players[id].ack+1,run=s.run_id,kind=kind,data=data}) end
    for i=1,2 do assert(not raw(i,'ready',{ready=true})) end
    assert(not raw(1,'shop_done',{round=0,ante=1,index=2}))
    assert(not raw(1,'shop_done',{round=1,ante=2,index=2})); eq(s.phase,'shop')
    assert(raw(1,'shop_done',{round=1,ante=1,index=2})); eq(s.phase,'shop')
    assert(raw(1,'ready',{ready=false})); eq(s.players[1].ready,false); eq(s.players[1].shop_done,1)
    assert(raw(1,'ready',{ready=true})); eq(s.phase,'shop')
    assert(raw(2,'shop_done',{round=1,ante=1,index=2})); eq(s.phase,'prepare')
    assert(not raw(1,'ready',{ready=true,round=1,ante=1,index=1})); eq(s.players[1].ready,false)
end)
test('wire handles split/coalesced frames and rejects malformed/oversized input',function()
    local b=W.new(); eq(#assert(W.feed(b,'{"x":',json.decode)),0)
    local msgs=assert(W.feed(b,'1}\n{"x":2}\n',json.decode)); eq(#msgs,2); eq(msgs[1].x,1); eq(msgs[2].x,2)
    assert(not W.feed(W.new(),'invalid\n',json.decode)); assert(not W.feed(W.new(),string.rep('X',65537),json.decode))
end)
local L=dofile(ROOT..'/ui/layout.lua')
test('HUD layout bounds at 720p, 1080p, ultrawide 3840x1080, and 4K',function()
    for _,wh in ipairs({{1280,720},{1920,1080},{2560,1440},{3840,1080},{3840,2160},{800,600}}) do
        for _,scale in ipairs({0.6,1,1.6}) do for _,top in ipairs({false,true}) do
            local l=L.compute(wh[1],wh[2],scale,top)
            assert(l.x>=0 and l.x+l.w<=wh[1]); assert(l.y>=0 and l.y+l.h<=wh[2])
        end end
    end
end)
print('TOTAL '..passed..' PASSED')
return passed
