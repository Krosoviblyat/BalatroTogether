return function(U,h)
    local g=love.graphics;local H=BT.Session.Harbinger
    local motion=assert(SMODS.load_file('ui/motion.lua',BT.id))()
    local V={time=0,quads={},pulse={x=0,v=0},entrance={x=0,v=0},age=0}
    local purple={0.72,0.28,1};local light={0.94,0.73,1};local dark={0.12,0.07,0.18}
    local function still() return BT.config.reduced_motion or (BT.config.motion or 1)==0 end
    local function fmt(v) return BT.numbers.format(v or 0) end
    function V.clear_native()
        for node,visible in pairs(V.hidden or {}) do if node.states then node.states.visible=visible end end;V.hidden={}
        if V.clash_text then V.clash_text:remove();V.clash_text=nil end
        V.clash_active=false
    end
    local function native_clash(a,dt)
        local show=a and a.age>=1.15 and not U.screen and not G.OVERLAY_MENU and not G.OVERLAY_TUTORIAL
        if not show then V.clear_native();return end
        V.clash_active=true;V.hidden=V.hidden or {}
        for _,key in ipairs({'hand_text_area','hand_mult_area','hand_chip_total'}) do
            local node=G.HUD and G.HUD:get_UIE_by_ID(key)
            if node and node.states then
                if V.hidden[node]==nil then V.hidden[node]=node.states.visible end
                node.states.visible=false
            end
        end
        if not V.clash_text then
            V.clash_text=DynaText{string={'CLASH'},colours={{0.97,0.88,1,1}},scale=1.25,shadow=true,
                float=not still(),bump=not still(),rotate=not still(),spacing=2,silent=true,pop_in=0,pop_in_rate=10,
                min_cycle_time=still() and 0 or nil,text_outline={0.32,0.08,0.49,1},text_outline_scale=0.025}
            if V.clash_sound~=a.id then V.clash_sound=a.id
                if BT.config.sounds then pcall(play_sound,'gong',0.82,0.22);pcall(play_sound,'cardSlide1',0.8,0.23) end
            end
        end
        V.clash_text:update(dt)
        if a.hit and V.clash_impact~=a.id then V.clash_impact=a.id;if not still() then V.clash_text:pulse(0.7) end end
    end
    function V.update(dt)
        V.time=V.time+dt
        local b=BT.state and BT.state.harbinger;local a=b and b.pending
        native_clash(a,dt)
        if a then
            if V.id~=a.id then V.id=a.id;V.age=0;V.entrance={x=0,v=0};V.hit=false end
            V.age=math.min(a.age+0.08,V.age+dt);V.age=math.max(V.age,a.age)
            if a.hit and not V.hit then V.hit=true;V.pulse.x=1;V.pulse.v=0
                if BT.config.sounds and U.screen==nil then pcall(play_sound,'tarot2',0.72,0.45);pcall(play_sound,'chips2',0.8,0.28) end
            end
            local flips=math.floor(math.max(0,V.age-0.2)/0.13)
            if flips~=(V.flips or 0) and V.age<1.15 and BT.config.sounds and not still() and not U.screen then pcall(play_sound,'card1',0.9+flips*0.035,0.10) end
            V.flips=flips
        end
        motion.spring(V.entrance,a and 1 or 0,dt,still(),BT.config.motion or 1)
        motion.spring(V.pulse,0,dt,still(),BT.config.motion or 1)
    end
    local function sprite(atlas,pos,x,y,w,height,key)
        if not atlas or not atlas.image then return false end
        local image=atlas.image;local px,py=atlas.px,atlas.py;local name=tostring(image)..':'..key
        local q=V.quads[name]
        if not q then q=g.newQuad(pos.x*px,pos.y*py,px,py,image:getDimensions());V.quads[name]=q end
        h.col({1,1,1});g.draw(image,q,x,y,0,w/px,height/py);return true
    end
    function V.chip(x,y,size,juice)
        local atlas=G.ANIMATION_ATLAS and G.ANIMATION_ATLAS.btogether_harbinger
        g.push();g.translate(x,y);local s=1+(still() and 0 or (juice or 0)*0.12);g.scale(s,s)
        if not sprite(atlas,{x=0,y=0},-size/2,-size/2,size,size,'harbinger') then h.col(purple);g.circle('fill',0,0,size/2) end
        g.pop()
    end
    local rank={[14]='A',[13]='K',[12]='Q',[11]='J',[10]='T'}
    local suits={Spades='S',Hearts='H',Clubs='C',Diamonds='D'}
    local function card(c,x,y,w,height,flip,scoring)
        local show=flip>=0.5;local sx=math.max(0.03,math.abs(math.cos(flip*math.pi)))
        g.push();g.translate(x+w/2,y+height/2);g.scale(sx,1);g.translate(-w/2,-height/2)
        h.rect(-3,-3,w+6,height+6,show and scoring and purple or {0.27,0.17,0.34},6)
        if not show then
            h.rect(0,0,w,height,dark,5);h.col(purple,0.8);g.setLineWidth(1)
            for n=1,4 do g.rectangle('line',n*4,n*4,w-n*8,height-n*8,3,3) end
            V.chip(w/2,height/2,w*0.55)
        else
            h.rect(0,0,w,height,{0.98,0.96,0.88},5)
            local key=suits[c.suit]..'_'..(rank[c.rank] or tostring(c.rank));local front=G.P_CARDS[key]
            local atlas=G.ASSET_ATLAS[front and front.atlas or (G.SETTINGS.colourblind_option and 'cards_2' or 'cards_1')]
            if not front or not sprite(atlas,front.pos,0,0,w,height,key) then
                h.txt(rank[c.rank] or c.rank,5,4,w*0.35,{0.2,0.08,0.24},w-10)
            end
            if not scoring then h.col(dark,0.3);g.rectangle('fill',0,0,w,height,4,4) end
        end
        g.pop()
    end
    function V.draw(w,height)
        local s=BT.state;local b=s and s.harbinger
        if not b or (s.phase~='blind' and s.phase~='starting') or U.expanded then return end
        local z=math.min(w/1280,height/800);local a=b.pending
        if not a then
            return
        end
        local p=V.entrance.x;local impact=still() and 0 or V.pulse.x
        local width=670*z;local x=w/2-width/2+58*z;local y=height*0.29+(1-p)*28*z
        g.push();g.translate(x+width/2,y+155*z);g.scale(still() and 1 or 0.97+0.03*p);g.translate(-x-width/2,-y-155*z)
        h.rect(x,y,width,312*z,dark,12*z)
        h.col(purple,0.7);g.setLineWidth(2*z);g.rectangle('line',x+5*z,y+5*z,width-10*z,302*z,8*z,8*z)
        local bob=still() and 0 or math.sin(V.time*2)*2*z
        V.chip(x+52*z,y+47*z+bob,72*z,impact)
        h.txt('THE HARBINGER',x+102*z,y+15*z,31*z,light,width-120*z)
        local detail=(V.age>=1.15 or still()) and (a.name:upper()..' / '..a.chips..' CHIPS x '..a.mult..' MULT') or ('COUNTER '..b.turn..' / '..H.tier(s).name..' STAKE')
        h.txt(detail,x+102*z,y+50*z,17*z,h.muted,width-120*z)
        local scoring={};for _,i in ipairs(a.scoring) do scoring[i]=true end
        local cw,ch=66*z,88*z;local gap=18*z;local left=x+width/2-(5*cw+4*gap)/2
        for i,c in ipairs(a.cards) do
            local age=V.age-0.15-i*0.13;local reveal=still() and 1 or math.max(0,math.min(1,age/0.28))
            local lift=still() and 0 or (1-motion.reveal(math.max(0,age),0,false))*22*z
            g.push();g.translate(left+(i-1)*(cw+gap)+cw/2,y+130*z);g.rotate(still() and 0 or math.sin(V.age*1.6+i)*0.015)
            card(c,-cw/2,-ch/2+lift,cw,ch,reveal,scoring[i]);g.pop()
        end
        local text=V.age>1.15 or still()
        if not V.clash_active then
            h.txt(text and a.name:upper() or 'DEALING ITS OWN HAND...',x+20*z,y+186*z,29*z,light,width-40*z,'center')
            h.txt(text and (a.chips..' CHIPS  x  '..a.mult..' MULT') or 'A REAL DECK. A REAL COUNTER.',x+20*z,y+222*z,22*z,h.ink,width-40*z,'center')
        end
        local stamp=a.hit and ('TEAM -'..fmt(a.removed)) or (text and ('INCOMING '..fmt(a.damage)..' DAMAGE') or 'YOUR SCORE IS ON THE LINE')
        g.push();g.translate(x+width/2,y+269*z);g.scale(1+impact*0.11)
        h.txt(stamp,-width/2+20*z,-15*z,31*z,a.hit and {1,0.34,0.58} or purple,width-40*z,'center');g.pop()
        if impact>0.02 and BT.config.effects and not still() then
            h.col(light,impact*0.7);g.setLineWidth(3*z);g.rectangle('line',x-impact*10*z,y-impact*6*z,width+impact*20*z,312*z+impact*12*z,10*z,10*z)
        end
        g.pop()
        if V.clash_text then
            -- Native DynaText draws through prep_draw in engine tile units.
            -- Position it in the counter's scoring slot after our panel, retaining
            -- Balatro's own letter bounce, pulse, shadows and font rendering.
            local object=V.clash_text;local unit=G.TILESCALE*G.TILESIZE
            object.T.x=(x+width/2)/unit-object.T.w/2;object.T.y=(y+214*z)/unit-object.T.h/2
            object.VT.x=object.T.x;object.VT.y=object.T.y;object.VT.w=object.T.w;object.VT.h=object.T.h
            g.push('all');g.origin();h.col(purple,0.17);g.ellipse('fill',x+width/2,y+217*z,190*z,35*z)
            object:draw();g.pop()
        end
    end
    function V.rules(w,height)
        h.backdrop(w,height,'THE HARBINGER','BOSS RULES / OWN DECK / YOUR TEAM SCORE IS ITS TARGET')
        V.chip(255,395,260,still() and 0 or math.sin(V.time*2)*0.25)
        h.txt('YOUR SKIN. YOUR NEMESIS.',65,568,24,light,395,'center')
        h.txt('It counters every team hand.\nIts chips x Mult become damage.\nBeat the target AFTER its reply.',65,611,23,h.muted,395,'center')
        local s=BT.state;local stake=s and s.boss_stake or BT.config.boss_stake or 1
        local own=s and BT.client.model and s.phase=='lobby';local enabled=not s or own
        local function change(key,value)
            BT.config[key]=value;BT.persist()
            if own then BT.client.action('boss_rules',{stake=BT.config.boss_stake,mode=BT.config.boss_mode,quick=BT.config.quick_duel}) end
        end
        h.txt('BOSS STAKES',520,206,32,light,650)
        for i,tier in ipairs(H.tiers) do
            local y=254+(i-1)*72
            h.button((i==stake and '> ' or '')..tier.name,520,y,220,49,function() change('boss_stake',i) end,tier.color,enabled)
            h.txt('Boss goal x'..tier.target..' / counter x'..tier.damage,760,y+7,22,h.ink,450)
            h.txt('Harbinger hand levels +'..tier.level,760,y+31,16,h.muted,450)
        end
        local mode=s and s.boss_mode or BT.config.boss_mode
        local quick=s and s.quick_duel or not s and BT.config.quick_duel
        h.button(mode=='harbinger' and 'BOSSES: HARBINGER AFTER ANTE 1' or 'MIXED BOSSES / HARBINGER 20%',520,558,650,44,function() change('boss_mode',mode=='harbinger' and 'mixed' or 'harbinger') end,purple,enabled)
        h.button(quick and 'QUICK DUEL / FORCED BOSS TEST' or 'FULL RUN / START AT SMALL BLIND',520,616,650,44,function() change('quick_duel',not quick) end,light,enabled)
        h.txt(quick and 'Test mode deliberately forces The Harbinger without a warm-up.' or 'First boss protected. Mixed mode: 20% from Ante 2. Finale bosses stay native.',520,679,16,h.muted,650)
        h.button('BACK',920,718,250,36,function() U.navigate(s and 'lobby' or 'home') end,h.muted)
    end
    U.harbinger_view=V
    return V
end
