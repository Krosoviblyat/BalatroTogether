-- Pinned Cryptid/Amulet integration. No received code is ever evaluated.
local C={decks={},registered={}}
C.blocked={c_cry_revert=true,c_cry_semicolon=true,c_cry_console=true,c_cry_analog=true,
    j_cry_redeo=true,v_hieroglyph=true,v_petroglyph=true,v_cry_asteroglyph=true}
function C.allowed(center)
    return not (center and C.blocked[center.key])
end
function C.dismiss_bot_notice()
    if not (BT.bots and BT.bots.config and G.OVERLAY_MENU and G.OVERLAY_MENU.get_UIE_by_ID) then return false end
    local node=G.OVERLAY_MENU:get_UIE_by_ID('overlay_menu_back_button')
    if node and node.config and node.config.button=='continue_unlock' then
        G.FUNCS.continue_unlock(); return true
    end
    return false
end
local function sorted(value)
    local t=type(value)
    if t~='table' then return tostring(value) end
    local keys={}; for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local out={}; for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..sorted(value[k]) end
    return '{'..table.concat(out,',')..'}'
end
function C.profile()
    local p=G and G.PROFILES and G.PROFILES[G.SETTINGS.profile] or {}
    return {gameset=p.cry_gameset or 'mainline',overrides=p.cry_gameset_overrides or {}}
end
function C.run_choices(deck)
    local choices={};local rs=SMODS.RunSelect
    local profile=G.PROFILES[G.SETTINGS.profile]
    profile.last_choices=profile.last_choices or {}
    if rs then
        rs.Setup=rs.Setup or {};rs.Setup.choices=rs.Setup.choices or {}
        for key,page in pairs(rs.Pages or {}) do
            if key~='deck_choice' and key~='stake_choice' and page.set_default then
                choices[key]=page:set_default(profile.last_choices[key])
            end
        end
    end
    choices.cry_antimatter=choices.cry_antimatter or {}
    choices.deck_choice=deck;choices.stake_choice='stake_white'
    return choices
end
function C.prepare_run(deck,seed)
    local choices=BT.Session.copy(BT.state.setup_choices or C.run_choices(deck))
    choices.deck_choice=deck;choices.seed=seed;choices.enable_seed=true;choices.stake_choice='stake_white'
    choices.cry_antimatter=choices.cry_antimatter or {}
    if SMODS.RunSelect then SMODS.RunSelect.Setup.choices=BT.Session.copy(choices) end
    G.PROFILES[G.SETTINGS.profile].last_choices=BT.Session.copy(choices)
    return {stake=1,stake_choice=1,seed=seed,deck_choice=G.P_CENTERS[deck]}
end
function C.register_decks()
    -- Keep effects that independently rewind/end a run out of a shared run.
    -- Wrappers remain inert in single player, including collections and previews.
    for key in pairs(C.blocked) do
        local center=G.P_CENTERS and G.P_CENTERS[key]
        if center and not center.bt_coop_guard then
            center.bt_coop_guard=true
            local pool=center.in_pool
            center.in_pool=function(...)
                if BT.active and BT.active() then return false end
                if pool then return pool(...) end
                return true
            end
            for _,method in ipairs({'use','redeem','calculate','force_use'}) do
                local ref=center[method]
                if ref then center[method]=function(...)
                    if BT.active and BT.active() then BT.notice('That effect changes individual run progression and is unavailable in co-op.'); return end
                    return ref(...)
                end end
            end
        end
    end
    for _,entry in ipairs(BT.Session.DECKS) do C.registered[entry[1]]=true end
    local keys={}
    for key,center in pairs(G.P_CENTERS or {}) do
        if center.set=='Back' and center.mod and center.mod.id=='Cryptid' and not center.cry_disabled and not C.registered[key] then keys[#keys+1]=key end
    end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local center=G.P_CENTERS[key]; local name=center.name or key
        if localize then local ok,value=pcall(localize,{type='name_text',set='Back',key=key}); if ok and type(value)=='string' then name=value end end
        BT.Session.DECKS[#BT.Session.DECKS+1]={key,name}; C.registered[key]=true; C.decks[#C.decks+1]=key
    end
end
function C.signature()
    C.register_decks()
    local parts={}
    for id,mod in pairs(SMODS.Mods or {}) do
        if not mod.disabled and mod.can_load~=false and id~='BTLabHarness' and id~='Talisman' and id~='cdataman' then
            parts[#parts+1]=id..':'..tostring(mod.version or '')
        end
    end
    table.sort(parts)
    local profile=C.profile()
    local config=Cryptid_config or {}; local gameplay={}
    for k,v in pairs(config) do if k~='Cryptid' and k~='HTTPS' and k~='menu' and k~='force_tooltips' and k~='family_mode' then gameplay[k]=v end end
    local stamp=table.concat(parts,'|')..'|omega='..tostring(Big~=nil)..'|'..sorted(profile)..'|'..sorted(gameplay)
    return love.data.encode('string','hex',love.data.hash('sha256',stamp))
end
function C.install()
    if Talisman and Talisman.Amulet and Talisman.forced_features then Talisman.forced_features.force_omeganum() end
    local intro=G.FUNCS and G.FUNCS.cry_intro_controller
    if intro then G.FUNCS.cry_intro_controller=function(...)
        if BT.bots and BT.bots.config then
            G.PROFILES[G.SETTINGS.profile].cry_intro_complete=true
            return
        end
        return intro(...)
    end end
    local notify=Cryptid and Cryptid.notification_overlay
    if notify then Cryptid.notification_overlay=function(...)
        if BT.bots and BT.bots.config then return end
        return notify(...)
    end end
    local calculate=SMODS.calculate_context
    if calculate then SMODS.calculate_context=function(context,...)
        local result=calculate(context,...)
        if BT.active and BT.active() and context.modify_ante~=nil then
            -- The party owns ante progression. Cryptid's Joke can
            -- otherwise jump just one native player to ante eight on cash-out.
            result=result or {}; result.modify=context.ante_end and 1 or 0
        end
        return result
    end end
end
function C.center(center)
    return center and (not center.mod or center.mod.id=='Cryptid')
end
return C
