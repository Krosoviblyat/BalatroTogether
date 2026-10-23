return function(U,h)
    local V={}
    function V.draw(w,height)
        local s=BT.state;local vote=s and s.skip_vote
        h.backdrop(w,height,'SKIP THIS BLIND?','YOUR TABLE DECIDES. A TIE MEANS PLAY.')
        if not vote then h.txt('The vote has finished.',60,280,32,h.ink);h.button('BACK TO RUN',60,620,290,50,function() U.navigate(nil) end);return end
        h.txt(vote.yes..' YES / '..vote.needed..' NEEDED',60,210,42,h.colors[2],1160,'center')
        h.txt('Small and Big Blinds only. Everyone receives their own native skip tag.',60,273,24,h.muted,1160,'center')
        for i=1,4 do local p=s.players[tostring(i)];local x=60+(i-1)*298
            h.rect(x,342,280,156,h.panel,9)
            h.txt(p and p.name or 'EMPTY SEAT',x+13,358,28,p and h.colors[i] or h.muted,254,'center')
            local choice=vote.votes[tostring(i)]
            h.txt(not p and '-' or p.bot and 'FOLLOWS THE VOTE' or choice=='yes' and 'SKIP' or choice=='no' and 'PLAY' or 'DECIDING...',x+13,425,22,choice=='yes' and h.colors[1] or h.muted,254,'center')
        end
        h.button('VOTE TO SKIP',320,549,310,58,function() BT.game.vote_skip('yes') end,h.colors[2])
        h.button('PLAY THIS BLIND',650,549,310,58,function() BT.game.vote_skip('no') end,h.colors[1])
        local remaining=math.max(0,math.ceil(vote.deadline-(s.vote_clock or 0)))
        h.txt('MAJORITY OF '..vote.total..' HUMAN PLAYERS / '..remaining..'s LEFT',60,651,23,h.muted,1160,'center')
        h.button('BACK TO RUN',480,710,320,38,function() U.navigate(nil) end,h.muted)
    end
    return V
end
