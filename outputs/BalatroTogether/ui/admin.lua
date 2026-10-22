return function(U,h)
    local V={target=nil,confirm=nil}
    local violet={0.69,0.59,1}; local red={1,0.30,0.40}; local gold={1,0.76,0.24}
    local choices={{'CASH +$25','cash25'},{'CASH +$100','cash100'},{'GOLD D6 +1','gold'},
        {'RED D20 +1','red'},{'WHEEL SPIN +1','wheel'},{'ALL LEVELS +1','levels'},
        {'FREE REFRESHES +3','refreshes'},{'NEXT HANDS +2','hands'},{'NEXT DISCARDS +2','discards'},
        {'NEXT CHIPS +100','chips'},{'NEXT MULT +20','mult'}}
    function V.draw(w,height)
        h.backdrop(w,height,'ADMIN PANEL','OWNER STEAM ACCOUNT VERIFIED / PRESS / TO CLOSE')
        if not BT.admin.allowed() then U.screen=nil; return end
        local s=BT.state
        if not s or s.phase=='lobby' then
            h.txt('Start a Together run to use rewards and recovery controls.',60,230,30,h.ink,1150)
            h.button('BACK',950,718,270,34,function() U.screen=nil end,h.muted); return
        end
        V.target=V.target or BT.client.id
        h.txt('GRANT TO',60,190,23,h.muted)
        for i=1,4 do local p=s.players[tostring(i)]
            if p then h.button(p.name,60+(i-1)*295,224,280,40,function() V.target=i; V.confirm=nil end,V.target==i and violet or h.muted) end
        end
        local p=s.players[tostring(V.target)]
        local enabled=(s.phase=='prepare' or s.phase=='shop') and p and p.connected and not p.ready and not p.busy
            and not p.transferring and not BT.Session.Dice.pending(p) and not BT.Session.Pot.pending(p)
        h.txt('Grants deliver while the selected player is unready between blinds.',60,282,21,h.muted,1160)
        for i,c in ipairs(choices) do
            local reward=c[2]
            h.button(c[1],60+(i-1)%3*255,326+math.floor((i-1)/3)*66,240,46,
                function() BT.admin.action('admin_grant',{target=V.target,reward=reward}) end,violet,enabled)
        end
        h.rect(850,326,370,310,h.panel,12)
        h.txt('RUN RECOVERY',875,341,28,gold,320)
        h.button('RETRY NATIVE SYNC',875,390,320,42,function() BT.admin.action('admin_retry') end,gold)
        h.button('RETIRE SELECTED SEAT',875,450,320,42,function() V.confirm='retire' end,red,
            p and V.target~=1 and not p.connected and not p.withdrawn)
        h.button('RESTART SAME SEED',875,510,320,42,function() V.confirm='restart' end,red)
        h.txt('Sync retries native entry and shop acknowledgements.',875,577,19,h.muted,320)
        if V.confirm then
            local action=V.confirm
            h.rect(60,618,750,80,h.panel,10)
            h.txt(action=='restart' and 'Restart ends the current run for the entire party.' or 'Retiring a disconnected seat removes it from this run.',75,629,21,red,720)
            h.button(action=='restart' and 'CONFIRM RESTART' or 'CONFIRM RETIRE',75,662,345,30,function()
                V.confirm=nil; BT.admin.action(action=='restart' and 'admin_restart' or 'admin_retire',{target=V.target})
            end,red)
            h.button('CANCEL',435,662,345,30,function() V.confirm=nil end,h.muted)
        else h.txt('Hand levels and refreshes last this run. NEXT bonuses last one blind.',60,630,21,h.muted,730) end
        h.button('BACK TO RUN',950,718,270,34,function() U.screen=nil end,h.muted)
    end
    return V
end
