return function(U,h)
    local V={};local D=BT.deck_choices
    function V.open(readonly)
        V.readonly=readonly==true;V.deck=V.readonly and BT.state.deck or BT.config.deck
        V.choices=V.readonly and BT.Session.copy(BT.state.setup_choices or {}) or BT.compat.run_choices(V.deck,(BT.config.deck_options or {})[V.deck])
        V.tab=nil;V.page=1;U.navigate('deck_options')
    end
    function V.back() U.navigate(V.readonly and 'lobby' or 'host') end
    function V.draw(w,height)
        local pages=D.pages(V.deck,V.choices,V.readonly)
        h.backdrop(w,height,'MAKE IT YOUR DECK',BT.Session.deck_name(V.deck)..(V.readonly and ' / HOST SETTINGS' or ' / SHARED BY THE WHOLE PARTY'))
        local current=pages[1]
        for _,page in ipairs(pages) do if page.key==V.tab then current=page end end
        if not current then h.txt('This deck needs no extra choices.',80,230,32,h.ink,1100);h.button('BACK',80,690,1120,48,V.back);return end
        V.tab=current.key
        for i,page in ipairs(pages) do
            h.button(page.name,65,205+(i-1)*62,260,49,function() V.tab=page.key;V.page=1 end,page.key==current.key and h.colors[1] or h.muted)
        end
        h.txt(current.multiple and 'Choose the decks to combine. Each selected effect applies.' or 'Choose one. Every player starts with this setting.',355,198,25,h.muted,850)
        local pool=D.pool(current.key,V.readonly);local total=math.max(1,math.ceil(#pool/12));V.page=math.max(1,math.min(V.page,total))
        if #pool==0 then h.txt('No compatible decks unlocked yet.\nAntimatter follows your Cryptid gameset and deck unlocks.',355,280,28,h.muted,820) end
        for index=(V.page-1)*12+1,math.min(V.page*12,#pool) do
            local entry=pool[index];local i=index-(V.page-1)*12-1;local x=355+(i%3)*288;local y=245+math.floor(i/3)*83
            local chosen=current.multiple and V.choices[current.key][entry.key] or V.choices[current.key]==entry.key
            h.button(D.name(current.key,entry.key),x,y,273,55,function()
                if V.readonly then return end
                if current.multiple then V.choices[current.key][entry.key]=not V.choices[current.key][entry.key] or nil
                else V.choices[current.key]=entry.key end
            end,chosen and h.colors[1] or h.muted)
            h.txt(chosen and 'SELECTED' or V.readonly and 'NOT SELECTED' or current.multiple and 'CLICK TO INCLUDE' or 'CLICK TO SELECT',x,y+58,16,chosen and h.colors[1] or h.muted,273,'center')
        end
        h.button('<',355,590,65,37,function() V.page=V.page-1 end,h.muted,V.page>1)
        h.txt('PAGE '..V.page..' / '..total,430,597,22,h.muted,155,'center')
        h.button('>',595,590,65,37,function() V.page=V.page+1 end,h.muted,V.page<total)
        if current.multiple and not V.readonly then
            h.button('SELECT ALL',700,590,244,37,function() for _,entry in ipairs(pool) do V.choices[current.key][entry.key]=true end end,h.colors[3])
            h.button('CLEAR',958,590,244,37,function() V.choices[current.key]={} end,h.muted)
        end
        h.txt(D.summary(V.deck,V.choices,V.readonly),65,644,22,h.colors[1],1137,'center')
        if V.readonly then h.button('BACK TO TABLE',65,693,1137,48,V.back)
        else
            h.button('USE THESE CHOICES',355,693,562,48,function()
                BT.config.deck_options=BT.config.deck_options or {}
                BT.config.deck_options[V.deck]=D.normalize(V.deck,V.choices);BT.persist();V.back()
            end)
            h.button('CANCEL',932,693,270,48,V.back,h.muted)
        end
    end
    return V
end
