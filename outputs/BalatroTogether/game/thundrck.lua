-- Deliberately curated party seed; ordinary seeded/unseeded runs stay native.
local M={SEED='THUNDRCK'}
function M.active()
    return G and G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed==M.SEED
end
function M.state()
    if not M.active() then return end
    G.GAME.bt_thundrck=G.GAME.bt_thundrck or {shops={},version=1}
    return G.GAME.bt_thundrck
end
function M.second_shop()
    local resets=G.GAME and G.GAME.round_resets
    local blinds=resets and resets.blind_states
    return M.active() and G.GAME.round==2 and blinds and blinds.Small=='Defeated' and blinds.Big=='Defeated'
end
-- Put an existing straight flush at the draw end. No ranks, suits, editions,
-- hand size or boss effects are changed. Modified decks fall back to a flush.
function M.opening(cards,round)
    local suits={'Spades','Hearts','Clubs','Diamonds'}
    local selected
    for offset=0,3 do
        local suit=suits[((round or 1)-1+offset)%4+1]
        local ranks={};local suited={}
        for _,card in ipairs(cards) do
            if card.base and card.base.suit==suit and not card.debuff then
                local rank=card:get_id()
                if type(rank)=='number' and rank>=2 and rank<=14 then ranks[rank]=ranks[rank] or card;suited[#suited+1]=card end
            end
        end
        for high=14,6,-1 do
            local hand={}
            for rank=high,high-4,-1 do if ranks[rank] then hand[#hand+1]=ranks[rank] end end
            if #hand==5 then selected=hand;break end
        end
        if selected then break end
        if #suited>=5 then
            table.sort(suited,function(a,b) return a:get_id()>b:get_id() end)
            selected={suited[1],suited[2],suited[3],suited[4],suited[5]}
            break
        end
    end
    if not selected then return false end
    local marked={};for _,card in ipairs(selected) do marked[card]=true end
    local order={};for _,card in ipairs(cards) do if not marked[card] then order[#order+1]=card end end
    for _,card in ipairs(selected) do order[#order+1]=card end
    for i,card in ipairs(order) do cards[i]=card end
    return true
end
function M.install()
    local cost=Card.set_cost
    function Card:set_cost(...)
        local result=cost(self,...)
        if M.active() and self.ability and self.ability.bt_thundrck_starter then
            self.cost=math.min(self.cost,1)
            self.sell_cost=1
            self.sell_cost_label=self.sell_cost
        end
        return result
    end
    local shuffle=CardArea.shuffle
    function CardArea:shuffle(seed)
        local result=shuffle(self,seed)
        local state=M.state()
        if state and self==G.deck and type(seed)=='string' and seed:match('^nr') and state.opening_round~=G.GAME.round then
            state.opening_round=G.GAME.round
            if M.opening(self.cards,G.GAME.round) then self:set_ranks() end
        end
        return result
    end
    local pack=get_pack
    function get_pack(key,...)
        local state=M.state()
        if state and key=='shop_pack' and M.second_shop() and not state.buffoon_stocked then
            state.buffoon_stocked=true
            return G.P_CENTERS.p_buffoon_normal_1
        end
        return pack(key,...)
    end
    local open=Card.open
    function Card:open(...)
        -- Native use_card removes a purchased pack from its CardArea before
        -- Card:open. PACK_INTERRUPT and booster_pos retain its shop origin.
        local purchased=self.area==G.shop_booster or self.ability.booster_pos and G.GAME.PACK_INTERRUPT==G.STATES.SHOP
        local qualifies=M.second_shop() and purchased and not self.from_tag and not self.cry_monopoly_destroyed
            and self.config.center.kind=='Buffoon'
        local result=open(self,...)
        if qualifies and not self.cry_monopoly_destroyed then M.state().buffoon_opened=true end
        return result
    end
    local reroll=G.FUNCS.reroll_shop
    G.FUNCS.reroll_shop=function(...)
        local state=M.state()
        if state and M.second_shop() and state.buffoon_opened and not state.soul_offered then state.offer_pending=true end
        return reroll(...)
    end
    local shop=create_card_for_shop
    function create_card_for_shop(area,...)
        local card=shop(area,...)
        local state=M.state()
        if not state or area~=G.shop_jokers then return card end
        local key
        if state.offer_pending and M.second_shop() and not state.soul_offered then
            key='c_soul';state.offer_pending=nil;state.soul_offered=true
        else
            local round=tostring(G.GAME.round)
            if not state.shops[round] then
                state.shops[round]=true
                -- A useful Negative at the start of each shop fuels the new
                -- Legendary. Remaining slots and rerolls retain native RNG.
                key=G.GAME.round==1 and 'j_abstract' or G.GAME.round>=3 and 'j_blueprint' or nil
            end
        end
        if not key then return card end
        card:remove()
        card=create_card(key=='c_soul' and 'Spectral' or 'Joker',area,nil,nil,true,nil,key,'bt_thundrck_shop')
        if key=='c_soul' then card.ability.bt_thundrck_soul=true else
            card:set_edition({negative=true},true)
            if key=='j_abstract' then card.ability.bt_thundrck_starter=true end
        end
        card:set_cost();create_shop_card_ui(card)
        return card
    end
    local use=Card.use_consumeable
    function Card:use_consumeable(...)
        local state=M.state()
        if state and self.config.center.key=='c_soul' and self.ability.bt_thundrck_soul and not state.soul_used then state.soul_pending=true end
        return use(self,...)
    end
    local create=create_card
    function create_card(kind,area,legendary,rarity,skip,soulable,forced,append,...)
        local state=M.state()
        local government=state and state.soul_pending and not state.soul_used and kind=='Joker' and legendary and append=='sou'
        if government then forced='j_btogether_government_man' end
        local card=create(kind,area,legendary,rarity,skip,soulable,forced,append,...)
        if government and card and card.config.center.key==forced then state.soul_pending=nil;state.soul_used=true end
        return card
    end
end
return M
