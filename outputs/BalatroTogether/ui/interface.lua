local U={screen=nil,hits={},fields={},focus=nil,fonts={},seen={},feed={},progress=0,expanded=nil,open_amount=0,inspection_scroll=0,bursts={},screen_age=0}
local layout=assert(SMODS.load_file('ui/layout.lua',BT.id))()
local colors={{0.20,0.84,0.71},{1,0.60,0.24},{0.52,0.64,1},{0.96,0.40,0.57}}
local alt={{0.35,0.77,1},{1,0.78,0.30},{0.85,0.58,1},{0.40,0.90,0.59}}
local bg={0.085,0.135,0.125}; local panel={0.18,0.235,0.22}; local ink={1,0.97,0.89}; local muted={0.63,0.72,0.67}
local g=love.graphics
local motion=assert(SMODS.load_file('ui/motion.lua',BT.id))()
local TextInput=assert(SMODS.load_file('core/text_input.lua',BT.id))()
local pot_view
U.widgets={}; U.opening={x=0,v=0}
local function sync_screen()
    if U.last_screen==U.screen then return end
    U.last_screen=U.screen;U.screen_age=0;U.opening={x=0,v=0}
    if U.closing_screen~=U.screen then U.closing=false end
end
local function col(c,a) g.setColor(c[1],c[2],c[3],(a or 1)*(U.opacity or 1)) end
local function ease(t) t=math.max(0,math.min(1,t)); return 1-(1-t)^3 end
local function font(size)
    size=math.max(10,math.floor(size))
    if not U.fonts[size] then U.fonts[size]=g.newFont('resources/fonts/m6x11plus.ttf',size);U.fonts[size]:setFilter('nearest','nearest') end
    return U.fonts[size]
end
local function txt(t,x,y,size,c,w,align)
    t=tostring(t or ''):gsub('–','-'):gsub('—','-'):gsub('−','-'):gsub('•','/'):gsub('×','x'):gsub('…','...'):gsub('’',"'")
    if w and size>=26 and not t:find('\n',1,true) and font(size):getWidth(t)>w then size=math.max(16,math.floor(size*w/font(size):getWidth(t))) end
    g.setFont(font(size))
    local color=c or ink
    if size>=18 and color[1]+color[2]+color[3]>1.4 then col({0.035,0.045,0.04},0.55);g.printf(t,x+1,y+1.5,w or 10000,align or 'left') end
    col(c or ink); g.setFont(font(size)); g.printf(tostring(t or ''),x,y,w or 10000,align or 'left')
end
local function shade(c,f) return {math.min(1,c[1]*f),math.min(1,c[2]*f),math.min(1,c[3]*f)} end
local function cutrect(x,y,w,h,r)
    r=math.min(r or 7,w/4,h/4)
    g.polygon('fill',x+r,y,x+w-r,y,x+w-r,y+r/2,x+w,y+r,x+w,y+h-r,x+w-r/2,y+h-r,x+w-r,y+h,x+r,y+h,x+r,y+h-r/2,x,y+h-r,x,y+r,x+r/2,y+r)
end
local function rect(x,y,w,h,c,r,a)
    if w<12 or h<12 then col(c,a);g.rectangle('fill',x,y,w,h);return end
    local radius=math.min(r or 9,12)
    col({0.025,0.035,0.03},0.5*(a or 1));cutrect(x+1,y+5,w,h,radius)
    col(shade(c,0.48),a);cutrect(x,y,w,h,radius)
    col(shade(c,1.16),a);cutrect(x+2,y+1,w-4,h-5,radius)
    col(c,a);cutrect(x+3,y+3,w-6,h-7,radius)
end
local function diamond(x,y,size,c,a)
    col(c,a); g.polygon('fill',x,y-size,x+size,y,x,y+size,x-size,y)
end
local function hit(x,y,w,h,fn,label)
    if (U.opacity or 1)<0.25 or U.closing then return end
    -- Match the rendered bounds, including page/card entrance transforms.
    local ax,ay=g.transformPoint(x,y);local bx,by=g.transformPoint(x+w,y+h)
    if U.modal then ax=(ax-U.modal.x)/U.modal.scale;ay=(ay-U.modal.y)/U.modal.scale;bx=(bx-U.modal.x)/U.modal.scale;by=(by-U.modal.y)/U.modal.scale end
    U.hits[#U.hits+1]={x=math.min(ax,bx),y=math.min(ay,by),w=math.abs(bx-ax),h=math.abs(by-ay),fn=fn,label=label}
end
local function button(text,x,y,w,h,fn,c,enabled)
    c=c or colors[1];local accent=c
    if c==muted then c={0.25,0.32,0.29} end
    if enabled==false then c={0.13,0.18,0.16} end
    local id=tostring(U.screen)..':'..math.floor(x)..':'..math.floor(y)
    local b=U.widgets[id]
    if not b then b={hover={x=0,v=0},press={x=0,v=0}}; U.widgets[id]=b end
    b.seen=love.timer.getTime()
    local mx,my=love.mouse.getPosition();local ax,ay=g.transformPoint(x,y);local bx,by=g.transformPoint(x+w,y+h)
    local over=enabled~=false and mx>=ax and mx<=bx and my>=ay and my<=by
    b.target=over and 1 or 0
    if over and not b.over and BT.config.sounds then pcall(play_sound,'card1',0.9,0.07) end
    b.over=over
    local animated=not BT.config.reduced_motion and (BT.config.motion or 1)>0
    if animated then y=y-b.hover.x*2+b.press.x*3 end
    g.push();g.translate(x+w/2,y+h/2)
    if animated then g.scale(1+b.hover.x*0.008-b.press.x*0.016,1-b.press.x*0.035) end
    g.translate(-x-w/2,-y-h/2)
    rect(x,y,w,h,c,7)
    if animated and b.hover.x>0.01 then col(accent,b.hover.x*0.4); g.setLineWidth(1);g.line(x+9,y+2,x+w-9,y+2) end
    if over then col(ink,0.12); g.rectangle('fill',x,y,w,h,7,7) end
    local light=c[1]*0.299+c[2]*0.587+c[3]*0.114>0.59
    txt(text,x+8,y+h*0.17,h*0.59,enabled==false and {0.39,0.48,0.43} or light and bg or ink,w-16,'center')
    if enabled~=false then hit(x,y,w,h,function() b.press.x=1; b.press.v=0;if BT.config.sounds then pcall(play_sound,'cardSlide1',1.05,0.18) end;fn() end,text) end
    g.pop()
end
local function group(delay,draw)
    local reduced=BT.config.reduced_motion or (BT.config.motion or 1)==0
    local p=motion.reveal(U.screen_age*(BT.config.motion or 1),delay,reduced)
    local opacity=U.opacity;U.opacity=(opacity or 1)*math.max(0,math.min(1,p))
    g.push();g.translate(0,(1-p)*22);draw();g.pop();U.opacity=opacity
end
U.group=group
function U.navigate(screen)
    if screen=='join' and U.screen~='join' then BT.config.room_code='';BT.config.steam_lobby='';BT.config.pin='' end
    U.screen=screen;U.focus=nil;U.editor=nil;U.closing=false
end
function U.ensure_editor(select_all)
    local key=U.focus;if not key then U.editor=nil;U.editor_key=nil;return end
    local pot=key=='pot_amount' and pot_view
    local value=pot and pot.get_entry() or BT.config[key] or ''
    if U.editor_key~=key or not U.editor then
        local digits=key=='room_code' or key=='pin' or key=='host_pin' or key=='port' or pot
        U.editor=TextInput.new{value=value,select_all=select_all,limit=pot and 5 or (key=='room_code' or key=='pin' or key=='host_pin') and 6 or key=='seed' and 8 or key=='port' and 5 or (key=='username' or key=='friend_search') and 24 or 100,
            filter=function(text)
                if pot then text=text:gsub('[%s,$]','');if text:find('[^0-9]') then return end;return text end
                if digits then return text:gsub('[^0-9]','') end
                if key=='seed' then return text:upper():gsub('[^A-Z0-9]','') end
                return text
            end,
            changed=function(text) if pot then pot.edit_entry(text) else BT.config[key]=text end end,
            clipboard=function(mode,text) if mode=='read' then return love.system.getClipboardText() end;love.system.setClipboardText(text) end}
        U.editor_key=key
    elseif U.editor.value~=value then U.editor.value=value;U.editor.cursor=#value;U.editor.anchor=#value end
    return U.editor
end
local function field_text(value,x,y,w,h,size)
    local e=U.ensure_editor();local f=font(size);local scroll=0
    if e then scroll=math.max(0,f:getWidth(value:sub(1,e.cursor))-w+4) end
    local ax,ay=g.transformPoint(x,y);local bx,by=g.transformPoint(x+w,y+h)
    local sx,sy,sw,sh=g.getScissor();g.setScissor(ax,ay,math.max(1,bx-ax),math.max(1,by-ay))
    if e then
        local lo,hi=e:selection()
        if hi>lo then col(colors[3],0.38);g.rectangle('fill',x+f:getWidth(value:sub(1,lo))-scroll,y+2,f:getWidth(value:sub(lo+1,hi)),h-5,2,2) end
    end
    txt(value,x-scroll,y,size,ink,w+scroll+1000)
    if e and e.blink%1<0.58 then col(ink);g.setLineWidth(2);local at=x+f:getWidth(value:sub(1,e.cursor))-scroll;g.line(at,y+3,at,y+h-4) end
    if sx then g.setScissor(sx,sy,sw,sh) else g.setScissor() end
end
local function input(label,key,x,y,w,h)
    txt(label,x,y-24,21,muted,w)
    rect(x,y,w,h,U.focus==key and {0.13,0.23,0.28} or panel,7)
    if U.focus==key then field_text(BT.config[key] or '',x+12,y+8,w-24,h-13,28)
    else txt(BT.config[key] or '',x+12,y+8,28,ink,w-24) end
    U.fields[#U.fields+1]=key
    hit(x,y,w,h,function() U.focus=key;U.editor=nil;U.ensure_editor(true) end,label)
end
local function fmt(n)
    if BT.numbers then return BT.numbers.format(n) end
    n=tonumber(n) or 0
    if n>=1e12 then return string.format('%.2e',n) end
    if n>=1e9 then return string.format('%.2fB',n/1e9) end
    if n>=1e6 then return string.format('%.2fM',n/1e6) end
    if n>=1e4 then return string.format('%.1fK',n/1e3) end
    return tostring(math.floor(n))
end
local function palette(id) return (BT.config.palette==2 and alt or colors)[id] or ink end
local function me() return BT.state and BT.state.players[tostring(BT.client.id)] end
local function backdrop(w,h,title,sub)
    col({0.04,0.10,0.08},0.92);g.rectangle('fill',0,0,w,h)
    rect(20,15,w-40,h-56,bg,12,0.97)
    col(ink,0.055);g.line(48,164,w-48,164)
    if BT.config.effects and not BT.config.reduced_motion and (BT.config.motion or 1)>0 then
        local t=love.timer.getTime()*(BT.config.motion or 1)
        for i=1,5 do
            local x=40+(i*239+t*3)%(w-80); local y=190+(i*107+t*4)%(h-250)
            g.push(); g.translate(x,y); g.rotate(t*0.07+i); diamond(0,0,6+i%3*3,colors[1],0.035); g.pop()
        end
    end
    diamond(55,39,6,colors[1]);txt(Cryptid and 'TOGETHER / CRYPTID' or 'BALATRO TOGETHER',70,27,23,muted)
    txt(title,46,65,55,ink,850)
    txt(sub or 'ONE TABLE. FOUR BUILDS. ONE SHARED RUN.',50,128,21,muted)
    txt(BT.version..' / '..(BT.client.transport=='tcp' and 'DIRECT IP' or 'STEAM'),48,h-27,16,muted)
    txt('F8  TABLE     ESC  BACK',w-315,h-27,16,muted,267,'right')
    if BT.state and BT.state.phase~='lobby' then
        local nav={{'TABLE','lobby'},{'GIFTS','donations'},{'BET POTS','pot'},{'REWARDS','dice'}}
        local challenge=BT.dice.challenge and BT.dice.challenge()
        local locked=BT.state.phase=='saving' or BT.state.phase=='resuming'
        for i,v in ipairs(nav) do button(v[1],720+(i-1)*126,27,118,30,function() U.navigate(v[2]) end,(U.screen==v[2] or U.screen=='boss_rewards' and v[2]=='dice') and colors[1] or muted,not locked and (not challenge or v[2]=='dice')) end
    end
end
local function close()
    U.focus=nil;U.closing=true;U.closing_screen=U.screen
    if BT.config.reduced_motion or (BT.config.motion or 1)==0 then U.screen=nil;U.closing=false end
    BT.persist()
end
U.close=close
local donation_view=assert(SMODS.load_file('ui/donations.lua',BT.id))()(U,{col=col,txt=txt,rect=rect,button=button,diamond=diamond,
    backdrop=backdrop,ink=ink,muted=muted,panel=panel,colors=colors})
pot_view=assert(SMODS.load_file('ui/pot.lua',BT.id))()(U,{col=col,txt=txt,rect=rect,button=button,hit=hit,field_text=field_text,
    backdrop=backdrop,ink=ink,muted=muted,panel=panel,colors=colors})
local dice_view=assert(SMODS.load_file('ui/dice.lua',BT.id))()(U,{col=col,txt=txt,rect=rect,button=button,
    backdrop=backdrop,ink=ink,muted=muted,panel=panel,colors=colors})
local boss_view=assert(SMODS.load_file('ui/harbinger.lua',BT.id))()(U,{col=col,txt=txt,rect=rect,button=button,backdrop=backdrop,ink=ink,muted=muted,panel=panel})
local admin_view=assert(SMODS.load_file('ui/admin.lua',BT.id))()(U,{col=col,txt=txt,rect=rect,button=button,
    backdrop=backdrop,ink=ink,muted=muted,panel=panel,colors=colors})
local inspect_view=assert(SMODS.load_file('ui/inspect.lua',BT.id))()(U,{col=col,txt=txt,rect=rect,button=button,hit=hit,diamond=diamond,
    ink=ink,muted=muted,panel=panel,bg=bg,colors=colors,palette=palette,fmt=fmt})
local vote_view=assert(SMODS.load_file('ui/vote.lua',BT.id))()(U,{txt=txt,rect=rect,button=button,backdrop=backdrop,
    ink=ink,muted=muted,panel=panel,colors=colors})
local saving_view=assert(SMODS.load_file('ui/saving.lua',BT.id))()(U,{txt=txt,rect=rect,backdrop=backdrop,
    ink=ink,muted=muted,panel=panel,colors=colors})
function U.menu() U.navigate('home') end
local function home(w,h)
    backdrop(w,h,'TOGETHER','SIMULTANEOUS CO-OP FOR 1–4 PLAYERS')
    group(0.03,function()
        txt('FACE THE\nHARBINGER.',64,214,58,ink,555)
        txt('It plays back. You push harder.\nIsolated saves. A separate test build.',67,365,27,muted,535)
        local still=BT.config.reduced_motion or (BT.config.motion or 1)==0
        local t=still and 0 or love.timer.getTime()*(BT.config.motion or 1)
        for i=1,4 do
            g.push();g.translate(190+i*56,535+math.sin(t*1.5+i)*3);g.rotate((i-2.5)*0.16)
            rect(-49,-64,98,135,panel);col(palette(i));cutrect(-43,-59,86,123,7)
            diamond(0,0,17,bg);txt(tostring(i),-33,-49,21,bg,66);g.pop()
        end
        button('BOSS RULES / STAKES',67,655,462,40,function() U.navigate('boss_lab') end,colors[3])
    end)
    group(0.09,function()
        local saved=BT.save and BT.save.summary
        rect(690,212,526,498,panel)
        txt('TAKE YOUR SEAT',721,235,30,ink,464)
        input('DISPLAY NAME','username',722,316,462,48)
        button('HOST A TABLE',722,393,462,54,function() U.navigate('host') end)
        button('JOIN FRIENDS',722,461,462,49,function() U.navigate('join') end,muted)
        button('SAVED RUNS / '..#(BT.save.entries or {}),722,528,462,46,function() BT.save.refresh();U.saves_page=1;U.navigate('saves') end,colors[2])
        if saved then
            txt('ANTE '..saved.ante..' / '..saved.players..' BUILDS / '..os.date('%b %d %H:%M',saved.at),722,583,18,muted,462,'center')
            if not saved.compatible then txt('Save needs its original Cryptid pack/settings.',722,583,17,colors[4],462,'center') end
        else
            txt('MANUAL CHECKPOINTS / EVERY RUN HAS ITS OWN SEAT',722,583,17,muted,462,'center')
        end
        local sy=620
        button('OPTIONS',722,sy,145,39,function() U.return_to='home';U.navigate('settings') end,muted)
        button('CREDITS',880,sy,145,39,function() U.credits_return='home';U.navigate('credits') end,colors[3])
        button('BACK',1038,sy,146,39,close,muted)
        txt('RUNNING '..BT.version..' / SIX-DIGIT CODES',722,sy+63,19,colors[1],462,'center')
    end)
end
local function connect_screen(w,h,is_host)
    backdrop(w,h,is_host and 'HOST A TABLE' or 'JOIN THE TABLE',is_host and 'A PRIVATE TABLE FOR YOUR FRIENDS' or 'YOUR BUILD. YOUR CARDS. YOUR TEAM.')
    local x=w/2-300; local y=190
    local steam=BT.config.transport~='tcp'
    if is_host then
        txt('PLAYERS AT THIS TABLE',x,y,26,muted)
        for i=1,4 do button(tostring(i),x+(i-1)*153,y+42,141,53,function() BT.config.intended_players=i; BT.persist() end,palette(i),true)
            if BT.config.intended_players==i then txt('SELECTED',x+(i-1)*153,y+100,20,palette(i),141,'center') end end
        input('SEED (OPTIONAL)','seed',x,y+150,steam and 600 or 190,48)
        if not steam then
            input('HOST PORT','port',x+205,y+150,190,48)
            input('ROOM PIN','host_pin',x+410,y+150,190,48)
            txt('6 digits, or blank',x+410,y+201,16,muted,190)
        end
        txt('TEAM DIFFICULTY × '..string.format('%.1f',BT.config.scaling),x,y+314,23,muted)
        button('-',x+390,y+302,65,40,function() BT.config.scaling=math.max(0.5,BT.config.scaling-0.1) end,muted)
        button('+',x+470,y+302,65,40,function() BT.config.scaling=math.min(3,BT.config.scaling+0.1) end,muted)
        txt('PARTY DECK',x,y+218,23,muted)
        if BT.compat then BT.compat.register_decks() end
        local decks=BT.Session.DECKS; local selected=1
        for i,v in ipairs(decks) do if v[1]==BT.config.deck then selected=i end end
        button('<',x,y+247,52,40,function() BT.config.deck=decks[(selected-2)%#decks+1][1]; BT.persist() end,muted)
        txt(BT.Session.deck_name(BT.config.deck),x+68,y+253,28,ink,456,'center')
        button('>',x+548,y+247,52,40,function() BT.config.deck=decks[selected%#decks+1][1]; BT.persist() end,muted)
        button(steam and 'STEAM - SELECTED' or 'USE STEAM',x,y+365,292,36,function() BT.config.transport='steam'; U.focus=nil; BT.persist() end,steam and colors[1] or muted)
        button(not steam and 'DIRECT IP - SELECTED' or 'USE DIRECT IP',x+308,y+365,292,36,function() BT.config.transport='tcp'; U.focus=nil; BT.persist() end,not steam and colors[2] or muted)
        txt(steam and 'No IP, PIN or port forwarding. Add bots in the lobby.' or 'Direct IP requires a reachable host port and room PIN.',x,y+414,21,muted,600)
    else
        button(steam and 'STEAM - SELECTED' or 'USE STEAM',x,y,292,40,function() BT.config.transport='steam'; U.focus=nil; BT.persist() end,steam and colors[1] or muted)
        button(not steam and 'DIRECT IP - SELECTED' or 'USE DIRECT IP',x+308,y,292,40,function() BT.config.transport='tcp'; U.focus=nil; BT.persist() end,not steam and colors[2] or muted)
        if steam then
            txt('Ask the host for their six-digit table code.\nEnter it below and take your seat.\nSteam invites work here too.',x,y+76,27,ink,600)
            input('TABLE CODE / 6 DIGITS','room_code',x,y+222,600,53)
            txt('A fresh code for every table. No IP address needed.',x,y+288,20,muted,600)
        else
            input('HOST IP OR DNS NAME','address',x,y+96,600,48)
            input('PORT','port',x,y+200,270,48); input('ROOM PIN','pin',x+305,y+200,295,48)
            txt('Direct IP requires the host to forward their TCP port.',x,y+275,22,muted,600)
        end
    end
    local by=is_host and y+452 or y+342
    button(is_host and 'OPEN TABLE' or 'JOIN TABLE',x,by,390,53,function() BT.persist(); if is_host then BT.client.host(steam and 'steam' or 'tcp') elseif steam then BT.client.join_code(BT.config.room_code) else BT.client.join() end end)
    button('BACK',x+406,by,194,53,function() U.screen='home'; U.focus=nil end,muted)
end
local function steam_friends(w,h)
    backdrop(w,h,'INVITE YOUR FRIENDS','AN INVITE OR SIX DIGITS. SAME TABLE.')
    local x=w/2-390
    if not (BT.steam.lobby and BT.client.model and (BT.client.model.phase=='lobby' or BT.client.model.phase=='resuming')) then
        txt('Open a Steam table before inviting friends.',x,225,30,ink,780)
        button('BACK TO TABLE',x,640,780,44,function() U.screen='lobby' end,muted); return
    end
    input('FIND A FRIEND','friend_search',x,208,530,44)
    button('REFRESH',x+550,208,230,44,function() BT.steam.refresh_friends(); U.friend_page=1 end,muted)
    local list={}; local query=(BT.config.friend_search or ''):lower()
    for _,friend in ipairs(BT.steam.friend_list or {}) do if friend.name:lower():find(query,1,true) then list[#list+1]=friend end end
    local pages=math.max(1,math.ceil(#list/6)); U.friend_page=math.max(1,math.min(U.friend_page or 1,pages))
    for i=(U.friend_page-1)*6+1,math.min(U.friend_page*6,#list) do
        local friend=list[i]; local y=280+(i-(U.friend_page-1)*6-1)*53
        local label=#friend.name>34 and (BT.Session.limit_text(friend.name,31)..'...') or friend.name
        rect(x,y,780,45,panel); txt(label,x+13,y+7,27,ink,445)
        txt(friend.state==0 and 'OFFLINE' or 'ONLINE',x+470,y+12,20,muted,110)
        local joined=BT.steam.peers[friend.id]~=nil
        local sent=BT.steam.sent_invites[friend.id] and BT.steam.clock-BT.steam.sent_invites[friend.id]<10
        button(joined and 'AT TABLE' or sent and 'SENT' or 'INVITE',x+600,y+5,168,34,function() BT.steam.invite_friend(friend.id) end,colors[1],not joined and not sent)
    end
    if #list==0 then txt(query=='' and 'No Steam friends found. Check that Steam is online.' or 'No friends match that name.',x,310,27,muted,780,'center') end
    button('<',x,615,70,38,function() U.friend_page=math.max(1,U.friend_page-1) end,muted,U.friend_page>1)
    txt('PAGE '..U.friend_page..' / '..pages,x+90,623,24,muted,600,'center')
    button('>',x+710,615,70,38,function() U.friend_page=math.min(pages,U.friend_page+1) end,muted,U.friend_page<pages)
    button('BACK TO TABLE',x,674,780,44,function() U.screen='lobby'; U.focus=nil end,muted)
end
local function steam_invite(w,h)
    backdrop(w,h,'STEAM INVITE','YOUR FRIEND HAS A SEAT FOR YOU')
    txt(BT.state and 'Joining will leave your current table.\nReady to join your friend?' or 'Join your friend\'s Balatro Together table through Steam.',w/2-300,265,31,ink,600,'center')
    button('JOIN FRIEND',w/2-300,415,390,55,function() BT.client.join_steam(BT.steam.invited) end)
    button('CANCEL',w/2+106,415,194,55,function() BT.steam.invited=nil; U.screen=BT.state and 'lobby' or 'home' end,muted)
end
local function pin_screen(w,h)
    backdrop(w,h,'CHANGE ROOM PIN','YOUR CONNECTED FRIENDS STAY AT THIS TABLE')
    local x=w/2-300
    input('NEW ROOM PIN (6 DIGITS)','host_pin',x,270,600,53)
    txt('Leave blank to generate a random PIN.\nJoining friends need the new PIN. Existing seats can reconnect.',x,355,24,muted,600)
    button('APPLY PIN',x,458,390,53,function() if BT.client.set_pin(BT.config.host_pin) then U.screen='lobby'; U.focus=nil end end)
    button('BACK',x+406,458,194,53,function() U.screen='lobby'; U.focus=nil end,muted)
end
local function name_screen(w,h)
    backdrop(w,h,'CHANGE YOUR NAME','YOUR SEAT AND RUN STAY THE SAME')
    local x=w/2-300
    input('DISPLAY NAME','username',x,270,600,53)
    txt('Up to 24 characters. Your teammates see the updated name.',x,355,24,muted,600)
    button('SAVE NAME',x,458,390,53,function() BT.client.rename(BT.config.username) end)
    button('BACK',x+406,458,194,53,function() U.screen='lobby'; U.focus=nil end,muted)
end
local function lobby(w,h)
    local s=BT.state
    backdrop(w,h,s and s.phase=='resuming' and 'WELCOME BACK.' or 'YOUR TABLE',s and s.phase=='resuming' and 'ORIGINAL PLAYERS JOIN WITH THE NEW CODE. EVERY BUILD RETURNS.' or s and 'GET READY. YOUR NEXT RUN STARTS TOGETHER.' or 'FINDING YOUR FRIEND\'S TABLE...')
    rect(w-271,87,214,40,colors[2],7)
    txt('BETA / '..BT.version,w-263,94,23,bg,198,'center')
    button('BOSS STAKES / '..BT.Session.Harbinger.tier(s or BT.config).name,w-401,137,344,32,function() U.navigate('boss_lab') end,colors[3])
    local start=math.max(190,h*0.24); local gap=18; local width=math.min((w-130)/4,264); local x=(w-width*4-gap*3)/2
    for i=1,4 do
        local p=s and s.players[tostring(i)]; local px=x+(i-1)*(width+gap); local c=palette(i)
        local animated=not BT.config.reduced_motion and (BT.config.motion or 1)>0
        local entrance=motion.reveal(U.screen_age*(BT.config.motion or 1),(i-1)*0.045,not animated)
        local start=start+(1-entrance)*32
        local opacity=U.opacity; U.opacity=(opacity or 1)*math.max(0,math.min(1,entrance))
        rect(px,start,width,245,p and panel or bg)
        txt(i==1 and 'HOST / SEAT 1' or 'SEAT '..i,px+16,start+15,18,muted,width-45)
        col(p and p.connected and c or muted,p and 1 or 0.3);g.circle('fill',px+width-21,start+25,3)
        local ready=U.seat_ready and U.seat_ready[i] and U.seat_ready[i].x or 0
        local bob=animated and math.sin(love.timer.getTime()*1.5+i)*1.5 or 0
        diamond(px+width/2,start+69+bob,24,c,p and 1 or 0.16)
        txt(tostring(i),px+width/2-18,start+56+bob,26,p and bg or muted,36,'center')
        txt(p and p.name or 'OPEN SEAT',px+12,start+108,30,p and ink or muted,width-24,'center')
        if not p and s and s.phase=='lobby' and BT.client.model and i<=s.intended then
            button('ADD BOT',px+12,start+210,width-24,28,BT.bots.add,colors[3])
        elseif p and p.bot and s.phase=='lobby' and BT.client.model then
            button('REMOVE BOT',px+12,start+210,width-24,28,function() BT.bots.remove(i) end,colors[4])
        end
        if p and p.bot then txt('NATIVE BOT',px+10,start+149,16,muted,width-20,'center')
        elseif p and p.steam_name then txt(p.steam_name,px+10,start+149,16,muted,width-20,'center') end
        local ry=start+175-(animated and math.max(0,ready-1)*10 or 0)
        rect(px+30,ry,width-60,27,p and p.ready and shade(c,0.35) or bg,6)
        local status=p and (p.connected and (s.phase=='resuming' and (p.restore_done and 'RESTORED' or 'RESTORING...') or p.ready and 'READY' or 'NOT READY') or 'OFFLINE') or 'WAITING'
        txt(status,px+32,ry+3,19,p and p.ready and c or muted,width-64,'center')
        if p and not p.connected and not p.bot and BT.client.model and i~=1 then
            button('RETIRE SEAT',px+12,start+210,width-24,28,function() BT.client.drop(i) end,colors[4])
        end
        if p and i==BT.client.id and not p.bot then
            button('CHANGE NAME',px+12,start+210,width-24,28,function() BT.config.username=p.name; U.screen='name'; U.focus='username' end,colors[1])
        end
        if ready>0.01 then col(c,math.min(1,ready)*0.35);g.setLineWidth(1);g.line(px+12,start+3,px+width-12,start+3) end
        U.opacity=opacity
    end
    local y=start+280
    if s and s.phase=='lobby' then
        button(me() and me().ready and 'UNREADY' or 'READY UP',w/2-305,y,295,55,BT.client.ready)
        button('START RUN',w/2+10,y,295,55,BT.client.start,colors[2],BT.client.model~=nil)
        txt('Requires '..s.intended..' ready player'..(s.intended==1 and '' or 's')..' / '..BT.Session.deck_name(s.deck)..' / Seed '..(s.custom_seed~='' and s.custom_seed or 'RANDOM')..' / ENDLESS',w/2-445,y+69,21,muted,890,'center')
    elseif s and s.phase=='resuming' then
        local restored,expected=0,0
        for _,p in pairs(s.players) do if not p.withdrawn then expected=expected+1;if p.connected and p.restore_done==s.resume_checkpoint then restored=restored+1 end end end
        button('CONTINUE SAVED RUN / '..restored..' OF '..expected,w/2-305,y,610,55,function() BT.client.action('resume_start',{}) end,colors[2],BT.client.model~=nil and restored==expected)
        txt(BT.Session.deck_name(s.deck)..' / ANTE '..s.ante,w/2-445,y+66,22,muted,890,'center')
    elseif s then
        button('RETURN TO RUN',w/2-305,y,295,55,close)
        button('FAST RESTART',w/2+10,y,295,55,BT.client.restart,colors[2],BT.client.model~=nil)
        local checkpoint=s.checkpoint;local status=checkpoint and checkpoint.status=='saving' and 'SAVING EVERY BUILD...' or checkpoint and checkpoint.status=='failed' and 'SAVE FAILED / PREVIOUS CHECKPOINT RETAINED' or checkpoint and checkpoint.at and ('CHECKPOINT '..os.date('%H:%M',checkpoint.at)) or 'MANUAL CHECKPOINTS / HOST SAVES BETWEEN BLINDS'
        txt(status,w/2-400,y+70,22,checkpoint and checkpoint.status=='failed' and colors[4] or muted,800,'center')
    end
    if s and BT.client.model and (s.phase=='prepare' or s.phase=='shop') then
        button(s.manual_save_requested and 'WAITING FOR SHOPS...' or 'SAVE & LEAVE',w/2-305,y+207,295,35,function() BT.save.request(true) end,colors[2],not s.manual_save_requested)
        button('SAVE CHECKPOINT',w/2+10,y+207,295,35,function() BT.save.request(false) end,muted,not s.manual_save_requested)
    end
    if BT.client.transport=='steam' then
            local code=BT.client.model and (BT.steam.code_ready and BT.steam.code) or s and s.room_code
            txt(code and ('TABLE CODE  '..code:sub(1,3)..' '..code:sub(4)) or 'MAKING A FRESH TABLE CODE...',w/2-400,y+107,34,colors[1],800,'center')
            local open=code and s and (s.phase=='lobby' or s.phase=='resuming')
            button('INVITE FRIENDS',w/2-305,y+154,240,35,BT.steam.friends,colors[1],open and BT.client.model~=nil)
            button('COPY CODE',w/2-53,y+154,172,35,function() love.system.setClipboardText(code); BT.notice('Six-digit table code copied.') end,muted,open)
            button('NEW CODE',w/2+131,y+154,174,35,BT.steam.rotate_code,muted,open and BT.client.model~=nil)
    elseif BT.client.model then
            txt('DIRECT IP TABLE : '..BT.config.port..'  /  PIN '..BT.config.pin,w/2-400,y+111,27,colors[1],800,'center')
            button('CHANGE PIN',w/2-305,y+153,190,35,function() BT.config.host_pin=BT.client.pin; U.screen='pin'; U.focus='host_pin' end,muted)
            button('COPY PIN + PORT',w/2-100,y+153,405,35,function() love.system.setClipboardText('TCP port '..BT.config.port..' / PIN '..BT.config.pin); BT.notice('PIN and port copied. Share your host IP separately.') end,muted)
    end
    button('LEAVE',w-160,h-73,120,35,function() BT.client.stop(); U.navigate('home') end,colors[4],not (s and s.phase=='saving'))
    button('SETTINGS',w-320,h-73,145,35,function() U.return_to='lobby'; U.screen='settings' end,muted)
    button('CREDITS',w-480,h-73,145,35,function() U.credits_return='lobby';U.navigate('credits') end,colors[3])
    if s then txt('PARTY / '..BT.Session.deck_name(s.deck),60,h-65,21,muted,570) end
end
local setting_list={
    {'Show player panels','panels'},{'HUD at top','hud_top'}, {'Feed on right','feed_right'},
    {'Score notifications','feed_scores'},{'Action notifications','feed_actions'},
    {'Notification sounds','sounds'},{'Reduced motion','reduced_motion'},{'Celebration effects','effects'},
    {'Allow build inspection','inspect'},{'Reveal my current hand','reveal_hand'},
    {'Network diagnostics','diagnostics'},
}
local function settings(w,h)
    backdrop(w,h,'TABLE SETTINGS','SAVED BETWEEN SESSIONS • YOUR GAME SETTINGS STAY YOURS')
    local width=math.min(465,(w-130)/2); local x=w/2-width-20; local y=190
    for i,v in ipairs(setting_list) do
        local column=math.floor((i-1)/6); local row=(i-1)%6; local px=x+column*(width+40); local py=y+row*55
        txt(v[1],px,py+8,24,ink,width-100)
        button(BT.config[v[2]] and 'ON' or 'OFF',px+width-90,py,90,40,function() BT.config[v[2]]=not BT.config[v[2]]; BT.persist() end,BT.config[v[2]] and colors[1] or muted)
    end
    local py=y+345
    txt('HUD SCALE '..string.format('%.1f',BT.config.hud_scale)..'×',x,py,24,muted)
    button('−',x+220,py,50,36,function() BT.config.hud_scale=math.max(0.6,BT.config.hud_scale-0.1); BT.persist() end,muted)
    button('+',x+280,py,50,36,function() BT.config.hud_scale=math.min(1.6,BT.config.hud_scale+0.1); BT.persist() end,muted)
    txt('FEED '..BT.config.feed_duration..' SECONDS',x,py+52,24,muted)
    button('−',x+220,py+52,50,36,function() BT.config.feed_duration=math.max(2,BT.config.feed_duration-1); BT.persist() end,muted)
    button('+',x+280,py+52,50,36,function() BT.config.feed_duration=math.min(15,BT.config.feed_duration+1); BT.persist() end,muted)
    button('PLAYER PALETTE '..BT.config.palette,x+width+40,py,width,40,function() BT.config.palette=BT.config.palette==1 and 2 or 1; BT.persist() end,colors[3])
    txt('Revealing your hand shares only visible cards.\nInspection never lets a teammate control your game.',x+width+40,py+55,22,muted,width)
    txt('ANIMATION '..string.format('%.1f',BT.config.motion or 1)..'x',x+width+40,py+105,24,muted)
    button('−',x+width+265,py+105,50,36,function() BT.config.motion=math.max(0,(BT.config.motion or 1)-0.1); BT.persist() end,muted)
    button('+',x+width+325,py+105,50,36,function() BT.config.motion=math.min(1.5,(BT.config.motion or 1)+0.1); BT.persist() end,muted)
    button('BACK',w/2-130,math.min(h-76,py+162),260,46,function() U.screen=U.return_to; BT.persist() end)
end
local function saved_runs(w,h)
    backdrop(w,h,'SAVED RUNS','ONE CHECKPOINT PER RUN / SAVE AGAIN TO REPLACE THAT RUN\'S CHECKPOINT')
    local entries=BT.save.entries or {};local pages=math.max(1,math.ceil(#entries/4))
    U.saves_page=math.max(1,math.min(pages,U.saves_page or 1))
    if #entries==0 then
        rect(160,250,960,265,panel)
        diamond(w/2,299,24,colors[2]);txt(BT.save.scan and 'FINDING YOUR SAVED RUNS...' or 'YOUR NEXT RUN BELONGS HERE.',190,355,35,ink,900,'center')
        txt('Host a table, then choose Save Checkpoint or Save & Leave\nbetween blinds. Each different run keeps its own checkpoint.',190,420,24,muted,900,'center')
    end
    for row=1,4 do
        local entry=entries[(U.saves_page-1)*4+row]
        if entry then
            local y=200+(row-1)*107;local item=entry
            group(0.02+row*0.035,function()
                rect(60,y,1160,94,panel);diamond(84,y+27,8,colors[(row-1)%4+1])
                txt(BT.Session.deck_name(item.deck)..' / '..item.seed,107,y+11,29,ink,830)
                local blind=({'SMALL BLIND','BIG BLIND','BOSS BLIND'})[item.index] or 'NEXT BLIND'
                txt('ANTE '..item.ante..' / '..blind..' / '..item.players..' BUILDS / '..os.date('%b %d %H:%M',item.at),83,y+50,21,muted,850)
                if item.compatible then
                    button('CONTINUE',976,y+24,216,43,function() BT.save.resume(item.path) end,colors[1],not BT.state)
                else
                    txt('NEEDS ORIGINAL\nPACK / SETTINGS',965,y+24,20,colors[4],232,'center')
                end
            end)
        end
    end
    button('PREVIOUS',60,650,160,36,function() U.saves_page=U.saves_page-1 end,muted,U.saves_page>1)
    txt(U.saves_page..' / '..pages..'  /  '..#entries..' SAVED RUNS',238,657,22,muted,800,'center')
    button('NEXT',1060,650,160,36,function() U.saves_page=U.saves_page+1 end,muted,U.saves_page<pages)
    button('BACK',w/2-130,h-93,260,43,function() U.navigate('home') end)
    if BT.save.scan then txt('CHECKING SAVES...',60,716,18,colors[2],360) end
end
local function credits(w,h)
    backdrop(w,h,'THE ZERO CREW','MADE BY THE ZERO CREW FOR THE ZERO CREW / VIVAT NIHIL')
    group(0.02,function()
        rect(60,197,548,424,panel)
        for i=1,4 do
            g.push();g.translate(126+(i-1)*125,260)
            if not BT.config.reduced_motion and (BT.config.motion or 1)>0 then g.rotate(math.sin(love.timer.getTime()*1.4+i)*0.06) end
            diamond(0,0,27,palette(i));g.pop()
        end
        txt('by Mind_the_assassin',88,323,38,ink,490,'center')
        txt('Balatro Together',88,382,29,colors[1],490,'center')
        txt('One table. Four builds. Your crew.',88,429,24,muted,490,'center')
        txt('Design, direction and supplied boss art:\nMind_the_assassin / the Zero Crew',88,484,23,ink,490,'center')
        txt('AI-assisted code and testing: Codex\nModding tools: Universal Modder',88,554,21,muted,490,'center')
    end)
    group(0.09,function()
        rect(636,197,584,424,panel)
        txt('BUILT ON GREAT MODS',664,222,29,colors[3],528)
        local rows={
            {'Balatro','LocalThunk / Playstack'},
            {'Lovely','ethangreen-dev and contributors'},
            {'Steamodded','Steamodded contributors'},
            {'Cryptid','MathIsFun_ / Cryptid contributors'},
            {'Amulet','frostice482 and contributors'},
            {'JSON','rxi / MIT licensed'},
        }
        for i,row in ipairs(rows) do local y=274+(i-1)*42
            txt(row[1],664,y,24,ink,155)
            txt(row[2],824,y+2,20,muted,368)
        end
        txt('Dependency licenses and exact sources ship with setup.\nTogether code: MIT / see ATTRIBUTION.md.',664,552,20,muted,528)
    end)
    button('OPEN CRASH REPORTS',60,650,360,46,function()
        love.filesystem.createDirectory('TogetherReports')
        love.system.openURL('file://'..love.filesystem.getSaveDirectory()..'/TogetherReports')
    end,muted)
    button('BACK',w/2-130,h-104,260,46,function() U.navigate(U.credits_return or 'home') end)
    txt('Crash reports stay on this PC. Nothing is uploaded.',60,712,18,muted,480)
end
local function scorebox(l)
    local s=BT.state; local z=l.s
    rect(l.x,l.y,l.w,l.score_h,panel,8*z)
    txt('TEAM  /  ANTE '..s.ante..'  /  '..(s.proposal and s.proposal.name or 'NEXT BLIND'),l.x+14*z,l.y+7*z,20*z,muted,l.w-28*z)
    txt(fmt(s.score)..' / '..fmt(s.target),l.x+14*z,l.y+26*z,29*z,ink,l.w-28*z)
    txt(s.target>0 and math.floor((BT.numbers and BT.numbers.ratio(s.score,s.target) or math.min(1,s.score/s.target))*100)..'%' or 'READY?',l.x+l.w-112*z,l.y+26*z,27*z,colors[1],95*z,'right')
    local bx=l.x+14*z; local by=l.y+56*z; local bw=l.w-28*z
    col(bg); g.rectangle('fill',bx,by,bw,5*z,2,2)
    local cursor=bx
    for i=1,4 do local p=s.players[tostring(i)]; if p and s.target>0 then
        local proportion=math.min((BT.numbers and BT.numbers.ratio(p.contribution,s.target) or p.contribution/s.target),1-U.progress_drawn)
        local width=bw*math.max(0,proportion)*U.progress
        col(palette(i)); g.rectangle('fill',cursor,by,width,5*z,2,2); cursor=cursor+width
        U.progress_drawn=U.progress_drawn+math.max(0,proportion)
    end end
end
-- Balatro's native blind UI remains visible in the lab.
local function hud(w,h)
    local s=BT.state; local l=layout.compute(w,h,BT.config.hud_scale,BT.config.hud_top); local z=l.s
    U.blind_rect=nil
    if BT.config.panels then
        local order={BT.client.id or 1}; for i=1,4 do if i~=BT.client.id then order[#order+1]=i end end
        local x=l.x
        for _,id in ipairs(order) do
            local p=s.players[tostring(id)]; local localplayer=id==BT.client.id; local width=(localplayer and 204 or 172)*z
            local y=l.y+l.panel_y; local c=palette(id)
            rect(x,y,width,l.panel_h,panel,7*z); col(c); g.rectangle('fill',x,y,4*z,l.panel_h,2,2)
            txt((localplayer and 'YOU • ' or '')..(p and p.name or 'Empty'),x+12*z,y+5*z,22*z,p and ink or muted,width-18*z)
            if p then
                local activity=not p.connected and 'DISCONNECTED' or p.ready and 'READY / WAITING' or (p.busy and 'CALCULATING' or p.activity:upper())
                txt(activity,x+12*z,y+27*z,15*z,c,width-18*z)
                txt(fmt(p.contribution)..'  H'..p.hands..' D'..p.discards..'  $'..p.money..'  J'..#p.jokers,x+12*z,y+45*z,16*z,muted,width-18*z)
            end
            local seat=id; hit(x,y,width,l.panel_h,function() U.expanded=U.expanded==seat and nil or seat; U.inspection_scroll=0 end,'Inspect seat '..id)
            x=x+width+l.gap
        end
    end
    if s.phase=='prepare' then
        button(me() and me().ready and 'READY / CLICK TO WAIT' or 'READY FOR SHARED BLIND',l.x+l.w/2-270*z,l.y+l.h+8*z,310*z,37*z,BT.game.ready,colors[1],not s.skip_vote)
        if s.blind_index<3 then button(s.skip_vote and ('SKIP '..s.skip_vote.yes..' / '..s.skip_vote.needed) or 'VOTE TO SKIP',l.x+l.w/2+52*z,l.y+l.h+8*z,220*z,37*z,function() if s.skip_vote then U.navigate('vote') else BT.game.vote_skip('yes') end end,colors[2]) end
    elseif s.phase=='shop' and G.STATE==G.STATES.BLIND_SELECT then
        button(me() and me().ready and 'WAITING FOR TEAM SHOPPERS' or 'READY FOR NEXT BLIND',l.x+l.w/2-180*z,l.y+l.h+8*z,360*z,37*z,BT.game.ready,colors[1],not (me() and me().ready))
    elseif s.phase=='saving' then
        local n=0;for _ in pairs(s.checkpoint and s.checkpoint.uploads or {}) do n=n+1 end
        txt('SAVING PARTY / '..n..' BUILDS RECEIVED',l.x,l.y+l.h+8*z,22*z,colors[2],l.w,'center')
    elseif s.phase=='skipping' then
        txt('MAJORITY PASSED / COLLECTING EVERY PLAYER\'S TAG',l.x,l.y+l.h+8*z,22*z,colors[2],l.w,'center')
    elseif s.phase=='starting' then
        txt('WAITING FOR EVERY PLAYER TO LOAD THE BLIND',l.x,l.y+l.h+8*z,22*z,colors[2],l.w,'center')
    elseif not BT.client.connected then
        txt('RECONNECTING — KEEP THIS GAME OPEN',l.x,l.y+l.h+8*z,22*z,colors[4],l.w,'center')
    elseif s.phase=='blind' and s.score>=s.target then
        txt('TEAM TARGET REACHED • FINISHING HANDS',l.x,l.y+l.h+8*z,22*z,colors[1],l.w,'center')
    elseif s.phase=='blind' and me() and me().exhausted then
        txt('OUT OF HANDS • CHEER ON YOUR TEAM',l.x,l.y+l.h+8*z,22*z,colors[2],l.w,'center')
    end
    if BT.config.diagnostics then txt('TCP '..(BT.client.connected and 'CONNECTED' or 'OFFLINE')..' / REV '..s.revision..' / ROUND '..s.round,14,h-28,17,muted) end
    button('TABLE [F8]',w-160,10,148,29,function() U.navigate('lobby') end,muted)
    button('DONATION BOX',w-160,49,148,29,function() U.navigate('donations') end,muted)
    button('BET POT',w-160,88,148,29,function() U.navigate('pot') end,muted)
    local own=me();local tickets=(own and own.dice_gold or 0)+(own and own.dice_red or 0)+(own and own.dice_boss or 0)
    button('DICE '..tickets,w-160,127,148,29,function() U.navigate('dice') end,tickets>0 and colors[2] or muted)
    if own and (own.dice_active_mult or 0)>0 then txt('DICE +'..own.dice_active_mult..' MULT',w-190,167,20,colors[4],178,'right') end
end
local function feed(w,h)
    local z=math.min(h/1080,1.2); local width=320*z; local x=BT.config.feed_right and w-width-18 or 18
    local y=h*0.48
    for i=math.max(1,#U.feed-3),#U.feed do
        local e=U.feed[i]; local age=love.timer.getTime()-e.time; local a=math.min(1,(BT.config.feed_duration-age)*2)
        if a>0 then
            local opacity=U.opacity;U.opacity=(opacity or 1)*math.min(1,a)
            local offset=(BT.config.reduced_motion or (BT.config.motion or 1)==0) and 0 or math.max(0,1-age*5)*30*z
            rect(x+offset,y,width,64*z,panel,7*z,a)
            local p=BT.state.players[tostring(e.player)]
            txt(p and p.name or 'TEAM',x+12*z+offset,y+6*z,20*z,palette(e.player),width-24*z)
            txt(e.amount and ((e.amount>=0 and '+' or '')..fmt(e.amount)..' • '..e.text) or e.text,x+12*z+offset,y+29*z,19*z,ink,width-24*z)
            y=y+72*z
            U.opacity=opacity
        end
    end
end
local function ending(w,h)
    local s=BT.state
    backdrop(w,h,s.phase=='victory' and 'FOUR OF A KIND.' or 'THE TABLE FOLDS.',s.phase=='victory' and 'A SHARED VICTORY. EVERY BUILD MATTERED.' or 'YOUR NEXT RUN IS ANOTHER CHANCE TOGETHER.')
    txt('TEAM '..fmt(s.lifetime_score)..' CHIPS  •  '..s.completed_antes..' ANTES COMPLETE',w/2-470,191,36,colors[1],940,'center')
    local top,topscore=nil,-1; for i=1,4 do local p=s.players[tostring(i)]; if p and p.highest>topscore then top=i; topscore=p.highest end end
    for i=1,4 do local p=s.players[tostring(i)]; if p then
        local y=263+(i-1)*77
        rect(w/2-470,y,940,64,panel)
        txt(p.name..(top==i and ' • MVP HAND' or ''),w/2-450,y+13,29,palette(i),310)
        txt(fmt(p.total)..' total  /  '..fmt(p.highest)..' best  /  '..p.hands_played..' hands',w/2-125,y+18,25,ink,570,'right')
    end end
    button('BET POT',60,610,260,43,function() U.screen='pot' end,colors[2])
    button('BACK TO TABLE',w/2-180,math.min(h-105,610),360,52,function() U.screen='lobby' end)
    button('FAST RESTART',w/2-180,math.min(h-45,674),360,39,BT.client.restart,colors[2],BT.client.model~=nil)
end
function U.update(dt)
    donation_view.update(dt)
    pot_view.update(dt)
    dice_view.update(dt)
    boss_view.update(dt)
    local s=BT.state
    if s and s.phase=='saving' and U.screen~='saving' then U.before_save=U.screen;U.navigate('saving')
    elseif U.screen=='saving' and not (s and s.phase=='saving') then local screen=U.before_save;U.before_save=nil;U.navigate(screen) end
    if s and s.skip_vote and U.vote_seen~=s.skip_vote.deadline then
        U.vote_seen=s.skip_vote.deadline;if not U.screen or U.screen=='lobby' then U.navigate('vote') end
    elseif U.screen=='vote' and not (s and s.skip_vote) then U.navigate(nil) end
    local editor=U.screen and U.ensure_editor()
    if editor and love.keyboard and love.keyboard.isDown then editor:update(dt,love.keyboard.isDown) end
    sync_screen()
    U.screen_age=U.screen_age+dt
    local reduced=BT.config.reduced_motion or (BT.config.motion or 1)==0
    local checkpoint=s and s.checkpoint
    if checkpoint and U.save_generation~=checkpoint.id then U.save_generation=checkpoint.id;U.save_progress={x=0,v=0} end
    if checkpoint and U.save_progress then
        local done,total=0,0
        for id,p in pairs(s.players) do if not p.withdrawn then total=total+1;if checkpoint.uploads[tostring(id)] then done=done+1 end end end
        motion.spring(U.save_progress,done/math.max(1,total),dt,reduced,BT.config.motion or 1)
    end
    U.seat_ready=U.seat_ready or {}
    for i=1,4 do
        U.seat_ready[i]=U.seat_ready[i] or {x=0,v=0}
        local p=s and s.players[tostring(i)]
        motion.spring(U.seat_ready[i],p and p.ready and 1 or 0,dt,reduced,BT.config.motion or 1)
    end
    motion.spring(U.opening,U.closing and 0 or 1,dt,reduced,BT.config.motion or 1)
    if U.closing and math.abs(U.opening.x)<0.015 then U.screen=nil;U.closing=false;U.focus=nil end
    local now=love.timer.getTime()
    for key,b in pairs(U.widgets) do
        if now-(b.seen or 0)>3 then U.widgets[key]=nil
        else motion.spring(b.hover,b.target or 0,dt,reduced,BT.config.motion or 1); motion.spring(b.press,0,dt,reduced,BT.config.motion or 1) end
    end
    if s and (U.run_id~=s.run_id or U.round_id~=s.round) then
        U.run_id=s.run_id; U.round_id=s.round; U.display_score=0; U.visual_score=0; U.previous_score=0; U.bursts={}
    end
    if s and U.feed_run~=s.run_id then U.seen={}; U.feed={}; U.feed_run=s.run_id end
    local target=s and s.target>0 and (BT.numbers and BT.numbers.ratio(s.score,s.target) or math.min(1,s.score/s.target)) or 0
    local intensity=BT.config.motion or 1
    local motion=(BT.config.reduced_motion or intensity==0) and 1 or math.min(1,dt*8*intensity)
    U.visual_score=(U.visual_score or 0)+(target-(U.visual_score or 0))*motion
    U.progress=target>0 and U.visual_score/target or 0
    if s then
        U.display_score=(U.display_score or 0)+(s.score-(U.display_score or 0))*motion
        if math.abs(s.score-U.display_score)<1 then U.display_score=s.score end
        if s.score>(U.previous_score or 0) then U.score_pulse=(BT.config.reduced_motion or intensity==0) and 0 or 1; U.previous_score=s.score end
    end
    U.score_pulse=math.max(0,(U.score_pulse or 0)-dt*2)
    U.open_amount=U.open_amount+((U.expanded and 1 or 0)-U.open_amount)*motion
    if U.expanded then U.shown_player=U.expanded end
    if s then
        for _,e in ipairs(s.events or {}) do
            if not U.seen[e.seq] then
                U.seen[e.seq]=true
                if (e.kind=='score' and BT.config.feed_scores) or (e.kind=='activity' and BT.config.feed_actions) or e.kind=='milestone' or e.kind=='connection' or e.kind=='donation' or e.kind=='pot' or e.kind=='dice' then
                    local v=BT.Session.copy(e); v.time=love.timer.getTime(); U.feed[#U.feed+1]=v
                    if #U.feed>8 then table.remove(U.feed,1) end
                    if BT.config.sounds and e.kind=='score' then pcall(play_sound,'chips1',1+e.player*0.06,0.22) end
                    if BT.config.effects and not BT.config.reduced_motion and intensity>0 and e.kind=='score' and e.amount and e.amount>0 then
                        U.bursts[#U.bursts+1]={time=love.timer.getTime(),player=e.player,amount=e.amount,power=e.amount>=s.target*0.5}
                        if #U.bursts>4 then table.remove(U.bursts,1) end
                    end
                end
            end
        end
    else U.seen={}; U.feed={}; U.expanded=nil end
end
local function celebrations(w,h)
    if BT.config.reduced_motion or not BT.config.effects or (BT.config.motion or 1)==0 then return end
    local z=math.min(w/1920,h/1080); local r=U.blind_rect
    if not r then return end
    for _,b in ipairs(U.bursts) do
        local age=love.timer.getTime()-b.time; local life=b.power and 1.2 or 0.7
        if age<life then
            local t=age/life; local c=palette(b.player); local cx=r.x+r.w/2; local cy=r.y+r.h*0.6
            if b.power then for i=1,14 do
                local angle=i*math.pi*2/14; local radius=(22+85*ease(t))*z*(BT.config.motion or 1)
                diamond(cx+math.cos(angle)*radius,cy+math.sin(angle)*radius,4*z*(1-t),c,1-t)
            end end
            txt('+'..fmt(b.amount),r.x,cy-35*z*t,28*z,c,r.w,'center')
        end
    end
end
function U.draw()
    -- Input can switch pages between update and draw. Start the transition
    -- immediately, avoiding one fully visible frame before its entrance.
    sync_screen()
    U.hits={};U.fields={}
    if G.OVERLAY_TUTORIAL then U.modal=nil;U.inspect_rect=nil;U.blind_rect=nil;return end
    if G.OVERLAY_MENU and not U.screen then
        -- Native deck/run-info/options menus own the screen and input. Clear
        -- cached bounds as well as hiding the HUD and its notifications.
        U.modal=nil;U.inspect_rect=nil;U.blind_rect=nil
        return
    end
    local w,h=g.getDimensions()
    g.push('all'); g.origin(); g.setShader(); g.setScissor(); g.setStencilTest(); g.setBlendMode('alpha'); g.setColorMask(true,true,true,true)
    U.hits={}; U.fields={}
    -- Modal screens use a fixed design coordinate system, fitted to any window.
    U.opacity=1
    if U.screen then
        local p=(BT.config.reduced_motion or (BT.config.motion or 1)==0) and 1 or U.opening.x
        local fit=math.min(w/1280,h/800);local scale=fit*(0.985+0.015*p)
        U.modal={scale=scale,x=(w-1280*scale)/2,y=(h-800*scale)/2+(1-p)*24*fit}
        g.translate(U.modal.x,U.modal.y);g.scale(scale)
        U.opacity=math.max(0,math.min(1,p))
        if U.screen=='home' then home(1280,800)
        elseif U.screen=='host' then connect_screen(1280,800,true)
        elseif U.screen=='join' then connect_screen(1280,800,false)
        elseif U.screen=='lobby' then lobby(1280,800)
        elseif U.screen=='boss_lab' then boss_view.rules(1280,800)
        elseif U.screen=='settings' then settings(1280,800)
        elseif U.screen=='credits' then credits(1280,800)
        elseif U.screen=='saves' then saved_runs(1280,800)
        elseif U.screen=='pin' then pin_screen(1280,800)
        elseif U.screen=='name' then name_screen(1280,800)
        elseif U.screen=='steam_invite' then steam_invite(1280,800)
        elseif U.screen=='steam_friends' then steam_friends(1280,800)
        elseif U.screen=='donations' then donation_view.draw(1280,800)
        elseif U.screen=='pot' then pot_view.draw(1280,800)
        elseif U.screen=='dice' then dice_view.draw(1280,800)
        elseif U.screen=='boss_rewards' then dice_view.draw_rewards(1280,800)
        elseif U.screen=='admin' then admin_view.draw(1280,800) end
        if U.screen=='vote' then vote_view.draw(1280,800) end
        if U.screen=='saving' then saving_view.draw(1280,800) end
    elseif BT.state and BT.state.phase~='lobby' then
        U.modal=nil
        if BT.state.phase=='victory' or BT.state.phase=='defeat' then
            local scale=math.min(w/1280,h/800); g.translate((w-1280*scale)/2,(h-800*scale)/2); g.scale(scale)
            U.modal={scale=scale,x=(w-1280*scale)/2,y=(h-800*scale)/2}; ending(1280,800)
        else hud(w,h); celebrations(w,h); feed(w,h); boss_view.draw(w,h); if U.open_amount>0.01 and U.shown_player then inspect_view.draw(w,h) end end
    else
        U.modal=nil
        if G.STAGE==G.STAGES.MAIN_MENU and not G.OVERLAY_MENU then
            local bw=math.min(210,w*0.32); local bh=math.max(34,math.min(48,h*0.06))
            button('TOGETHER [F8]',w-bw-18,math.max(88,h*0.15),bw,bh,U.menu)
        end
    end
    U.opacity=1
    if BT.message and love.timer.getTime()-(BT.message_time or 0)<8 then
        local compact=U.screen=='admin' or U.screen=='boss_rewards' or U.screen=='dice' or U.screen=='pot' or U.screen=='donations' or U.screen=='steam_friends' or U.screen=='saves' or U.screen=='credits'
        local top=compact and h-35 or h-85
        g.origin(); rect(w/2-math.min(w-30,800)/2,top,math.min(w-30,800),compact and 28 or 48,bg)
        txt(BT.message,w/2-math.min(w-50,780)/2,top+(compact and 4 or 11),compact and 16 or 22,ink,math.min(w-50,780),'center')
    end
    g.pop()
end
function U.install()
    local resize=love.resize
    function love.resize(w,h,...)
        -- Recreate our text atlases after a Windows graphics-mode change.
        -- Reusing them across setMode can leave previously cached glyphs blank.
        U.fonts={};inspect_view.reset()
        if resize then return resize(w,h,...) end
    end
    G.FUNCS.bt_menu=function() U.menu() end
    G.FUNCS.bt_credits=function() U.credits_return='home';U.navigate('credits') end
    BT.config_tab=function() return {n=G.UIT.ROOT,config={align='cm',padding=0.2,colour=G.C.BLACK},nodes={
        UIBox_button{label={'Together settings / lobby'},button='bt_menu',minw=5},
        UIBox_button{label={'Credits / Zero Crew'},button='bt_credits',minw=5},
        {n=G.UIT.R,config={align='cm'},nodes={{n=G.UIT.T,config={text='F8 opens Together at any time',scale=0.35,colour=G.C.WHITE}}}}
    }} end
    local draw=love.draw; function love.draw(...) draw(...); U.draw() end
    local wheel=love.wheelmoved; function love.wheelmoved(dx,dy)
        if G.OVERLAY_TUTORIAL then if wheel then return wheel(dx,dy) end;return end
        if U.screen then return end
        if G.OVERLAY_MENU then if wheel then return wheel(dx,dy) end;return end
        local r=U.inspect_rect; local x,y=love.mouse.getPosition()
        if U.expanded and r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h then
            U.inspection_scroll=math.max(0,math.min(U.inspect_max or 0,U.inspection_scroll-dy*36)); return
        end
        if wheel then return wheel(dx,dy) end
    end
    local press=love.mousepressed; function love.mousepressed(x,y,button,...)
        if G.OVERLAY_TUTORIAL then if press then return press(x,y,button,...) end;return end
        if G.OVERLAY_MENU and not U.screen then if press then return press(x,y,button,...) end;return end
        local px,py=x,y
        if U.modal then px=(x-U.modal.x)/U.modal.scale; py=(y-U.modal.y)/U.modal.scale end
        if button==1 then
            for i=#U.hits,1,-1 do local hit=U.hits[i]
                if px>=hit.x and px<=hit.x+hit.w and py>=hit.y and py<=hit.y+hit.h then hit.fn(); return end
            end
        end
        if U.screen or U.modal then return end
        if press then return press(x,y,button,...) end
    end
    local release=love.mousereleased; function love.mousereleased(...)
        if G.OVERLAY_TUTORIAL then if release then return release(...) end;return end
        if G.OVERLAY_MENU and not U.screen then if release then return release(...) end;return end
        if U.screen or U.modal then return end; if release then return release(...) end
    end
    local move=love.mousemoved; function love.mousemoved(...) if U.screen and not G.OVERLAY_TUTORIAL then return end; if move then return move(...) end end
    local key=love.keypressed; function love.keypressed(k,...)
        if G.OVERLAY_TUTORIAL then if key then return key(k,...) end;return end
        local scancode,isrepeat=...
        if BT.state and (BT.state.phase=='saving' or BT.state.phase=='resuming') and (k=='escape' or k=='f8' or k=='r' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl'))) then return end
        if k=='space' and BT.dice.space and BT.dice.space(isrepeat) then U.screen='dice';return end
        if BT.dice.challenge and BT.dice.challenge() and (k=='f8' or k=='escape') then U.screen='dice';return end
        if k=='/' and not U.focus and not (G.CONTROLLER and G.CONTROLLER.text_input_hook) then
            if BT.admin.allowed() then BT.admin.toggle(); return end
        end
        if k=='r' and BT.active() and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then BT.client.restart(); return end
        if k=='f8' then if U.screen then close() else U.screen=BT.state and 'lobby' or 'home' end; return end
        if U.screen then
            local ctrl=love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
            local shift=love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')
            local editor=U.ensure_editor()
            if editor and editor:key(k,ctrl,shift,isrepeat) then return end
            if k=='escape' then close()
            elseif k=='tab' then
                local index=0; for i,f in ipairs(U.fields) do if f==U.focus then index=i end end
                U.focus=U.fields[(index+(shift and -2 or 0))%math.max(1,#U.fields)+1];U.editor=nil;U.ensure_editor(true)
            elseif (k=='return' or k=='kpenter') and not isrepeat then
                if U.screen=='join' then
                    if (BT.config.transport or 'steam')=='steam' then BT.client.join_code(BT.config.room_code) else BT.client.join() end
                elseif U.screen=='name' then BT.client.rename(BT.config.username)
                elseif U.screen=='pin' then if BT.client.set_pin(BT.config.host_pin) then U.navigate('lobby') end
                else U.focus=nil end
            end
            return
        end
        if U.modal then return end
        if key then return key(k,...) end
    end
    local keyrelease=love.keyreleased
    function love.keyreleased(k,...)
        if U.editor then U.editor:release(k) end
        if k=='space' and BT.dice then BT.dice.space_down=false end
        if keyrelease then return keyrelease(k,...) end
    end
    local text=love.textinput; function love.textinput(t)
        if G.OVERLAY_TUTORIAL then if text then return text(t) end;return end
        if U.screen then
            local editor=U.ensure_editor();if editor then editor:write(t) end;return
        end
        if text then return text(t) end
    end
end
U.layout=layout
return U
