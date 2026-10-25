-- Host deck choices use Cryptid's registered pools, defaults and eligibility rules.
local D={definitions={
    {'cry_antimatter','DECK COMBINATION',true},
    {'cry_edeck_ed','EDITION'}, {'cry_edeck_enh','ENHANCEMENT'},
    {'cry_edeck_sk','STICKER'}, {'cry_edeck_st','SUIT'}, {'cry_edeck_sl','SEAL'},
}}
local function copy(v) return BT.Session.copy(v) end
local function scoped(choices,fn)
    local rs=SMODS.RunSelect;if not rs then return end
    local previous=rs.Setup;rs.Setup={choices=choices}
    local ok,result=pcall(fn);rs.Setup=previous
    if ok then return result end
end
function D.pool(key,shared)
    local page=SMODS.RunSelect and SMODS.RunSelect.Pages[key]
    if not page then return {} end
    local pool=page.pool
    if not pool and page.generate_pool then local ok,v=pcall(page.generate_pool,page);if ok then pool=v end end
    local out={}
    for _,entry in ipairs(pool or {}) do
        if type(entry.key)=='string' and (key~='cry_antimatter' or Cryptid.antimatter_compat(entry.key,shared==true)) then out[#out+1]=entry end
    end
    return out
end
function D.normalize(deck,values,shared)
    local out=copy(values or {});out.deck_choice=deck;out.stake_choice='stake_white'
    for _,def in ipairs(D.definitions) do
        local key=def[1];local page=SMODS.RunSelect and SMODS.RunSelect.Pages[key]
        if page then
            local pool=D.pool(key,shared);local allowed={};for _,entry in ipairs(pool) do allowed[entry.key]=true end
            local value=out[key]
            if def[3] then
                if type(value)~='table' then value=nil end
                -- Only the host's setup uses personal unlocks. Guests and saved
                -- runs retain the host-approved combination on their profiles.
                local chosen=shared and value or scoped(out,function() return page:set_default(value) end) or {}
                out[key]={};for k,v in pairs(chosen) do if allowed[k] and v==true then out[key][k]=true end end
            else
                if type(value)~='string' or not allowed[value] then value=nil end
                local chosen=scoped(out,function() return page:set_default(value) end)
                out[key]=allowed[chosen] and chosen or pool[1] and pool[1].key
            end
        end
    end
    out.cry_antimatter=out.cry_antimatter or {}
    return out
end
function D.pages(deck,choices,shared)
    local out={};choices=D.normalize(deck,choices,shared)
    for _,def in ipairs(D.definitions) do
        local page=SMODS.RunSelect and SMODS.RunSelect.Pages[def[1]]
        if page and (#D.pool(def[1],shared)>0 or def[3]) and scoped(choices,function() return not page.optional or page:optional() end) then
            out[#out+1]={key=def[1],name=def[2],multiple=def[3]==true}
        end
    end
    return out
end
function D.name(key,value)
    if value=='random' then return 'Random' end
    if value=='all' then return 'All stickers' end
    local page=SMODS.RunSelect and SMODS.RunSelect.Pages[key]
    local ok,name=pcall(function()
        if key=='cry_antimatter' then return localize{type='name_text',set='Back',key=value} end
        return page and page.selected_text and page:selected_text(value)
    end)
    if ok and type(name)=='string' and name~='' and name~='ERROR' then return name end
    return tostring(value):gsub('^e_',''):gsub('^m_',''):gsub('_',' ')
end
function D.summary(deck,choices,shared)
    local parts={};choices=D.normalize(deck,choices,shared)
    for _,page in ipairs(D.pages(deck,choices,shared)) do
        local value=choices[page.key]
        if page.multiple then local n=0;for _,v in pairs(value or {}) do if v then n=n+1 end end;parts[#parts+1]=n..' decks'
        else parts[#parts+1]=D.name(page.key,value) end
    end
    return table.concat(parts,' / ')
end
return D
