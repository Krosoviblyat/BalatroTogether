local written={};local original_calls=0
love={filesystem={createDirectory=function() return true end,write=function(path,data) written[path]=data;return true end},
    errorhandler=function(message) original_calls=original_calls+1;return 'original '..message end}
BT={version='test',state={phase='blind',ante=7,round=21,score=-70,target=1000,players={{token='PRIVATE_TOKEN',name='PRIVATE_NAME'}},room_pin='PRIVATE_PIN'}}
G={STATE=1,GAME={blind={config={blind={key='bl_cry_chromatic'}}}}};SMODS={Mods={Amulet={version='3.6.1'}}}
local d=dofile(ROOT..'/game/diagnostics.lua');d.install()
assert(love.errorhandler('test crash')=='original test crash' and original_calls==1)
local text=assert(written['TogetherReports/last-crash.txt'])
assert(text:find('test crash',1,true) and text:find('bl_cry_chromatic',1,true) and text:find('Amulet: 3.6.1',1,true))
assert(not text:find('PRIVATE',1,true),'Report leaked private party data')
print('PASS crash reports preserve the native handler and contain boss context without party secrets')
love.filesystem.write=function() error('Disk unavailable') end
assert(love.errorhandler('still delegates')=='original still delegates' and original_calls==2)
print('PASS report I/O failure never replaces the real crash handler')
local notices,reports=0,0
BT={state={round=1},active=function() return true end,notice=function() notices=notices+1 end,
    diagnostics={record=function() reports=reports+1 end}}
G={GAME={chips=0/0,current_round={hands_left=3}}}
local b=dofile(ROOT..'/game/bridge.lua');b.started=true;b.round=1;b.hand=1;b.reported=0;b.lastchips=0
for i=1,20 do assert(b.capture_score()==false) end
assert(notices==1 and reports==1 and b.reported==0)
print('PASS invalid score is reported once per hand without publishing NaN')
return 3
