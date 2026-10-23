local M=dofile(ROOT..'/core/session.lua');M.Pot=dofile(ROOT..'/core/pot.lua');M.Dice=dofile(ROOT..'/core/dice.lua')
M.Vote=dofile(ROOT..'/core/skip_vote.lua');M.Save=dofile(ROOT..'/core/checkpoint.lua')
local Codec=dofile(ROOT..'/core/save_codec.lua');local json=dofile(ROOT..'/core/save_json.lua');local Editor=dofile(ROOT..'/core/text_input.lua')
local n=0;local function test(name,f) f();n=n+1;print('PASS '..name) end
local function room(count)
    local m=M.new{intended=count or 3,party_id=string.rep('a',32),token=string.rep('1',64)}
    for i=2,count or 3 do assert(m:join('Friend '..i,string.rep(tostring(i),64))) end
    m.phase='prepare';m.run_id=1
    for _,p in pairs(m.players) do p.native_safe=true;p.native_ante=1;p.native_index=1 end
    return m
end
local function action(m,id,kind,data) return m:apply(id,{seq=m.players[id].ack+1,run=m.run_id,kind=kind,data=data or {}}) end
local function vote(m,id,choice) return action(m,id,'skip_vote',{round=m.round,ante=m.ante,index=m.blind_index,choice=choice}) end
test('hold Backspace repeats locally and release stops without global keyboard repeat',function()
    local e=Editor.new{value='abcdefghijklmnopqrstuvwx'};e:key('backspace',false,false,false)
    for _=1,12 do e:update(.05,function() return true end) end
    assert(#e.value<20 and #e.value>0);local text=e.value;e:release('backspace');e:update(1,function() return true end);assert(e.value==text)
end)
test('UTF-8 selection, cursor editing, delete and clipboard preserve complete characters',function()
    local clip='';local e=Editor.new{value='aéZ',limit=24,clipboard=function(mode,t) if mode=='write' then clip=t else return clip end end}
    e:key('left');e:key('backspace');assert(e.value=='aZ');e:key('home');e:key('right',false,true);e:key('c',true);assert(clip=='a')
    e:key('a',true);e:write('éé');assert(e.value=='éé');e:key('home');e:key('delete');assert(e.value=='é')
    clip='ok';e:key('a',true);e:key('v',true);assert(e.value=='ok')
end)
test('text field limits never cut a UTF-8 codepoint or count OS repeats twice',function()
    local e=Editor.new{value='',limit=3};e:write('éé');assert(e.value=='é');e:key('backspace');assert(e.value=='')
    e:write('xyz');e:key('backspace',false,false,true);assert(e.value=='xyz')
end)
test('two of three human votes pass and every native skip must acknowledge before progression',function()
    local m=room();assert(vote(m,1,'yes'));assert(m.phase=='prepare' and m.skip_vote.needed==2)
    assert(vote(m,2,'yes'));assert(m.phase=='skipping' and m.blind_index==1 and m.round==0)
    local id=m.skip_order.id
    for i=1,2 do assert(action(m,i,'skip_done',{order=id,ante=1,index=2}));assert(m.phase=='skipping') end
    assert(action(m,3,'skip_done',{order=id,ante=1,index=2}));assert(m.phase=='prepare' and m.blind_index==2 and m.round==0)
    assert(m.pot.settled_round==nil and not m.players[1].dice_gold)
end)
test('a two-player tie plays and bots never cast or lower the human threshold',function()
    local m=room(4);m.players[4].bot=true
    assert(vote(m,1,'yes'));assert(m.skip_vote.needed==2 and m.skip_vote.total==3);assert(not vote(m,4,'yes'))
    local two=room(2);assert(vote(two,1,'yes'));assert(vote(two,2,'no'));assert(two.phase=='prepare' and not two.skip_vote)
end)
test('Boss, stale-position and unsafe-transfer votes are rejected',function()
    local m=room();m.blind_index=3;assert(not vote(m,1,'yes'));m.blind_index=1;m.players[1].native_index=2;assert(not vote(m,1,'yes'))
    m.players[1].native_index=1;m.players[2].transferring=true;assert(not vote(m,1,'yes'));assert(not m.skip_vote)
end)
test('disconnect and expiry cancel votes rather than silently changing the majority',function()
    local m=room();M.Vote.tick(m,10);vote(m,1,'yes');m:disconnect(3);M.Vote.tick(m,11);assert(not m.skip_vote)
    m.players[3].connected=true;vote(m,1,'yes');M.Vote.tick(m,32);assert(not m.skip_vote and m.phase=='prepare')
end)
test('an open vote cannot race a ready action into a native blind',function()
    local m=room();assert(m:set_proposal(1,{base=300,key='bl_small',ante=1,index=1}));vote(m,1,'yes')
    for i=1,3 do assert(action(m,i,'ready',{ready=true,ante=1,index=1,round=0})) end
    assert(m.phase=='prepare' and m.skip_vote)
end)
test('checkpoint freeze requires matching native positions and protects all transactions',function()
    local m=room();m.players[2].native_index=2;assert(not action(m,1,'save_begin'));m.players[2].native_index=1
    assert(not action(m,2,'save_begin'));assert(action(m,1,'save_begin',{leave=true}));assert(m.phase=='saving')
    assert(not action(m,2,'pot_deposit',{tx=1,amount=5,balance=30}));assert(not action(m,2,'ready',{ready=true}))
    m.checkpoint.uploads['1']='host';m.checkpoint.uploads['2']='guest';assert(not M.Save.commit(m,123))
    m.checkpoint.uploads['3']='third';assert(M.Save.commit(m,123));assert(m.phase=='prepare' and m.saved_leave==m.checkpoint.id)
end)
test('party model restores original seats, tokens, pots and progression behind an all-player barrier',function()
    local m=room();m.players[1].pot_credit=12;m.players[1].pot_received=12;m.players[1].personal_pot={bank=17};m.players[2].steam_id='76561198000000002'
    m.donation_data.items={};assert(M.Save.begin(m,1));for i=1,3 do m.checkpoint.uploads[tostring(i)]='hash' end;assert(M.Save.commit(m,100))
    local restored=M.Save.restore(M,m);assert(restored.phase=='resuming' and restored.players[1].connected and not restored.players[2].connected)
    assert(restored.players[1].personal_pot.bank==17 and restored.players[1].pot_received==12 and restored.players[2].steam_id=='76561198000000002')
    for i=2,3 do restored.players[i].connected=true end
    for i=1,3 do assert(action(restored,i,'restore_ready',{checkpoint=restored.resume_checkpoint,ante=1,index=1})) end
    assert(restored.phase=='prepare' and not restored.players[1].ready)
end)
test('failed checkpoint releases play without replacing the previous saved position',function()
    local m=room();assert(M.Save.begin(m,1));M.Save.cancel(m,'disk full');assert(m.phase=='prepare' and m.checkpoint.status=='failed' and m.checkpoint.error=='disk full')
    assert(m.checkpoint_position==M.Save.position(m))
end)
test('data-only save codec preserves numeric keys and shared table identity',function()
    local a={rank='A',ability={mult=20}};local input={GAME={cards={[1]=a,[7]=a},round=5},[11]='numeric key'}
    local result=Codec.decode(Codec.encode(input,json),json)
    assert(result[11]=='numeric key' and result.GAME.cards[1]==result.GAME.cards[7] and result.GAME.cards[1].ability.mult==20)
end)
test('save codec rejects executable/cyclic values, hostile references and deep JSON',function()
    assert(not pcall(Codec.encode,{fn=function() end},json));local cycle={};cycle.loop=cycle;assert(not pcall(Codec.encode,cycle,json))
    assert(not pcall(Codec.decode,string.rep('[',20)..string.rep(']',20),json))
    assert(not pcall(Codec.decode,'{"schema":1,"root":["t",1],"nodes":[[[["s","loop"],["t",1]]]]}',json))
end)
test('large checkpoint parsing collects temporary memory even when Balatro pauses automatic GC',function()
    local old=nuGC;nuGC=function() end
    local data={};for i=1,1600 do data[i]={index=i,name='A checkpoint card',effect={chips=30,mult=4,edition='holo'}} end
    collectgarbage('stop');local text=Codec.encode(data,json);local result=Codec.decode(text,json)
    collectgarbage('restart');nuGC=old
    assert(#result==1600 and result[1600].effect.mult==4)
end)
test('checkpoint JSON decodes long escaped native-build strings without quadratic concatenation',function()
    local payload=string.rep('"cards"\\"effects"\n',30000)
    local text=Codec.encode({builds={payload,payload}},json);local result=Codec.decode(text,json)
    assert(result.builds[1]==payload and result.builds[2]==payload)
end)
test('chunk assembly is bounded, duplicate-safe, order-independent and never accepts conflicting chunks',function()
    local text=string.rep('a',Codec.CHUNK)..'tail';local hash=string.rep('a',64);local b,data
    b,data=Codec.add_chunk(nil,{id='party-1',hash=hash,total=2,index=2,data='tail'});assert(not data)
    b,data=Codec.add_chunk(b,{id='party-1',hash=hash,total=2,index=2,data='tail'});assert(b.count==1)
    b,data=Codec.add_chunk(b,{id='party-1',hash=hash,total=2,index=1,data=text:sub(1,Codec.CHUNK)});assert(data==text)
    assert(not pcall(Codec.add_chunk,b,{id='party-1',hash=hash,total=2,index=2,data='evil'}))
    assert(not pcall(Codec.add_chunk,nil,{id='../bad',hash=hash,total=2,index=2,data='bad'}))
end)
test('retiring an absent saved seat releases the restoration barrier for the remaining party',function()
    local m=room();assert(M.Save.begin(m,1));for i=1,3 do m.checkpoint.uploads[tostring(i)]='hash' end;assert(M.Save.commit(m,100))
    local r=M.Save.restore(M,m);r.players[2].connected=true
    for i=1,2 do assert(action(r,i,'restore_ready',{checkpoint=r.resume_checkpoint,ante=1,index=1})) end
    assert(r.phase=='resuming');assert(r:drop(3));assert(r.phase=='prepare' and r.players[3].withdrawn)
end)
test('native starts wait for delayed tutorial characters and native menu wipes',function()
    local old=G;G={SETTINGS={paused=false},CONTROLLER={locks={}},E_MANAGER={}}
    local b=dofile(ROOT..'/game/bridge.lua');assert(b.can_start_native())
    G.OVERLAY_TUTORIAL={};assert(not b.can_start_native());G.OVERLAY_TUTORIAL={Jimbo={}};assert(not b.can_start_native())
    G.OVERLAY_TUTORIAL=nil;G.screenwipe={};assert(not b.can_start_native());G.screenwipe=nil
    G.SETTINGS.paused=true;assert(not b.can_start_native());G=old
end)
test('only the authorized owner may retire an absent seat during restoration',function()
    M.Admin=dofile(ROOT..'/core/admin.lua')
    local m=room();assert(M.Save.begin(m,1));for i=1,3 do m.checkpoint.uploads[tostring(i)]='hash' end;assert(M.Save.commit(m,100))
    local r=M.Save.restore(M,m);r.players[1].steam_id=M.Admin.OWNER;r.players[2].connected=true
    assert(not action(r,2,'admin_retire',{target=3}));assert(not r.players[3].withdrawn)
    for i=1,2 do assert(action(r,i,'restore_ready',{checkpoint=r.resume_checkpoint,ante=1,index=1})) end
    assert(action(r,1,'admin_retire',{target=3}));assert(r.phase=='prepare' and r.players[3].withdrawn)
    M.Admin=nil
end)
print('TOTAL '..n..' PARTY SAVE/VOTE/EDITOR TESTS PASSED')
