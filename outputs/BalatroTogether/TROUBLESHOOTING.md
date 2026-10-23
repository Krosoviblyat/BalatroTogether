## Jimbo nil crash during menu/run transitions

Together 0.7 waits for native/Cryptid tutorials and screen wipes before starting or restoring a run. Finish Cryptid onboarding when it appears; Together yields its screen and controls to it. Everyone closes Balatro before updating. A crash from an older build cannot recover an unsaved hand; Continue Saved Party uses the last complete checkpoint.

## Steam invite does nothing

Everyone installs the same 0.7.0-dev build and restarts Balatro. The host opens a Steam table before the run and uses INVITE FRIENDS inside Together. Accept the new game invite rather than an old chat invite or Invite to Watch. Steam must be signed in and the recipient must own/install Balatro with Together in its normal Steam installation. Accepted invites join from the menu; a current party or solo run asks before leaving. If Steam itself does not launch Balatro, open Balatro through Steam, then accept a fresh invite. Share the new six-digit TABLE CODE and enter it in Together's Steam join field. No router forwarding is needed in Steam mode.

# Troubleshooting

## Bot windows or consoles

Update every client to 0.3.3-dev. Bots launch the owned game with `--disable-console` and hide only their own native windows. The private LabHarness is never part of the ZIP or installed mod. Closing the party's host game stops its bots; closing unrelated apps does not. On this PC, the supplied Play Balatro Together shortcut also suppresses Lovely's console for the main game. With Steam, use `--disable-console` in Balatro's launch options if you want to suppress that host console too.

If a bot cannot start, read its separate `together-bots/.../Mods/lovely/log` directory under the host's save identity. A bot's three normal seats need extra native processes and sufficient RAM. Add them before Start Run and wait for Ready. Remove/re-add in the lobby if startup failed; during a run, retire an absent failed seat to continue.

**F8 does nothing / no Mods button:** check Lovely winmm.dll is beside Balatro.exe; Steamodded and BalatroTogether must be immediate child folders of `%AppData%\Balatro\Mods`. Each mod JSON/main.lua must be one level below Mods, not two. Confirm exact pinned loader versions from INSTALL.md.

**The game crashes on startup:** move Together outside Mods, then launch with only Steamodded. Check conflicts and duplicate copies. Lovely logs are in `%AppData%\Balatro\Mods\lovely\log`. Save the first error and stack, mod list and exact versions. Do not post your entire save folder, session reconnect tokens, room PINs or personal network addresses publicly.

**Cannot host / address already in use:** only one host can bind a given port. Close an older host or change the port (1024–65535); friends must use the same port. A failed listener must not be treated as a successful lobby.

**Direct IP cannot connect / timeout:** confirm host is running, address is reachable, PIN is current and every player has exactly 0.3.3-dev. 127.0.0.1 connects only on the same PC. LAN addresses are not public internet addresses. Remote play may need an existing private VPN or manual TCP forwarding; Direct IP does not use Steam relay. The mod does not change firewalls. If your network blocks TCP or uses carrier-grade NAT, ask the network owner for an appropriate reachable connection.

**Steam invite does not appear:** both players need 0.3.3-dev, Steam online, and their own Steam copy of Balatro. Host with Steam Invites selected, wait for the table to finish opening, then click Invite Friends. Enable Steam Overlay globally and for Balatro. Accept while the modded game is open. The host can copy the Steam table link for Join Friends as a fallback. This new path still needs cross-account acceptance testing; report the exact in-game error if it fails.

**Start is refused:** the host's configured player count must equal occupied active seats, every seat must be connected and everyone must be ready. Set intended count before opening the table. No late joins once a run starts.

**Waiting after a huge score:** the host is waiting for accepted actions to finish or a disconnected seat to recover. Never count another scoring animation twice. Wait for their connection. If necessary the host can open F8 and retire a disconnected seat. Current blind difficulty does not decrease after retirement.

**A player used all hands:** they wait for teammates. Individual exhaustion does not cause loss until every active player is exhausted below the target.

**Waiting after shopping:** cash out first, finish buying/packs, then select native Next Round. Each player must return to blind selection and ready for the next shared blind. Close overlays that pause your local game. F8 → Return to Run closes the Together lobby.

**Connection drops:** keep the original game process open. It retries the selected transport using a per-session reconnect token and requests a current snapshot. Shared transitions pause. Closing the game loses local private deck state and cannot be repaired from the shared snapshot. No host migration: if the host exits, restart the session together.

**HUD is too large / blocks a control:** F8 → Settings → reduce HUD scale, move HUD to the other edge, hide panels, or change feed side. Closing inspection restores card-area visibility. 3840×1080 uses height-based scaling rather than stretching.

**Joker details or selected cards are missing:** inspection may be disabled by that player; hands are hidden unless explicitly revealed. Inspection is a compact textual state view, not a second interactive board. See KNOWN_ISSUES.md for remaining visual limitations.


**Only Invite to Watch appears:** 0.3.3 opens its own friend picker from the host Steam lobby's Invite Friends button. Choose a friend there. It sends a lobby invite directly; the ordinary Steam overlay menu is not used. Copy Table Link remains an alternative.

**Stuck in SHOP at the next native blind:** update both clients to 0.3.3-dev. It retries rejected native-entry/shop-exit acknowledgements and recognizes a settled matching post-shop position without depending on sampling one cash-out frame. Ready for Next Blind can confirm your shop completion. All teammates must actually finish their shops/packs. Start a fresh party after updating; updating files does not repair code already loaded in a running game.

**Can't change Player:** use Change Name on your own lobby seat, type a name and Save Name. It updates the same seat on all clients. Everyone needs the new build.
