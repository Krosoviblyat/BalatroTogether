local A={last_recovery=0}
function A.allowed()
    if os.getenv('BT_BOT_ID') then return false end
    local identity=BT.steam.available()
    if type(identity)~='table' or identity.id~=BT.Session.Admin.OWNER then return false end
    local p=BT.state and BT.client.id and BT.state.players[tostring(BT.client.id)]
    return not BT.state or (p and p.steam_id==identity.id and not p.bot) or false
end
function A.toggle()
    if not A.allowed() then BT.notice('Admin access is locked to the owner Steam account. Open through Steam.'); return end
    if BT.ui.screen=='admin' then BT.ui.screen=nil else BT.ui.screen='admin' end
    BT.ui.focus=nil
end
function A.action(kind,data)
    if not A.allowed() then return end
    return BT.client.action(kind,data or {})
end
function A.update()
    local s=BT.state
    if not s then A.run=nil; A.last_recovery=0; return end
    if A.run~=s.run_id then A.run=s.run_id; A.last_recovery=0 end
    if (s.admin_recovery or 0)<=A.last_recovery or not BT.game.started or not BT.pot.settled()
        or BT.dice.busy() or BT.pot.busy() or BT.donation.busy() then return end
    A.last_recovery=s.admin_recovery
    BT.game.entry_pending=nil; BT.game.entry_sent_at=-10
    BT.game.shop_pending=nil; BT.game.shop_sent_at=-10; BT.game.shopready=nil
    BT.game.finish_shop(true)
    if BT.client.resync then BT.client.resync() end
    BT.notice('Admin requested a native synchronization retry.')
end
return A
