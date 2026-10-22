-- Bounded newline framing. JSON is data only; never loadstring network input.
local W={MAX=65536}
function W.new() return {buffer=''} end
function W.feed(state, bytes, decode)
    if type(bytes)~='string' then return nil,'invalid bytes' end
    state.buffer=state.buffer..bytes
    if #state.buffer>W.MAX*2 then return nil,'receive buffer limit' end
    local out={}
    while true do
        local i=state.buffer:find('\n',1,true); if not i then break end
        if i>W.MAX then return nil,'frame limit' end
        local line=state.buffer:sub(1,i-1); state.buffer=state.buffer:sub(i+1)
        local ok,v=pcall(decode,line)
        if not ok or type(v)~='table' then return nil,'invalid JSON object' end
        out[#out+1]=v
        if #out>128 then return nil,'message rate limit' end
    end
    if #state.buffer>W.MAX then return nil,'frame limit' end
    return out
end
return W
