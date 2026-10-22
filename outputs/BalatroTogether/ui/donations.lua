return function(U,h)
    local g=love.graphics
    local motion=assert(SMODS.load_file('ui/motion.lua',BT.id))()
    local V={widgets={},quads={},opening={x=0,v=0},flights={},page=1,boxpage=1,target=0,time=0}
    local function reduced() return BT.config.reduced_motion or (BT.config.motion or 1)==0 end
    local function widget(key)
        local w=V.widgets[key]
        if not w then w={enter={x=0,v=0},hover={x=0,v=0},press={x=0,v=0},target=0}; V.widgets[key]=w end
        w.seen=V.time; return w
    end
    local function hover(x,y,w,height)
        local mx,my=love.mouse.getPosition()
        if U.modal then mx=(mx-U.modal.x)/U.modal.scale; my=(my-U.modal.y)/U.modal.scale end
        return mx>=x and mx<=x+w and my>=y and my<=y+height
    end
    function V.update(dt)
        V.time=V.time+dt
        if V.lastscreen~=U.screen then
            V.lastscreen=U.screen
            if U.screen=='donations' then V.opening={x=0,v=0}; V.widgets={} end
        end
        motion.spring(V.opening,U.screen=='donations' and 1 or 0,dt,reduced(),BT.config.motion or 1)
        for key,w in pairs(V.widgets) do
            if V.time-w.seen>4 then V.widgets[key]=nil
            else
                motion.spring(w.enter,1,dt,reduced(),BT.config.motion or 1)
                motion.spring(w.hover,w.target,dt,reduced(),BT.config.motion or 1)
                motion.spring(w.press,0,dt,reduced(),BT.config.motion or 1)
            end
        end
        if reduced() then V.flights={} end
        for i=#V.flights,1,-1 do if V.time-V.flights[i].time>0.85 then table.remove(V.flights,i) end end
    end
    function V.amount() return reduced() and 1 or V.opening.x end
    local function icon(card,x,y,w,height,angle)
        local center=G.P_CENTERS[card.center]
        local atlas=center and G.ASSET_ATLAS[center.atlas or center.set]
        if not atlas or not atlas.image then return end
        local key=card.center..':'..tostring(atlas.image)
        if not V.quads[key] then V.quads[key]=g.newQuad(center.pos.x*atlas.px,center.pos.y*atlas.py,atlas.px,atlas.py,atlas.image:getDimensions()) end
        h.col(h.ink); g.draw(atlas.image,V.quads[key],x+w/2,y+height/2,angle or 0,w/atlas.px,height/atlas.py,atlas.px/2,atlas.py/2)
    end
    function U.donation_event(kind,card)
        if reduced() or not BT.config.effects then return end
        V.flights[#V.flights+1]={time=V.time,card=card,kind=kind,
            from=V.lastclick or {x=kind=='donated' and 300 or 950,y=400},
            to={x=kind=='donated' and 942 or 300,y=225}}
        if #V.flights>4 then table.remove(V.flights,1) end
        local pulse=widget('box'); pulse.press.x=1; pulse.press.v=0
        if BT.config.sounds then pcall(play_sound,kind=='donated' and 'cardSlide1' or 'timpani',1.05,0.3) end
    end
    local function tile(key,card,x,y,c,action,label,enabled,detail)
        local state=widget(key); state.target=hover(x,y,550,91) and 1 or 0
        local enter=reduced() and 1 or state.enter.x
        local rise=(1-enter)*16-state.hover.x*4
        local scale=1+state.hover.x*0.012-state.press.x*0.035
        g.push(); g.translate(x+275,y+45+rise); g.scale(scale); g.translate(-x-275,-y-45)
        h.rect(x,y,550,91,h.panel,10)
        h.col(c,0.4+state.hover.x*0.45); g.setLineWidth(1.5); g.rectangle('line',x,y,550,91,10,10)
        icon(card,x+12,y+9,48,66,state.hover.x*0.035)
        h.txt(card.name,x+75,y+7,24,h.ink,305)
        h.txt(card.kind..(card.edition~='' and ' / '..card.edition:upper() or ''),x+75,y+32,17,c,300)
        h.txt(detail or card.effect or '',x+75,y+53,16,h.muted,300)
        h.button(label,x+398,y+29,138,34,function()
            state.press.x=1; state.press.v=0; V.lastclick={x=x+38,y=y+44}; action()
        end,c,enabled)
        g.pop()
    end
    local function pager(page,total,x,y,set)
        h.button('< PREV',x,y,112,31,function() set(math.max(1,page-1)) end,h.muted,page>1)
        h.txt(page..' / '..math.max(1,math.ceil(total/4)),x+127,y+4,20,h.muted,290,'center')
        h.button('NEXT >',x+438,y,112,31,function() set(page+1) end,h.muted,page*4<total)
    end
    function V.draw(w,height)
        h.backdrop(w,height,'DONATION BOX','SHARE YOUR LUCK. BUILD A STRONGER TABLE.')
        local state=BT.state
        if not state or not BT.active() then h.txt('Start a party run to share cards.',60,230,30,h.ink); return end
        local items=state.donations and state.donations.items or {}
        local own={}
        for _,area in ipairs({G.jokers,G.consumeables}) do for _,card in ipairs(area and area.cards or {}) do own[#own+1]=card end end
        local targets={{id=0,name='EVERYONE'}}
        for i=1,4 do local p=state.players[tostring(i)]; if i~=BT.client.id and p and not p.withdrawn then targets[#targets+1]={id=i,name=p.name} end end
        local index=1; for i,t in ipairs(targets) do if t.id==V.target then index=i end end
        V.target=targets[index].id
        h.txt('YOUR INVENTORY',60,174,25,h.ink)
        h.button('SEND TO: '..targets[index].name,60,210,550,39,function() V.target=targets[index%#targets+1].id end,h.colors[3],not BT.donation.busy())
        h.txt('TEAM BOX  '..#items..' / '..(state.donations and state.donations.limit or 8),670,174,25,h.colors[1])
        h.txt('Everyone can take public gifts. Reserved gifts go to that seat.',670,214,19,h.muted,550)
        local pulse=widget('box'); local b=reduced() and 0 or pulse.press.x
        g.push(); g.translate(1190,112-8*b); g.rotate(b*0.08)
        h.col(h.colors[2]); g.rectangle('fill',-29,-18,58,42,5,5); g.rectangle('fill',-34,-25,68,13,3,3)
        h.col(h.colors[1]); g.rectangle('fill',-5,-25,10,49); g.rectangle('line',-20,-43,20,17,8,8); g.rectangle('line',0,-43,20,17,8,8); g.pop()
        V.page=math.max(1,math.min(V.page,math.max(1,math.ceil(#own/4))))
        V.boxpage=math.max(1,math.min(V.boxpage,math.max(1,math.ceil(#items/4))))
        for row=1,4 do
            local c=own[(V.page-1)*4+row]
            if c then
                local eligible,reason=BT.donation.eligible(c)
                local edition=''; for _,key in ipairs({'negative','polychrome','holo','foil'}) do if c.edition and c.edition[key] then edition=key; break end end
                if c.edition and type(c.edition.type)=='string' and c.edition.type:match('^cry_') then edition=c.edition.type end
                local data={center=c.config.center.key,name=c.ability.name,kind=c.ability.set,edition=edition,effect=BT.game.effect_summary(c.ability)}
                tile('owned:'..c.sort_id,data,60,264+(row-1)*99,h.colors[BT.client.id] or h.colors[1],function() BT.donation.offer(c,V.target) end,
                    eligible and 'DONATE' or 'LOCKED',eligible and BT.donation.available() and #items<8,reason)
            end
            local item=items[(V.boxpage-1)*4+row]
            if item then
                local donor=state.players[tostring(item.donor)]; local target=state.players[tostring(item.target)]
                local detail='From '..(donor and donor.name or 'teammate')..' / '..(item.target==0 and 'Everyone' or target and target.name or 'teammate')
                local allowed=item.target==0 or item.target==BT.client.id or item.donor==BT.client.id
                local label=item.status=='reserved' and 'DELIVERING' or item.donor==BT.client.id and 'TAKE BACK' or 'TAKE'
                tile('gift:'..item.id,item.card,670,264+(row-1)*99,h.colors[item.donor] or h.colors[1],function() BT.donation.claim(item) end,label,
                    allowed and item.status=='available' and BT.donation.available() and BT.donation.space(item.card),detail)
            end
        end
        if #own==0 then
            h.rect(60,264,550,386,h.panel,12)
            h.txt('YOUR NEXT GREAT FIND',85,365,29,h.ink,500,'center')
            h.txt('Pick up a Joker or consumable in the shop.\nGive a teammate something to build around.',85,419,23,h.muted,500,'center')
        end
        if #items==0 then
            h.rect(670,264,550,386,h.panel,12)
            h.txt('A LITTLE GENEROSITY.\nA BIGGER NEXT HAND.',710,345,32,h.colors[1],470,'center')
            h.txt('Donated cards appear here for your team.',710,435,23,h.muted,470,'center')
        end
        pager(V.page,#own,60,671,function(page) V.page=page end)
        pager(V.boxpage,#items,670,671,function(page) V.boxpage=page end)
        local message=BT.donation.busy() and 'TRANSFERRING... KEEP YOUR GAME OPEN' or BT.donation.available() and 'Trade while unready. Editions and built-up card stats travel with the card.' or 'Finish animations and stay unready in the shop or between blinds to trade.'
        local self=state.players[tostring(BT.client.id)]
        h.txt(message,60,722,21,h.muted,self and self.ready and 580 or 900)
        if self and self.ready and (state.phase=='prepare' or state.phase=='shop') then h.button('UNREADY TO TRADE',680,717,280,39,BT.client.ready,h.colors[2]) end
        h.button('BACK TO TABLE',1000,717,220,39,function() U.screen='lobby' end,h.colors[1])
        for _,flight in ipairs(V.flights) do
            local t=(V.time-flight.time)/0.65
            if t<1 then
                local x,y=motion.arc(t,flight.from,flight.to)
                icon(flight.card,x-27,y-37,54,74,math.sin(t*math.pi)*0.18)
                for i=1,6 do local angle=i*math.pi/3; h.diamond(x+math.cos(angle)*t*45,y+math.sin(angle)*t*45,3*(1-t),h.colors[2],1-t) end
            end
        end
    end
    return V
end
