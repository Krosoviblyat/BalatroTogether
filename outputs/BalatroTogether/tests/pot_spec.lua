local S=dofile(ROOT..'/core/session.lua'); S.Pot=dofile(ROOT..'/core/pot.lua')
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function new(n)
    local m=S.new{intended=n or 2}; for i=2,n or 2 do assert(m:join('P'..i,'token'..i)) end
    m.phase='prepare'; m.run_id=1
    for _,p in pairs(m.players) do p.activity='waiting'; p.money=20 end
    return m
end
local function act(m,id,kind,data) local p=m.players[id]; return m:apply(id,{seq=p.ack+1,run=m.run_id,kind=kind,data=data or {}}) end
local function bet(m,id,amount,tx) return act(m,id,'pot_deposit',{amount=amount,balance=20,tx=tx or (m.players[id].pot_tx or 0)+1}) end
local function finish(m,won)
    m.round=m.round+1; m.phase='blind'; m.target=100; m.score=won and 100 or 0
    for _,p in pairs(m.players) do p.exhausted=true; p.busy=false end
    m:advance()
end
test('pooled bets settle once with a rounded-down 37.5 percent bonus',function()
    local m=new(); assert(bet(m,1,5)); assert(bet(m,2,6)); assert(m.pot.wager==11)
    finish(m,true); assert(m.pot.bank==15 and m.pot.last.bonus==4 and m.pot.wager==0)
    S.Pot.settle(m); m:advance(); assert(m.pot.bank==15)
end)
test('a losing blind burns its bets while preserving saved winnings',function()
    local m=new(); m.pot.bank=17; assert(bet(m,1,7)); finish(m,false)
    assert(m.phase=='defeat' and m.pot.bank==17 and m.pot.last.returned==0 and m.pot.wager==0)
end)
test('deposit replay under old and fresh action sequences cannot debit the pot twice',function()
    local m=new(); assert(bet(m,2,5)); local a=m.players[2].ack
    assert(m:apply(2,{seq=a,run=1,kind='pot_deposit',data={tx=1,amount=5,balance=20}}))
    assert(bet(m,2,5,1)); assert(m.pot.wager==5)
    assert(not bet(m,2,5,3)); assert(m.pot.wager==5)
end)
test('ready, blind, poor, malformed and nonfinite bets are refused with refund receipts',function()
    for _,amount in ipairs({0,-1,1.5,21,10001,0/0,math.huge,'5'}) do
        local m=new(); assert(not bet(m,1,amount)); assert(m.pot.wager==0 and m.players[1].pot_receipt.status=='rejected')
    end
    for _,field in ipairs({'ready','busy','transferring'}) do local m=new(); m.players[1][field]=true; assert(not bet(m,1,5)) end
    local m=new(); m.phase='blind'; assert(not bet(m,1,5))
end)
test('only the host splits evenly among connected seats and retains the remainder',function()
    local m=new(4); m.pot.bank=14; m:disconnect(4)
    assert(not act(m,2,'pot_split')); assert(act(m,1,'pot_split'))
    assert(m.pot.bank==2 and m.players[4].pot_credit==nil)
    for i=1,3 do assert(m.players[i].pot_credit==4 and not m.players[i].ready) end
    assert(not act(m,1,'pot_split')); assert(m.pot.bank==2)
end)
test('unreceived payouts gate ready, shop exit, another split and restart',function()
    local m=new(); m.phase='shop'; m.pot.bank=20; assert(act(m,1,'pot_split'))
    assert(not act(m,1,'shop_done',{round=0,ante=1,index=2}))
    assert(not act(m,2,'ready',{ready=true})); assert(not act(m,1,'pot_split')); assert(not m:restart('NEW'))
    for i=1,2 do assert(act(m,i,'pot_received',{total=10})) end
    assert(m:restart('NEW')); assert(m.pot.bank==0 and m.players[1].pot_credit==nil)
end)
test('payout receipts are exact and idempotent across disconnect and reconnect',function()
    local m=new(); m.pot.bank=10; assert(act(m,1,'pot_split')); m:disconnect(2)
    assert(m:reconnect('token2')==2); assert(m.players[2].pot_credit==5)
    assert(not act(m,2,'pot_received',{total=6})); assert(act(m,2,'pot_received',{total=5})); assert(act(m,2,'pot_received',{total=5}))
    assert(m.players[2].pot_received==5)
end)
test('pot snapshots are independent and stale-run bets cannot affect the fresh run',function()
    local m=new(); assert(bet(m,1,8)); local snap=m:snapshot(1); snap.pot.wager=99; assert(m.pot.wager==8)
    assert(m:restart('NEW')); assert(not m:apply(2,{seq=m.players[2].ack+1,run=1,kind='pot_deposit',data={tx=1,amount=5,balance=20}}))
    assert(m.pot.wager==0 and m.pot.bank==0)
end)
test('next-blind bets placed in the shop survive until that blind settles',function()
    local m=new(); finish(m,true); assert(bet(m,1,9)); assert(m.pot.wager==9 and m.pot.bank==0)
    m:advance(); assert(m.pot.wager==9)
    finish(m,true); assert(m.pot.bank==12 and m.pot.last.round==2)
end)
test('bounded pot volume and transaction counters reject excess without changing balances',function()
    local m=new(); m.pot.volume=800000; assert(not bet(m,1,1)); assert(m.pot.bank==0 and m.pot.wager==0)
    m=new(); assert(not bet(m,1,1,4097)); assert(m.players[1].pot_tx==nil)
end)
test('repeated wins, losses and splits conserve deposits plus bonuses exactly',function()
    local m=new(4); local deposited,bonuses,lost,paid=0,0,0,0
    for turn=1,120 do
        m.phase='prepare'; for _,p in pairs(m.players) do p.activity='waiting'; p.ready=false end
        local stake=0
        for id=1,4 do local amount=(turn*id)%20+1; assert(bet(m,id,amount)); stake=stake+amount end
        deposited=deposited+stake
        local won=turn%5~=0; finish(m,won)
        if won then bonuses=bonuses+math.floor(stake*0.375) else lost=lost+stake end
        if turn%3==0 and m.pot.bank>=4 then
            local share=math.floor(m.pot.bank/4); assert(act(m,1,'pot_split')); paid=paid+share*4
            for id=1,4 do assert(act(m,id,'pot_received',{total=m.players[id].pot_credit})) end
        end
        assert(m.pot.bank+paid+lost==deposited+bonuses)
    end
end)
print('TOTAL '..count..' BET POT LEDGER TESTS PASSED')
