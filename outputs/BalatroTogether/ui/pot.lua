return function(U,h)
    local g=love.graphics
    local motion=assert(SMODS.load_file('ui/motion.lua',BT.id))()
    local V={opening={x=0,v=0},pulse={x=0,v=0},count={x=0,v=0},widgets={},coins={},time=0,bet=5,entry='5',scope='team'}
    local function reduced() return BT.config.reduced_motion or (BT.config.motion or 1)==0 end
    local function own() return BT.state and BT.state.players[tostring(BT.client.id)] end
    local function set_amount(value)
        V.entry=tostring(value);V.bet=value;U.focus=nil;V.selected=false
    end
    local function edit(value)
        -- Accept formatted clipboard dollars, but never turn negatives or
        -- exponent notation into a different, unintended positive amount.
        value=value:gsub('[%s,$]','')
        if value:find('[^0-9]') or #value>5 then return end
        V.entry=value;V.bet=tonumber(value) or 0;V.selected=false
    end
    function V.textinput(value)
        if U.focus~='pot_amount' then return false end
        if value:find('[^0-9]') then return true end
        edit((V.selected and '' or V.entry)..value);return true
    end
    function V.keypressed(key,ctrl)
        if U.focus~='pot_amount' then return false end
        if ctrl and key=='a' then V.selected=true
        elseif ctrl and key=='v' then edit(love.system.getClipboardText())
        elseif key=='backspace' or key=='delete' then edit(V.selected and '' or V.entry:sub(1,-2))
        elseif key=='return' or key=='kpenter' or key=='escape' then U.focus=nil;V.selected=false
        elseif key=='tab' then return false end
        return true
    end
    local function animate(kind,amount)
        if reduced() then return end
        V.pulse.x=1; V.pulse.v=0
        if BT.config.effects then
            for i=1,math.min(12,math.max(3,amount or 3)) do
                V.coins[#V.coins+1]={time=V.time+i*0.025,kind=kind,angle=i*2.4}
            end
            while #V.coins>36 do table.remove(V.coins,1) end
        end
        if BT.config.sounds then pcall(play_sound,'coin1',kind=='payout' and 1.2 or 0.95,0.25) end
    end
    function U.pot_event(kind,amount) animate(kind,amount) end
    function V.update(dt)
        V.time=V.time+dt
        if U.screen~='pot' and U.focus=='pot_amount' then U.focus=nil end
        if V.screen~=U.screen then V.screen=U.screen; if U.screen=='pot' then V.opening={x=0,v=0}; V.widgets={} end end
        local speed=BT.config.motion or 1
        motion.spring(V.opening,U.screen=='pot' and 1 or 0,dt,reduced(),speed)
        motion.spring(V.pulse,0,dt,reduced(),speed)
        local s=BT.state; local p=own();local pot=V.scope=='personal' and p and (p.personal_pot or BT.Session.Pot.empty()) or s and s.pot
        if V.run~=(s and s.run_id) then V.run=s and s.run_id; V.result=0; V.count={x=pot and pot.bank or 0,v=0}; V.coins={} end
        motion.spring(V.count,pot and pot.bank or 0,dt,reduced(),speed)
        if pot and pot.last and pot.last.round>V.result then
            V.result=pot.last.round
            if pot.last.stake>0 then animate(pot.last.won and 'win' or 'loss',pot.last.stake) end
        end
        for _,b in pairs(V.widgets) do motion.spring(b.hover,b.target,dt,reduced(),speed); motion.spring(b.press,0,dt,reduced(),speed) end
        for i=#V.coins,1,-1 do if reduced() or V.time-V.coins[i].time>0.9 then table.remove(V.coins,i) end end
    end
    function V.amount() return reduced() and 1 or V.opening.x end
    local function button(label,x,y,w,height,fn,c,enabled)
        h.button(label,x,y,w,height,fn,c,enabled)
    end
    local gold={1,0.75,0.26}
    local function coin(x,y,r,alpha)
        h.col(gold,alpha); g.circle('fill',x,y,r)
        h.col({0.60,0.32,0.08},alpha); g.setLineWidth(2); g.circle('line',x,y,r-3)
        h.txt('$',x-r,y-r+1,r*1.6,{0.30,0.16,0.04},r*2,'center')
    end
    function V.draw(w,height)
        h.backdrop(w,height,'BET POTS','BACK THE BLIND. BANK YOUR LUCK.')
        local s=BT.state;local p=own();local personal=V.scope=='personal'
        local pot=personal and p and (p.personal_pot or BT.Session.Pot.empty()) or s and s.pot
        if not pot or not p then h.txt('Start a party run to bet in-game dollars.',60,240,30,h.ink); button('BACK',60,650,220,42,function() U.screen='lobby' end); return end
        button('TEAM / +37.5%',670,126,267,35,function() V.scope='team' end,not personal and h.colors[1] or h.muted)
        button('PERSONAL / +15%',950,126,270,35,function() V.scope='personal' end,personal and gold or h.muted)
        local wallet=G.GAME and G.GAME.dollars or 0
        local n=0; for _,q in pairs(s.players) do if q.connected and not q.withdrawn then n=n+1 end end
        local share=n>0 and math.floor(pot.bank/n) or 0
        local section=U.group or function(_,draw) draw() end
        section(0.025,function()
        h.rect(60,184,550,490,h.panel,16)
        h.txt(personal and 'YOUR PRIVATE WINNINGS' or 'TEAM SAFE WINNINGS',85,202,27,gold,500,'center')
        local bounce=reduced() and 0 or V.pulse.x
        local float=reduced() and 0 or math.sin(V.time*1.7)*2
        g.push(); g.translate(335,361-12*bounce+float); g.rotate(bounce*0.045); g.scale(1+bounce*0.035,1-bounce*0.04)
        h.col({0.10,0.21,0.17}); g.rectangle('fill',-115,-25,230,140,45,45)
        h.col(personal and gold or h.colors[1]); g.setLineWidth(3); g.rectangle('line',-115,-25,230,140,45,45)
        h.col({0.08,0.16,0.20}); g.ellipse('fill',0,-25,116,30)
        for i=1,7 do coin(-74+(i-1)*25,-28+(i%2)*9,18,1) end
        h.txt('$'..math.max(0,math.floor(V.count.x+0.5)),-115,17,64,h.ink,230,'center')
        h.txt('SAVED',-110,80,22,h.colors[1],220,'center'); g.pop()
        h.txt('NEXT BLIND BETS  $'..pot.wager,85,500,31,h.ink,500,'center')
        h.txt('WIN BONUS  +'..(personal and '15%' or '37.5%'),85,553,28,personal and gold or h.colors[1],500,'center')
        h.txt('Saved winnings stay safe.\nCurrent bets are at risk. Bonuses round down.',85,599,20,h.muted,500,'center')
        end)
        section(0.08,function()
        h.rect(648,184,590,490,h.panel,16)
        h.txt('YOUR WALLET  $'..wallet,670,195,28,h.ink,550)
        h.txt('YOUR NEXT BETS  $'..(pot.bets[tostring(BT.client.id)] or 0),670,229,24,h.colors[1],550)
        for i,value in ipairs({1,5,10,25}) do button('$'..value,670+(i-1)*140,274,130,38,function() set_amount(value) end,V.bet==value and gold or h.muted) end
        button('-5',670,331,85,42,function() set_amount(math.max(1,V.bet-5)) end,h.muted)
        button('-1',767,331,70,42,function() set_amount(math.max(1,V.bet-1)) end,h.muted)
        local focused=U.focus=='pot_amount'
        h.rect(847,327,160,50,focused and {0.18,0.35,0.33} or {0.11,0.16,0.17},7)
        if focused and V.selected then h.rect(860,333,134,33,{0.25,0.43,0.40},4) end
        local cursor=focused and math.floor(V.time*2)%2==0 and '_' or ''
        h.txt('$'..V.entry..cursor,851,333,32,gold,152,'center')
        h.txt('TYPE AMOUNT',847,376,14,h.muted,160,'center')
        U.fields=U.fields or {};U.fields[#U.fields+1]='pot_amount'
        h.hit(847,327,160,50,function() U.focus='pot_amount';V.selected=true end,'BET AMOUNT')
        button('+1',1018,331,75,42,function() set_amount(math.min(10000,V.bet+1)) end,h.muted)
        button('+5',1105,331,115,42,function() set_amount(math.min(10000,V.bet+5)) end,h.muted)
        local valid=V.bet>=1 and V.bet<=BT.Session.Pot.MAX_BET
        button('BET $'..V.bet..(personal and ' / PERSONAL' or ' / TEAM'),670,403,550,49,function() U.focus=nil;BT.pot.deposit(V.bet,V.scope) end,gold,valid and BT.pot.available() and wallet>=V.bet)
        h.txt(not valid and 'Enter a whole-dollar amount from $1 to $10,000.' or wallet<V.bet and 'Not enough money in your wallet.' or 'Bets lock in immediately for the next shared blind.',670,467,21,not valid and h.colors[4] or h.muted,550)
        h.txt(personal and ('COLLECT $'..pot.bank..' / ALL YOURS') or ('SPLIT: $'..share..' EACH / '..n..' PLAYERS'),670,516,26,h.colors[1],550)
        h.txt(personal and 'Only you can collect this pot.\nCollection takes saved winnings; your next bets stay in play.' or ('Host splits evenly among connected seats, including bots.\nRemainder stays safe: $'..(pot.bank-share*n)..'. Bets stay in play.'),670,554,21,h.muted,550)
        local phase=s.phase=='prepare' or s.phase=='shop' or s.phase=='victory' or s.phase=='defeat'
        button(personal and 'COLLECT MY WINNINGS' or BT.client.id==1 and 'SPLIT WINNINGS' or 'HOST SPLITS WINNINGS',670,622,550,48,personal and BT.pot.claim or BT.pot.split,h.colors[1],phase and not BT.pot.busy() and (personal and pot.bank>0 or not personal and BT.client.id==1 and share>0))
        end)
        local last=pot.last
        h.txt(last and ('LAST BLIND: '..(last.won and ('$'..last.stake..' returned + $'..last.bonus..' bonus') or ('$'..last.stake..' lost'))) or 'No bets settled yet.',60,687,22,last and not last.won and h.colors[4] or h.muted,1160)
        local message=BT.pot.busy() and 'TRANSFERRING... KEEP YOUR GAME OPEN' or p.ready and 'Unready to place a bet.' or 'In-game dollars. New runs clear the pot.'
        h.txt(message,60,718,20,h.muted,590)
        if p.ready and (s.phase=='prepare' or s.phase=='shop') then button('UNREADY TO BET',660,707,270,41,BT.client.ready,h.colors[2]) end
        button('BACK TO RUN',950,707,270,41,function() if U.close then U.close() else U.screen=nil end end,h.muted)
        for _,c in ipairs(V.coins) do
            local t=(V.time-c.time)/0.8
            if t>=0 and t<1 then
                local from=c.kind=='deposit' and {x=945,y=415} or {x=335,y=335}
                local to=c.kind=='deposit' and {x=335,y=335} or {x=945,y=205}
                if c.kind=='win' then from={x=335+math.cos(c.angle)*100,y=210}; to={x=335,y=335} end
                if c.kind=='loss' then to={x=335+math.cos(c.angle)*220,y=620} end
                local x,y=motion.arc(t,from,to); coin(x+math.sin(c.angle)*16,y,12,1-t*0.7)
            end
        end
    end
    return V
end
