local count=0;local function test(name,f) f();count=count+1;print('PASS '..name) end
local local_id='76561198000000001';local lobby='109775240123456789';local other='109775240123456799'
local function fixture(known)
    local data={};local joins={};local joinable={};local choices={100000,100001,100002};local pick=0
    local e=setmetatable({arg={},G={},BT={id='BalatroTogether',version='code-test',ui={},config={}}},{__index=_G})
    local n={valid_id=function(s) return type(s)=='string' and s:match('^%d+$') and #s>=16 and #s<=20 end,
        init=function() return {id=local_id} end,pump=function() end,invites=function() return {} end,create=function() return lobby end,
        join=function(id) joins[#joins+1]=id;return id end,poll=function(call) return call end,
        set=function(_,key,value) data[key]=value;return true end,
        get=function(id,key) if id==lobby then return data[key] or '' end;return known and known.metadata and known.metadata[key] or '' end,
        presence=function() end,owner=function() return local_id end,members=function() return {local_id} end,receive=function() return {} end,
        search=function(code) return {code=code} end,poll_search=function(call) return known and known[call.code] or {} end,
        joinable=function(_,v) joinable[#joinable+1]=v end,leave=function() end,close=function() end}
    e.love={math={random=function() pick=pick+1;return choices[pick] or 100003 end}}
    e.BT.notice=function() end;e.BT.client={model={phase='lobby',changed=function() end}}
    e.SMODS={load_file=function(path) if path=='net/steam_native.lua' then return function() return n end end;return assert(loadfile(ROOT..'/'..path)) end}
    local f=assert(loadfile(ROOT..'/net/steam.lua'));setfenv(f,e);local s=f()
    return s,n,e,data,joins,joinable
end
test('Steam codes preserve leading zeroes and accept exactly six digits',function()
    local s=fixture();assert(s.valid_code('001234')=='001234')
    for _,bad in ipairs({'12345','1234567','123 456','abc123',lobby,'steam://joinlobby/2379780/'..lobby..'/'..local_id}) do assert(not s.valid_code(bad)) end
end)
test('host checks collisions before publishing a fresh searchable code',function()
    local s,n,e,data=fixture({['100000']={other}});s.host();s.update(.1);assert(not s.code_ready)
    s.update(.1);assert(s.code_ready and s.code=='100001' and data.bt_code=='100001' and e.BT.client.model.room_code=='100001')
end)
test('code lookup routes to exactly one metadata-validated Steam lobby',function()
    local s,n,e,data,joins=fixture({['001234']={other},metadata={bt_mod='BalatroTogether',bt_code='001234',bt_version='code-test'}})
    -- Stop after joining to keep this fixture independent of a real handshake.
    n.poll=function() return end;s.join_code('001234');s.update(.1);assert(joins[1]==other)
end)
test('unknown and ambiguous codes report a useful error without joining',function()
    local s=fixture();local _,out=s.join_code('999999');s.update(.1);local event=out:pop();assert(event.type=='error' and event.error:find('No open table'))
    local q,n,e,data,joins=fixture({['001234']={other,'109775240123456798'},metadata={bt_mod='BalatroTogether',bt_code='001234',bt_version='code-test'}})
    local _,output=q.join_code('001234');q.update(.1);assert(#joins==0 and output:pop().error:find('more than one'))
end)
test('mismatched builds never join a code result',function()
    local s,n,e,data,joins=fixture({['001234']={other},metadata={bt_mod='BalatroTogether',bt_code='001234',bt_version='older'}})
    local _,out=s.join_code('001234');s.update(.1);assert(#joins==0 and out:pop().error:find('Everyone must update'))
end)
test('code rotation and leaving clear old identities; active runs close discovery',function()
    local s,n,e,data,joins,open=fixture();s.host();s.update(.1);assert(s.code_ready)
    e.BT.client.model.phase='blind';s.update(.1);assert(open[#open]==false)
    e.BT.client.model.phase='lobby';s.rotate_code();assert(not s.code_ready and not e.BT.client.model.room_code)
    s.update(.1);assert(s.code_ready and s.code=='100001');s.stop();assert(not s.code and not s.invited and not s.lookup_code)
end)
print('TOTAL '..count..' STEAM CODE TESTS PASSED')
