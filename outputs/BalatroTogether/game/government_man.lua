-- Native Legendary Joker. Acquisition uses Steamodded's card_added context.
local M={KEY='j_btogether_government_man',restoring=false,pending=setmetatable({},{__mode='k'})}
local function owned(card)
    if not card or card.removed or card.getting_sliced or not card.added_to_deck or not G.jokers then return false end
    for _,c in ipairs(G.jokers.cards) do if c==card then return true end end
    return false
end
function M.restore(card)
    -- A rejected escrow deposit returns the same owned card, not a new pickup.
    local before=M.restoring;M.restoring=true
    local ok,err=pcall(card.add_to_deck,card);M.restoring=before
    if not ok then error(err) end
end
function M.acquired(card,other,context)
    if M.restoring or context.blueprint or context.retrigger_joker or card==other or not other
        or other.ability.set~='Joker' or not (other.edition and other.edition.negative) then return end
    local queue=M.pending[card]
    if not queue then queue=setmetatable({},{__mode='k'});M.pending[card]=queue end
    if queue[other] then return end
    queue[other]=true
    -- card_added happens before the native shop/pack emplaces its new Joker.
    -- Resolve after emplacement and discard rolled-back/removed acquisitions.
    G.E_MANAGER:add_event(Event{trigger='after',delay=0.05,func=function()
        queue[other]=nil
        if not owned(card) or card.debuff or not owned(other) then return true end
        local extra=card.ability.extra
        extra.x_mult=extra.x_mult+0.5
        extra.acquired=extra.acquired+1
        card:juice_up(0.4,0.35)
        card_eval_status_text(card,'extra',nil,nil,nil,{message=localize{type='variable',key='a_xmult',vars={extra.x_mult}},colour=G.C.MULT})
        if extra.acquired%2==0 then
            local targets={}
            for _,candidate in ipairs(G.jokers.cards) do
                if owned(candidate) and not (candidate.edition and candidate.edition.negative) then targets[#targets+1]=candidate end
            end
            if #targets>0 then
                local target=pseudorandom_element(targets,pseudoseed('bt_government_negative'))
                target:set_edition({negative=true});target:juice_up(0.5,0.4)
            end
        end
        return true
    end})
end
function M.install()
    SMODS.Atlas{key='government_man',path='government_man.png',px=71,py=95}
    SMODS.Joker{
        key='government_man',name='Government Man',atlas='government_man',pos={x=0,y=0},
        rarity=4,cost=20,unlocked=true,discovered=false,blueprint_compat=true,
        eternal_compat=true,perishable_compat=false,
        config={extra={x_mult=2,acquired=0}},
        loc_txt={name='Government Man',text={
            'Gains {X:mult,C:white}X0.5{} Mult whenever',
            'a {C:dark_edition}Negative Joker{} is acquired',
            'Every {C:attention}2{} acquired, turn a',
            'random Joker {C:dark_edition}Negative{}',
            '{C:inactive}(Currently {X:mult,C:white}X#1#{C:inactive} Mult; #2#/2)'}},
        loc_vars=function(self,info_queue,card)
            info_queue[#info_queue+1]=G.P_CENTERS.e_negative
            return {vars={card.ability.extra.x_mult,card.ability.extra.acquired%2}}
        end,
        calculate=function(self,card,context)
            if context.card_added then M.acquired(card,context.card,context) end
            if context.joker_main then return {x_mult=card.ability.extra.x_mult} end
        end
    }
end
return M
