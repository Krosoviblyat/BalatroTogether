-- Side-effect-free expected-score planner. Never calls native joker evaluation,
-- consumes game RNG, or observes deck order / another player's hidden hand.
local A={}
local defaults={['High Card']={5,1},Pair={10,2},['Two Pair']={20,2},['Three of a Kind']={30,3},
    Straight={30,4},Flush={35,4},['Full House']={40,4},['Four of a Kind']={60,7},
    ['Straight Flush']={100,8},['Five of a Kind']={120,12},['Flush House']={140,14},['Flush Five']={160,16}}
local function contains(t,v) for _,x in ipairs(t) do if x==v then return true end end end
local function count(ctx,key)
    if ctx._counts then return ctx._counts[key] or 0 end
    local n=0;for _,j in ipairs(ctx.jokers or {}) do if j.key==key and not j.debuff then n=n+1 end end;return n
end
local function has(ctx,key) return count(ctx,key)>0 end
function A.prepare(ctx)
    if ctx._compiled then return ctx end
    local out={};for k,v in pairs(ctx) do out[k]=v end
    local original=ctx.jokers or {};out.jokers={};out._counts={};out._compiled=true
    local function resolve(i,seen)
        local j=original[i];if not j or j.debuff or seen[i] then return end
        seen[i]=true
        if j.key=='j_blueprint' then return resolve(i+1,seen) end
        if j.key=='j_brainstorm' then return resolve(1,seen) end
        if j.blueprint_compat==false then return end
        return j
    end
    for i,j in ipairs(original) do
        local value=j
        if not j.debuff and (j.key=='j_blueprint' or j.key=='j_brainstorm') then
            local target=resolve(i,{})
            value={};for k,v in pairs(target or {}) do value[k]=v end
            value.key=value.key or j.key;value.foil=j.foil;value.holo=j.holo;value.poly=j.poly
            value.copied=true
        end
        out.jokers[#out.jokers+1]=value
        if not value.debuff then out._counts[value.key]=(out._counts[value.key] or 0)+1 end
    end
    return out
end
function A.classify(cards,ctx)
    ctx=ctx or {}; local ranks,suits={},{}; local all={}
    for i,c in ipairs(cards) do
        if not c.stone and not c.rankless and c.rank>0 then ranks[c.rank]=ranks[c.rank] or {}; table.insert(ranks[c.rank],i) end
        all[#all+1]=i
    end
    local groups={}; for r,v in pairs(ranks) do groups[#groups+1]={rank=r,ids=v} end
    table.sort(groups,function(a,b) return #a.ids==#b.ids and a.rank>b.rank or #a.ids>#b.ids end)
    local need=ctx.four_fingers and 4 or 5
    local flush
    for _,s in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
        local ids={}; for i,c in ipairs(cards) do
            local known=c.suit=='Hearts' or c.suit=='Diamonds' or c.suit=='Spades' or c.suit=='Clubs'
            local same=c.suit==s or c.wild or (ctx.smeared and known and ((c.suit=='Hearts' or c.suit=='Diamonds')==(s=='Hearts' or s=='Diamonds')))
            if not c.stone and not c.suitless and same then ids[#ids+1]=i end
        end
        if #ids>=need then flush=ids; break end
    end
    local straight
    for high=14,need,-1 do
        local ids,previous={},nil
        for r=high,1,-1 do
            local key=r==1 and 14 or r
            if ranks[key] then
                if previous and previous-r>(ctx.shortcut and 2 or 1) then break end
                ids[#ids+1]=ranks[key][1]; previous=r
                if #ids==need then straight=ids; break end
            elseif previous and not ctx.shortcut then break end
        end
        if straight then break end
    end
    local g=groups[1]; local g2=groups[2]
    if g and #g.ids>=5 then return flush and 'Flush Five' or 'Five of a Kind',all end
    if g and #g.ids==3 and g2 and #g2.ids==2 then return flush and 'Flush House' or 'Full House',all end
    if flush and straight then
        local union,seen={},{};for _,ids in ipairs({flush,straight}) do for _,i in ipairs(ids) do if not seen[i] then union[#union+1]=i;seen[i]=true end end end
        return 'Straight Flush',union
    end
    if g and #g.ids==4 then return 'Four of a Kind',g.ids end
    if flush then return 'Flush',flush end
    if straight then return 'Straight',straight end
    if g and #g.ids==3 then return 'Three of a Kind',g.ids end
    if g and #g.ids==2 and g2 and #g2.ids==2 then local ids={}; for _,v in ipairs({g,g2}) do for _,i in ipairs(v.ids) do ids[#ids+1]=i end end; return 'Two Pair',ids end
    if g and #g.ids==2 then return 'Pair',g.ids end
    return 'High Card',g and {g.ids[1]} or {}
end
local suit_joker={j_greedy_joker='Diamonds',j_lusty_joker='Hearts',j_wrathful_joker='Spades',j_gluttenous_joker='Clubs'}
local hand_joker={j_jolly={'Pair',8},j_zany={'Three of a Kind',12},j_mad={'Two Pair',10},j_crazy={'Straight',12},j_droll={'Flush',10},
    j_sly={'Pair',50,'chips'},j_wily={'Three of a Kind',100,'chips'},j_clever={'Two Pair',80,'chips'},j_devious={'Straight',100,'chips'},j_crafty={'Flush',80,'chips'}}
local function num(v,fallback)
    if type(v)=='number' or (BT and BT.numbers and BT.numbers.finite(v)) then return v end
    return tonumber(v) or fallback
end
local function numeric(j,key,fallback) local e=j.extra; return type(e)=='table' and num(e[key],fallback) or num(e,fallback) end
local function triggers(name,cards,wanted,ctx)
    if name==wanted then return true end
    if wanted=='Flush' then return name=='Straight Flush' or name=='Flush House' or name=='Flush Five' end
    if wanted=='Straight' then return name=='Straight Flush' end
    local counts={}; for _,c in ipairs(cards) do if not c.stone and not c.rankless and c.rank>0 then counts[c.rank]=(counts[c.rank] or 0)+1 end end
    local paircount,trips,quads=0,0,0; for _,n in pairs(counts) do if n>=2 then paircount=paircount+1 end; if n>=3 then trips=trips+1 end; if n>=4 then quads=quads+1 end end
    return wanted=='Pair' and paircount>0 or wanted=='Two Pair' and paircount>1 or wanted=='Three of a Kind' and trips>0 or wanted=='Four of a Kind' and quads>0
end
function A.score(cards,held,ctx)
    ctx=A.prepare(ctx)
    local name,ids=A.classify(cards,ctx); local base=(ctx.hands or {})[name] or defaults[name]
    local chips,mult=base.chips or base[1],base.mult or base[2]
    mult=mult+(ctx.dice_mult or 0)
    chips=chips+(ctx.dice_chips or 0)
    if ctx.flint then chips=math.floor(chips/2+0.5); mult=math.floor(mult/2+0.5) end
    local scored={}; for _,i in ipairs(ids) do scored[i]=true end
    local splash=has(ctx,'j_splash'); local faceall=has(ctx,'j_pareidolia')
    local repetitions=count(ctx,'j_sock_and_buskin');local first_scored,first_face
    for i,c in ipairs(cards) do if scored[i] or c.stone or splash then
        first_scored=first_scored or i
        if not c.rankless and not c.stone and (faceall or c.rank>=11 and c.rank<=13) then first_face=first_face or i end
    end end
    for i,c in ipairs(cards) do
        if (scored[i] or c.stone or splash) and not c.debuff then
            local face=not c.rankless and not c.stone and (faceall or (c.rank>=11 and c.rank<=13))
            local times=1+(c.red_seal and 1 or 0)+(face and repetitions or 0)+(c.rank>=2 and c.rank<=5 and count(ctx,'j_hack') or 0)
            times=times+count(ctx,'j_seltzer')+(ctx.hands_left==1 and count(ctx,'j_dusk') or 0)
                +(i==first_scored and count(ctx,'j_hanging_chad')*2 or 0)
            for _=1,times do
                chips=chips+(c.chips or 0)+(c.foil and 50 or 0)
                mult=(mult+(c.mult or 0)+(c.holo and 10 or 0))*(c.xmult or 1)*(c.poly and 1.5 or 1)
                for _,j in ipairs(ctx.jokers or {}) do if not j.debuff then
                    local key=j.key
                    if suit_joker[key] and (c.suit==suit_joker[key] or c.wild) then mult=mult+3
                    elseif key=='j_even_steven' and not c.rankless and c.rank<=10 and c.rank%2==0 then mult=mult+4
                    elseif key=='j_odd_todd' and (c.rank==14 or c.rank<=10 and c.rank%2==1) then chips=chips+31
                    elseif key=='j_scary_face' and face then chips=chips+30
                    elseif key=='j_smiley' and face then mult=mult+5
                    elseif key=='j_fibonacci' and contains({2,3,5,8,14},c.rank) then mult=mult+8
                    elseif key=='j_scholar' and c.rank==14 then chips=chips+20; mult=mult+4
                    elseif key=='j_triboulet' and (c.rank==12 or c.rank==13) then mult=mult*2
                    elseif key=='j_photograph' and i==first_face then mult=mult*2
                    elseif key=='j_bloodstone' and (c.suit=='Hearts' or c.wild) then mult=mult*1.25
                    elseif key=='j_arrowhead' and (c.suit=='Spades' or c.wild) then chips=chips+50
                    elseif key=='j_onyx_agate' and (c.suit=='Clubs' or c.wild) then mult=mult+7
                    elseif key=='j_walkie_talkie' and (c.rank==4 or c.rank==10) then chips=chips+10; mult=mult+4 end
                end end
            end
        end
    end
    local lowest,black=99,true
    for _,c in ipairs(held) do
        if not c.stone then lowest=math.min(lowest,c.rank) end
        if c.suit~='Spades' and c.suit~='Clubs' and not c.wild then black=false end
        if not c.debuff then
            local times=1+(c.red_seal and 1 or 0)+count(ctx,'j_mime')
            for _=1,times do mult=(mult+(c.held_mult or 0))*(c.held_xmult or 1)
                if c.rank==13 then mult=mult*1.5^count(ctx,'j_baron') end
                if c.rank==12 then mult=mult+13*count(ctx,'j_shoot_the_moon') end
            end
        end
    end
    for index,j in ipairs(ctx.jokers or {}) do if not j.debuff then
        local key=j.key; local add,bonus,x=0,0,1; local rule=hand_joker[key]
        if rule and triggers(name,cards,rule[1],ctx) then if rule[3] then bonus=rule[2] else add=rule[2] end
        elseif key=='j_joker' then add=4
        elseif key=='j_half' and #cards<=3 then add=20
        elseif key=='j_banner' then bonus=(ctx.discards_left or 0)*30
        elseif key=='j_mystic_summit' and ctx.discards_left==0 then add=15
        elseif key=='j_abstract' then add=#ctx.jokers*3
        elseif key=='j_blue_joker' then bonus=(ctx.deck_count or 0)*2
        elseif key=='j_raised_fist' and lowest<99 then add=math.min(lowest,10)*2
        elseif key=='j_blackboard' and black then x=3
        elseif key=='j_stencil' then x=math.max(1,(ctx.joker_limit or 5)-#ctx.jokers+1)
        elseif key=='j_cavendish' then x=3
        elseif key=='j_gros_michel' then add=15
        elseif key=='j_popcorn' then add=numeric(j,'mult',20)
        elseif key=='j_ice_cream' then bonus=numeric(j,'chips',100)
        elseif key=='j_ramen' then x=numeric(j,'Xmult',2)
        elseif key=='j_card_sharp' and (ctx.played_hands or {})[name] then x=3
        elseif key=='j_acrobat' and ctx.hands_left==1 then x=3
        elseif key=='j_green_joker' then add=numeric(j,'mult',0)
        elseif key=='j_ride_the_bus' then add=numeric(j,'mult',0)
        elseif key=='j_supernova' then add=(ctx.hand_plays or {})[name] or 0
        elseif key=='j_bull' then bonus=(ctx.money or 0)*2
        elseif key=='j_bootstraps' then add=math.floor((ctx.money or 0)/5)*2
        elseif key=='j_loyalty_card' and numeric(j,'loyalty_remaining',5)==0 then x=4
        elseif key=='j_photograph' or key=='j_blueprint' or key=='j_brainstorm' then
        elseif key=='j_duo' and triggers(name,cards,'Pair',ctx) then x=2
        elseif key=='j_trio' and triggers(name,cards,'Three of a Kind',ctx) then x=3
        elseif key=='j_family' and triggers(name,cards,'Four of a Kind',ctx) then x=4
        elseif key=='j_order' and triggers(name,cards,'Straight',ctx) then x=3
        elseif key=='j_tribe' and triggers(name,cards,'Flush',ctx) then x=2
        else
            add=num(j.mult,0); bonus=num(j.chips,0)
            x=math.max(1,num(j.xmult,1))
        end
        chips=chips+bonus+(j.foil and 50 or 0)
        mult=(mult+add+(j.holo and 10 or 0))*x*(j.poly and 1.5 or 1)
    end end
    if ctx.plasma then local average=math.floor((chips+mult)/2); return average*average,name end
    return math.max(0,chips*mult),name
end
function A.best(hand,ctx,yieldfn)
    ctx=A.prepare(ctx)
    local best={score=-1,indices={}}; local selected={}; local iterations=0
    local candidates={};for i=1,#hand do candidates[i]=i end
    if #hand>16 then
        local ranks,suits={},{};for _,c in ipairs(hand) do ranks[c.rank]=(ranks[c.rank] or 0)+1;suits[c.suit]=(suits[c.suit] or 0)+1 end
        local function priority(c) return (c.chips or 0)+(c.mult or 0)*8+((c.xmult or 1)-1)*35
            +(c.rank>0 and (ranks[c.rank] or 0)*14 or 0)+(suits[c.suit] or 0)*3-((c.held_xmult or 1)-1)*25 end
        table.sort(candidates,function(a,b) local x,y=priority(hand[a]),priority(hand[b]);return x==y and a<b or x>y end)
        while #candidates>16 do table.remove(candidates) end;table.sort(candidates)
    end
    local function evaluate()
        if ctx._budget then
            if ctx._budget.evaluations>=ctx._budget.limit then ctx._budget.exhausted=true;return end
            ctx._budget.evaluations=ctx._budget.evaluations+1
        end
        local cards,held={},{}; local mask={}
        for _,i in ipairs(selected) do cards[#cards+1]=hand[i]; mask[i]=true end
        for i,c in ipairs(hand) do if not mask[i] then held[#held+1]=c end end
        if ctx.psychic and #cards~=5 then return end
        local score,name=A.score(cards,held,ctx)
        if ctx.forbidden and ctx.forbidden[name] then score=0 end
        if ctx.only_hand and name~=ctx.only_hand then score=0 end
        if score>best.score or score==best.score and #selected<#best.indices then
            local ids={}; for _,i in ipairs(selected) do ids[#ids+1]=i end
            best={score=score,indices=ids,name=name}
        end
        iterations=iterations+1; if yieldfn and iterations%32==0 then yieldfn() end
    end
    local function visit(start)
        if ctx._budget and ctx._budget.exhausted then return end
        if #selected>0 then evaluate() end
        if #selected==5 then return end
        for i=start,#candidates do
            if ctx._budget and ctx._budget.exhausted then break end
            selected[#selected+1]=candidates[i];visit(i+1);selected[#selected]=nil
        end
    end
    visit(1); return best
end
function A.discard_plans(hand,best,ctx)
    local plans,seen={},{}
    local function keep(keep)
        local ids={}; for i=1,#hand do if not keep[i] then ids[#ids+1]=i end end
        if #ids<1 then return end
        table.sort(ids,function(a,b)
            local function value(c) return (c.chips or 0)+(c.mult or 0)*8+((c.held_xmult or 1)-1)*50+(c.held_mult or 0)*8 end
            local x,y=value(hand[a]),value(hand[b]);return x==y and a<b or x<y
        end)
        while #ids>math.min(5,ctx and ctx.max_discard or 5) do table.remove(ids) end
        table.sort(ids)
        local key=table.concat(ids,','); if not seen[key] then seen[key]=true; plans[#plans+1]=ids end
    end
    local hold={}; for _,i in ipairs(best.indices) do hold[i]=true end; keep(hold)
    for i,c in ipairs(hand) do if (c.held_xmult or 1)>1 or (c.held_mult or 0)>0 or ctx and has(ctx,'j_baron') and c.rank==13 then hold[i]=true end end;keep(hold)
    for _,s in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
        hold={}; local n=0; for i,c in ipairs(hand) do if not c.stone and (c.suit==s or c.wild) then hold[i]=true; n=n+1 end end
        if n>=3 then keep(hold) end
    end
    local counts={}; for _,c in ipairs(hand) do if not c.stone and c.rank>0 then counts[c.rank]=(counts[c.rank] or 0)+1 end end
    hold={}; for i,c in ipairs(hand) do if (counts[c.rank] or 0)>=2 then hold[i]=true end end; keep(hold)
    for high=14,5,-1 do
        hold={}; local used={}; local n=0
        for i,c in ipairs(hand) do local r=c.rank==14 and high==5 and 1 or c.rank
            if r<=high and r>high-5 and not used[r] then hold[i]=true; used[r]=true; n=n+1 end
        end
        if n>=4 then keep(hold) end
    end
    -- Hold a single strong enhanced/face/high card when the board has no draw.
    local strongest,index=-1,1
    for i,c in ipairs(hand) do local v=(c.chips or 0)+(c.mult or 0)*5+(c.held_xmult or 1)*12
        if v>strongest then strongest,index=v,i end end
    keep({[index]=true})
    return plans
end
function A.card_key(c)
    local out={};for _,k in ipairs({'rank','suit','chips','mult','xmult','held_mult','held_xmult','stone','rankless','suitless','wild','red_seal','foil','holo','poly','debuff'}) do out[#out+1]=tostring(c[k] or '') end
    return table.concat(out,'/')
end
function A.plan(hand,deck,ctx,yieldfn)
    ctx=A.prepare(ctx);ctx._budget={evaluations=0,limit=ctx.evaluation_limit or 40000}
    local best=A.best(hand,ctx,yieldfn);best.kind='play';best.evaluations=ctx._budget.evaluations
    if (ctx.discards_left or 0)<1 or #deck==0 or best.score>=(ctx.remaining_target or math.huge) then return best end
    -- Canonical composition only: never use the actual draw order or game RNG.
    local pool={};for _,c in ipairs(deck) do pool[#pool+1]={card=c,key=A.card_key(c)} end
    table.sort(pool,function(a,b) return a.key<b.key end)
    local future={};for k,v in pairs(ctx) do future[k]=v end;future.discards_left=ctx.discards_left-1
    local trials={};local memo={};local cache_hits=0
    local function sample(proposal)
        if ctx._budget.exhausted then return end
        local seed=104729+(proposal.samples+1)*8191
        local function random(n) seed=seed*16807%2147483647;return seed%n+1 end
        local trial,remap={},{};for i,c in ipairs(hand) do trial[i]=c end
        local remaining=#pool
        for _,index in ipairs(proposal.indices) do
            local draw=random(remaining);local picked=remap[draw] or draw
            remap[draw]=remap[remaining] or remaining;remaining=remaining-1;trial[index]=pool[picked].card
        end
        local key={};for i,c in ipairs(trial) do key[i]=A.card_key(c) end;key=table.concat(key,'|')
        local value=memo[key]
        if value==nil then
            value=A.best(trial,future,yieldfn).score
            if ctx._budget.exhausted then return end
            memo[key]=value
        else cache_hits=cache_hits+1 end
        proposal.total=proposal.total+math.max(0,value);proposal.samples=proposal.samples+1
        proposal.expected=proposal.total/proposal.samples
    end
    for _,indices in ipairs(A.discard_plans(hand,best,ctx)) do if #indices<=#deck then
        local p={indices=indices,total=0,samples=0,expected=0};trials[#trials+1]=p
        for _=1,4 do sample(p) end
    end end
    table.sort(trials,function(a,b) return a.expected==b.expected and table.concat(a.indices,',')<table.concat(b.indices,',') or a.expected>b.expected end)
    for i=1,math.min(2,#trials) do for _=1,8 do sample(trials[i]) end end
    local chosen;local threshold=best.score*((ctx.discards_left==1 and ctx.hands_left~=1) and 1.2 or 1.16)
    for _,p in ipairs(trials) do
        -- Small lucky pilots cannot outrank a thoroughly sampled good draw.
        local estimate=best.score+(p.expected-best.score)*p.samples/(p.samples+2)
        if p.samples>=4 and estimate>threshold then chosen=p;threshold=estimate end
    end
    if chosen then return {kind='discard',indices=chosen.indices,score=best.score,expected=chosen.expected,name=best.name,
        evaluations=ctx._budget.evaluations,cache_hits=cache_hits,samples=chosen.samples,play_indices=best.indices} end
    best.evaluations=ctx._budget.evaluations;best.cache_hits=cache_hits;return best
end
local shop_values={j_joker=7,j_gros_michel=16,j_cavendish=40,j_half=22,j_banner=20,j_mystic_summit=15,
    j_fibonacci=23,j_scholar=18,j_abstract=20,j_blue_joker=23,j_scary_face=14,j_even_steven=15,j_odd_todd=19,
    j_raised_fist=17,j_blackboard=23,j_stencil=30,j_card_sharp=26,j_supernova=17,j_green_joker=17,
    j_popcorn=24,j_ice_cream=23,j_ramen=26,j_bull=19,j_bootstraps=17,j_sock_and_buskin=22,j_hack=22,
    j_blueprint=35,j_brainstorm=34,j_trading=16,j_golden=13,j_to_the_moon=16,j_rocket=15,j_business=11,
    j_credit_card=0,j_diet_cola=0,j_obelisk=2,j_madness=2,j_ceremonial=3,j_luchador=2,j_mr_bones=7,
    j_8_ball=9,j_splash=10,j_photograph=17,j_smiley=15,j_triboulet=45,j_baron=30,j_mime=24,
    j_hanging_chad=29,j_btogether_government_man=48,j_btogether_shroombo=48}
function A.preferred_hand(ctx)
    if ctx.preferred_hand and ctx.preferred_hand~='' then return ctx.preferred_hand end
    local name,plays='',0;for k,n in pairs(ctx.hand_plays or {}) do if n>plays or n==plays and k<name then name,plays=k,n end end
    if name~='' then return name end
    if has(ctx,'j_baron') or has(ctx,'j_half') then return 'High Card' end
    local total,largest=0,0;for _,n in pairs(ctx.suits or {}) do total=total+n;largest=math.max(largest,n) end
    if total>0 and largest/total>=0.55 then return 'Flush' end
    return 'Pair'
end
function A.shop_value(j,ctx)
    if j.set=='Planet' then return j.hand_type==A.preferred_hand(ctx) and 23 or ((ctx.hand_plays or {})[j.hand_type] or 0)>0 and 13 or 2 end
    if j.set=='Tarot' then return contains({'c_hermit','c_temperance','c_judgement'},j.key) and 18 or 4 end
    if j.set~='Joker' then return 0 end
    local value=shop_values[j.key]
    if not value then value=(j.mult or 0)*1.4+(j.chips or 0)/4+math.max(0,(j.xmult or 1)-1)*18; if value==0 then value=hand_joker[j.key] and 14 or suit_joker[j.key] and 12 or 8 end end
    value=math.max(value,(j.mult or 0)*1.2+(j.chips or 0)/6+math.max(0,(j.xmult or 1)-1)*18)
    local preferred=A.preferred_hand(ctx)
    if hand_joker[j.key] then value=value*(preferred==hand_joker[j.key][1] and 1.8 or 0.7) end
    if suit_joker[j.key] then
        local total=0;for _,n in pairs(ctx.suits or {}) do total=total+n end
        local share=total>0 and ((ctx.suits or {})[suit_joker[j.key]] or 0)/total or 0.25
        value=value*(0.4+share*2.4)
    end
    if j.key=='j_photograph' and has(ctx,'j_hanging_chad') or j.key=='j_hanging_chad' and has(ctx,'j_photograph') then value=value+24 end
    if j.key=='j_baron' and has(ctx,'j_mime') or j.key=='j_mime' and has(ctx,'j_baron') then value=value+20 end
    if j.key=='j_blueprint' or j.key=='j_brainstorm' then
        local strongest=0;for _,other in ipairs(ctx.jokers or {}) do if other.key~='j_blueprint' and other.key~='j_brainstorm' and other.blueprint_compat~=false then strongest=math.max(strongest,(other.xmult or 1)-1) end end
        value=value+math.min(40,strongest*8)
    end
    if j.eternal and value<8 then return 0 end
    if j.rental then value=value-8 end
    if j.perishable then value=value*0.7 end
    return value+(j.foil and 10 or 0)+(j.holo and 12 or 0)+(j.poly and 16 or 0)
end
return A
