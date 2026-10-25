BT=SMODS.current_mod
BT.version='0.8.9-dev'
BT.root=BT.path
local function load(path) return assert(SMODS.load_file(path,BT.id))() end
BT.numbers=load('core/numbers.lua')
BT.json=BT.numbers.codec(load('vendor/json.lua'))
BT.Session=load('core/session.lua')
BT.Session.Harbinger=load('core/harbinger.lua')
BT.Session.Harbinger.Strategy=load('bots/strategy.lua')
BT.Session.Numbers=BT.numbers
BT.deck_choices=load('game/deck_choices.lua')
BT.compat=load('game/compat.lua')
BT.compat.install()
BT.Session.Donations=load('core/donations.lua')
BT.Session.Donations.Numbers=BT.numbers
BT.Session.Pot=load('core/pot.lua')
BT.Session.Dice=load('core/dice.lua')
BT.Session.Dice.Physics=load('core/dice_physics.lua')
BT.Session.Dice.Wheel=load('core/boss_wheel.lua')
BT.Session.Dice.QTE=load('core/wheel_qte.lua')
BT.Session.Dice.Boss=load('core/boss_rewards.lua')
BT.Session.Admin=load('core/admin.lua')
BT.Session.Vote=load('core/skip_vote.lua')
BT.Session.Save=load('core/checkpoint.lua')
BT.Session.Dice.random=love.math.random
BT.steam=load('net/steam.lua')
BT.client=load('net/client.lua')
BT.game=load('game/bridge.lua')
BT.donation=load('game/donations.lua')
BT.pot=load('game/pot.lua')
BT.dice=load('game/dice.lua')
BT.admin=load('game/admin.lua')
BT.save=load('game/checkpoint.lua')
BT.bots=load('bots/controller.lua')
BT.ui=load('ui/interface.lua')
BT.diagnostics=load('game/diagnostics.lua')
BT.diagnostics.install()
function BT.active() return BT.state and BT.state.phase~='lobby' end
function BT.round_won() return BT.active() and BT.state.winner==true end
function BT.notice(message) BT.message=tostring(message); BT.message_time=love.timer.getTime() end
-- Joining fields belong to one visit, never to saved player preferences.
BT.config.room_code='';BT.config.steam_lobby='';BT.config.pin=''
function BT.persist()
    local transient={room_code=BT.config.room_code,steam_lobby=BT.config.steam_lobby,pin=BT.config.pin}
    BT.config.room_code='';BT.config.steam_lobby='';BT.config.pin=''
    local ok,err=pcall(SMODS.save_mod_config,BT)
    for key,value in pairs(transient) do BT.config[key]=value end
    if not ok then error(err) end
end
if BT.Session.Harbinger.migrate_config(BT.config) then BT.persist() end
BT.game.install()
BT.donation.install()
BT.pot.install()
BT.dice.install()
BT.save.install()
BT.ui.install()
BT.harbinger=load('game/harbinger.lua')
BT.harbinger.install()
BT.government=load('game/government_man.lua')
BT.government.install()
BT.curated_seed=load('game/thundrck.lua')
BT.curated_seed.install()
-- Install invite callbacks before vanilla's first Steam callback pump.
if not (BT.bots and BT.bots.config) then BT.steam.available() end
local update=love.update
function love.update(dt)
    update(dt)
    BT.client.update(dt)
    BT.game.update(dt)
    BT.save.update(dt)
    BT.donation.update(dt)
    BT.pot.update(dt)
    BT.dice.update(dt)
    BT.admin.update(dt)
    BT.bots.update(dt)
    BT.ui.update(dt)
end
local quit=love.quit
function love.quit(...) BT.client.stop(); BT.steam.shutdown(); if quit then return quit(...) end end
sendInfoMessage('Loaded Balatro Together '..BT.version,'BalatroTogether')
