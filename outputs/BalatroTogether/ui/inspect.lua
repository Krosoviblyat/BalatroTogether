return function(U,h)
    local g=love.graphics;local V={quads={}}
    function V.reset() V.quads={} end
    local function thumbnail(item,x,y,w,height,accent)
        local center=G.P_CENTERS and G.P_CENTERS[item.key]
        local atlas=center and G.ASSET_ATLAS and G.ASSET_ATLAS[center.atlas or (center.set=='Joker' and 'Joker' or 'Tarot')]
        local image=atlas and atlas.image;local pos=center and center.pos
        h.rect(x-3,y-3,w+6,height+6,item.edition=='negative' and h.colors[3] or item.edition=='polychrome' and h.colors[4] or accent,4)
        if image and pos and type(pos.x)=='number' and type(pos.y)=='number' then
            local key=tostring(image)..':'..item.key
            local quad=V.quads[key]
            local px,py=atlas.px or 71,atlas.py or 95
            if not quad then quad=g.newQuad(pos.x*px,pos.y*py,px,py,image:getDimensions());V.quads[key]=quad end
            h.col(item.debuff and {0.48,0.48,0.48} or {1,1,1});g.draw(image,quad,x,y,0,w/px,height/py)
            if center.soul_pos then
                local soul=V.quads[key..':soul']
                if not soul then local p=center.soul_pos;soul=g.newQuad(p.x*px,p.y*py,px,py,image:getDimensions());V.quads[key..':soul']=soul end
                h.col({1,1,1});g.draw(image,soul,x,y,0,w/px,height/py)
            end
        else
            h.rect(x,y,w,height,h.panel,4);h.diamond(x+w/2,y+height/2,w*0.21,accent)
        end
    end
    local function rows(items,x,cy,width,z,accent)
        if #items==0 then h.txt('Nothing here yet.',x,cy+8*z,21*z,h.muted,width);return cy+54*z end
        for i,item in ipairs(items) do
            local height=111*z;local iconw=51*z;local iconh=69*z
            local hover=U.inspect_card==item.key..':'..i
            h.rect(x,cy,width,height-7*z,hover and {0.22,0.30,0.27} or h.panel,6)
            local bob=not BT.config.reduced_motion and (BT.config.motion or 1)>0 and hover and math.sin(love.timer.getTime()*3)*1.5*z or 0
            thumbnail(item,x+13*z,cy+15*z+bob,iconw,iconh,accent)
            local tx=x+82*z;local tw=width-95*z
            h.txt(item.name or item.key,tx,cy+10*z,25*z,h.ink,tw)
            local label=item.debuff and 'DEBUFFED' or item.edition~='' and item.edition:upper() or 'BASE'
            h.txt(label,tx,cy+42*z,15*z,item.debuff and h.colors[4] or accent,tw)
            h.txt(item.effect and item.effect~='' and item.effect or 'Native card effect',tx,cy+65*z,18*z,h.muted,tw)
            if cy+height>U.inspect_clip_y and cy<U.inspect_clip_y+U.inspect_clip_h then
                h.hit(x,math.max(cy,U.inspect_clip_y),width,math.min(cy+height,U.inspect_clip_y+U.inspect_clip_h)-math.max(cy,U.inspect_clip_y),function() U.inspect_card=item.key..':'..i end,'Inspect '..(item.name or item.key))
            end
            cy=cy+height
        end
        return cy
    end
    function V.draw(w,height)
        local p=BT.state.players[tostring(U.shown_player)];if not p then U.expanded=nil;return end
        local z=math.min(height/900,1.15);local width=math.min(540*z,w-30);local ph=math.min(690*z,height-110)
        local x=w-width-18+(1-U.open_amount)*(width+20);local y=height-ph-18;local c=h.palette(p.id)
        U.inspect_rect={x=x,y=y,w=width,h=ph};h.rect(x,y,width,ph,h.bg,10)
        h.hit(x,y,width,ph,function() end,'Inspection panel')
        h.txt(p.name,x+21*z,y+15*z,34*z,c,width-87*z)
        h.button('X',x+width-49*z,y+14*z,31*z,29*z,function() U.expanded=nil end,h.muted)
        h.txt((p.activity or 'waiting'):upper()..' / $'..h.fmt(p.money)..' / H'..p.hands..' D'..p.discards,x+21*z,y+57*z,20*z,h.muted,width-42*z)
        h.txt('TEAM '..h.fmt(p.contribution)..' / BEST '..h.fmt(p.highest),x+21*z,y+86*z,21*z,h.ink,width-42*z)
        if not p.inspect then h.txt('This player keeps their build private.',x+21*z,y+148*z,25*z,h.muted,width-42*z);return end
        local tabs={{'BUILD','build'},{'DECK','deck'},{'SHOP','shop'}};U.inspect_tab=U.inspect_tab or 'build'
        local tw=(width-52*z)/3
        for i,tab in ipairs(tabs) do h.button(tab[1],x+19*z+(i-1)*(tw+7*z),y+121*z,tw,31*z,function() U.inspect_tab=tab[2];U.inspection_scroll=0 end,U.inspect_tab==tab[2] and c or h.muted) end
        local clip_y=y+171*z;local clip_h=ph-224*z
        U.inspect_clip_y=clip_y;U.inspect_clip_h=clip_h
        g.setScissor(x+10*z,clip_y,width-20*z,clip_h)
        local cy=clip_y-U.inspection_scroll;local left=x+19*z;local content=width-38*z
        if U.inspect_tab=='build' then
            h.txt('JOKERS / '..#p.jokers,left,cy,21*z,c,content);cy=cy+31*z
            cy=rows(p.jokers,left,cy,content,z,c)
            cy=cy+15*z;h.txt('CONSUMABLES / '..#p.consumables,left,cy,21*z,c,content);cy=cy+31*z
            cy=rows(p.consumables,left,cy,content,z,c)
        elseif U.inspect_tab=='shop' then
            h.txt('BROWSING',left,cy,23*z,c,content);cy=cy+34*z
            cy=rows(p.shop or {},left,cy,content,z,c)
        else
            h.txt('DECK COMPOSITION',left,cy,24*z,c,content);cy=cy+44*z
            for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
                h.rect(left,cy,content,48*z,h.panel,5);h.txt(suit,left+14*z,cy+8*z,25*z,(suit=='Hearts' or suit=='Diamonds') and h.colors[4] or h.ink,content-90*z)
                h.txt(p.deck[suit] or 0,left+content-80*z,cy+8*z,26*z,c,65*z,'right');cy=cy+59*z
            end
            cy=cy+15*z;h.txt('LAST HAND',left,cy,20*z,c,content);cy=cy+31*z;h.txt(p.last_hand~='' and p.last_hand or 'No hands yet',left,cy,25*z,h.ink,content);cy=cy+62*z
            local cards={};for _,v in ipairs(p.board or {}) do cards[#cards+1]=(v.selected and '* ' or '')..v.rank..' '..v.suit end
            h.txt(p.reveal and ('LIVE HAND / '..table.concat(cards,' / ')) or 'Live hand stays private.',left,cy,21*z,h.muted,content);cy=cy+150*z
        end
        U.inspect_max=math.max(0,cy+U.inspection_scroll-clip_y-clip_h+12*z);g.setScissor()
        U.inspection_scroll=math.min(U.inspection_scroll,U.inspect_max)
        if U.inspect_max>0 then
            local track=clip_h;local thumb=math.max(25*z,track*track/(track+U.inspect_max));local sy=clip_y+(track-thumb)*U.inspection_scroll/U.inspect_max
            h.col(c,0.5);g.rectangle('fill',x+width-7*z,sy,3*z,thumb,2,2)
        end
        h.txt('READ-ONLY / SCROLL FOR MORE',x+21*z,y+ph-35*z,16*z,h.muted,width-42*z)
    end
    return V
end
