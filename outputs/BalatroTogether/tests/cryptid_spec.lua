-- Uses the pinned, real Amulet arithmetic library, not a simulated big-number type.
package.path=AMULET_ROOT..'/?.lua;'..package.path
Big=require('big-num.omeganum')
local N=dofile(ROOT..'/core/numbers.lua')
local J=N.codec(dofile(ROOT..'/vendor/json.lua'))
local S=dofile(ROOT..'/core/session.lua'); S.Numbers=N
S.Donations=dofile(ROOT..'/core/donations.lua'); S.Donations.Numbers=N
local count=0; local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function big(x) return Big:create(x) end
local function act(m,id,k,d) return m:apply(id,{seq=m.players[id].ack+1,run=m.run_id,kind=k,data=d}) end
test('real Amulet cdata scores roundtrip through bounded JSON beyond native infinity',function()
    for _,value in ipairs({'1e1000','ee100','10^^8','-1e1000'}) do
        local x=big(value); local y=J.decode(J.encode({value=x})).value
        assert(x==y and N.big(y) and N.finite(y))
    end
    assert(J.decode(J.encode({v=big(25)})).v==25)
end)
test('native save codec retains small and huge Amulet cdata instead of reducing its type',function()
    local codec=dofile(ROOT..'/core/save_codec.lua');local raw=dofile(ROOT..'/vendor/json.lua')
    for _,value in ipairs({'0','1','4','-4','1e1000','ee100'}) do
        local x=big(value);local y=codec.decode(codec.encode({value=x},raw,N),raw,N).value
        assert(N.big(y) and x==y,'Native Big type/value changed: '..value)
    end
end)
test('hostile big-number envelopes are rejected before invoking the arithmetic backend',function()
    for _,payload in ipairs({
        {__bt_omega=2,sign=1,values={'100','2'}},
        {__bt_omega=1,sign=0,values={'100'}},
        {__bt_omega=1,sign=1,values={'1e9999'}},
        {__bt_omega=1,sign=1,values={'1','-2'}},
        {__bt_omega=1,sign=1,values={'1','2.5'}},
        {__bt_omega=1,sign=1,values={'100','2'},code='os.execute()'}
    }) do assert(not pcall(N.unpack,payload)) end
    local payload={__bt_omega=1,sign=1,values={}};for i=1,65 do payload.values[i]='1' end
    assert(not pcall(N.unpack,payload)); assert(not pcall(J.encode,{v=Big.constants.POSITIVE_INFINITY}))
end)
test('two huge contributions sum once and meet a huge shared target with exact acknowledgements',function()
    local m=S.new{intended=2};m:join('Guest','guest');m.phase='prepare';m.run_id=1;m.scaling=1
    assert(m:set_proposal(1,{base=big('1e1000'),ante=1,index=1,key='bl_small'}))
    for _,p in pairs(m.players) do p.ready=true end;m:begin_blind()
    for _,p in pairs(m.players) do p.entered=true end;m:advance()
    for id=1,2 do assert(act(m,id,'busy',{round=1})) end
    for id=1,2 do assert(act(m,id,'score',{round=1,hand=1,amount=big('2e1000'),name='Cryptid hand'})) end
    assert(m.score==big('4e1000')); assert(m.phase=='blind')
    for id=1,2 do assert(act(m,id,'idle',{round=1,exhausted=false})) end
    assert(m.phase=='shop' and m.winner and m.players[2].highest==big('2e1000'))
    local s=J.decode(J.encode(m:snapshot(2))); assert(s.score==m.score and s.target==m.target)
end)
test('negative, infinite and nonnumeric scores cannot corrupt a Cryptid session',function()
    local m=S.new{intended=1}; m.phase='blind';m.run_id=1;m.round=1;m.target=big('ee100');m.players[1].busy=true
    for _,v in ipairs({big('-1e1000'),Big.constants.NaN,Big.constants.POSITIVE_INFINITY,1e308,{array={1000,1}}}) do
        assert(not act(m,1,'score',{round=1,hand=1,amount=v,name='bad'}))
    end
    assert(m.score==0 and m.players[1].completed==0)
    assert(N.score(big('1e308')) and not N.score(1e308))
end)
test('UI score ratios are ordinary bounded numbers and huge values retain readable formatting',function()
    assert(type(N.ratio(big('1e1000'),big('2e1000')))=='number')
    assert(math.abs(N.ratio(big('1e1000'),big('2e1000'))-.5)<1e-10)
    assert(N.ratio(big('ee100'),big('1e1000'))==1 and N.ratio(5,0)==0)
    assert(#N.format(big('ee100'))>1)
end)
test('Cryptid cards retain native huge ability values and edition state in escrow',function()
    local c={center='j_cry_googol_play',kind='Joker',name='cry-Googol Play Card',
        ability={set='Joker',name='cry-Googol Play Card',extra={Xmult=big('1e1000'),odds=1}},
        edition='cry_mosaic',edition_data={key='e_cry_mosaic',type='cry_mosaic',cry_mosaic=true,extra=big('1e900')}}
    local card=assert(S.Donations.card(c)); local wire=J.decode(J.encode(card));assert(wire.ability.extra.Xmult==big('1e1000'))
    assert(wire.edition_data.extra==big('1e900') and S.Donations.card(wire))
    c.edition='cry_double_sided';assert(not S.Donations.card(c))
end)
test('Cryptid Code cards are transferable data while executable and cyclic fields are refused',function()
    local c={center='c_cry_multiply',kind='Code',ability={set='Code',name='Multiply'},edition=''}
    assert(S.Donations.card(c));c.ability.extra=function() end;assert(not S.Donations.card(c))
    c.ability.extra=c.ability;assert(not S.Donations.card(c))
end)
test('a calculating Amulet coroutine cannot publish an early hand score',function()
    local calls=0
    BT={numbers=N,state={round=1},active=function() return true end,notice=function() end,client={action=function() calls=calls+1 end}}
    G={GAME={chips=big('1e1000'),current_round={hands_left=3}},hand={cards={1}},deck={cards={1}}}
    local b=dofile(ROOT..'/game/bridge.lua');b.started=true;b.round=1;b.hand=1;b.reported=0;b.lastchips=0
    Talisman={scoring_coroutine={}};assert(b.capture_score()==false and calls==0 and b.reported==0)
    Talisman.scoring_coroutine=nil;assert(b.capture_score() and calls==2 and b.reported==1)
    assert(b.capture_score() and calls==2);Talisman=nil
end)
test('compatibility signatures reject content/rules changes while allowing personal music settings',function()
    G={P_CENTERS={},SETTINGS={profile=1},PROFILES={{cry_gameset='mainline'}}}
    SMODS={Mods={Cryptid={version='0.5.17c'},Amulet={version='3.6.1'}}}
    love={data={hash=function(_,s) return s end,encode=function(_,_,s) return s end}}
    BT={Session=S};Cryptid_config={Cryptid={jimball_music=true},experimental=false}
    local c=dofile(ROOT..'/game/compat.lua');local first=c.signature()
    Cryptid_config.Cryptid.jimball_music=false;assert(c.signature()==first)
    G.PROFILES[1].cry_gameset='madness';assert(c.signature()~=first);G.PROFILES[1].cry_gameset='mainline'
    SMODS.Mods.Cryptid.version='other';assert(c.signature()~=first)
end)
test('available Cryptid decks enter the selector and disabled or foreign decks stay out',function()
    G.P_CENTERS={b_cry_misprint={set='Back',name='Misprint',mod={id='Cryptid'}},
        b_other={set='Back',mod={id='Other'}},b_cry_hidden={set='Back',mod={id='Cryptid'},cry_disabled=true}}
    local c=dofile(ROOT..'/game/compat.lua');c.register_decks();c.register_decks()
    assert(S.valid_deck('b_cry_misprint') and not S.valid_deck('b_other') and not S.valid_deck('b_cry_hidden'))
end)
test('Cryptid ante modifiers cannot split the party schedule and remain native in single player',function()
    local active=true
    BT={active=function() return active end,notice=function() end}
    SMODS.calculate_context=function(context) return {modify=context.modify_ante and 7 or nil,other=true} end
    local c=dofile(ROOT..'/game/compat.lua');c.install()
    assert(SMODS.calculate_context{modify_ante=1,ante_end=true}.modify==1)
    assert(SMODS.calculate_context{modify_ante=-1}.modify==0)
    assert(SMODS.calculate_context{other=true}.other)
    active=false;assert(SMODS.calculate_context{modify_ante=1,ante_end=true}.modify==7)
end)
test('individual rewind and skip effects are guarded only during co-op',function()
    local active=true;local uses=0
    BT={Session=S,active=function() return active end,notice=function() end}
    G.P_CENTERS={c_cry_revert={key='c_cry_revert',use=function() uses=uses+1 end}}
    local c=dofile(ROOT..'/game/compat.lua');c.register_decks()
    assert(not c.allowed(G.P_CENTERS.c_cry_revert));assert(not G.P_CENTERS.c_cry_revert.in_pool())
    G.P_CENTERS.c_cry_revert.use();assert(uses==0)
    active=false;G.P_CENTERS.c_cry_revert.use();assert(uses==1 and G.P_CENTERS.c_cry_revert.in_pool())
end)
test('hidden companions bypass only Cryptid onboarding and personal notifications',function()
    local intros,notifications=0,0
    G.FUNCS={cry_intro_controller=function() intros=intros+1 end}
    Cryptid={notification_overlay=function() notifications=notifications+1 end}
    BT={bots={config={}}}
    local c=dofile(ROOT..'/game/compat.lua');c.install()
    G.FUNCS.cry_intro_controller();Cryptid.notification_overlay('jimball')
    assert(intros==0 and notifications==0 and G.PROFILES[1].cry_intro_complete)
    BT.bots.config=nil;G.FUNCS.cry_intro_controller();Cryptid.notification_overlay('jimball')
    assert(intros==1 and notifications==1)
end)
test('only a hidden bot can dismiss a normal unlock notice, never an Amulet calculation overlay',function()
    local dismissed=0;local button='continue_unlock'
    G.FUNCS.continue_unlock=function() dismissed=dismissed+1 end
    G.OVERLAY_MENU={get_UIE_by_ID=function() return {config={button=button}} end}
    BT={bots={config={}}}
    local c=dofile(ROOT..'/game/compat.lua')
    assert(c.dismiss_bot_notice() and dismissed==1)
    button='tal_abort';assert(not c.dismiss_bot_notice() and dismissed==1)
    button='continue_unlock';BT.bots.config=nil;assert(not c.dismiss_bot_notice() and dismissed==1)
end)
print('TOTAL '..count..' PINNED AMULET/CRYPTID TESTS PASSED')
