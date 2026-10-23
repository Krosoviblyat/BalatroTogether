-- Steam IDs stay decimal strings; command lines are data, never executed.
local P={}
function P.lobby(value)
    if type(value)~='string' or #value>1024 then return end
    value=value:match('^%s*(.-)%s*$')
    return value:match('^(%d+)$') or value:match('^steam://joinlobby/2379780/(%d+)/%d+/?$')
end
function P.command(value)
    if type(value)=='table' then
        local keys={}
        for k in pairs(value) do if type(k)=='number' and k%1==0 then keys[#keys+1]=k end end
        table.sort(keys)
        for _,k in ipairs(keys) do
            if value[k]=='+connect_lobby' then return P.lobby(value[k+1]) end
            local link=type(value[k])=='string' and value[k]:match('^steam://joinlobby/') and P.lobby(value[k])
            if link then return link end
        end
        return
    end
    if type(value)~='string' or #value>32768 then return end
    value=value:match('^[^%z]*')
    local tokens={}; local pos=1
    while pos<=#value do
        local _,last=value:find('^%s+',pos)
        if last then pos=last+1 end
        if pos>#value then break end
        local token
        if value:sub(pos,pos)=='"' then
            local close=value:find('"',pos+1,true)
            if not close then return end
            token=value:sub(pos+1,close-1); pos=close+1
            if pos<=#value and not value:sub(pos,pos):match('%s') then return end
        else
            local finish=value:find('%s',pos) or (#value+1)
            token=value:sub(pos,finish-1); pos=finish
        end
        tokens[#tokens+1]=token
    end
    return P.command(tokens)
end
return P
