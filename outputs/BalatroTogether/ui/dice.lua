return function(U,h)
    local g=love.graphics; local H=BT.Session.Dice.Physics
    local motion=assert(SMODS.load_file('ui/motion.lua',BT.id))()
    local renderer=assert(SMODS.load_file('ui/dice_renderer.lua',BT.id))()(H,g,h.col)
    local V={time=0,opening={x=0,v=0},widgets={},revealed={},particles={},flash=0,shake=0,selected=nil,launch={x=1,v=0},impact={x=0,v=0},prize={x=1,v=0},pointer={x=0,v=0},space={x=0,v=0},progress={x=0,v=0}}
    local gold={1,0.76,0.24}; local red={1,0.25,0.36}; local violet={0.69,0.59,1}
    local function reduced() return BT.config.reduced_motion or (BT.config.motion or 1)==0 end
    function U.qte_press()
        if not reduced() then V.space.x=1;V.space.v=0;V.flash=0.14 end
        if BT.config.sounds then pcall(play_sound,'card1',1.1+(V.time%0.2),0.25) end
    end
    local function button(label,x,y,w,height,fn,c,enabled)
        h.button(label,x,y,w,height,fn,c,enabled)
    end
    function V.update(dt)
        V.time=V.time+dt
        if V.screen~=U.screen then V.screen=U.screen; if U.screen=='dice' then V.opening={x=0,v=0}; V.widgets={} end end
        if V.run~=(BT.state and BT.state.run_id) then V.run=BT.state and BT.state.run_id; V.revealed={}; V.particles={}; V.selected=BT.client.id;V.preview=nil end
        motion.spring(V.opening,U.screen=='dice' and 1 or 0,dt,reduced(),BT.config.motion or 1)
        for _,name in ipairs({'launch','impact','prize','pointer','space','progress'}) do
            local target=(name=='launch' or name=='prize') and 1 or 0
            if name=='progress' then
                local roll=BT.state and BT.state.dice and BT.state.dice.rolls[tostring(V.selected or BT.client.id)]
                target=roll and roll.status=='challenge' and roll.challenge.hits/roll.challenge.required or 0
            end
            motion.spring(V[name],target,dt,reduced(),BT.config.motion or 1)
        end
        V.flash=math.max(0,V.flash-dt*1.8); V.shake=math.max(0,V.shake-dt*6)
        local a=BT.dice.animations[tostring(V.selected or BT.client.id)]
        if a and V.animation~=a.id then
            V.animation=a.id;V.impacts=0;V.preview=nil
            if not reduced() then V.launch={x=0.84,v=0};V.prize={x=0.6,v=0} end
        end
        if a and a.pose and a.pose.impacts>(V.impacts or 0) then
            V.impacts=a.pose.impacts
            if not reduced() then
                if a.roll.die=='boss' then V.pointer.x=-0.22;V.pointer.v=-1.1
                else V.impact.x=1;V.impact.v=0;V.shake=0.4;V.impact_time=V.time end
            end
        end
        if a and a.elapsed>=a.roll.duration and not V.revealed[a.id] then
            V.revealed[a.id]=true
            if U.screen=='dice' then
                V.reveal_time=V.time; V.flash=reduced() and 0 or 0.65;V.prize={x=reduced() and 1 or 0.55,v=0}
                if BT.config.sounds then pcall(play_sound,a.roll.die=='gold' and 'timpani' or 'tarot1',a.roll.face==20 and 0.7 or 1.1,0.45) end
                if not reduced() and BT.config.effects then
                    for i=1,a.roll.die=='boss' and 100 or 64 do local angle=i*2.39996; local speed=130+(i%7)*34
                        V.particles[#V.particles+1]={x=425,y=425,vx=math.cos(angle)*speed,vy=math.sin(angle)*speed-150,age=0,die=a.roll.die,spin=angle}
                    end
                end
            end
        end
        for i=#V.particles,1,-1 do
            local p=V.particles[i]; p.age=p.age+dt
            p.x=p.x+p.vx*dt; p.y=p.y+p.vy*dt; p.vy=p.vy+330*dt
            if p.age>1.6 or reduced() then table.remove(V.particles,i) end
        end
    end
    function V.amount() return reduced() and 1 or V.opening.x end
    local wheel_labels={'$35','FREE x3','HANDS','DISCARDS','CHIPS','MULT','LEVELS','SHOP','TOOLKIT','LUCKY','HOT','RICH','FREE x6','LEVELS','GOLD','LIMIT','DRIVE','COSMIC','ROYAL','CROWN','100'}
    local wheel_colors={{0.12,0.54,0.48},{0.32,0.23,0.62},{0.15,0.39,0.56},{0.59,0.25,0.41}}
    function V.wheel(angle,face)
        local cx,cy,radius=425,410,145
        h.col({0,0,0},0.35); g.ellipse('fill',cx,cy+158,164,12)
        h.col({0.035,0.05,0.045}); g.circle('fill',cx,cy+7,167)
        h.col({0.36,0.40,0.33}); g.circle('fill',cx,cy,166)
        h.col({0.08,0.13,0.12}); g.circle('fill',cx,cy,161)
        h.col(violet); g.setLineWidth(4); g.circle('line',cx,cy,157)
        local low=1
        for i,reward in ipairs(BT.Session.Dice.Boss.tiers) do
            local first=-math.pi/2+(low-1)/100*math.pi*2+angle
            local last=-math.pi/2+reward.max/100*math.pi*2+angle
            local points={cx,cy}; local steps=math.max(2,math.ceil((last-first)*35))
            for n=0,steps do local a=first+(last-first)*n/steps; points[#points+1]=cx+math.cos(a)*radius; points[#points+1]=cy+math.sin(a)*radius end
            local won=face and face>=low and face<=reward.max
            local c=i==21 and gold or wheel_colors[(i-1)%#wheel_colors+1]
            h.col(c,won and 1 or 0.88); g.polygon('fill',points)
            h.col(won and gold or {0.09,0.13,0.20}); g.setLineWidth(won and 3 or 1.5); g.polygon('line',points)
            local middle=(first+last)/2
            g.push(); g.translate(cx+math.cos(middle)*98,cy+math.sin(middle)*98)
            local direction=middle%(2*math.pi); g.rotate(middle+(direction>math.pi/2 and direction<math.pi*1.5 and math.pi or 0))
            h.txt(wheel_labels[i],-48,-7,i==21 and 10 or 14,i==21 and {0.14,0.09,0.02} or h.ink,96,'center'); g.pop()
            low=reward.max+1
        end
        for i=0,39 do
            local a=i/40*math.pi*2; local pulse=reduced() and 1 or 0.6+0.4*math.sin(V.time*7-i*0.8)
            h.col(face and gold or violet,0.55+0.45*pulse); g.circle('fill',cx+math.cos(a)*157,cy+math.sin(a)*157,2.5)
        end
        h.col({0.06,0.09,0.15}); g.circle('fill',cx,cy,49); h.col(gold); g.setLineWidth(3); g.circle('line',cx,cy,49)
        h.txt(face and 'WON!' or 'ZERO',cx-46,cy-23,25,gold,92,'center')
        h.txt(face and tostring(face) or 'WHEEL',cx-46,cy+7,21,h.ink,92,'center')
        local flick=reduced() and 0 or V.pointer.x
        g.push(); g.translate(cx,cy-radius-9); g.rotate(flick)
        h.col({0,0,0},0.4); g.polygon('fill',-15,-14,15,-14,0,23)
        h.col(gold); g.polygon('fill',-12,-16,12,-16,0,17); g.pop()
    end
    function V.draw(w,height)
        h.backdrop(w,height,'THE REWARD TABLE','YOUR SPOILS. YOUR MOMENT. SEND IT.')
        local s=BT.state; local p=s and s.players[tostring(BT.client.id)]
        if not p or not s.dice then h.txt('Start a party run to earn reward dice.',60,230,30,h.ink); return end
        renderer.warm()
        local seat=V.selected or BT.client.id; local player=s.players[tostring(seat)] or p
        local a=BT.dice.animations[tostring(seat)]; local roll=a and a.roll
        local challenge=s.dice.rolls[tostring(seat)]
        challenge=challenge and challenge.status=='challenge' and challenge or nil
        local busy=roll and a.elapsed<roll.duration
        if V.preview and not busy and roll and V.preview~=roll.die then a=nil;roll=nil end
        local kind=challenge and 'boss' or roll and roll.die or V.preview or ((player.dice_boss or 0)>0 and 'boss' or 'gold')
        local color=kind=='red' and red or kind=='boss' and violet or gold
        button('WHEEL PRIZES',990,124,230,32,function() U.screen='boss_rewards' end,violet)
        h.rect(60,190,735,482,h.panel,18)
        h.rect(78,207,699,53,{0.10,0.16,0.14},9)
        h.txt(kind=='gold' and 'GOLD D6 / CASH DROP' or kind=='red' and 'RED D20 / NEXT BLIND MULT' or 'BOSS WHEEL / ALL GOOD THINGS',93,217,28,color,669,'center')
        h.txt(player.name,94,273,17,h.muted,170)
        local shake=reduced() and 0 or V.shake
        g.push(); g.translate(math.sin(V.time*100)*shake*2,math.cos(V.time*87)*shake*1.5)
        local pose=a and a.pose
        if challenge then
            local c=challenge.challenge
            local remaining=math.max(0,c.duration-c.elapsed)
            h.txt('FUCK THE TABLE',92,296,49,red,665,'center')
            h.txt('32 PRESSES. 5 SECONDS. ONE JACKPOT.',92,354,23,h.muted,665,'center')
            local press=reduced() and 0 or V.space.x
            g.push();g.translate(425,423+press*5);g.scale(1-press*0.035,1-press*0.06)
            h.rect(-144,-32,288,63,gold,9);h.txt('SPACE',-136,-22,40,{0.10,0.13,0.10},272,'center');g.pop()
            h.txt(c.hits..' / '..c.required,112,475,34,h.ink,620,'center')
            for i=1,c.required do
                local x=116+(i-1)*19.3
                h.col(i<=c.hits and gold or {0.10,0.15,0.13});g.rectangle('fill',x,523,16,14,2,2)
            end
            h.rect(115,554,620,15,{0.08,0.12,0.10},4)
            h.col(remaining<1.5 and red or gold);g.rectangle('fill',118,557,614*remaining/c.duration,7)
            h.txt(string.format('%.1fs',remaining),100,576,34,remaining<1.5 and red or gold,650,'center')
            h.txt('PRESS AND RELEASE / WIN = PERFECT HUNDRED',100,632,20,h.muted,650,'center')
        elseif kind=='boss' then
            g.push();g.translate(425,420);g.scale(V.launch.x*0.92);g.translate(-425,-410)
            V.wheel(pose and pose.angle or (reduced() and 0 or V.time*0.04),roll and a.elapsed>=roll.duration and roll.face or nil)
            g.pop()
        else
            renderer.tray(425,478,48)
            if not pose then
                local t=reduced() and 0 or V.time
                local q={0.92,0.21,0.27*math.sin(t*0.35),0.15*math.cos(t*0.35)}; local length=math.sqrt(q[1]^2+q[2]^2+q[3]^2+q[4]^2)
                for i=1,4 do q[i]=q[i]/length end
                pose={x=0,y=0,z=1.9+math.sin(t*1.5)*0.14,q=q}
            end
            if a and a.elapsed<a.roll.duration and not reduced() and BT.config.effects then
                for i=4,1,-1 do renderer.die(H.sample(a.frames,math.max(0,a.elapsed-i*0.035)),roll.die,425,478,48,0.055*(5-i)) end
            end
            local bounce=reduced() and 0 or V.impact.x
            g.push();g.translate(425,478);g.scale(V.launch.x*(1+bounce*0.045),V.launch.x*(1-bounce*0.07));g.translate(-425,-478)
            renderer.die(pose,kind,425,478,48);g.pop()
            local age=V.impact_time and V.time-V.impact_time or 1
            if not reduced() and BT.config.effects and age<0.45 then
                h.col(color,(1-age/0.45)*0.32);g.setLineWidth(2);g.ellipse('line',425,479,70+age*125,25+age*35)
            end
        end
        g.pop()
        if challenge then
        elseif roll and a.elapsed>=roll.duration then
            local pop=reduced() and 1 or V.prize.x
            g.push(); g.translate(425,600); g.scale(pop)
            local headline=roll.die=='gold' and ('+$'..roll.payout) or roll.die=='red' and ('+'..roll.face..' MULT') or (roll.face==100 and 'JACKPOT / ' or '')..roll.reward.name
            h.txt(headline,-325,-23,roll.die=='boss' and 36 or 58,color,650,'center'); g.pop()
            if roll.die=='boss' then
                local r=roll.reward; local permanent={}; local nextblind={}
                if r.money then permanent[#permanent+1]='+$'..r.money end
                if r.levels then permanent[#permanent+1]='ALL HANDS +'..r.levels..' LEVELS' end
                if r.rerolls then permanent[#permanent+1]=r.rerolls..' FREE REFRESHES' end
                for _,field in ipairs({'hands','discards','chips','mult'}) do if r[field] then nextblind[#nextblind+1]='+'..r[field]..' '..field:upper() end end
                h.txt(table.concat(permanent,' / '),80,627,17,h.ink,695,'center')
                h.txt(#nextblind>0 and ('NEXT BLIND: '..table.concat(nextblind,' / ')) or 'ALL GOOD. NO DOWNSIDES.',80,651,17,h.muted,695,'center')
            else h.txt(roll.die=='red' and (roll.face==20 and 'NATURAL 20 / NEXT BLIND POWERED UP' or 'EVERY HAND IN YOUR NEXT BLIND') or ('ROLLED '..roll.face..' / $5 PER PIP'),100,645,20,h.muted,650,'center') end
        else
            h.txt(roll and (kind=='boss' and 'ROUND AND ROUND...' or 'LET IT BOUNCE.') or (kind=='boss' and 'EVERY SECTOR WINS.' or kind=='red' and '+1 TO +20 MULT / ONE BLIND' or '$5 PER PIP / NO BAD ROLLS'),100,605,29,color,650,'center')
            h.txt(roll and 'THE RESULT IS LOCKED. ENJOY THE RIDE.' or 'Pick your reward on the right to roll.',100,644,19,h.muted,650,'center')
        end
        local section=U.group or function(_,draw) draw() end
        section(0.04,function()
        h.rect(821,185,413,134,h.panel,12)
        h.txt('GOLD D6  x'..(p.dice_gold or 0),839,195,29,gold,277)
        button('LOOK',1125,197,94,28,function() V.preview='gold' end,gold)
        h.txt('$5 x face / $5-$30 to your wallet',835,231,20,h.muted,385)
        button('ROLL GOLD D6',835,265,385,43,function() V.selected=BT.client.id; V.preview=nil; V.impacts=0; BT.dice.roll('gold') end,gold,BT.dice.available('gold'))
        end)
        section(0.085,function()
        h.rect(821,324,413,134,h.panel,12)
        h.txt('RED D20  x'..(p.dice_red or 0),839,334,29,red,277)
        button('LOOK',1125,336,94,28,function() V.preview='red' end,red)
        h.txt('+1 to +20 Mult for the next blind',835,370,20,h.muted,385)
        button('ROLL RED D20',835,402,385,43,function() V.selected=BT.client.id; V.preview=nil; V.impacts=0; BT.dice.roll('red') end,red,BT.dice.available('red'))
        end)
        section(0.13,function()
        h.rect(821,463,413,197,h.panel,12)
        h.txt('BOSS WHEEL  x'..(p.dice_boss or 0),839,473,29,violet,277)
        button('LOOK',1125,475,94,28,function() V.preview='boss' end,violet)
        h.txt('One spin per boss win / 21 good rewards',835,506,20,h.muted,385)
        button('SPIN BOSS WHEEL',835,538,385,43,function() V.selected=BT.client.id; V.preview=nil; V.impacts=0; BT.dice.roll('boss') end,violet,BT.dice.available('boss'))
        button('FUCK THE TABLE',835,591,385,43,function() V.selected=BT.client.id;V.preview=nil;V.impacts=0;BT.dice.roll('boss',true) end,red,BT.dice.available('boss'))
        h.txt('32 Space presses / 5 seconds / uses 1 spin',835,641,17,h.muted,385)
        end)
        h.txt('NEXT: +'..(p.dice_next_mult or 0)..' MULT / +'..(p.dice_next_chips or 0)..' CHIPS',835,666,18,violet,385)
        if not p.ready then h.txt('REFRESHES: '..(G.GAME.bt_boss_rerolls or 0)..' / H+'..(p.dice_next_hands or 0)..' D+'..(p.dice_next_discards or 0),835,688,17,gold,385) end
        for i=1,4 do local q=s.players[tostring(i)]; if q then
            button((i==BT.client.id and 'YOU' or q.name),60+(i-1)*186,688,174,34,function() V.selected=i; V.preview=nil; V.impacts=0 end,seat==i and color or h.muted)
        end end
        if p.ready and (s.phase=='prepare' or s.phase=='shop') then button('UNREADY TO ROLL',835,688,385,34,BT.client.ready,red) end
        h.txt(BT.dice.busy() and 'YOUR DIE IS RESOLVING. KEEP THIS GAME OPEN.' or 'Free rewards. Roll while unready in the shop or between blinds.',60,730,20,h.muted,870)
        button('BACK TO RUN',970,718,250,34,function() if U.close then U.close() else U.screen=nil end end,h.muted)
        if not reduced() and BT.config.effects then
            if V.flash>0 then h.col(color,V.flash*0.13); g.rectangle('fill',60,190,735,482,18,18) end
            for _,particle in ipairs(V.particles) do
                local alpha=math.max(0,1-particle.age/1.6); local c=particle.die=='gold' and gold or particle.die=='boss' and violet or red
                g.push(); g.translate(particle.x,particle.y); g.rotate(particle.spin+particle.age*5)
                h.col(c,alpha)
                if particle.die=='gold' then g.ellipse('fill',0,0,8,8*math.max(0.15,math.abs(math.cos(particle.age*9+particle.spin))))
                else g.polygon('fill',-4,-12,4,-12,2,12,-2,12) end
                g.pop()
            end
        end
    end
    function V.draw_rewards(w,height)
        h.backdrop(w,height,'BOSS WHEEL','EVERY RESULT IS A REWARD. HANDS, DISCARDS, CHIPS AND MULT LAST ONE BLIND.')
        local low=1
        for i,r in ipairs(BT.Session.Dice.Boss.tiers) do
            local x=60+math.floor((i-1)/7)*393; local y=185+(i-1)%7*74
            h.rect(x,y,375,67,h.panel,9)
            h.txt((low==r.max and tostring(r.max) or low..'-'..r.max)..' / '..r.name,x+10,y+5,21,violet,355)
            local description=r.max==100 and '+$100 / ALL LEVELS +3 / 6 FREE REFRESHES\nNEXT: +3 HANDS & DISCARDS / +400 CHIPS / +100 MULT' or BT.Session.Dice.Boss.describe(r)
            h.txt(description,x+10,y+30,r.max==100 and 13 or 15,h.muted,355)
            low=r.max+1
        end
        button('BACK TO DICE',950,718,270,34,function() U.screen='dice' end,violet)
    end
    return V
end
