local checks=0
local function test(name,fn) fn();checks=checks+1;print('PASS '..name) end
local function world()
    local events={};local definition
    G={jokers={cards={}},P_CENTERS={e_negative={}},C={MULT={}}}
    G.E_MANAGER={add_event=function(_,e) events[#events+1]=e end}
    Event=function(e) return e end
    SMODS={Atlas=function() end,Joker=function(c) definition=c end}
    localize=function() return 'Upgraded' end;card_eval_status_text=function() end
    pseudoseed=function(k) return k end;pseudorandom_element=function(t) return t[1] end
    local m=dofile(ROOT..'/game/government_man.lua');m.install()
    local function make(negative,government,kind)
        local c={added_to_deck=true,ability={set=kind or 'Joker',extra={x_mult=2,acquired=0}},edition=negative and {negative=true} or nil}
        function c:juice_up() end
        function c:set_edition(e) self.edition=e;self.editions=(self.editions or 0)+1 end
        G.jokers.cards[#G.jokers.cards+1]=c
        return c
    end
    local owner=make(false,true)
    local function flush() while #events>0 do table.remove(events,1).func() end end
    local function add(c,ctx) definition.calculate(definition,owner,ctx or {card_added=true,card=c}) end
    return m,definition,owner,make,flush,add,events
end
test('Government Man registers as a native Legendary with $20 cost, blueprint scoring and X2 base',function()
    local m,d,c=world();assert(d.rarity==4 and d.cost==20 and d.unlocked and d.blueprint_compat and not d.perishable_compat)
    assert(d.calculate(d,c,{joker_main=true}).x_mult==2)
end)
test('Two new Negative acquisitions add exactly X1 and convert one eligible native Joker',function()
    local m,d,c,make,flush,add=world();add(make(true));flush();assert(c.ability.extra.x_mult==2.5 and c.ability.extra.acquired==1 and not c.edition)
    add(make(true));flush();assert(c.ability.extra.x_mult==3 and c.ability.extra.acquired==2 and c.edition.negative and c.editions==1)
end)
test('Acquisition resolves after native emplacement and duplicate pending contexts count once',function()
    local m,d,c,make,flush,add=world();local other=make(true);G.jokers.cards[2]=nil;add(other);add(other);G.jokers.cards[2]=other;flush();assert(c.ability.extra.acquired==1)
end)
test('Removed or rolled-back pickups cannot grant upgrades',function()
    local m,d,c,make,flush,add=world();local other=make(true);add(other);G.jokers.cards[2]=nil;flush();assert(c.ability.extra.acquired==0)
end)
test('Blueprint and Cryptid retriggers do not duplicate acquisition progress',function()
    local m,d,c,make,flush,add=world();local other=make(true)
    add(other,{card_added=true,card=other,blueprint=true});add(other,{card_added=true,card=other,retrigger_joker=true});flush();assert(c.ability.extra.acquired==0)
    assert(d.calculate(d,c,{joker_main=true,blueprint=true}).x_mult==2)
end)
test('Already-owned conversions, non-Negatives and Negative consumables do not count',function()
    local m,d,c,make,flush,add=world();local other=make(false);add(other);other:set_edition{negative=true};add(make(true,false,'Tarot'));flush()
    assert(c.ability.extra.acquired==0)
end)
test('No extra conversion occurs when the whole inventory is already Negative',function()
    local m,d,c,make,flush,add=world();c.edition={negative=true};add(make(true));add(make(true));flush();assert(c.ability.extra.x_mult==3 and not c.editions)
end)
test('Rejected donation returns suppress only Government Man acquisition progress',function()
    local m,d,c,make,flush,add=world();local other=make(true);function other:add_to_deck() add(self) end
    m.restore(other);flush();assert(c.ability.extra.acquired==0 and not m.restoring)
    other.add_to_deck=function() error('rollback fixture') end;assert(not pcall(m.restore,other) and not m.restoring)
end)
test('Debuffed or removed Government Man cannot grow after a queued pickup',function()
    local m,d,c,make,flush,add=world();add(make(true));c.debuff=true;flush();assert(c.ability.extra.acquired==0)
end)
return checks
