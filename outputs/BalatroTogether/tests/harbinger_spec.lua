local S=dofile(ROOT..'/core/session.lua');local H=dofile(ROOT..'/core/harbinger.lua')
H.Strategy=dofile(ROOT..'/bots/strategy.lua');S.Harbinger=H
local total=0
local function test(name,fn) fn();total=total+1;print('PASS '..name) end
local function act(s,id,k,d) return s:apply(id,{run=s.run_id,seq=s.players[id].ack+1,kind=k,data=d or {}}) end
local function room(n,stake)
 local s=S.new{intended=n or 1,quick_duel=true,boss_stake=stake or 1,boss_mode='harbinger'}
 for i=2,n or 1 do assert(s:join('Friend','token'..i)) end
 for id in pairs(s.players) do assert(act(s,id,'ready',{ready=true})) end
 assert(s:start('HARBINGR'));assert(s.blind_index==3)
 assert(s:set_proposal(1,{key=H.KEY,base=600,ante=1,index=3,boss=true}))
 for id in pairs(s.players) do assert(act(s,id,'ready',{ready=true,ante=1,index=3,round=0})) end
 for id in pairs(s.players) do assert(act(s,id,'entered',{ante=1,index=3,round=1,key=H.KEY})) end
 return s
end
local function score(s,id,amount,disabled)
 assert(act(s,id,'busy',{round=s.round}))
 local a={run=s.run_id,seq=s.players[id].ack+1,kind='score',data={round=s.round,hand=s.players[id].completed+1,amount=amount,name='Pair',boss_disabled=disabled}}
 assert(s:apply(id,a));assert(s:apply(id,a));assert(act(s,id,'idle',{round=s.round}));return a
end
local function tick(s,seconds,paused)
 for i=1,math.ceil(seconds/.05) do s.now=(s.now or 0)+.05;H.tick(s,s.now,paused) end
end
local function card(r,suit) return {rank=r,suit=suit or 'Spades',chips=r==14 and 11 or math.min(10,r)} end
test('Boss stakes are host-only, validated, and clear ready flags',function()
 local s=S.new{intended=2};assert(s:join('Friend','token2'));s.players[1].ready=true
 assert(not act(s,2,'boss_rules',{stake=4,mode='harbinger',quick=true}))
 assert(not act(s,1,'boss_rules',{stake=9,mode='harbinger',quick=true}))
 assert(act(s,1,'boss_rules',{stake=3,mode='harbinger',quick=true}));assert(s.boss_stake==3 and not s.players[1].ready)
end)
test('All four boss tiers scale only boss targets',function()
 for i,t in ipairs(H.tiers) do local s=room(1,i);assert(s.target==math.ceil(600*t.target));s.blind_index=1;assert(H.target(s,300)==300) end
end)
test('Actual poker chips, scoring subsets, wheel straight and hand levels are exact',function()
 local p=H.evaluate({card(14),card(14,'Hearts'),card(9),card(5),card(2)},0)
 assert(p.name=='Pair' and p.chips==32 and p.mult==2 and p.raw==64 and #p.scoring==2)
 local w=H.evaluate({card(14),card(2),card(3),card(4),card(5)},0)
 assert(w.name=='Straight Flush' and w.chips==125 and w.raw==1000)
 local l=H.evaluate({card(14),card(14,'Hearts'),card(9),card(5),card(2)},3)
 assert(l.chips==77 and l.mult==5 and l.raw==385)
end)
test('A seeded independent deck picks exactly five cards and never leaks through snapshots',function()
 local a,b=room(),room();score(a,1,100);score(b,1,100)
 assert(#a.harbinger.pending.cards==5 and #a.harbinger_private.hand==8)
 for i,c in ipairs(a.harbinger.pending.cards) do assert(c.id==b.harbinger.pending.cards[i].id) end
 assert(a:snapshot().harbinger_private==nil and a:snapshot().harbinger.pending.cards[1].id)
end)
test('Damage lands once at impact and leaves gross player contributions intact',function()
 local s=room();score(s,1,400);local hit=s.harbinger.pending;tick(s,2)
 assert(s.score==400 and not hit.hit);tick(s,.15)
 assert(hit.hit and s.score==400-math.min(400,hit.damage));assert(s.players[1].contribution==400)
 local damage=s.harbinger.damage;tick(s,.4);assert(s.harbinger.damage==damage)
end)
test('Crossing the target cannot win before the counter; damaged teams can play again',function()
 local s=room();score(s,1,600);assert(s.phase=='blind');tick(s,2.9)
 assert(s.phase=='blind' and s.score<600 and not H.blocks(s));assert(act(s,1,'busy',{round=1}))
end)
test('Win resolves only after a survived reply and rejected replays cannot spawn counters',function()
 local s=room();local action=score(s,1,100000);assert(s.phase=='blind');assert(s:apply(1,action));assert(s.harbinger.turn==1)
 tick(s,2.9);assert(s.phase=='shop' and s.winner and s.harbinger.turn==1)
end)
test('Concurrent in-flight hands queue exactly one counter per seat and floor team chips at zero',function()
 local s=room(4)
 for id=1,4 do assert(act(s,id,'busy',{round=1})) end
 for id=1,4 do assert(act(s,id,'score',{round=1,hand=1,amount=1,name='High Card'}));assert(act(s,id,'idle',{round=1})) end
 assert(#s.harbinger.queue==3 and s.harbinger.turn==1)
 assert(not act(s,1,'busy',{round=1}));tick(s,12)
 assert(s.score==0 and s.harbinger.turn==4 and #s.harbinger.history==3 and not H.blocks(s))
end)
test('Disconnect and native pause freeze the counter without duplicating damage on resume',function()
 local s=room(2);score(s,1,200);tick(s,.4);local age=s.harbinger.pending.age
 tick(s,3,true);assert(s.harbinger.pending.age==age);s:disconnect(2);tick(s,3);assert(s.harbinger.pending.age==age)
 assert(s:reconnect('token2'));tick(s,3);assert(s.harbinger.last.hit and not H.blocks(s))
end)
test('A disabled native boss does not counter and restart clears every old attack',function()
 local s=room();score(s,1,10,true);assert(not H.blocks(s) and s.harbinger.turn==0)
 score(s,1,10);assert(H.blocks(s));assert(s:restart(1));assert(s.harbinger==nil and s.harbinger_private==nil and s.blind_index==3)
end)
test('Independent boss deck reshuffles without duplicating held cards',function()
 local s=room();s.target=1e20
 for i=1,30 do score(s,1,100);tick(s,2.9)
  local p=s.harbinger_private;local seen={};local n=0
  for _,pile in ipairs({p.deck,p.discard,p.hand}) do for _,c in ipairs(pile) do assert(not seen[c.id]);seen[c.id]=true;n=n+1 end end
  assert(n==52)
 end
 assert(s.harbinger_private.shuffles>0)
end)
test('First boss and native finales never spawn Harbinger in either normal mode',function()
 for _,mode in ipairs({'mixed','harbinger'}) do for i=1,1000 do
  local s={phase='prepare',seed='SPAWN'..i,round=0,boss_mode=mode,quick_duel=false}
  assert(not H.should_spawn(s,1,8) and not H.should_spawn(s,8,8) and not H.should_spawn(s,16,8))
  assert(not H.should_spawn(s,4,4))
 end end
end)
test('Mixed encounters are deterministically 20 percent without rerolling on inspection',function()
 local hits=0
 for i=1,10000 do local s={phase='prepare',seed='SEED'..i,round=0,boss_mode='mixed'}
  local a=H.should_spawn(s,2,8);assert(a==H.should_spawn(s,2,8));if a then hits=hits+1 end
 end
 assert(hits>=1850 and hits<=2150,'Unexpected hit rate: '..hits)
end)
test('Quick Duel is explicit opt-in while full forced mode still protects the first boss',function()
 local s={phase='prepare',seed='TEST',round=0,boss_mode='harbinger',quick_duel=false}
 assert(not H.should_spawn(s,1,8) and H.should_spawn(s,2,8));s.quick_duel=true;assert(H.should_spawn(s,1,8))
 s.phase='lobby';assert(not H.should_spawn(s,1,8))
end)
test('Old forced-duel settings migrate once without changing unrelated player preferences',function()
 local c={boss_mode='harbinger',quick_duel=true,username='Friend',reduced_motion=true}
 assert(H.migrate_config(c) and c.boss_mode=='mixed' and c.quick_duel==false and c.harbinger_spawn_revision==2)
 assert(c.username=='Friend' and c.reduced_motion);c.quick_duel=true;c.boss_mode='harbinger'
 assert(not H.migrate_config(c) and c.quick_duel and c.boss_mode=='harbinger')
end)
test('Fresh installs start a full mixed run with a fresh seed',function()
 local c=dofile(ROOT..'/config.lua');assert(c.boss_mode=='mixed' and not c.quick_duel and c.seed=='')
 local s=S.new{intended=1,boss_mode=c.boss_mode,quick_duel=c.quick_duel};assert(act(s,1,'ready',{ready=true}));assert(s:start('SPAWN2'));assert(s.blind_index==1)
end)
test('Harbinger damage never heals or consumes existing negative native score debt',function()
 local s=room();score(s,1,-70);tick(s,2.9)
 assert(s.score==-70 and s.harbinger.last.removed==0 and s.harbinger.damage==0)
 assert(not H.blocks(s) and act(s,1,'busy',{round=1}))
end)
print('TOTAL '..total..' HARBINGER TESTS PASSED')
