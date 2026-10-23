BT=SMODS.current_mod
BT.version='0.6.5-dev'
BT.root=BT.path
local function load(path) return assert(SMODS.load_file(path,BT.id))() end
BT.numbers=load('core/numbers.lua')
BT.json=BT.numbers.codec(load('vendor/json.lua'))
BT.Session=load('core/session.lua')
BT.Session.Numbers=BT.numbers
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
BT.Session.Dice.random=love.math.random
BT.steam=load('net/steam.lua')
BT.client=load('net/client.lua')
BT.game=load('game/bridge.lua')
BT.donation=load('game/donations.lua')
BT.pot=load('game/pot.lua')
BT.dice=load('game/dice.lua')
BT.admin=load('game/admin.lua')
BT.bots=load('bots/controller.lua')
BT.ui=load('ui/interface.lua')
function BT.active() return BT.state and BT.state.phase~='lobby' end
function BT.round_won() return BT.active() and BT.state.winner==true end
function BT.notice(message) BT.message=tostring(message); BT.message_time=love.timer.getTime() end
function BT.persist() SMODS.save_mod_config(BT) end
BT.game.install()
BT.donation.install()
BT.pot.install()
BT.dice.install()
BT.ui.install()
-- Install invite callbacks before vanilla's first Steam callback pump.
if not (BT.bots and BT.bots.config) then BT.steam.available() end
local update=love.update
function love.update(dt)
    update(dt)
    BT.client.update(dt)
    BT.game.update(dt)
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
