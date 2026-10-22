local M=dofile(ROOT..'/core/session.lua')
local json=dofile(ROOT..'/vendor/json.lua')
local notices,channels,token_counter={}, {},0
local function channel(name)
    if not channels[name] then channels[name]={items={},push=function(self,v) self.items[#self.items+1]=v end,pop=function(self) return table.remove(self.items,1) end} end
    return channels[name]
end
love={math={random=function(a) return a end},timer={getTime=function() return 1 end},
    data={hash=function() token_counter=token_counter+1; return string.format('%064x',token_counter) end,encode=function(_,_,s) return s end},
    thread={getChannel=channel,newThread=function() return {start=function() end,getError=function() end} end}}
NFS={read=function() return '-- worker stub' end}
BT={root='',version='test-pin',Session=M,json=json,config={port='24872',username='Host',intended_players=4,seed='',deck='b_red',address='127.0.0.1'},
    ui={},game={reset=function() end},steam={name=function() end},persist=function() end,notice=function(v) notices[#notices+1]=v end}
local C=dofile(ROOT..'/net/client.lua'); BT.client=C
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function host(pin)
    BT.config.host_pin=pin; BT.config.pin='999999'; C.host(); assert(C.model and C.connected)
    return C.model
end
local function event(t) C.output:push(t); C.update(0.2) end
local function hello(id,pin,resume) event{type='line',id=id,line=json.encode{type='hello',protocol=1,version=BT.version,pin=pin,resume=resume,name='Friend'}} end
local function messages(id)
    local out={}; for _,e in ipairs(C.input.items) do if e.type=='send' and e.id==id then out[#out+1]=json.decode(e.line) end end; return out
end
local function has(id,kind)
    for _,m in ipairs(messages(id)) do if m.type==kind then return m end end
end

test('host honors a custom six-digit PIN including leading zeros',function()
    host('001234'); assert(C.pin=='001234' and BT.config.pin=='001234' and BT.state.room_pin=='001234')
end)
test('blank host PIN generates six digits independently of the join field',function()
    host(''); assert(C.pin:match('^%d%d%d%d%d%d$') and C.pin~='999999' and BT.config.host_pin=='')
end)
test('invalid host PIN cannot replace or disconnect an existing room',function()
    local model=host('001234')
    for _,pin in ipairs({'123','1234567','12a456',' 123456',123456}) do
        BT.config.host_pin=pin; C.host(); assert(C.model==model and C.connected and C.pin=='001234')
        assert(not C.set_pin(pin)); assert(C.pin=='001234')
    end
end)
test('live PIN rotation keeps seats and broadcasts the new PIN only to authenticated peers',function()
    local model=host('001234'); hello(10,'001234'); assert(C.peers[10]==2)
    local seat=model.players[2]; assert(C.set_pin('009876')); C.update(0.2)
    assert(C.model==model and model.players[2]==seat and C.peers[10]==2 and seat.connected)
    local found=false; for _,m in ipairs(messages(10)) do if m.state and m.state.room_pin=='009876' then found=true end end; assert(found)
end)
test('new friends need the current PIN and wrong PIN gets no private snapshot',function()
    host('001234'); C.set_pin('009876'); hello(20,'001234')
    assert(not C.peers[20] and has(20,'error') and not has(20,'welcome') and not has(20,'state'))
    hello(21,'009876'); assert(C.peers[21]==2 and has(21,'welcome').state.room_pin=='009876')
end)
test('a disconnected existing seat reconnects with its secret after the PIN changes',function()
    local model=host('001234'); hello(30,'001234'); local token=model.players[2].token
    model.phase='prepare'; C.set_pin('009876'); event{type='closed',id=30}
    assert(not model.players[2].connected)
    hello(31,'001234',token); assert(C.peers[31]==2 and model.players[2].connected)
    assert(has(31,'welcome').state.room_pin=='009876')
    hello(32,'001234',string.rep('f',64)); assert(not C.peers[32] and has(32,'error') and not has(32,'welcome'))
end)
test('client updates its PIN from host snapshots before the next reconnect handshake',function()
    local model=host('001234'); hello(40,'001234'); local token=model.players[2].token; local state=model:snapshot(2); state.room_pin='009876'
    BT.config.pin='001234'; C.join(); event{type='line',id=1,line=json.encode{type='welcome',id=2,resume=token,state=state}}
    assert(C.pin=='009876' and BT.config.pin=='009876')
    event{type='closed',id=1}; C.update(2.1); event{type='connected',id=1}
    local request=has(1,'hello'); assert(request and request.pin=='009876' and request.resume==token)
end)
test('guests cannot rotate a host PIN',function()
    assert(not C.model); local pin=C.pin; assert(not C.set_pin('111111')); assert(C.pin==pin)
end)
print('TOTAL '..count..' PIN TESTS PASSED')
return count
