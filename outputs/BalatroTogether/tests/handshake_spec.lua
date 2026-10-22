local Session=dofile(ROOT..'/core/session.lua')
number_format=tostring
local passed=0
local function test(name,fn) fn(); passed=passed+1; print('PASS '..name) end
local function fixture(phase)
    local s=Session.new{intended=2,name='Host'}; s:join('Guest','guest'); s.run_id=1; s.round=1; s.ante=1; s.blind_index=1
    s.phase=phase or 'shop'; s.target=635; s.winner=s.phase=='shop' and true or nil
    s.proposal={key='bl_small',ante=1,index=1}; s.players[1].entered=true
    G={STAGES={RUN=1},STAGE=1,STATES={BLIND_SELECT=7,SELECTING_HAND=1,ROUND_EVAL=8},STATE=7,
        SETTINGS={paused=false},CONTROLLER={locks={}},E_MANAGER={queues={base={}}},blind_select={},
        GAME={round_resets={ante=1},blind_on_deck='Big',current_round={hands_left=4,discards_left=3},dollars=4,
            blind={config={blind={key='bl_small'}}}},hand={cards={1}},deck={cards={1}}}
    local attempts,callbacks={},{}
    BT={state=s:snapshot(2),active=function() return true end,notice=function() end,config={},ui={},json={encode=function() return '{}' end},
        client={id=2,clock=1,connected=true},donation={busy=function() return false end,reset=function() end},bots={}}
    local b=dofile(ROOT..'/game/bridge.lua'); b.reset(); b.started=true; b.run_id=1; b.round=1; b.finished=1; b.started_round=1
    local reject,defer=false,false
    BT.client.action=function(kind,data,callback)
        local seq=s.players[2].ack+1; attempts[#attempts+1]={kind=kind,data=data}
        local function deliver()
            local copy=Session.copy(data); if reject then copy.ante=99; reject=false end
            local ok,err=s:apply(2,{seq=seq,run=1,kind=kind,data=copy}); BT.state=s:snapshot(2)
            if callback then callback(ok,err) end
        end
        if defer then callbacks[#callbacks+1]=deliver else deliver() end
        return seq
    end
    return s,b,attempts,callbacks,function(r,d) reject=r; defer=d end
end
test('native next-blind position completes shop even if the adapter missed the cash-out frame',function()
    local s,b,attempts=fixture(); assert(not b.evaluated_round)
    assert(b.finish_shop(false)); assert(#attempts==1 and s.players[2].shop_done==1 and s.players[2].ready)
end)
test('a rejected shop completion retries instead of permanently latching a human in waiting',function()
    local s,b,attempts,_,mode=fixture(); mode(true,false)
    b.finish_shop(false); assert(not s.players[2].ready and not b.shop_pending)
    BT.client.clock=2; b.finish_shop(false); assert(#attempts==2 and s.players[2].shop_done==1 and s.players[2].ready)
end)
test('pending shop acknowledgement is bounded and a rejected delayed request can recover',function()
    local s,b,attempts,callbacks,mode=fixture(); mode(true,true)
    b.finish_shop(false); BT.client.clock=2; b.finish_shop(false); assert(#attempts==1)
    callbacks[1](); assert(not b.shop_pending); mode(false,false)
    b.finish_shop(false); assert(#attempts==2 and s.players[2].ready)
end)
test('explicit next-blind ready recovers waiting while a human can still unready to trade',function()
    local s,b,attempts=fixture(); b.finish_shop(false)
    s:apply(2,{seq=s.players[2].ack+1,run=1,kind='ready',data={ready=false}}); BT.state=s:snapshot(2)
    BT.client.clock=2; b.finish_shop(false); assert(#attempts==1 and not s.players[2].ready)
    b.ready(); assert(#attempts==2 and s.players[2].ready)
end)
test('wrong native position, open shop and unsettled events cannot bypass shop completion',function()
    local _,b,attempts=fixture(); G.GAME.blind_on_deck='Small'; assert(not b.finish_shop(true))
    G.GAME.blind_on_deck='Big'; G.shop={}; assert(not b.finish_shop(true)); G.shop=nil
    G.E_MANAGER.queues.base={{complete=false,blocking=true}}; assert(not b.finish_shop(true)); assert(#attempts==0)
end)
test('a rejected native blind-entry acknowledgement retries and releases the shared start barrier',function()
    local s,b,attempts,_,mode=fixture('starting'); G.STATE=1; G.GAME.blind_on_deck='Small'; mode(true,false)
    b.update(.1); assert(s.phase=='starting' and not s.players[2].entered and not b.entry_pending)
    BT.client.clock=2; b.update(.1); assert(s.phase=='blind' and s.players[2].entered)
    local entries=0; for _,a in ipairs(attempts) do if a.kind=='entered' then entries=entries+1 end end; assert(entries==2)
end)
print('TOTAL '..passed..' NATIVE HANDSHAKE TESTS PASSED')
