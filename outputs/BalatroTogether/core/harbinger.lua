-- Host-owned counterplay. Never reads player hands, native RNG or game objects.
local H={KEY='bl_btogether_harbinger',IMPACT=2.10,DURATION=2.75,MAX_QUEUE=8,SPAWN_CHANCE=0.20}
function H.migrate_config(config)
    if (config.harbinger_spawn_revision or 0)>=2 then return false end
    config.boss_mode='mixed';config.quick_duel=false;config.harbinger_spawn_revision=2
    return true
end
function H.spawn_roll(seed,ante)
    -- A separate, stateless seed stream. Rebuilding UI, reconnecting or opening
    -- the boss selector cannot reroll the encounter or consume game RNG.
    local value=1
    for c in ('harbinger-spawn-v2:'..tostring(seed)..':'..tostring(ante)):gmatch('.') do value=(value*31+c:byte())%2147483647 end
    for i=1,4 do value=value*16807%2147483647 end
    return value/2147483647
end
function H.should_spawn(s,ante,win_ante)
    if not s or s.phase=='lobby' then return false end
    -- Deliberate opt-in test mode is the only first-ante exception.
    if s.quick_duel and s.round==0 then return true end
    win_ante=win_ante or 8
    if ante<2 or win_ante>0 and ante%win_ante==0 then return false end
    if s.boss_mode=='harbinger' then return true end
    return s.boss_mode=='mixed' and H.spawn_roll(s.seed,ante)<H.SPAWN_CHANCE
end
H.tiers={
    {name='WHITE',target=1,damage=1,level=0,color={0.92,0.88,1}},
    {name='VIOLET',target=1.25,damage=1.15,level=1,color={0.68,0.32,1}},
    {name='CRIMSON',target=1.5,damage=1.35,level=2,color={1,0.25,0.42}},
    {name='ECLIPSE',target=2,damage=1.75,level=3,color={0.94,0.65,1}},
}
local hands={['High Card']={5,1,10,1},Pair={10,2,15,1},['Two Pair']={20,2,20,1},
    ['Three of a Kind']={30,3,20,2},Straight={30,4,30,3},Flush={35,4,15,2},
    ['Full House']={40,4,25,2},['Four of a Kind']={60,7,30,3},['Straight Flush']={100,8,40,4}}
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
function H.tier(m) return H.tiers[m.boss_stake or 1] or H.tiers[1] end
function H.rules(m,id,d)
    if id~=1 or m.phase~='lobby' then return nil,'Only the host can change boss stakes before a run.' end
    if type(d.stake)~='number' or d.stake%1~=0 or not H.tiers[d.stake]
        or (d.mode~='harbinger' and d.mode~='mixed') or type(d.quick)~='boolean' then return nil,'Invalid boss rules.' end
    m.boss_stake=d.stake;m.boss_mode=d.mode;m.quick_duel=d.quick
    for _,p in pairs(m.players) do p.ready=false end
    m:event(1,'milestone','Boss stakes: '..H.tier(m).name);return true
end
function H.target(m,target) return m.blind_index==3 and target*H.tier(m).target or target end
local function random(p,limit) p.rng=p.rng*16807%2147483647;return p.rng%limit+1 end
local function shuffle(p,t) for i=#t,2,-1 do local j=random(p,i);t[i],t[j]=t[j],t[i] end end
local function draw(p)
    if #p.deck==0 then p.deck=p.discard;p.discard={};shuffle(p,p.deck);p.shuffles=p.shuffles+1 end
    return table.remove(p.deck)
end
function H.begin(m)
    m.harbinger=nil;m.harbinger_private=nil
    if not m.proposal or m.proposal.key~=H.KEY then return end
    local seed=1;for c in (m.seed..':'..m.ante..':'..m.round):gmatch('.') do seed=(seed*31+c:byte())%2147483647 end
    local p={rng=math.max(1,seed),deck={},discard={},hand={},shuffles=0}
    local id=0;for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do for rank=2,14 do
        id=id+1;p.deck[#p.deck+1]={id=id,suit=suit,rank=rank,chips=rank==14 and 11 or math.min(rank,10)}
    end end
    shuffle(p,p.deck);for i=1,8 do p.hand[i]=draw(p) end
    m.harbinger_private=p
    m.harbinger={round=m.round,turn=0,score=0,damage=0,queue={},last=nil,history={},clock=m.now or 0}
end
function H.evaluate(cards,level)
    local name,ids=H.Strategy.classify(cards,{})
    local base=assert(hands[name]);local chips,mult=base[1]+base[3]*level,base[2]+base[4]*level
    for _,i in ipairs(ids) do chips=chips+cards[i].chips end
    return {name=name,chips=chips,mult=mult,raw=chips*mult,scoring=copy(ids)}
end
local function start(m)
    local b,p=m.harbinger,m.harbinger_private
    if b.pending or #b.queue==0 or not p then return end
    local trigger=table.remove(b.queue,1);local tier=H.tier(m);local levels={}
    for name,base in pairs(hands) do levels[name]={chips=base[1]+base[3]*tier.level,mult=base[2]+base[4]*tier.level} end
    local plan=H.Strategy.best(p.hand,{hands=levels,jokers={},psychic=true})
    local cards,keep,mask={},{},{}
    for _,i in ipairs(plan.indices) do cards[#cards+1]=copy(p.hand[i]);mask[i]=true end
    for i,c in ipairs(p.hand) do if mask[i] then p.discard[#p.discard+1]=c else keep[#keep+1]=c end end
    p.hand=keep;while #p.hand<8 do p.hand[#p.hand+1]=draw(p) end
    local attack=H.evaluate(cards,tier.level)
    attack.cards=cards;attack.age=0;attack.hit=false;attack.seat=trigger.seat;attack.hand=trigger.hand
    b.turn=b.turn+1;attack.id=m.run_id..':'..m.round..':'..b.turn
    attack.damage=(m.Numbers and m.Numbers.ceil or math.ceil)(attack.raw*(m.proposal.base/600)*tier.damage)
    b.pending=attack;m:changed()
end
function H.counter(m,id,hand,disabled)
    local b=m.harbinger;if not b or m.phase~='blind' then return end
    if disabled then m:event(id,'boss','The Harbinger is silenced for this build');return end
    -- There can be one in-flight native hand per seat; this is bounded even
    -- when reports from several seats arrive in the same network batch.
    assert(#b.queue<H.MAX_QUEUE,'Too many Harbinger counters')
    b.queue[#b.queue+1]={seat=id,hand=hand};start(m)
end
function H.blocks(m) local b=m.harbinger;return b and (b.pending~=nil or #b.queue>0) end
function H.tick(m,now,paused)
    local b=m.harbinger;if not b then return end
    local dt=math.max(0,math.min(0.25,now-(b.clock or now)));b.clock=now
    if m.phase~='blind' then return end
    if paused or not m:all(function(p) return p.connected end) then return end
    start(m);local a=b.pending;if not a then return end
    a.age=math.min(H.DURATION,a.age+dt)
    if a.age>=H.IMPACT and not a.hit then
        a.hit=true;a.removed=m.score<a.damage and m.score or a.damage;m.score=m.score-a.removed
        b.score=b.score+a.damage;b.damage=b.damage+a.removed
        local shown=m.Numbers and m.Numbers.format(a.removed) or tostring(a.removed)
        m:event(0,'boss',a.name..' / '..a.chips..' x '..a.mult..' / TEAM -'..shown)
        m:changed()
    end
    if a.age>=H.DURATION then
        b.last=copy(a);b.history[#b.history+1]=copy(a);if #b.history>3 then table.remove(b.history,1) end
        b.pending=nil;start(m);m:changed();m:advance()
    elseif math.floor(a.age*15)~=(a.frame or -1) then a.frame=math.floor(a.age*15);m:changed() end
end
return H
