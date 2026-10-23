# Steam tables — 0.7.0-dev

Everyone installs the same build on Windows x64 and opens their owned Balatro with Steam signed in.

Host: F8 → Host a Table → Steam → Open Table. Share the six-digit TABLE CODE. Friends choose Join Friends → Steam, type those six digits and join. No public IP, PIN or port forwarding is required. Codes are temporary; reopening the table makes a new code, and Change Code invalidates the previous one. Join fields are cleared when opening a fresh join screen and are never saved as preferences.

INVITE FRIENDS opens Together's own friend list. Its Invite button sends a Steam game invite with native lobby fallback. A fresh accepted invite joins directly from an idle menu; a current party or solo run asks before replacement. Steam's ordinary friends menu may still offer Invite to Watch. If Steam does not launch a closed game, open Balatro through Steam and use the table code or accept a fresh game invite. This mod cannot change Valve's app launch configuration.

Codes use exact mod/code filters on public Steam lobbies. Search refuses ambiguous, expired or incompatible tables. The session still verifies Steam identities, capacity and build/settings compatibility. Codes are convenience addresses, not private passwords; share them with your party. Closed/running tables stop accepting new seats. A resumed checkpoint reserves seats for its original Steam accounts.

Use Change Name on your own seat without leaving. Steam persona names stay separate. A guest can edit only their own Together name. Both players Ready Up; the host Start Run. Finish native shops normally before the next blind.

Native two-client save/skip testing uses isolated TCP copies. Cross-account invite delivery, closed-game Steam launch and internet relay behavior still require a second account/device; no unsolicited friend invites are sent during QA. See TEST_RESULTS.md for observed tests and SAVES.md for checkpoint recovery.

API references: [Steam lobby search](https://partner.steamgames.com/doc/api/ISteamMatchmaking#RequestLobbyList), [game invites](https://partner.steamgames.com/doc/api/ISteamFriends#InviteUserToGame), [Steam networking messages](https://partner.steamgames.com/doc/api/ISteamNetworkingMessages). Together uses the game's initialized Steam library and real Balatro App ID. No Steam SDK headers, libraries or game assets are redistributed.
