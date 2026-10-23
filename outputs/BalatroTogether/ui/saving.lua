return function(U,h)
    local V={}
    function V.draw(w,height)
        local s=BT.state;local checkpoint=s and s.checkpoint
        h.backdrop(w,height,'KEEPING YOUR SEATS.','A CHECKPOINT FOR EVERY BUILD AT THE TABLE.')
        if not checkpoint then return end
        local done,total=0,0
        for i=1,4 do local p=s.players[tostring(i)];if p and not p.withdrawn then
            total=total+1;local saved=checkpoint.uploads[tostring(i)]~=nil;if saved then done=done+1 end
            local x=60+(i-1)*298;local y=310
            local still=BT.config.reduced_motion or (BT.config.motion or 1)==0
            local bob=not still and math.sin(love.timer.getTime()*2.3+i)*4 or 0
            h.rect(x,y+bob,280,177,h.panel,10);h.txt(p.name,x+14,y+18+bob,29,h.colors[i],252,'center')
            h.txt(saved and 'BUILD RECEIVED' or 'PACKING CARDS...',x+14,y+96+bob,23,saved and h.colors[1] or h.muted,252,'center')
        end end
        h.txt(done..' / '..total..' BUILDS SAFE',60,211,45,h.colors[2],1160,'center')
        local progress=math.max(0,math.min(1,U.save_progress and U.save_progress.x or done/math.max(1,total)))
        h.rect(240,550,800,17,h.panel,4);if progress>0 then h.rect(240,550,800*progress,17,h.colors[1],4) end
        h.txt(checkpoint.leave and 'Saving, then returning everyone to the menu.' or 'Cards, dollars, tags, pots and rewards stay with their owners.',60,609,27,h.ink,1160,'center')
        h.txt('The previous checkpoint stays safe until this one is complete.',60,664,22,h.muted,1160,'center')
    end
    return V
end
