-- Pure donation policy. Read only the public build information teammates share.
return function(ai)
    local T={}
    local function has(ctx,key) for _,j in ipairs(ctx.jokers or {}) do if j.key==key then return true end end end
    function T.context(player,centers)
        if not player or player.inspect~=true then return end
        local profile=player.bot_profile or {};local ctx={jokers={},hand_plays={},suits=player.deck or {},preferred_hand=profile.preferred_hand or player.last_hand,
            joker_limit=profile.joker_limit or 5,consumable_limit=profile.consumable_limit or 2}
        for _,item in ipairs(player.jokers or {}) do
            local center=centers[item.key];local config=center and center.config or {}
            ctx.jokers[#ctx.jokers+1]={key=item.key,set='Joker',mult=item.score_mult or config.mult or 0,chips=item.score_chips or config.bonus or 0,
                xmult=item.score_xmult or config.x_mult or 1,blueprint_compat=center and center.blueprint_compat,
                debuff=item.debuff,foil=item.edition=='foil',holo=item.edition=='holo',poly=item.edition=='polychrome'}
        end
        return ctx
    end
    function T.value(item,ctx)
        if item.set=='Enhanced' then return has(ctx,'j_btogether_shroombo') and 28 or 6 end
        return ai.shop_value(item,ctx)
    end
    function T.choose(items,own,players,self_id,centers)
        local best
        for index,item in ipairs(items) do
            local owned_value=T.value(item,own)
            local can_give=not item.eternal and not item.debuff and not item.received and not item.legendary
            if item.set=='Joker' and (#own.jokers<3 or owned_value>=40) then can_give=false end
            if item.set=='Enhanced' and (own.fungus_count or 0)<2 then can_give=false end
            if can_give then for i=1,4 do
                local p=players[tostring(i)]
                if i~=self_id and p and p.connected and not p.withdrawn then
                    local ctx=T.context(p,centers)
                    if ctx then
                        local space=item.set=='Joker' and (#ctx.jokers<ctx.joker_limit or item.negative)
                            or item.set=='Enhanced' or item.set~='Joker' and #(p.consumables or {})<ctx.consumable_limit
                        local value=T.value(item,ctx);local gain=value-owned_value
                        -- Useful spare scoring Jokers help an under-equipped teammate.
                        if item.set=='Joker' and #ctx.jokers<2 and #own.jokers>=4 and owned_value<23 then gain=gain+15 end
                        if space and value>=10 and gain>=8 and (not best or gain>best.gain or gain==best.gain and i<best.target) then
                            best={index=index,target=i,gain=gain,value=value,reason=item.set=='Planet' and 'hand synergy' or item.set=='Enhanced' and 'Shroombo synergy' or 'stronger teammate build'}
                        end
                    end
                end
            end end
        end
        return best
    end
    return T
end
