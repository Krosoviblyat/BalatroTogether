local S=dofile(ROOT..'/core/session.lua'); S.Pot=dofile(ROOT..'/core/pot.lua')
local P,m,reject,drop,sent,changes
local function setup()
    m=S.new{intended=1}; m.phase='prepare'; m.run_id=1; m.players[1].activity='waiting'
    reject=false; drop=false; sent={}; changes={}
    G={GAME={dollars=20},HUD={},SETTINGS={},CONTROLLER={locks={}},E_MANAGER={queues={base={}}},STATES={SHOP=1,BLIND_SELECT=2},STATE=2,FUNCS={buy_from_shop=function() return 'bought' end}}
    BT={Session=S,state=m:snapshot(),active=function() return true end,game={started=true},donation={busy=function() return false end},notice=function() end,ui={}}
    BT.client={id=1,connected=true,action=function(kind,d)
        sent[#sent+1]={kind=kind,data=d}
        if drop then return end
        if reject and kind=='pot_deposit' then m.players[1].ready=true end
        m:apply(1,{seq=m.players[1].ack+1,run=1,kind=kind,data=d}); BT.state=m:snapshot()
        return m.players[1].ack
    end}
    ease_dollars=function(amount,instant) assert(instant); G.GAME.dollars=G.GAME.dollars+amount; changes[#changes+1]=amount end
    P=dofile(ROOT..'/game/pot.lua'); BT.pot=P; P.update(0.1)
end
local count=0
local function test(name,fn) setup(); fn(); count=count+1; print('PASS '..name) end
test('native deposit debits before publication and duplicate receipts never debit again',function()
    P.deposit(5); assert(G.GAME.dollars==15 and m.pot.wager==5 and P.busy())
    for _=1,20 do P.update(0.1) end
    assert(not P.busy() and G.GAME.dollars==15 and #changes==1)
end)
test('rejected and unsent bets refund exactly once',function()
    reject=true; P.deposit(5); P.update(0.1); P.update(0.1)
    assert(G.GAME.dollars==20 and #changes==2 and m.pot.wager==0)
    m.players[1].ready=false; BT.state=m:snapshot(); drop=true; P.deposit(5)
    assert(G.GAME.dollars==20 and not P.busy() and P.counter==1)
end)
test('cumulative payouts apply once even when acknowledgements are delayed or retried',function()
    m.pot.bank=10; assert(BT.client.action('pot_split',{})); drop=true
    for _=1,10 do P.update(0.1) end
    assert(G.GAME.dollars==30 and P.busy() and #changes==1)
    drop=false; for _=1,10 do P.update(0.1) end
    assert(not P.busy() and G.GAME.dollars==30 and m.players[1].pot_received==10)
    m.pot.bank=5; BT.client.action('pot_split',{}); P.update(0.1)
    assert(G.GAME.dollars==35 and #changes==2)
end)
test('disconnected or unsettled clients keep payouts pending and spending blocked',function()
    P.install(); m.pot.bank=5; BT.client.action('pot_split',{}); BT.client.connected=false
    P.update(1); assert(G.GAME.dollars==20 and G.FUNCS.buy_from_shop()==nil)
    BT.client.connected=true; G.E_MANAGER.queues.base={{blocking=true}}; P.update(1); assert(G.GAME.dollars==20)
    G.E_MANAGER.queues.base={}; P.update(1); assert(G.GAME.dollars==25 and G.FUNCS.buy_from_shop()=='bought')
end)
test('insufficient funds and a restart cannot spend or credit old-run pot money',function()
    P.deposit(21); assert(#changes==0 and m.pot.wager==0)
    P.deposit(5); P.reset(); m:restart('NEW'); BT.state=m:snapshot(); G.GAME.dollars=4; P.update(1)
    assert(G.GAME.dollars==4 and not P.busy())
end)
test('a completed paused native results overlay can receive its final split without blocking restart',function()
    m.phase='defeat'; m.pot.bank=5; BT.client.action('pot_split',{})
    G.STATES.GAME_OVER=3; G.STATE=3; G.STATE_COMPLETE=true; G.OVERLAY_MENU={}; G.SETTINGS.paused=true
    G.E_MANAGER.queues.base={{blocking=true}}
    P.update(1); assert(G.GAME.dollars==25 and not P.busy()); assert(m:restart('NEW'))
end)
test('the real pot screen renders editable bet amounts independently of its opening animation',function()
    local buttons={}; local noop=function() end
    love={graphics=setmetatable({},{__index=function() return noop end}),mouse={getPosition=function() return 0,0 end}}
    SMODS={load_file=function(path) return assert(loadfile(ROOT..'/'..path)) end}
    BT.config={motion=1,reduced_motion=false,effects=true,sounds=false}
    local h={col=noop,txt=function(value) assert(type(value)=='string' or type(value)=='number') end,rect=noop,backdrop=noop,
        button=function(label,x,y,w,height,fn) buttons[label]=fn end,hit=function(x,y,w,height,fn,label) buttons[label]=fn end,colors={{},{},{},{}},muted={},ink={},panel={}}
    BT.ui.screen='pot'; local V=dofile(ROOT..'/ui/pot.lua')(BT.ui,h)
    V.update(0.05); V.draw(1280,800); assert(type(V.amount())=='number' and buttons['BET $5 / TEAM'])
    buttons['+1'](); V.draw(1280,800); assert(buttons['BET $6 / TEAM'])
    buttons['BET AMOUNT']();assert(V.textinput('17'));V.draw(1280,800);assert(V.bet==17 and buttons['BET $17 / TEAM'])
    buttons['PERSONAL / +15%']();V.draw(1280,800);assert(buttons['BET $17 / PERSONAL'])
    V.keypressed('a',true);V.textinput('23');assert(V.bet==23)
    V.keypressed('backspace');assert(V.bet==2);V.keypressed('backspace');assert(V.bet==0)
    V.textinput('-5');assert(V.bet==0);V.textinput('10001');assert(V.bet==10001)
    love.system={getClipboardText=function() return '$1,234' end};V.keypressed('v',true);assert(V.bet==1234)
    love.system.getClipboardText=function() return '-50' end;V.keypressed('v',true);assert(V.bet==1234)
    V.keypressed('return');assert(not BT.ui.focus and m.pot.wager==0,'Enter edits without committing a bet')
    BT.config.reduced_motion=true; V.update(0.01); assert(V.amount()==1)
    BT.ui.pot_event('deposit',5); V.draw(1280,800)
end)
print('TOTAL '..count..' NATIVE BET POT BRIDGE TESTS PASSED')
