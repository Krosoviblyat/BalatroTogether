local V={}
function V.install()
    local H=BT.Session.Harbinger
    V.labels={progress='0%'};V.progress=0
    -- A real HUD object inside the blind's UIBox, below its native chip/rules.
    -- It consumes layout space instead of painting over the boss panel.
    local Meter=Moveable:extend()
    function Meter:init() Moveable.init(self,0,0,3.35,0.12);self.states.collide.can=false;self.states.hover.can=false end
    function Meter:draw()
        local s=BT.state;if not s or not self.states.visible then return end
        local g=love.graphics;g.push('all');prep_draw(self,1)
        g.setColor(0.06,0.08,0.09,1);g.rectangle('fill',0,0,self.T.w,self.T.h,0.035,0.035)
        local gross=0;for _,p in pairs(s.players) do gross=gross+p.contribution end
        local cursor=0;local colors={{0.19,0.85,0.7,1},{1,0.61,0.2,1},{0.52,0.59,1,1},{1,0.33,0.59,1}}
        if gross>0 then for id=1,4 do local p=s.players[tostring(id)]
            if p then local width=math.min(self.T.w-cursor,self.T.w*V.progress*BT.numbers.ratio(p.contribution,gross))
                g.setColor(colors[id]);g.rectangle('fill',cursor,0,math.max(0,width),self.T.h);cursor=cursor+width
            end
        end end
        g.setColor(1,1,1,0.23);g.setLineWidth(0.012);g.rectangle('line',0,0,self.T.w,self.T.h,0.035,0.035)
        g.pop();g.pop()
    end
    local native_blind_hud=create_UIBox_HUD_blind
    create_UIBox_HUD_blind=function(...)
        local result=native_blind_hud(...)
        if BT.active() then result.nodes[#result.nodes+1]={n=G.UIT.R,config={align='cm',padding=0.04,id='bt_native_team_meter'},nodes={
            {n=G.UIT.O,config={object=Meter()}},
            {n=G.UIT.B,config={w=0.10,h=0.10}},
            {n=G.UIT.T,config={ref_table=V.labels,ref_value='progress',scale=0.23,colour=G.C.WHITE,shadow=true,minw=0.5}}
        }} end
        return result
    end
    for _,key in ipairs({'can_play','can_discard'}) do
        local ref=G.FUNCS[key]
        G.FUNCS[key]=function(e,...)
            ref(e,...)
            if BT.state and H.blocks(BT.state) then e.config.button=nil;e.config.colour=G.C.UI.BACKGROUND_INACTIVE end
        end
    end
    -- Use the real Blind and HUD UIBox. Team accounting changes only the
    -- displayed round score, leaving the player's native chips untouched.
    local chip_ui=G.FUNCS.chip_UI_set
    G.FUNCS.chip_UI_set=function(e,...)
        chip_ui(e,...)
        if BT.active() then
            G.GAME.chips_text=number_format(BT.state.score)
            e.config.scale=math.min(0.8,scale_number(BT.state.score,1.1))
        end
    end
    local hud=create_UIBox_HUD
    create_UIBox_HUD=function(...)
        local result=hud(...)
        if BT.active() then
            local function walk(node,in_score)
                if type(node)~='table' then return end
                in_score=in_score or node.config and node.config.id=='row_dollars_chips'
                if in_score and node.config and node.config.text==localize('k_round') then node.config.text='Team' end
                for _,child in ipairs(node.nodes or {}) do walk(child,in_score) end
            end
            walk(result,false)
        end
        return result
    end
    SMODS.Atlas{key='harbinger',path='harbinger.png',px=34,py=34,frames=21,atlas_table='ANIMATION_ATLAS'}
    SMODS.Blind{key='harbinger',name='The Harbinger',atlas='harbinger',pos={x=0,y=0},dollars=7,mult=2,
        discovered=true,boss={min=2,max=2147483647},boss_colour=HEX('982CDE'),
        loc_txt={name='The Harbinger',text={'Counters with its own hands.','Damages TEAM chips. #1# stake.'}},
        loc_vars=function() return {vars={H.tier(BT.state or BT.config).name}} end,
        -- The explicit 20% encounter roll below is its sole entry route. Leaving
        -- it in the ordinary pool would add another chance on top of that roll.
        in_pool=function() return false end}
    local reset=SMODS.reset_blind_choices
    SMODS.reset_blind_choices=function(choices,...)
        reset(choices,...)
        local s=BT.state
        local boss=G.P_BLINDS[choices.Boss]
        local banned=G.GAME.banned_keys and G.GAME.banned_keys[H.KEY]
        local special=G.FORCE_BOSS or G.GAME.modifiers and G.GAME.modifiers.cry_big_showdown or boss and boss.boss and boss.boss.showdown
        if not banned and not special and H.should_spawn(s,G.GAME.round_resets.ante,G.GAME.win_ante) then choices.Boss=H.KEY end
    end
    -- Configure Quick Duel before native UI construction. Rebuilding an
    -- already-live selection would orphan its separately-owned prompt box.
    local select_ui=create_UIBox_blind_select
    create_UIBox_blind_select=function(...)
        local s=BT.state
        if s and s.quick_duel and s.round==0 and s.blind_index==3 then
            G.GAME.round_resets.blind_states.Small='Defeated'
            G.GAME.round_resets.blind_states.Big='Defeated'
            G.GAME.round_resets.blind_states.Boss='Select'
            G.GAME.round_resets.blind_choices.Boss=H.KEY
        end
        return select_ui(...)
    end
    local update=BT.game.update
    BT.game.update=function(dt)
        local s=BT.state
        if s then
            local goal=s.target>0 and BT.numbers.ratio(s.score,s.target) or 0
            V.progress=BT.config.reduced_motion and goal or V.progress+(goal-V.progress)*math.min(1,dt*12)
            V.labels.progress=math.floor(goal*100)..'%'
        end
        return update(dt)
    end
    local propose=BT.client.propose
    BT.client.propose=function(data)
        local s=BT.state
        if s and data.index==3 and (data.key==H.KEY or s.quick_duel and s.round==0) then
            data.key=H.KEY;data.name='The Harbinger';data.boss=true
            data.base=get_blind_amount(s.ante)*2*G.GAME.starting_params.ante_scaling
        end
        return propose(data)
    end
end
return V
