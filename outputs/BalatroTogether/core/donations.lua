-- Pure host-side escrow ledger. Payloads are data, never executable Lua.
local D={LIMIT=8,MAX_TRANSFERS=4096}
local kinds={Joker=true,Tarot=true,Planet=true,Spectral=true,Code=true}
local editions={['']=true,foil=true,holo=true,polychrome=true,negative=true}
function D.empty() return {items={},seen={},history={},history_order={},counter=0} end
local function clean(s,n) return tostring(s or ''):gsub('[%z\1-\31\127]',''):sub(1,n) end
function D.clone(value,extended)
    local count,bytes,path=0,0,{}
    local function visit(v,depth)
        count=count+1; if count>(extended and 1024 or 256) or depth>(extended and 8 or 6) then error('Card state is too large or deeply nested.') end
        bytes=bytes+(type(v)=='string' and #v or 16); if bytes>(extended and 12000 or 3200) then error('Card state is too large.') end
        if D.Numbers and D.Numbers.big(v) then D.Numbers.pack(v); return v:clone() end
        local t=type(v)
        if t=='number' then if v~=v or math.abs(v)>1e100 then error('Invalid card number.') end; return v end
        if t=='string' then if #v>(extended and 512 or 160) then error('Card text is too long.') end; return v end
        if t=='boolean' or t=='nil' then return v end
        if t~='table' or path[v] then error('Unsupported card state.') end
        path[v]=true; local out={}
        for k,x in pairs(v) do
            if not (type(k)=='string' and #k<=48 or type(k)=='number' and k%1==0 and k>=1 and k<=128) then error('Invalid card field.') end
            bytes=bytes+#tostring(k); out[k]=visit(x,depth+1)
        end
        path[v]=nil; return out
    end
    local ok,result=pcall(visit,value,0); if ok then return result end; return nil,tostring(result)
end
function D.card(value)
    if type(value)~='table' or not kinds[value.kind] or type(value.center)~='string' or #value.center>64 then return nil,'Share jokers, Tarot, Planet, Spectral and Cryptid Code cards.' end
    if not value.center:match(value.kind=='Joker' and '^j_[%w_ %-]+$' or '^c_[%w_ %-]+$') then return nil,'Invalid card identity.' end
    local edition=value.edition or ''
    if not editions[edition] and not (type(edition)=='string' and #edition<=48 and edition:match('^cry_[%w_]+$') and edition~='cry_double_sided') then return nil,'Unsupported card edition.' end
    local extended=value.center:match('^[jc]_cry_')~=nil
    local ability,err=D.clone(value.ability,extended)
    if not ability or type(ability)~='table' or ability.set~=value.kind or type(ability.name)~='string' then return nil,err or 'Invalid native card ability.' end
    if ability.eternal then return nil,'Eternal cards cannot be donated.' end
    local edition_data
    if value.edition_data then edition_data,err=D.clone(value.edition_data); if not edition_data then return nil,err end end
    return {center=value.center,kind=value.kind,name=clean(value.name or ability.name,60),ability=ability,
        edition=edition,edition_data=edition_data,pinned=value.pinned==true,effect=clean(value.effect,120)}
end
local function receipt(p,request,status,item,error)
    p.donation_receipt={request=type(request)=='string' and request:sub(1,48) or '',status=status,item=item,error=error}
end
local function reject(p,request,message)
    receipt(p,request,'rejected',nil,message); return nil,message
end
local function between(m,p)
    return (m.phase=='prepare' or m.phase=='shop') and not p.ready and not p.busy
        and (p.activity=='shopping' or p.activity=='blind_select' or p.activity=='waiting')
end
local function summary(item)
    local c=item.card
    return {id=item.id,donor=item.donor,target=item.target,status=item.status,claimer=item.claimer,
        card={center=c.center,kind=c.kind,name=c.name,edition=c.edition,pinned=c.pinned,effect=c.effect}}
end
function D.apply(m,id,kind,data)
    local p=m.players[id]; local box=m.donation_data
    local request=data.request
    if type(request)~='string' or #request>48 or not request:match('^'..m.run_id..':'..id..':%d+$') then return reject(p,request,'Invalid donation request.') end
    if kind=='donation_offer' then
        if not between(m,p) or p.transferring then return reject(p,request,'Donate between blinds or while shopping, before readying.') end
        if box.seen[request] then return reject(p,request,'That card deposit was already processed.') end
        local n=0; for _ in pairs(box.items) do n=n+1 end
        if n>=D.LIMIT or box.counter>=D.MAX_TRANSFERS then return reject(p,request,'The donation box is full. Take or return a card first.') end
        local target=data.target or 0
        if type(target)~='number' or target%1~=0 or target<0 or target>4 or target~=0 and (not m.players[target] or m.players[target].withdrawn) then return reject(p,request,'Choose an active teammate or Everyone.') end
        local card,err=D.card(data.card); if not card then return reject(p,request,err) end
        box.counter=box.counter+1; local item=box.counter
        box.items[item]={id=item,donor=id,target=target,card=card,status='available',source=request}
        box.seen[request]=true; receipt(p,request,'deposited',item)
        m:event(id,'donation','donated '..card.name); return true
    elseif kind=='donation_claim' then
        if not between(m,p) or p.transferring then return reject(p,request,'Take cards between blinds or while shopping, before readying.') end
        local item=box.items[data.item]
        if not item or item.status~='available' then return reject(p,request,'That card has already been taken or reserved.') end
        if item.target~=0 and item.target~=id and item.donor~=id then return reject(p,request,'That donation is reserved for another teammate.') end
        item.status='reserved'; item.claimer=id; item.claim_request=request
        p.transferring=true; p.activity='donating'; receipt(p,request,'reserved',item.id); return true
    elseif kind=='donation_commit' or kind=='donation_cancel' then
        local item=box.items[data.item]; local previous=box.history[data.item]
        if not item and previous and previous.claimer==id and previous.request==request and kind=='donation_commit' then receipt(p,request,'claimed',data.item); return true end
        if not item or item.status~='reserved' or item.claimer~=id or item.claim_request~=request then return reject(p,request,'No matching reserved donation.') end
        p.transferring=false; p.activity=m.phase=='shop' and 'shopping' or 'blind_select'
        if kind=='donation_cancel' then
            item.status='available'; item.claimer=nil; item.claim_request=nil
            receipt(p,request,'cancelled',item.id); return true
        end
        box.history[item.id]={claimer=id,request=request}; box.history_order[#box.history_order+1]=item.id
        if #box.history_order>64 then box.history[table.remove(box.history_order,1)]=nil end
        box.items[item.id]=nil; receipt(p,request,'claimed',item.id)
        m:event(id,'donation','received '..item.card.name); return true
    end
    return reject(p,request,'Unknown donation action.')
end
function D.retire(m,id)
    for _,item in pairs(m.donation_data.items) do
        if item.target==id then item.target=0 end
        if item.claimer==id then item.status='available'; item.claimer=nil; item.claim_request=nil end
    end
    m.players[id].transferring=false
end
function D.snapshot(m,state,viewer)
    state.donations={items={},limit=D.LIMIT}
    for i=1,m.donation_data.counter do
        local item=m.donation_data.items[i]
        if item then
            local public=summary(item)
            if item.status=='reserved' and item.claimer==viewer then public.payload=D.card(item.card) end
            state.donations.items[#state.donations.items+1]=public
        end
    end
end
return D
