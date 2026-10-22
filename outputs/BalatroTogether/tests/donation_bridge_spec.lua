-- Regression at the native reconstruction boundary: an edition's slot bonus
-- is already included in the sender's saved ability total.
local schema=dofile(ROOT..'/core/donations.lua')
local function world(fail)
    local area={T={x=0,y=0},config={card_limit=5},cards={1,2,3,4,5}}
    function area:emplace(c) self.cards[#self.cards+1]=c end
    G={jokers=area,consumeables={T={x=0,y=0},config={card_limit=2},cards={}},hand={config={card_limit=8}},
        P_CENTERS={j_juggler={name='Juggler',set='Joker'}},P_CARDS={empty={}},CARD_W=1,CARD_H=1,GAME={used_jokers={}}}
    Card=function(_,_,_,_,_,center)
        local c={ability={name=center.name,set=center.set,card_limit=0,h_size=1},states={},removed=false}
        function c:set_edition(e) self.edition=e; self.ability.card_limit=self.ability.card_limit+(e.negative and 1 or 0) end
        function c:set_cost() end
        function c:add_to_deck()
            self.added_to_deck=true; area.config.card_limit=area.config.card_limit+self.ability.card_limit
            G.hand.config.card_limit=G.hand.config.card_limit+self.ability.h_size
            if fail then error('Native fixture failure after applying passive effects') end
        end
        function c:remove()
            if self.added_to_deck then area.config.card_limit=area.config.card_limit-self.ability.card_limit; G.hand.config.card_limit=G.hand.config.card_limit-self.ability.h_size end
            self.removed=true
        end
        return c
    end
    BT={Session={Donations=schema}}
    return dofile(ROOT..'/game/donations.lua'),area
end
local payload={center='j_juggler',kind='Joker',name='Juggler',edition='negative',ability={name='Juggler',set='Joker',card_limit=1,h_size=1}}
local transfer,area=world(false)
assert(transfer.receive(payload,1)); assert(area.config.card_limit==6 and #area.cards==6 and G.hand.config.card_limit==9)
assert(transfer.receive(payload,1)); assert(area.config.card_limit==6 and #area.cards==6 and G.hand.config.card_limit==9)
print('PASS Negative reconstruction grants one slot and duplicate delivery cannot reapply native passives')
transfer,area=world(true)
assert(not transfer.receive(payload,1)); assert(area.config.card_limit==5 and #area.cards==5 and G.hand.config.card_limit==8)
assert(not transfer.received[1])
print('PASS failed native reconstruction rolls back passive effects without consuming the donation')
return 2
