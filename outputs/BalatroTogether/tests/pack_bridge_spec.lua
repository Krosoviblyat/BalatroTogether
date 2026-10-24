local calls,actions=0,{}
G={FUNCS={use_card=function() calls=calls+1;return 'native pack' end},CONTROLLER={locks={}},SETTINGS={},GAME={},STATES={}}
Game={update_hand_played=function() end};end_round=function() end
BT={active=function() return true end,notice=function() end,compat={allowed=function(c) return not (c and c.blocked) end},
 state={round=1,phase='prepare',players={['1']={ready=false}}},
 client={id=1,action=function(k,d) actions[#actions+1]={kind=k,data=d} end}}
local b=dofile(ROOT..'/game/bridge.lua');b.started=true;b:install()
local tag={from_tag=true,ability={set='Booster'},config={center={}}}
for _,phase in ipairs({'prepare','skipping','shop'}) do
 BT.state.phase=phase
 assert(G.FUNCS.use_card{config={ref_table=tag}}=='native pack')
end
assert(calls==3 and #actions==0)
print('PASS native free tag packs open during prepare, skip and shop without a combat busy request')
G.pack_cards={};G.booster_pack={};BT.state.phase='prepare';BT.state.players['1'].ready=true
local choice={area=G.pack_cards,config={center={}}}
assert(G.FUNCS.use_card{config={ref_table=choice}}=='native pack')
assert(#actions==1 and actions[1].kind=='ready' and actions[1].data.ready==false)
print('PASS native pack choices work between blinds and clear an obsolete ready flag')
for _,phase in ipairs({'saving','resuming','starting','defeat'}) do
 BT.state.phase=phase;G.FUNCS.use_card{config={ref_table=tag}};G.FUNCS.use_card{config={ref_table=choice}}
end
assert(calls==4)
BT.state.phase='prepare';choice.config.center.blocked=true;G.FUNCS.use_card{config={ref_table=choice}}
G.booster_pack=nil;choice.config.center.blocked=false;G.FUNCS.use_card{config={ref_table=choice}}
assert(calls==4)
print('PASS pack exception does not unlock checkpoint mutation, blocked progression cards or ordinary between-blind consumables')
return 3
