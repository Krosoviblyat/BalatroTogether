-- Fungus is a native playing-card enhancement, never a Joker/consumable.
local M={KEY='j_btogether_shroombo',FUNGUS='m_btogether_fungus'}
function M.is_fungus(card)
    return card and card.config and card.config.center and card.config.center.key==M.FUNGUS
end
function M.count()
    local n=0
    for _,card in ipairs(G.playing_cards or {}) do
        if M.is_fungus(card) and not card.removed and not card.getting_sliced and not card.shattered and not card.destroyed then n=n+1 end
    end
    return n
end
function M.mult() return 1+0.5*M.count() end
function M.create()
    local card=SMODS.add_card{set='Enhanced',key=M.FUNGUS,area=G.deck,front='S_2',
        no_edition=true,skip_materialize=true,key_append='bt_shroombo'}
    -- Native reactions (e.g. Hologram) see a real permanent deck addition.
    playing_card_joker_effects({card})
    return card
end
function M.install()
    SMODS.Atlas{key='shroombo',path='shroombo.png',px=71,py=95}
    SMODS.Atlas{key='fungus',path='fungus.png',px=71,py=95}
    SMODS.Enhancement{
        key='fungus',name='Fungus Card',atlas='fungus',pos={x=0,y=0},
        no_rank=true,no_suit=true,replace_base_card=true,always_scores=true,
        unlocked=true,discovered=false,config={mult=2.5},
        in_pool=function() return false end,
        loc_txt={name='Fungus Card',text={
            '{C:mult}+#1#{} Mult when scored',
            'No rank or suit',
            'Always scores when played'}},
        loc_vars=function(self,info_queue,card) return {vars={card.ability.mult}} end,
    }
    SMODS.Joker{
        key='shroombo',name='Shroombo',atlas='shroombo',pos={x=0,y=0},
        rarity=3,cost=20,unlocked=true,discovered=false,blueprint_compat=true,
        eternal_compat=true,perishable_compat=false,config={extra={}},
        loc_txt={name='Shroombo',text={
            'Scored cards have a {C:green}1 in 4{}',
            'chance to create a {C:attention}Fungus Card{}',
            'Gains {X:mult,C:white}X0.5{} Mult for each',
            '{C:attention}Fungus Card{} in deck',
            '{C:inactive}(Currently {X:mult,C:white}X#1#{C:inactive} Mult)'}},
        loc_vars=function(self,info_queue,card)
            info_queue[#info_queue+1]=G.P_CENTERS[M.FUNGUS]
            return {vars={M.mult()}}
        end,
        calculate=function(self,card,context)
            if context.individual and context.cardarea==G.play and context.other_card
                and SMODS.pseudorandom_probability(card,'bt_shroombo_fungus',1,4,'bt_shroombo_fungus',true) then
                M.create()
                return {message='Fungus!',colour=G.C.MULT,card=context.blueprint_card or card}
            end
            if context.joker_main then return {x_mult=M.mult()} end
        end,
    }
end
return M
