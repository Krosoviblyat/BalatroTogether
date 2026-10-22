# Owner admin panel

Press **/** to open or close the admin panel. It is locked to the owner's verified Steam account registered for this private build, independently of the display name or who hosts the table. Opening it requires Balatro running through Steam. Slash keeps its normal typing behavior while a text field is focused.

On Steam tables, the owner can use the panel as host or guest. On direct TCP, the owner must host: a remote TCP seat cannot establish a verified Steam identity by supplying a name, PIN or claimed account ID. Bots never receive admin access. The host validates every admin action against the transport's trusted seat identity; changing a display name or a status field cannot authorize an action. This is a private-party convenience, not protection against someone modifying their own Lua source.

Select a player at the top, then grant one of:

- $25 or $100 in native cash.
- One gold d6, red d20 or Boss Reward Wheel spin.
- +1 level to every poker hand for this run.
- Three banked free shop refreshes for this run.
- +2 hands, +2 discards, +100 chips per hand or +20 Mult per hand for the next blind.

The recipient must be connected, unready and between blinds, with no unfinished transfer or reward. Grants use the same native delivery receipts as normal rewards, so repeated network messages do not duplicate them. Pending native deliveries hold ready/restart controls. The party feed identifies admin actions.

## Run recovery

**Retry Native Sync** asks every client to retry its native entry/shop acknowledgements and refresh its shared snapshot. Existing native position checks still apply. It preserves scores, hands already played, the native event queue and unresolved transfers. It can help stale waiting requests; a genuine ante/progression mismatch still requires a restart.

**Retire Selected Seat** is enabled only for a disconnected teammate other than seat 1. Confirming removes that seat from this run and releases its participation barrier. The existing donation retirement rules apply.

**Restart Same Seed** first displays a party-wide restart warning. Only **Confirm Restart** sends the command. It starts a fresh run with the same seed/deck and identities, clearing rewards, bets and run progress. Reconnect or retire absent peers and finish pending native reward deliveries first. The normal host's existing Fast Restart remains available separately.

All clients need this same version. A live second Steam account was not available for native admin testing; reducer tests cover owner-as-guest authorization and rejection of other identities. Native testing verified the real owner account, an unverified TCP peer's denied shortcut/forged request, remote grants, synchronization retry and the confirmed native two-client restart.
