# Known issues (development)

- The build is not a production release.
- Six-digit codes use Steam public-lobby indexing, not a separately hosted room service. Exact lookup refuses missing or ambiguous results; Steam must be online. Steam mode uses Valve lobbies and reliable Steam networking; Direct IP uses TCP.
- Steam invites/networking are experimental and Windows x64 only. User screenshots show a connected remote Steam player and shared score contributions. Version 0.7.1 repairs the Windows callback vtable used by Steam to deliver accepted invites; native ABI dispatch and menu routing are verified in private game copies. Real cross-account invite acceptance, Steam launching a closed game on another PC and broader internet/relay behavior still need party verification. Avatars are not implemented. Steam must be online; the in-game friend picker does not use the overlay invite menu.
- Host trusts native score results from friends; it does not replay or validate all joker triggers, purchases or card legality remotely.
- No host migration. Closed-process recovery uses the last complete host checkpoint, with original seats and matching native mods/settings; it cannot recover an in-flight hand. See SAVES.md.
- No new players after run start. Saved parties reserve their original identities until restored or retired.
- The supported bundle is Cryptid 0.5.17c + Amulet 3.6.1 with the pinned loaders. Arbitrary additional mods and every Cryptid interaction are unverified. See CRYPTID.md.
- Personal dynamic blind-size changes are normalized to the host's shared target; those effects do not reprice the party target. Co-op progression adaptations are detailed in CRYPTID.md.
- Multiplayer seeded runs do not grant normal unseeded unlocks.
- Majority-voted Small/Big skips are supported. Boss rerolls and individual progression-changing effects remain restricted. Personal ante changes are suppressed; boss cash-out advances one shared ante. See CRYPTID.md for the excluded cards.
- Co-op uses an available vanilla/Cryptid deck, White Stake and a shared schedule with automatic endless after ante eight. Amulet scores must be finite and fit the bounded explicit Omega representation described in CRYPTID.md.
- Fast Restart cancels the whole current run and pending native events, retaining party identities/difficulty with the configured seed, or a fresh random seed when blank. Host only; reconnect or retire absent seats before restarting.
- TCP is unencrypted and intended for trusted parties. Remote build/card legality is not fully validated by the host.
- Teammate inspection is a reported card/shop/effect summary, not a fully interactive mirrored native board. Face-down cards stay redacted.
- Custom menus use desktop mouse/keyboard; controller navigation and other platforms/loader combinations are not certified.
- Four-PC internet play, ordinary unassisted victory and the full boss/joker matrix still need MANUAL_TEST_PLAN.md. The three-player native bot run ended in legitimate defeat; native three-player first-blind success remains unverified.

- Native companion bots require Windows and additional CPU/RAM. They are heuristic: booster drafting, targeted tarots, some advanced joker synergies/ordering and complete boss optimization are not implemented. See BOTS.md.
- All 38 selectable decks passed native start and same-seed restart checks; later balance/content coverage is narrower. Anaglyph receives its native tags when a majority skip passes.

- Donation Box supports owned vanilla/Cryptid Jokers and Tarot/Planet/Spectral/Code consumables while unready in the shop or between blinds. Eternal/debuffed cards, playing cards, vouchers, storage/double-sided cards, temporary Multiply effects and foreign custom content are excluded. See DONATIONS.md.
- In-flight donation delivery still needs the original process; closed-process recovery rolls back the entire party to its last complete checkpoint. Checkpoints wait for transfers to finish. There is no separate durable live escrow. Fast Restart empties the box.
- Receiving a gifted Tarot/Spectral does not make bot targeting more sophisticated; bots use only the consumables supported by their existing strategy. Transfer tests use granted private fixtures and are not balance or eight-ante victory evidence.

- A run already desynchronized in 0.3.0 cannot be repaired by changing files while it is running. Close the game to update, then use a new party run. 0.3.1 adds native entry/shop-exit barriers; all players must update together.


Bet Pot is fictional run currency, with a 37.5% team bonus and 15% personal bonus and whole-dollar rounding. It persists in complete party checkpoints; an unsaved leave or Fast Restart loses the current run. Bots receive splits but never wager automatically. A retired seat's undelivered allocated share is abandoned. Like score reporting, native wallet reporting is trusted in private co-op. Cross-account Steam delivery of the new pot actions has not been observed; native tests use isolated TCP clients.


Reward dice use game-scale approximate rigid body physics, not certified physical dice odds. They reset with the run. Red Mult is additive for each hand of the next blind, and saved red dice may stack before that blind. Bots account for the bonus in hand estimates but do not auto-roll tickets. Gold can be used at victory; red needs an upcoming blind. Only Windows x64 native local TCP delivery has been observed for the new dice actions; cross-account Steam remains a manual check. Celebration Effects and Reduced Motion can reduce animation cost.


Boss Reward Wheel (0.3.6): designed as powerful casual co-op rewards, not balanced competitive play. Each player's prize is personal. Bots save spins instead of using them. Slots have the displayed sector weights, but this is a game RNG, not an audited gambling implementation. Hand levels and refresh credits reset with the run. Native testing uses controlled builds to cover effects, not a statistical balance trial. Wheel delivery across separate Steam accounts still needs human testing.

Owner admin access requires a verified Steam identity. With direct TCP, only the owner hosting locally can be authenticated for admin; claimed remote TCP identities are refused. The native admin test used the real owner plus an unverified same-machine TCP peer. Owner-as-Steam-guest authorization is reducer-tested but still needs a live second account. Account checks do not make editable Lua mods an anti-cheat system.

The Space challenge requires 32 separate presses in five seconds. It is intentionally optional: normal wheel spins remain available. Extremely large endless builds may exceed engine, mod, performance or bounded network-number limits.
