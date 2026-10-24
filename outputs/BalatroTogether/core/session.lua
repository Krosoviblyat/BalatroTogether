-- Pure authoritative state machine; no LÖVE or Balatro dependency.
local M = {}
M.__index = M
M.PROTOCOL = 1
M.DECKS={{'b_red','Red Deck'},{'b_blue','Blue Deck'},{'b_yellow','Yellow Deck'},
    {'b_green','Green Deck'},{'b_black','Black Deck'},{'b_magic','Magic Deck'},
    {'b_nebula','Nebula Deck'},{'b_ghost','Ghost Deck'},{'b_abandoned','Abandoned Deck'},
    {'b_checkered','Checkered Deck'},{'b_zodiac','Zodiac Deck'},{'b_painted','Painted Deck'},
    {'b_anaglyph','Anaglyph Deck'},{'b_plasma','Plasma Deck'},{'b_erratic','Erratic Deck'}}
function M.valid_deck(key) for _,v in ipairs(M.DECKS) do if v[1]==key then return true end end; return false end
function M.deck_name(key) for _,v in ipairs(M.DECKS) do if v[1]==key then return v[2] end end; return 'Red Deck' end
local function copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}; for k,v in pairs(t) do r[k] = copy(v) end; return r
end
M.copy = copy
local function finite(x) return type(x) == 'number' and x == x and x >= 0 and x < 1e300 end
local function score_number(x) return M.Numbers and M.Numbers.score(x) or (finite(x) and x<=1e100) end
local function integer(x, lo, hi) return finite(x) and x % 1 == 0 and x >= lo and x <= hi end
local function clean(x, n)
    local value=tostring(x or ''):gsub('[%z\1-\31\127]', '')
    return M.limit_text and M.limit_text(value,n or 40) or value:sub(1,n or 40)
end
function M.limit_text(value,limit)
    local n=math.max(0,math.min(#value,limit))
    while n>0 do local b=value:byte(n+1); if not b or b<128 or b>191 then break end; n=n-1 end
    return value:sub(1,n)
end
function M.player_name(value,limit)
    if type(value)~='string' then return '' end
    return M.limit_text(value:gsub('[%z\1-\31\127]',''),limit or 24):match('^%s*(.-)%s*$')
end
local activities = {selecting=true, playing=true, calculating=true, discarding=true,
    jokers=true, shopping=true, consumable=true, waiting=true, ready=true, loading=true,
    blind_select=true, cashout=true, pack=true, disconnected=true,donating=true}
local function player(id, name, token)
    name=M.player_name(name); if name=='' then name='Player '..id end
    return {id=id, name=name, token=token, connected=true, ready=false,
        activity='waiting', contribution=0, total=0, highest=0, hands_played=0,
        hands=0, discards=0, money=0, jokers={}, consumables={}, deck={},
        last_hand='', busy=false, exhausted=false, ack=0, completed=0}
end
function M.new(opts)
    opts=opts or {}
    local self=setmetatable({phase='lobby', revision=0, round=0, ante=1, blind_index=1,
        intended=opts.intended or 4, scaling=opts.scaling or 1, players={}, events={},party_id=opts.party_id,save_autos=false,
        seed='', target=0, score=0, lifetime_score=0, winner=nil, proposal=nil,
        completed_antes=0, protocol=M.PROTOCOL,run_id=0,restarts=0,
        boss_stake=opts.boss_stake or 1,boss_mode=opts.boss_mode or 'mixed',quick_duel=opts.quick_duel==true,
        deck=opts.deck or 'b_red',custom_seed=opts.seed or '',endless=opts.endless~=false,donation_data={items={},seen={},history={},history_order={},counter=0}},M)
    assert(M.valid_deck(self.deck),'Choose a vanilla deck.')
    if M.Pot then self.pot=M.Pot.empty() end
    if M.Dice then self.dice=M.Dice.empty() end
    self.custom_seed=self.custom_seed:upper()
    assert(self.custom_seed=='' or (#self.custom_seed<=8 and self.custom_seed:match('^[A-Z0-9]+$')),'Seed must be 1-8 letters/digits or blank.')
    assert(integer(self.intended,1,4), 'intended player count must be 1–4')
    assert(type(self.scaling)=='number' and self.scaling>=0.5 and self.scaling<=3, 'invalid scaling')
    self.players[1]=player(1,opts.name or 'Host',opts.token or 'host')
    return self
end
function M:changed() self.revision=self.revision+1 end
function M:event(id, kind, text, amount)
    self.events[#self.events+1]={seq=self.revision+1, player=id, kind=kind, text=clean(text,120), amount=amount}
    if #self.events>24 then table.remove(self.events,1) end
end
function M:count()
    local n=0; for _,p in pairs(self.players) do if not p.withdrawn then n=n+1 end end; return n
end
function M:join(name, token, steam_name)
    if self.phase~='lobby' then return nil,'A run is already in progress; reconnect with the original session.' end
    for i=2,4 do
        if not self.players[i] and self:count()<self.intended then
            self.players[i]=player(i,name,token); self.players[i].steam_name=steam_name and clean(steam_name,40)
            self:event(i,'connection','joined the table'); self:changed(); return i
        end
    end
    return nil,'The table is full.'
end
function M:reconnect(token)
    for id,p in pairs(self.players) do
        if p.token==token and not p.connected and not p.withdrawn then
            p.connected=true; self:event(id,'connection','reconnected'); self:changed(); return id
        end
    end
    return nil,'No reconnectable seat. Keep the original game open to recover.'
end
function M:disconnect(id)
    local p=self.players[id]; if not p then return end
    if self.phase=='lobby' and id~=1 then self.players[id]=nil
    else p.connected=false; p.ready=false; p.activity='disconnected' end
    self:event(id,'connection','disconnected — progression is paused'); self:changed()
end
function M:all(test)
    for _,p in pairs(self.players) do if not p.withdrawn and not test(p) then return false end end; return true
end
function M:drop(id)
    local p=self.players[id]
    if id==1 or not p or p.connected then return nil,'Only a disconnected teammate can be retired.' end
    if self.phase=='lobby' then self.players[id]=nil
    else p.withdrawn=true; p.busy=false; p.exhausted=true; p.ready=false end
    if M.Donations then M.Donations.retire(self,id) end
    self:event(id,'connection','seat retired by host'); self:changed(); self:advance(); return true
end
function M:start(seed)
    if self.phase~='lobby' then return nil,'Already started.' end
    if self:count()~=self.intended or not self:all(function(p) return p.connected and p.ready end) then
        return nil,'Every intended player must be connected and ready.'
    end
    self.seed=self.custom_seed~='' and self.custom_seed or clean(seed,8):upper(); if not self.seed:match('^[A-Z0-9]+$') or #self.seed>8 or #self.seed<1 then return nil,'Seed must contain 1-8 letters or digits.' end
    self.run_id=self.run_id+1
    self.blind_index=self.quick_duel and 3 or 1
    self.phase='prepare'; for _,p in pairs(self.players) do p.ready=false; p.activity='loading' end
    self:changed(); return true
end
function M:restart(seed)
    if self.phase=='lobby' then return nil,'Start the party run first.' end
    if self.phase=='saving' or self.phase=='resuming' or self.phase=='skipping' then return nil,'Finish the party checkpoint or skip before restarting.' end
    if not self:all(function(p) return p.connected end) then return nil,'Reconnect or retire absent players before restarting.' end
    if not self:all(function(p) return (not M.Pot or not M.Pot.pending(p)) and (not M.Dice or not M.Dice.pending(p)) end) then return nil,'Wait for payouts and dice before restarting.' end
    seed=self.custom_seed~='' and self.custom_seed or clean(seed,8):upper()
    if not seed:match('^[A-Z0-9]+$') or #seed>8 or #seed<1 then return nil,'Seed must contain 1-8 letters or digits.' end
    self.run_id=self.run_id+1; self.restarts=self.restarts+1; self.seed=seed
    self.phase='prepare'; self.round=0; self.ante=1; self.blind_index=self.quick_duel and 3 or 1; self.proposal=nil
    self.harbinger=nil;self.harbinger_private=nil
    self.score=0; self.target=0; self.lifetime_score=0; self.completed_antes=0; self.winner=nil; self.events={}
    self.donation_data={items={},seen={},history={},history_order={},counter=0}
    if M.Pot then self.pot=M.Pot.empty() end
    if M.Dice then self.dice=M.Dice.empty() end
    for id,p in pairs(self.players) do
        local fresh=player(id,p.name,p.token)
        fresh.ack=p.ack; fresh.steam_name=p.steam_name; fresh.steam_id=p.steam_id; fresh.withdrawn=p.withdrawn; fresh.bot=p.bot
        fresh.connected=p.connected; fresh.activity='loading'
        self.players[id]=fresh
    end
    self.admin_recovery=0; self.admin_effect_counter=0
    self.skip_vote=nil;self.skip_order=nil;self.skip_counter=0;self.last_skip=nil
    self.checkpoint=nil;self.checkpoint_position=nil;self.saved_leave=nil;self.manual_save_requested=nil;self.save_leave_requested=nil
    self:event(1,'milestone','FRESH TABLE - PARTY RESTARTED'); self:changed(); return true
end
function M:set_proposal(id, data)
    if id~=1 or self.phase~='prepare' then return nil,'Only the host can propose a blind.' end
    if type(data)~='table' or not score_number(data.base) or data.base<=0
        or not integer(data.ante,1,2147483647) or not integer(data.index,1,3)
        or type(data.key)~='string' or not data.key:match('^bl_[%w_]+$') then return nil,'Invalid blind proposal.' end
    if data.ante~=self.ante or data.index~=self.blind_index then return nil,'Blind progression mismatch.' end
    self.proposal=copy(data); self:changed(); return true
end
function M:begin_blind()
    if self.skip_vote or self.checkpoint and self.checkpoint.status=='saving' then return end
    if M.Save and self.save_autos and self.checkpoint_position~=M.Save.position(self) then return end
    if not self.proposal or not self:all(function(p) return p.connected and p.ready and not p.transferring and (not M.Pot or not M.Pot.pending(p)) and (not M.Dice or not M.Dice.pending(p)) end) then return end
    self.round=self.round+1; self.phase='starting'; self.score=0; self.winner=nil
    local target=self.proposal.base * self:count()^1.08 * self.scaling
    if M.Harbinger then target=M.Harbinger.target(self,target);M.Harbinger.begin(self) end
    self.target=M.Numbers and M.Numbers.ceil(target) or math.ceil(target)
    for _,p in pairs(self.players) do
        p.contribution=0; p.ready=false; p.busy=false; p.exhausted=p.withdrawn or false
        p.dice_active_mult=p.dice_next_mult or 0; p.dice_next_mult=0
        for _,field in ipairs({'hands','discards','chips'}) do p['dice_active_'..field]=p['dice_next_'..field] or 0; p['dice_next_'..field]=0 end
        p.completed=0; p.entered=false; p.shop_done=nil; p.last_hand=''; p.activity=p.withdrawn and 'disconnected' or 'loading'
    end
    self:event(1,'milestone','waiting for every native blind to load'); self:changed()
end
function M:advance()
    if self.phase=='resuming' and M.Save then M.Save.advance(self);return end
    if self.phase=='skipping' and M.Vote then M.Vote.advance(self);return end
    if self.phase=='prepare' then self:begin_blind(); return end
    if self.phase=='starting' then
        if self:all(function(p) return p.connected and p.entered end) then
            self.phase='blind'; self:event(1,'milestone','the team blind begins'); self:changed()
        end
        return
    end
    if self.phase~='blind' then return end
    if M.Harbinger and M.Harbinger.blocks(self) then return end
    -- Do not close a blind while any connected player is resolving an action,
    -- or while a disconnected seat may still have an unacknowledged score.
    if not self:all(function(p) return p.connected and not p.busy end) then return end
    if self.score>=self.target then self.winner=true
    elseif self:all(function(p) return p.exhausted end) then self.winner=false
    else return end
    if self.winner then
        if self.blind_index==3 then self.completed_antes=self.ante end
        if self.ante==8 and self.blind_index==3 and not self.endless then self.phase='victory'
        else self.phase='shop' end
        if self.ante==8 and self.blind_index==3 and self.endless then self:event(1,'milestone','ANTE 8 CLEARED / ENDLESS CONTINUES') end
        self:event(1,'milestone',self.phase=='victory' and 'TEAM VICTORY' or 'BLIND COMPLETE')
    else self.phase='defeat'; self:event(1,'milestone','The table is out of hands') end
    if M.Pot then M.Pot.settle(self) end
    if M.Dice then M.Dice.reward(self) end
    for _,p in pairs(self.players) do p.ready=false end
    self:changed()
end
function M:next_blind()
    if self.phase~='shop' or not self:all(function(p) return p.connected and p.ready and not p.transferring and p.shop_done==self.round and (not M.Pot or not M.Pot.pending(p)) and (not M.Dice or not M.Dice.pending(p)) end) then return end
    self.blind_index=self.blind_index+1
    if self.blind_index>3 then self.blind_index=1; self.ante=self.ante+1 end
    self.phase='prepare'; self.proposal=nil
    for _,p in pairs(self.players) do p.ready=false end
    self:changed()
end
local function list(value, limit)
    local out={}; if type(value)~='table' then return out end
    for i=1,math.min(#value,limit) do
        local v=value[i]
        if type(v)=='table' then
            out[#out+1]={key=clean(v.key,48),name=clean(v.name,50),edition=clean(v.edition,24),effect=clean(v.effect,120),
                enhancement=clean(v.enhancement,30),seal=clean(v.seal,24),rank=clean(v.rank,8),
                suit=clean(v.suit,12),selected=v.selected==true,debuff=v.debuff==true}
        end
    end; return out
end
function M:apply(id, action)
    local p=self.players[id]
    if not p or not p.connected or p.withdrawn or type(action)~='table' then return nil,'Unknown or disconnected seat.' end
    if not integer(action.seq,1,2147483647) then return nil,'Invalid action sequence.' end
    if action.seq<=p.ack then return true,'duplicate' end
    if action.seq~=p.ack+1 then return nil,'Missing action; resend unacknowledged actions.' end
    if action.run~=self.run_id then
        p.ack=action.seq; self:changed(); return nil,'Stale action from the previous run.'
    end
    local kind=action.kind; local d=action.data or {}; local ok,err=true,nil
    if type(d)~='table' then return nil,'Invalid action payload.' end
    if (self.phase=='saving' or self.phase=='resuming') and kind~='status' and kind~='restore_ready' and kind~='resume_start'
        and not (self.phase=='resuming' and kind=='admin_retire') then
        ok,err=nil,'Waiting for the party checkpoint. Your run is protected.'
    elseif kind=='save_begin' or kind=='save_request' or kind=='restore_ready' or kind=='resume_start' then
        if M.Save then ok,err=M.Save.apply(self,id,kind,d) else ok,err=nil,'Party saves unavailable.' end
    elseif kind=='rename' then
        local name=M.player_name(d.name)
        if name=='' then ok,err=nil,'Enter a display name.'
        else p.name=name; self:event(id,'activity','updated their display name') end
    elseif kind=='boss_rules' then
        if M.Harbinger then ok,err=M.Harbinger.rules(self,id,d) else ok,err=nil,'Boss lab unavailable.' end
    elseif kind=='ready' then
        if p.transferring or ((M.Pot and M.Pot.pending(p)) or (M.Dice and M.Dice.pending(p))) then ok,err=nil,'Finish transfers before readying.'
        elseif self.phase~='lobby' and self.phase~='prepare' and self.phase~='shop' then ok,err=nil,'Cannot ready during a hand.'
        elseif d.ready==true and self.phase=='prepare' and (d.round~=self.round or d.ante~=self.ante or d.index~=self.blind_index) then ok,err=nil,'Wait for the matching native blind selection.'
        elseif d.ready==true and self.phase=='shop' and p.shop_done~=self.round then ok,err=nil,'Cash out and leave your native shop first.'
        else p.ready=d.ready==true; p.activity=p.ready and 'ready' or 'waiting'
            self:event(id,'activity',p.ready and 'is ready for the next blind' or 'is waiting') end
    elseif kind=='skip_vote' or kind=='skip_done' then
        if M.Vote then ok,err=M.Vote.apply(self,id,kind,d) else ok,err=nil,'Skip voting unavailable.' end
    elseif kind=='entered' then
        if self.phase~='starting' or d.round~=self.round or d.ante~=self.ante or d.index~=self.blind_index or not self.proposal or d.key~=self.proposal.key then ok,err=nil,'Native blind entry does not match the party.'
        else p.entered=true; p.activity='waiting' end
    elseif kind=='shop_done' then
        local index=self.blind_index%3+1; local ante=self.ante+(self.blind_index==3 and 1 or 0)
        if self.phase~='shop' or p.transferring or ((M.Pot and M.Pot.pending(p)) or (M.Dice and M.Dice.pending(p))) or d.round~=self.round or d.ante~=ante or d.index~=index then ok,err=nil,'Wait for native cash-out and shop completion.'
        else p.shop_done=self.round; p.ready=true; p.activity='ready' end
    elseif kind=='busy' then
        if self.phase~='blind' or d.round~=self.round or p.exhausted or self.score>=self.target or (M.Harbinger and M.Harbinger.blocks(self)) then ok,err=nil,'The blind is closing or the boss is countering.'
        else p.busy=true; p.activity='calculating' end
    elseif kind=='score' then
        if self.phase~='blind' or d.round~=self.round or not p.busy
            or not score_number(d.amount) or not integer(d.hand,1,10000)
            or d.hand~=p.completed+1 then ok,err=nil,'Invalid, stale, or unsolicited hand score.'
        else
            p.completed=d.hand; p.contribution=p.contribution+d.amount; p.total=p.total+d.amount
            if d.amount>p.highest then p.highest=d.amount end; p.hands_played=p.hands_played+1
            p.last_hand=clean(d.name,36); self.score=self.score+d.amount; self.lifetime_score=self.lifetime_score+d.amount
            self:event(id,'score','scored '..p.last_hand,d.amount)
            if M.Harbinger then M.Harbinger.counter(self,id,d.hand,d.boss_disabled==true) end
        end
    elseif kind=='idle' then
        if self.phase~='blind' or d.round~=self.round then ok,err=nil,'Stale action completion.'
        else p.busy=false; p.exhausted=d.exhausted==true; p.activity=p.exhausted and 'waiting' or 'selecting' end
    elseif type(kind)=='string' and kind:match('^donation_') then
        if M.Donations then ok,err=M.Donations.apply(self,id,kind,d) else ok,err=nil,'Donation box unavailable.' end
    elseif type(kind)=='string' and kind:match('^pot_') then
        if M.Pot then ok,err=M.Pot.apply(self,id,kind,d) else ok,err=nil,'Bet pot unavailable.' end
    elseif type(kind)=='string' and kind:match('^dice_') then
        if M.Dice then ok,err=M.Dice.apply(self,id,kind,d) else ok,err=nil,'Reward dice unavailable.' end
    elseif type(kind)=='string' and kind:match('^admin_') then
        if M.Admin then ok,err=M.Admin.apply(self,id,kind,d) else ok,err=nil,'Admin controls unavailable.' end
    elseif kind=='status' then
        p.native_safe=d.native_safe==true
        if integer(d.native_ante,1,2147483647) then p.native_ante=d.native_ante end
        if integer(d.native_index,1,3) then p.native_index=d.native_index end
        if activities[d.activity] and not p.transferring then p.activity=d.activity end
        for _,field in ipairs({'hands','discards','money'}) do
            if M.Numbers and M.Numbers.finite(d[field]) then
                p[field]=field=='money' and d[field] or M.Numbers.native(d[field],1e9)
            elseif type(d[field])=='number' and d[field]==d[field] and math.abs(d[field])<1e9 then p[field]=d[field] end
        end
        p.jokers=list(d.jokers,30); p.consumables=list(d.consumables,30)
        p.deck={}; if type(d.deck)=='table' then for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
            if integer(d.deck[suit],0,10000) then p.deck[suit]=d.deck[suit] end end end
        p.reveal=d.reveal==true; p.inspect=d.inspect~=false
        p.board=p.reveal and list(d.board,60) or {}
        p.played=list(d.played,20)
        p.shop=list(d.shop,20)
    elseif kind=='event' then
        local allowed={discard=true,purchase=true,consumable=true,joker=true}
        if allowed[d.event] then self:event(id,'activity',clean(d.text,90)) else ok,err=nil,'Unknown activity event.' end
    else ok,err=nil,'Unknown action.' end
    -- Rejected commands are acknowledged too: later legal actions must not deadlock.
    self.players[id].ack=action.seq; self:changed()
    self:advance(); self:next_blind()
    return ok,err
end
function M:snapshot(viewer)
    local state={}
    for k,v in pairs(self) do if k~='players' and k~='donation_data' and k~='harbinger_private' then state[k]=copy(v) end end
    state.players={}
    for i=1,4 do
        local p=self.players[i]
        if p then
            local q=copy(p); q.token=nil
            if i~=(viewer or 1) then q.personal_pot=nil end
            if not q.inspect then q.jokers={}; q.consumables={}; q.deck={}; q.board={}; q.played={}; q.shop={} end
            state.players[tostring(i)]=q
        end
    end
    if M.Donations then M.Donations.snapshot(self,state,viewer or 1) end
    return state
end
return M
