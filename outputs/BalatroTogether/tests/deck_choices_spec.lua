local S=dofile(ROOT..'/core/session.lua');BT={Session=S}
local original={choices={deck_choice='b_red'}}
SMODS={RunSelect={Setup=original,Pages={}}};local P=SMODS.RunSelect.Pages
local function page(key,deck,pool,default)
    P[key]={pool=pool,set_default=function(_,v) return v or default end,
        optional=function() local c=SMODS.RunSelect.Setup.choices;return c.deck_choice==deck or c.deck_choice=='b_cry_antimatter' and c.cry_antimatter[deck] end,
        selected_text=function(_,v) return 'Native '..v end}
end
page('cry_edeck_ed','b_cry_e_deck',{{key='e_foil'},{key='e_holo'},{key='random'}},'e_foil')
page('cry_edeck_sl','b_cry_sl_deck',{{key='Gold'},{key='Red'},{key='random'}},'Gold')
page('cry_edeck_st','b_cry_st_deck',{{key='Spades'},{key='Hearts'}},'Spades')
page('cry_antimatter','b_cry_antimatter',{{key='b_red'},{key='b_cry_e_deck'},{key='b_cry_sl_deck'},{key='locked'}},{b_red=true,b_cry_e_deck=true})
Cryptid={antimatter_compat=function(k) return k~='locked' end}
local D=dofile(ROOT..'/game/deck_choices.lua')
local function test(n,f) f();print('PASS '..n) end
test('deck options use native pools and only appear on relevant decks',function()
    assert(#D.pages('b_red',{})==0 and D.pages('b_cry_e_deck',{})[1].key=='cry_edeck_ed')
    assert(D.pages('b_cry_sl_deck',{})[1].key=='cry_edeck_sl')
end)
test('malformed/deleted choices normalize while Random remains selectable',function()
    local c=D.normalize('b_cry_e_deck',{cry_edeck_ed={bad=true},cry_edeck_sl='deleted'})
    assert(c.cry_edeck_ed=='e_foil' and c.cry_edeck_sl=='Gold' and c.cry_edeck_st=='Spades')
    assert(D.normalize('b_cry_sl_deck',{cry_edeck_sl='random'}).cry_edeck_sl=='random')
end)
test('Antimatter filters incompatible decks and reveals nested choices',function()
    local c=D.normalize('b_cry_antimatter',{cry_antimatter={b_cry_sl_deck=true,locked=true,evil=true}})
    assert(c.cry_antimatter.b_cry_sl_deck and not c.cry_antimatter.locked and not c.cry_antimatter.evil)
    local pages=D.pages('b_cry_antimatter',c);assert(#pages==2 and pages[2].key=='cry_edeck_sl')
    assert(#D.pages('b_cry_antimatter',{cry_antimatter={}})==1)
end)
test('options never mutate native solo setup or input, even when a page fails',function()
    local c={cry_edeck_ed='e_holo'};D.pages('b_cry_e_deck',c)
    assert(SMODS.RunSelect.Setup==original and original.choices.deck_choice=='b_red' and not c.cry_antimatter)
    P.cry_edeck_ed.optional=function() error('unavailable preview') end
    assert(#D.pages('b_cry_e_deck',{})==0 and SMODS.RunSelect.Setup==original)
end)
test('names use native localization and safe Random labels',function()
    assert(D.name('cry_edeck_sl','random')=='Random' and D.name('cry_edeck_ed','e_holo')=='Native e_holo')
end)
test('host choices survive snapshots and fast restart independently of guest preferences',function()
    local m=S.new{intended=1};m.setup_choices=D.normalize('b_cry_e_deck',{cry_edeck_ed='e_holo'})
    local snap=m:snapshot(1);snap.setup_choices.cry_edeck_ed='e_foil';assert(m.setup_choices.cry_edeck_ed=='e_holo')
    m.phase='prepare';assert(m:restart('DECKQA'));assert(m.setup_choices.cry_edeck_ed=='e_holo')
end)
test('a guest profile cannot discard the host Antimatter choices due to missing personal unlocks',function()
    Cryptid.antimatter_compat=function(k,shared) return k~='locked' and shared==true end
    P.cry_antimatter.set_default=function(_,v) local out={};for k in pairs(v or {}) do if Cryptid.antimatter_compat(k) then out[k]=true end end;return out end
    local host={cry_antimatter={b_cry_e_deck=true,b_cry_sl_deck=true},cry_edeck_ed='e_holo'}
    assert(not D.normalize('b_cry_antimatter',host).cry_antimatter.b_cry_e_deck)
    local received=D.normalize('b_cry_antimatter',host,true)
    assert(received.cry_antimatter.b_cry_e_deck and received.cry_antimatter.b_cry_sl_deck and received.cry_edeck_ed=='e_holo')
    assert(#D.pages('b_cry_antimatter',received,true)==2) -- edition optional above deliberately fails
end)
