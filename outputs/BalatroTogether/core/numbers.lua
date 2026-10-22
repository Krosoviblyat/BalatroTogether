-- Amulet values stay native in the reducer. Only bounded data crosses the wire.
local N={MAX_LAYERS=64,MAX_COMPONENT=9007199254740991}
function N.big(x) return Big and Big.is and not not Big.is(x) or false end
function N.finite(x)
    if type(x)=='number' then return x==x and x>-math.huge and x<math.huge end
    return N.big(x) and x:isFinite() or false
end
function N.score(x)
    -- Ordinary IEEE values must not overflow when several reports are added.
    -- Larger native Amulet scores use the explicit Omega envelope instead.
    return N.finite(x) and x>=0 and (N.big(x) or x<=1e100)
end
function N.ceil(x) return N.big(x) and x:ceil() or math.ceil(x) end
function N.abs(x) return N.big(x) and x:abs() or math.abs(x) end
function N.native(x,cap)
    local n=N.big(x) and x:to_number() or x
    if type(n)~='number' or n~=n then return 0 end
    cap=cap or 1e100
    return math.max(-cap,math.min(cap,n))
end
function N.ratio(a,b)
    if not N.score(a) or not N.score(b) or b<=0 then return 0 end
    return N.native(a/b,1)
end
function N.format(x)
    if N.big(x) then
        if number_format then return number_format(x) end
        return x:toString()
    end
    local n=tonumber(x) or 0
    if n>=1e12 then return string.format('%.2e',n) end
    if n>=1e9 then return string.format('%.2fB',n/1e9) end
    if n>=1e6 then return string.format('%.2fM',n/1e6) end
    if n>=1e4 then return string.format('%.1fK',n/1e3) end
    return tostring(math.floor(n))
end
function N.pack(x)
    assert(N.big(x) and x:isFinite(),'Invalid Amulet score')
    local small=x:to_number()
    if small==small and math.abs(small)<=1e12 then return small end
    local source=x:get_array(); assert(not getmetatable(source),'Implicit Amulet arrays cannot be sent')
    local length=0
    for k,v in pairs(source) do
        assert(type(k)=='number' and k%1==0 and k>=1 and k<=N.MAX_LAYERS,'Amulet score exceeds supported layers')
        assert(type(v)=='number' and N.finite(v) and v>=0 and v<=N.MAX_COMPONENT,'Invalid Amulet component')
        length=math.max(length,k)
    end
    local values={}
    for i=1,length do values[i]=string.format('%.17g',source[i] or 0) end
    return {__bt_omega=1,sign=x.sign,values=values}
end
function N.unpack(data)
    assert(Big and Big.create,'This score requires Amulet')
    assert(data.__bt_omega==1 and (data.sign==1 or data.sign==-1) and type(data.values)=='table','Invalid score envelope')
    for k in pairs(data) do assert(k=='__bt_omega' or k=='sign' or k=='values','Unexpected score field') end
    local arr={}; local n=#data.values
    assert(n>=1 and n<=N.MAX_LAYERS,'Invalid score size')
    for k,value in pairs(data.values) do
        assert(type(k)=='number' and k%1==0 and k>=1 and k<=n,'Invalid score index')
        assert(type(value)=='string' and #value<=32 and value:match('^[%d%.eE%+%-]+$'),'Invalid score component')
        local v=tonumber(value)
        assert(N.finite(v) and v>=0 and v<=N.MAX_COMPONENT and (k==1 or v%1==0),'Invalid score component')
        arr[k]=v
    end
    local result=Big:create(arr,data.sign); assert(result:isFinite(),'Nonfinite score')
    return result
end
function N.codec(json)
    local function map(value,decode,path,depth,count)
        count.n=count.n+1; assert(count.n<=30000 and depth<=24,'Network data limit')
        if not decode and N.big(value) then return N.pack(value) end
        local kind=type(value)
        if kind=='number' then assert(N.finite(value),'Nonfinite network number'); return value end
        if kind~='table' then assert(kind=='string' or kind=='boolean' or kind=='nil','Unsupported network value'); return value end
        if decode and value.__bt_omega~=nil then return N.unpack(value) end
        assert(not path[value],'Cyclic network value'); path[value]=true
        local out={}; for k,v in pairs(value) do out[k]=map(v,decode,path,depth+1,count) end
        path[value]=nil; return out
    end
    return {encode=function(v) return json.encode(map(v,false,{},0,{n=0})) end,
        decode=function(v) return map(json.decode(v),true,{},0,{n=0}) end}
end
return N
