# Steam tables — 0.4.0-dev experimental

Everyone installs this same build on Windows x64 and opens their owned Balatro with Steam signed in.

Host: F8 → Host a Table → select Steam → Open Table → Invite Friends. **An in-game friend list opens.** Find your friend and click the Invite button beside their name. Steam's ordinary friends menu may still show only Invite to Watch; use the mod's list instead. This calls Steam's lobby-invite API directly and reports if Steam refuses the request.

The friend accepts the Steam lobby invitation, then confirms Join Friend in Together. Both players Ready Up; the host Start Run. No public IP, PIN or forwarding is required in Steam mode. Copy Table Link remains a fallback: paste it into F8 → Join Friends with Steam selected. Select the Steam button explicitly; clicking it again keeps Steam selected.

Use Change Name on your own seat to edit your display name without leaving. The host shares it with everyone. Steam persona names stay separate. Between blinds, Ready for Next Blind can confirm a completed native shop; it cannot skip an unfinished shop, pack or wrong native position.

Invites are available to the host before the run starts. Already-present friends cannot be invited twice, repeated invitations have a short cooldown, and a full intended party must free a seat or create a larger table. There is no late join, durable reconnect after closing the game, or host migration.

Read-only native friend enumeration and the friend picker UI have been checked locally. A user screenshot shows a second named Steam player connected to a real Steam table in 0.3.2. The old overlay invite menu failed for that user. **Receipt/acceptance of the new direct lobby invite has not yet been observed across accounts.** Simulated-service tests check the target ID, cooldown and refusal behavior; no unsolicited test invites were sent. Native progression verification uses two isolated TCP clients so it does not replace the user's currently active Steam lobby.

API references: [InviteUserToLobby](https://partner.steamgames.com/doc/api/ISteamMatchmaking#InviteUserToLobby), [friend enumeration](https://partner.steamgames.com/doc/api/ISteamFriends#GetFriendCount), [Steam networking messages](https://partner.steamgames.com/doc/api/ISteamNetworkingMessages). The mod uses the game's initialized Steam library and real Balatro App ID. No Steam binaries, SDK headers or game files are redistributed.
