-- One visible checkpoint per party/run, independent of seed and blind position.
local C={}
function C.key(model)
    if type(model)~='table' or type(model.party_id)~='string' or #model.party_id~=32
        or not model.party_id:match('^[0-9a-f]+$') or type(model.run_id)~='number'
        or model.run_id<1 or model.run_id%1~=0 or model.run_id>2147483647 then return end
    return model.party_id..'-'..model.run_id
end
function C.entry(archive,path,compatible)
    if type(archive)~='table' or archive.schema~=1 or type(archive.builds)~='table'
        or type(archive.at)~='number' or archive.at<0 or archive.at>=1e12 then return end
    local m=archive.model;local key=C.key(m)
    if not key or not m.checkpoint or m.checkpoint.status~='saved' then return end
    if type(m.ante)~='number' or type(m.blind_index)~='number' or type(m.intended)~='number'
        or type(m.seed)~='string' or type(m.deck)~='string' then return end
    return {key=key,path=path,ante=m.ante,index=m.blind_index,round=m.round or 0,players=m.intended,
        deck=m.deck,seed=m.seed,run=m.run_id,serial=type(m.checkpoint_serial)=='number' and m.checkpoint_serial or 0,
        at=archive.at,version=archive.version,compatible=compatible}
end
function C.newer(a,b)
    if a.at~=b.at then return a.at>b.at end
    if a.serial~=b.serial then return a.serial>b.serial end
    return a.path>b.path
end
function C.add(groups,entry)
    if entry and (not groups[entry.key] or C.newer(entry,groups[entry.key])) then groups[entry.key]=entry end
end
function C.list(groups)
    local out={};for _,entry in pairs(groups) do out[#out+1]=entry end
    table.sort(out,C.newer);return out
end
return C
