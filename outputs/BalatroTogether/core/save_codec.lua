-- Data-only native save format. No loadstring/STR_UNPACK, executable values or
-- unbounded recursive JSON. Flat nodes retain numeric keys and shared tables.
local C={MAX_BYTES=4194304,MAX_NODES=120000,MAX_VALUES=250000,MAX_DEPTH=64,CHUNK=8192}
local function bulk(fn,...)
    -- Balatro's nuGC stops automatic collection outside its per-frame budget.
    -- A full checkpoint parses far more data than a normal network frame.
    -- Restore the collector's prior state even if validation throws.
    local known,running=pcall(collectgarbage,'isrunning')
    local stop_after=known and not running or not known and type(nuGC)=='function'
    collectgarbage('restart')
    local ok,result=pcall(fn,...)
    if stop_after then collectgarbage('stop') end
    if not ok then error(result,0) end;return result
end
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function C.encode(value,json,numbers,limit)
    local nodes,seen,path={}, {},{};local count=0
    local function visit(v,depth)
        count=count+1;assert(count<=C.MAX_VALUES and depth<=C.MAX_DEPTH,'Save is too large or deeply nested')
        if numbers and numbers.big(v) then
            local packed=numbers.pack(v)
            -- Network packing intentionally reduces small Big values to plain
            -- numbers. Native saves must retain their Amulet type on reload.
            if type(packed)=='number' then packed={__bt_omega=1,sign=packed<0 and -1 or 1,values={string.format('%.17g',math.abs(packed))}} end
            return {'o',packed,v.asize}
        end
        local t=type(v)
        if t=='nil' then return {'z'} end
        if t=='number' then assert(finite(v),'Save contains a nonfinite number');return {'n',v} end
        if t=='boolean' then return {'b',v} end
        if t=='string' then assert(#v<=C.MAX_BYTES,'Save text is too large');return {'s',v} end
        assert(t=='table' and not path[v],'Save contains executable, cyclic or unsupported state')
        if seen[v] then return {'t',seen[v]} end
        assert(#nodes<C.MAX_NODES,'Too many save tables')
        local index=#nodes+1;local entries={};nodes[index]=entries;seen[v]=index;path[v]=true
        for k,item in pairs(v) do
            assert(type(k)=='string' or finite(k),'Unsupported save key')
            entries[#entries+1]={visit(k,depth+1),visit(item,depth+1)}
        end
        path[v]=nil;return {'t',index}
    end
    local root=visit(value,0);local text=json.encode({schema=1,root=root,nodes=nodes})
    assert(#text<=(limit or C.MAX_BYTES),'Save exceeds its size limit');return text
end
function C.decode(text,json,numbers,limit)
    assert(type(text)=='string' and #text<=(limit or C.MAX_BYTES),'Invalid save size')
    local depth,quoted,escape=0,false,false
    for i=1,#text do
        local c=text:sub(i,i)
        if quoted then if escape then escape=false elseif c=='\\' then escape=true elseif c=='"' then quoted=false end
        elseif c=='"' then quoted=true elseif c=='{' or c=='[' then depth=depth+1;assert(depth<=12,'Invalid save nesting')
        elseif c=='}' or c==']' then depth=depth-1;assert(depth>=0,'Invalid save JSON') end
    end
    assert(depth==0 and not quoted,'Incomplete save')
    local data=json.decode(text)
    assert(type(data)=='table' and data.schema==1 and type(data.nodes)=='table' and #data.nodes<=C.MAX_NODES,'Unknown save format')
    local tables,state={}, {};local count=0
    local function ref(v,level)
        count=count+1;assert(count<=C.MAX_VALUES and level<=C.MAX_DEPTH and type(v)=='table','Invalid save data')
        local kind,value=v[1],v[2]
        if kind=='z' then return nil
        elseif kind=='n' then assert(finite(value),'Invalid save number');return value
        elseif kind=='s' then assert(type(value)=='string' and #value<=C.MAX_BYTES,'Invalid save text');return value
        elseif kind=='b' then assert(type(value)=='boolean','Invalid save boolean');return value
        elseif kind=='o' then
            assert(numbers,'This save needs Amulet');local result=numbers.unpack(value)
            if v[3]~=nil then
                assert(type(v[3])=='number' and v[3]%1==0 and v[3]>=0 and v[3]<=#value.values,'Invalid Amulet save size')
                result.asize=v[3]
            end
            return result
        elseif kind~='t' then error('Unknown save value') end
        assert(finite(value) and value%1==0 and value>=1 and value<=#data.nodes,'Invalid save table reference')
        assert(state[value]~=1,'Cyclic save references')
        if state[value]==2 then return tables[value] end
        state[value]=1;local result={};tables[value]=result
        local entries=data.nodes[value];assert(type(entries)=='table','Invalid save table')
        for _,entry in ipairs(entries) do
            assert(type(entry)=='table','Invalid save entry')
            local k=ref(entry[1],level+1);assert(type(k)=='string' or finite(k),'Invalid save key')
            assert(result[k]==nil,'Duplicate save key');result[k]=ref(entry[2],level+1)
        end
        state[value]=2;return result
    end
    return ref(data.root,0)
end
function C.add_chunk(buffer,msg)
    assert(type(msg)=='table' and type(msg.id)=='string' and #msg.id<=100 and msg.id:match('^[%w%-]+$'),'Invalid checkpoint identity')
    assert(type(msg.hash)=='string' and #msg.hash==64 and msg.hash:match('^[0-9a-f]+$'),'Invalid checkpoint checksum')
    assert(type(msg.total)=='number' and msg.total%1==0 and msg.total>=1 and msg.total<=512,'Invalid checkpoint chunks')
    assert(type(msg.index)=='number' and msg.index%1==0 and msg.index>=1 and msg.index<=msg.total,'Invalid checkpoint chunk index')
    assert(type(msg.data)=='string' and #msg.data<=C.CHUNK and (msg.index==msg.total or #msg.data==C.CHUNK),'Invalid checkpoint chunk length')
    buffer=buffer or {id=msg.id,hash=msg.hash,total=msg.total,parts={},bytes=0,count=0}
    assert(buffer.id==msg.id and buffer.hash==msg.hash and buffer.total==msg.total,'Checkpoint changed during transfer')
    local old=buffer.parts[msg.index];assert(not old or old==msg.data,'Conflicting checkpoint chunk')
    if not old then buffer.parts[msg.index]=msg.data;buffer.bytes=buffer.bytes+#msg.data;buffer.count=buffer.count+1 end
    assert(buffer.bytes<=C.MAX_BYTES,'Checkpoint transfer too large')
    if buffer.count==buffer.total then return buffer,table.concat(buffer.parts) end
    return buffer
end
local encode,decode=C.encode,C.decode
C.encode=function(...) return bulk(encode,...) end
C.decode=function(...) return bulk(decode,...) end
return C
