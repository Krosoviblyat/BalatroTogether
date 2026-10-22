-- Regression for the real-client failure: chip easing runs after the state
-- method is entered. The adapter must append its sample to the native queue.
local queue,actions={},{}
local cashouts=0
G={FUNCS={},SETTINGS={paused=false},CONTROLLER={locks={}},GAME={chips=0,current_round={hands_left=3}},
    STATES={DRAW_TO_HAND=3},STATE_COMPLETE=false,hand={cards={1}},deck={cards={1}},
    E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end}}
Game={update_hand_played=function() end}
G.FUNCS.cash_out=function() cashouts=cashouts+1 end
Event=function(t) return t end
end_round=function() end
BT={state={round=1,phase='blind',score=0,target=10000,players={['1']={exhausted=false}}},
    active=function() return true end,notice=function() end,
    client={id=1,connected=true,action=function(kind,data) actions[#actions+1]={kind=kind,data=data} end}}
local bridge=dofile(ROOT..'/game/bridge.lua')
bridge.started=true; bridge.round=1; bridge.hand=1; bridge.lastchips=0; bridge.reported=0
bridge.install()
Game.update_hand_played({},0.01)
assert(#actions==0,'Score sampled before queued animations finished')
assert(#queue==1,'Resolution event must be enqueued exactly once')
G.GAME.chips=12345
queue[1].func()
assert(actions[1].kind=='score' and actions[1].data.amount==12345)
assert(actions[2].kind=='idle')
print('PASS native event-queue score boundary regression')
BT.state.phase='shop'; bridge.finished=bridge.round
G.STATES.ROUND_EVAL=8; G.STATE=8; G.round_eval={}
G.FUNCS.cash_out({}); G.FUNCS.cash_out({})
assert(cashouts==1 and bridge.evaluated_round==bridge.round,'Cash-out must record native completion once')
print('PASS native cash-out completion is captured once even on repeated clicks')
BT.state.winner=true; BT.state.endless=true; BT.state.ante=8; BT.state.blind_index=3
local native_wins={}
bridge.refs.end_round=function() native_wins[#native_wins+1]=G.GAME.won==true end
G.GAME.won=false; bridge.finish_round()
assert(native_wins[1],'Endless must suppress the native victory decision before its queued evaluation')
BT.state.endless=false; G.GAME.won=false; bridge.finish_round()
assert(not native_wins[2],'Explicit finite runs must retain normal victory behavior')
BT.state.endless=true; BT.state.winner=false; G.GAME.won=false; bridge.finish_round()
assert(not native_wins[3],'A lost final boss must not be marked won')
print('PASS both native completion paths prepare endless before the victory decision')
return 3
