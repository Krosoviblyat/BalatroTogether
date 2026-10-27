local M={SEED='ZEROCREW'}
function M.active()
    return G and G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed==M.SEED
end
function M.state()
    if not M.active() then return end
    G.GAME.bt_crew_route=G.GAME.bt_crew_route or {version=1}
    return G.GAME.bt_crew_route
end
local function owns(key)
    for _,c in ipairs(G.jokers and G.jokers.cards or {}) do
        if c.config.center.key==key and not c.removed then return true end
    end
    return false
end
local function allowed(key)
    local center=G.P_CENTERS[key]
    return center and not (G.GAME.banned_keys or {})[key] and not owns(key)
        and (not BT.compat or not BT.compat.allowed or BT.compat.allowed(center))
end
function M.second_shop()
    local blinds=G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
    return M.active() and G.GAME.round==2 and blinds and blinds.Small=='Defeated' and blinds.Big=='Defeated'
end
function M.install()
    local pack=get_pack
    function get_pack(key,...)
        local state=M.state()
        if state and key=='shop_pack' and M.second_shop() and not state.pack_stocked
            and not (G.GAME.banned_keys or {}).p_buffoon_normal_1 then
            state.pack_stocked=true
            return G.P_CENTERS.p_buffoon_normal_1
        end
        return pack(key,...)
    end
    local open=Card.open
    function Card:open(...)
        local state=M.state()
        if state then state.pack_pending=nil end
        local purchased=self.area==G.shop_booster or self.ability.booster_pos and G.GAME.PACK_INTERRUPT==G.STATES.SHOP
        local qualifies=state and M.second_shop() and purchased and not self.from_tag
            and not self.cry_monopoly_destroyed and self.config.center.kind=='Buffoon' and owns('j_hanging_chad')
        local result=open(self,...)
        if qualifies and not self.cry_monopoly_destroyed then
            state.pack_opened=true
            if not state.photo_offered then state.pack_pending=true end
        end
        return result
    end
    local create=create_card
    function create_card(kind,area,legendary,rarity,skip,soulable,forced,append,...)
        local state=M.state()
        local qualifies=state and state.pack_pending and not state.photo_offered and M.second_shop()
            and kind=='Joker' and area==G.pack_cards and append=='buf' and not forced and not legendary
        if qualifies then
            state.pack_pending=nil
            if allowed('j_photograph') then forced='j_photograph' end
        end
        local card=create(kind,area,legendary,rarity,skip,soulable,forced,append,...)
        if qualifies and card and card.config.center.key=='j_photograph' then state.photo_offered=true end
        return card
    end
    local reroll=G.FUNCS.reroll_shop
    G.FUNCS.reroll_shop=function(...)
        local state=M.state();local price=G.GAME and G.GAME.current_round and G.GAME.current_round.reroll_cost
        if state and not state.reward_offered and state.pack_opened and state.photo_offered
            and G.GAME.round>=3 and G.GAME.round<=4 and G.STATE==G.STATES.SHOP
            and type(price)=='number' and price>0 and G.GAME.dollars>=price+20
            and owns('j_hanging_chad') and owns('j_photograph') and allowed('j_btogether_shroombo') then
            state.reward_pending=true
        end
        return reroll(...)
    end
    local shop=create_card_for_shop
    function create_card_for_shop(area,...)
        local card=shop(area,...);local state=M.state()
        if not state or area~=G.shop_jokers then return card end
        local key
        if state.reward_pending and not state.reward_offered and G.GAME.round>=3 and G.GAME.round<=4 then
            state.reward_pending=nil
            if allowed('j_btogether_shroombo') then key='j_btogether_shroombo';state.reward_offered=true end
        elseif G.GAME.round==1 and not state.starter_offered then
            state.starter_offered=true
            local blinds=G.GAME.round_resets and G.GAME.round_resets.blind_states
            if blinds and blinds.Small=='Defeated' and allowed('j_hanging_chad') then key='j_hanging_chad' end
        end
        if not key then return card end
        card:remove()
        card=create_card('Joker',area,nil,nil,true,nil,key,'crew_shop')
        card:set_cost();create_shop_card_ui(card)
        return card
    end
end
return M
