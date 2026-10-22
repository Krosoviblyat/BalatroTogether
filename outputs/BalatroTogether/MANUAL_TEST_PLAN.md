# Acceptance plan for four friends

Use four separate Windows PCs with licensed Steam Balatro 1.0.1o-FULL, Lovely 0.10.0, Steamodded 26.1002.0 and Together 0.5.0-dev, Cryptid 0.5.17c and Amulet 3.6.1. Match Cryptid rulesets and overrides. Back up saves. Record actual results per machine; a script pass or local same-PC run does not replace this check.

| Gate | Procedure and expected result |
|---|---|
| 1. Loader | Install by INSTALL.md, launch without errors, see Together in Mods. |
| 2. Single player | Without hosting/joining, start a native run; play/discard, buy a joker, complete a blind. No team state or network listener. |
| 3. Menu | F8, mod Config link, and main menu button (where available) open the same UI. Escape closes it without selecting underlying cards. |
| 4–7. Lobby | Host at intended 4; join B, C, D in that order. All clients show all four colored seats with host marked. Wrong PIN/version/fifth join are refused. |
| 8–9. Start | Try Start with an unready player: refused. Ready all and start: same seed, selected party deck, stake and blind on all clients. |
| 10. Simultaneous | A and B select different hands and play together while C discards and D inspects. No turn lock or remote control. |
| 11. Score | Record each native round total and team total. Sum must match exactly; repeated resyncs/reconnects must not add chips twice. |
| 12. Jokers | Obtain different vanilla jokers/editions; verify native effects and own inventory/money remain independent. Test score enhancers, negative slots, rental/perishable where applicable. |
| 13. Bosses | Confirm same boss identity/target; test The Needle, Eye, Mouth, Serpent, Water, Wall, Violet Vessel, Ox and Verdant Leaf. Local disable effects must not disable others' bosses. |
| 14. Shop | Buy/reroll/use packs independently. Leave one player shopping for 30 seconds; the next blind must wait. Finish, then ready everyone. |
| 15. Activity | Inspect feed during selecting, calculation, discard, purchase, consumable, waiting, readiness and reconnect. No guessed actions or repeated score notifications. |
| 16. Inspection | Click all three teammates. Check names, editions/stats, jokers, money, deck suits, hand/discards and shop. Hidden cards absent by default; explicitly reveal one hand and verify it appears. Disable inspection and confirm details disappear. |
| 17. Progression | Complete small, big, boss and transition to ante 2. Repeat with a slow scorer and a slow shopper. No double end-round joker trigger. |
| 18. Disconnect | Interrupt one guest's network mid-hand and mid-shop. Team does not advance while the guest is missing. Native state is not silently reset. |
| 19. Reconnect | Restore network with original game open; original seat and private local build survive; snapshots converge and pending action reports do not duplicate. Close/restart recovery is unsupported. Test host retirement of an absent seat. |
| 20. Complete run | Play a normal unassisted four-PC run to a valid shared victory or defeat; all screens agree. Record team total, best hand and per-player statistics. |
| Fast Restart | Host requests F8 → Fast Restart during scoring, shopping and after defeat/victory. Same seats/settings survive, all private decks reset, everyone shares the new seed, and stale old-run packets do not add score. Guest and disconnected-party attempts are refused. Check Ctrl+R and the native Restart button. |
| Animations | Observe staggered lobby entrances, animated score counts and bursts, feed slides, and panel expansion/closing. Set Reduced motion or intensity 0; motion stops. Resize repeatedly between 1920×1080 and 3840×1080 and confirm all text remains readable. |

Repeat lobby/start/scoring for 1, 2 and 3 players. Run one guest over a reachable internet connection, with ~100–250 ms latency; test a brief outage. In Steam mode, test Invite Friends → accept → Join Friend across distinct accounts and networks without any forwarded port; then test table-link joining, cold launch, wrong versions, loss/reconnect, host exit, simultaneous scoring and a donation. Record actual outcomes. Repeat the Direct IP fallback separately. Check 1280×720, 1920×1080 and 3840×1080, both HUD edges and palettes, reduced motion, feed filters and settings persistence after restart. Check opening/closing inspection never plays or buys an underlying card. Confirm standard game accessibility settings still work.

Release acceptance requires all gates to pass on the actual target setup. Mark skipped gates **UNVERIFIED**, not PASS.

## Bots and customized runs (0.2)

1. At the main menu, verify Together is top-right and Options remains unobstructed at 960×600, 1080p and ultrawide. Open/close both.
2. Host four seats; enter a fixed seed, choose Blue/Checkered/Abandoned/Plasma decks in separate runs. Verify native deck identity and effects on every seat.
3. Add three bots; verify bot labels, automatic readiness, one genuine native simulation per seat and no extra visible game/crash windows.
4. Remove/re-add a bot before start. Mix one bot and two human guests. Confirm full-table/start readiness checks.
5. Play while bots discard/score. Compare native player chips, contribution ledger and exactly-once team totals.
6. Observe real joker purchases, replacements, consumable use and shop exits; no repeated cash-out/leave callbacks.
7. Fast Restart during planning/scoring/shop. Verify all four reset, fixed seed/deck retained and stale actions ignored.
8. Host with blank seed; verify each restart uses a fresh seed.
9. Leave/close host and confirm companion processes exit. Force a host process exit in an isolated test and verify parent-watch cleanup.
10. Benchmark multiple seeds/bosses and build types before claiming general bot strength. No fixture jokers or granted scores in that benchmark.

## Donation Box (0.3)

1. On separate PCs, open F8 → Donation Box while unready at blind selection and in shops. Check all pages, recipient selection, native card art, full/empty box and the Unready to Trade control.
2. Donate a built-up Joker, Perishable/Rental/Foil variants and a Negative card into a full recipient inventory. Verify ability values, exact slot changes and passive effects on both owners. Reject Eternal/debuffed cards and shop stock.
3. Donate Tarot, Planet and Spectral cards; take and use them natively. Full inventories must leave gifts available. Check donor Take Back and addressed-seat restrictions.
4. Click Take concurrently from two PCs. Exactly one receives the card. Interrupt the recipient connection after reservation; reconnect the same open game. Verify one copy and one passive application. Close-process recovery is unsupported.
5. Address a gift to a bot. It should unready, accept, then ready. Public gifts must remain for humans. A full bot must leave the gift in the box. Close/Leave host during a transfer and confirm children exit.
6. Fast Restart with available and reserved gifts: box and local pending state clear, old-run actions cannot deliver to the new run.
7. Observe spring entrances, hover lift/tilt, button squish and transfer flights at small/full-HD/ultrawide sizes. Notices must clear footer buttons. Reduced Motion and intensity zero stop movement. Check prolonged play for callback/resource leaks.


Bet Pot cross-account check: both install 0.3.4, open Bet Pot while unready in the shop/between blinds, bet $5 and $6, win together, verify $13 saved, host split $6 each with $1 retained. Place another bet, lose the blind, verify only that wager burns. Pause/reconnect the recipient during a split and verify one payout. Confirm bot recipients, Reduced Motion, narrow/wide UI, exact-dollar wallet effects, end-screen payout and a fresh empty pot on Fast Restart. Keep the original client process open for reconnect. Install only after leaving the old-version match.

Expansion gate: select Antimatter and special effect decks; verify matching native effects after restart. Earn a wheel spin, compare ordinary spin, successful 32-press Space challenge and timeout. Bet in both tabs; confirm only the host splits team funds and each owner collects only their personal bank. Clear the final ante-eight boss and verify automatic ante-nine play without a blocking victory overlay.
