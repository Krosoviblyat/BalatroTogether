local S=dofile(ROOT..'/core/session.lua'); S.Admin=dofile(ROOT..'/core/admin.lua'); S.Dice=dofile(ROOT..'/core/dice.lua'); S.Pot=dofile(ROOT..'/core/pot.lua')
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function new(owner)
    local m=S.new{intended=2}; m:join('Guest','guest'); m.phase='shop'; m.run_id=1; m.seed='ADMIN123'
    m.players[owner or 1].steam_id=S.Admin.OWNER; return m
end
local function act(m,id,k,d) return m:apply(id,{seq=m.players[id].ack+1,run=m.run_id,kind=k,data=d or {}}) end
test('only the verified owner Steam identity gets admin powers, independently of hosting',function()
    local m=new(2); assert(not act(m,1,'admin_grant',{target=1,reward='cash100',steam_id=S.Admin.OWNER}))
    assert(act(m,2,'admin_grant',{target=2,reward='cash100'})); assert(m.players[2].dice_credit==100 and not m.players[1].dice_credit)
    m.players[2].bot=true; assert(not act(m,2,'admin_retry'))
end)
test('player names, status data and a forged owner ID never grant admin permission',function()
    local m=new(); assert(act(m,2,'rename',{name=S.Admin.OWNER})); assert(act(m,2,'status',{steam_id=S.Admin.OWNER,admin=true}))
    assert(not act(m,2,'admin_retry',{steam_id=S.Admin.OWNER})); assert(not m.admin_recovery and not m.players[2].steam_id)
end)
test('admin rewards use normal delivery barriers and duplicate action sequences stay idempotent',function()
    local m=new(); assert(act(m,1,'admin_grant',{target=2,reward='cash100'})); local ack=m.players[1].ack
    assert(m:apply(1,{seq=ack,run=1,kind='admin_grant',data={target=2,reward='cash100'}})); assert(m.players[2].dice_credit==100)
    assert(not act(m,1,'admin_grant',{target=2,reward='wheel'})); assert(not m:restart('NEW'))
    assert(act(m,2,'dice_received',{total=100})); assert(act(m,1,'admin_grant',{target=2,reward='wheel'})); assert(m.players[2].dice_boss==1)
    assert(act(m,1,'admin_grant',{target=2,reward='levels'})); assert(m.players[2].dice_effects[1].levels==1)
end)
test('admin grants reject unfinished blinds, ready targets, invalid prizes and invalid seats',function()
    local m=new(); m.phase='blind'; assert(not act(m,1,'admin_grant',{target=2,reward='gold'}))
    m.phase='shop'; m.players[2].ready=true; assert(not act(m,1,'admin_grant',{target=2,reward='gold'})); m.players[2].ready=false
    assert(not act(m,1,'admin_grant',{target=9,reward='gold'})); assert(not act(m,1,'admin_grant',{target=2,reward='execute_lua'}))
    assert(not m.players[2].dice_gold)
end)
test('recovery retries do not skip native entry or shop barriers and can retire only absent peers',function()
    local m=new(); assert(act(m,1,'admin_retry')); assert(m.phase=='shop' and m.admin_recovery==1 and not m.players[2].shop_done)
    assert(not act(m,1,'admin_retire',{target=2})); m:disconnect(2); assert(act(m,1,'admin_retire',{target=2})); assert(m.players[2].withdrawn)
end)
test('an owner guest can restart the same seed without losing sequence acknowledgements or identity',function()
    local m=new(2); assert(act(m,2,'admin_restart')); assert(m.run_id==2 and m.seed=='ADMIN123' and m.players[2].ack==1)
    assert(m.players[2].steam_id==S.Admin.OWNER and act(m,2,'admin_retry'))
    assert(not m:apply(2,{seq=3,run=1,kind='admin_grant',data={target=2,reward='cash100'}})); assert(not m.players[2].dice_credit)
end)
test('native sync retry resets only entry and shop request latches once per request',function()
    local finishes,resyncs=0,0
    BT={Session=S,state={run_id=1,admin_recovery=1,players={['1']={steam_id=S.Admin.OWNER}}},client={id=1,resync=function() resyncs=resyncs+1 end},
        steam={available=function() return {id=S.Admin.OWNER} end},game={started=true,entry_pending=9,shop_pending=9,hand=5,reported=5,finish_shop=function() finishes=finishes+1 end},
        pot={settled=function() return true end,busy=function() return false end},dice={busy=function() return false end},donation={busy=function() return false end},notice=function() end,ui={}}
    local A=dofile(ROOT..'/game/admin.lua'); assert(A.allowed()); A.toggle(); assert(BT.ui.screen=='admin'); A.toggle(); assert(not BT.ui.screen)
    A.update(); A.update(); assert(finishes==1 and resyncs==1 and not BT.game.entry_pending and not BT.game.shop_pending and BT.game.hand==5 and BT.game.reported==5)
    BT.steam.available=function() return {id='76561198000000002'} end; assert(not A.allowed()); A.toggle(); assert(not BT.ui.screen)
end)
test('slash opens the owner panel while text inputs keep normal typing behavior',function()
    local fallback=0; local noop=function() end
    G={FUNCS={},CONTROLLER={}}; love={graphics={},keyboard={isDown=function() return false end},keypressed=function() fallback=fallback+1 end}
    SMODS={load_file=function(path) return assert(loadfile(ROOT..'/'..path)) end}
    BT.id='BalatroTogether'; BT.config={}; BT.active=function() return false end; BT.persist=noop
    BT.dice={}; BT.steam.available=function() return {id=S.Admin.OWNER} end
    BT.admin=dofile(ROOT..'/game/admin.lua'); BT.ui=dofile(ROOT..'/ui/interface.lua'); BT.ui.install()
    love.keypressed('/'); assert(BT.ui.screen=='admin'); love.keypressed('/'); assert(not BT.ui.screen)
    BT.ui.screen='settings'; BT.ui.focus='username'; love.keypressed('/'); assert(BT.ui.screen=='settings')
    BT.ui.screen=nil; BT.ui.focus=nil; G.CONTROLLER.text_input_hook={}; love.keypressed('/'); assert(not BT.ui.screen and fallback==1)
    G.CONTROLLER.text_input_hook=nil; BT.steam.available=function() return {id='76561198000000002'} end; love.keypressed('/'); assert(not BT.ui.screen and fallback==2)
end)
test('native menus suppress HUD drawing and stale hits while retaining native mouse and scroll input',function()
    local native,stale=0,0
    local function input() native=native+1 end
    G={FUNCS={},CONTROLLER={},OVERLAY_MENU={}}
    love={graphics={},mouse={},mousepressed=input,mousereleased=input,wheelmoved=input}
    SMODS={load_file=function(path) return assert(loadfile(ROOT..'/'..path)) end}
    local U=dofile(ROOT..'/ui/interface.lua');U.install()
    U.hits={{x=0,y=0,w=100,h=100,fn=function() stale=stale+1 end}}
    U.modal={x=0,y=0,scale=1};U.inspect_rect={x=0,y=0,w=100,h=100};U.blind_rect={};U.fields={'old'}
    love.mousepressed(10,10,1);love.mousereleased(10,10,1);love.wheelmoved(0,1)
    assert(native==3 and stale==0,'An open native menu must bypass old Together hit regions')
    U.draw() -- Graphics has no methods: no HUD, toast or inspector may draw.
    assert(#U.hits==0 and #U.fields==0 and not U.modal and not U.inspect_rect and not U.blind_rect)
    G.OVERLAY_MENU=nil
    U.hits={{x=0,y=0,w=100,h=100,fn=function() stale=stale+1 end}}
    love.mousepressed(10,10,1);assert(stale==1,'Together controls return after the native menu closes')
end)
print('TOTAL '..count..' ADMIN ACCOUNT/RECOVERY TESTS PASSED')
