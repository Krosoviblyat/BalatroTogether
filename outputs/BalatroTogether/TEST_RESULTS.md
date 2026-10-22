# Test results

## 0.6.1-dev — native menu overlap hotfix — 2026-10-22

151 Lua checks and syntax for all 51 files pass. The added regression forbids any HUD/toast/inspector graphics calls under a native overlay, clears cached hit rectangles and verifies native mouse, release and wheel callbacks bypass stale Together controls. Controls work again after the overlay closes.

Two isolated native clients loaded the hotfix. Deck, Run Info, Options and hand-list menus all hid Together drawing/hit regions; closing each restored the goal HUD and controls. The full deck viewer screenshot was inspected with all deck details visible. An explicitly opened Together pot screen still works above a native overlay, then hides correctly on return to that overlay. See OVERLAY_QA_EVIDENCE.txt. The packaged runtime is checked against source and its installer retains the 23 synthetic upgrade/backup/rollback checks. Live files remain untouched.

## 0.6.0-dev — UI polish — 2026-10-22

All 150 Lua checks and 51 syntax checks pass. Motion checks now include delayed reveal boundaries, bounded overshoot, settling and Reduced Motion. This release changes presentation and input geometry; prior gameplay/deck/endless evidence remains below.

Two isolated native clients verified the real mouse callbacks at rendered control centers. Header navigation reached Table, Gifts, Bet Pots and Rewards. Typed bets of $7 team and $3 personal debited exactly; a gold roll paid its native reward and 32 Space presses produced and delivered the jackpot. Animated and Reduced Motion closes both returned to the run. The final transition timing adjustment was additionally checked through an actual $5 team deposit and recorded page open/navigation/close sequence.

Home, lobby, pots, donations and rewards were visually inspected; reward/pot layouts were checked at 960x600, 1280x800 and 1920x1080. Native PNG sequences record staggered entrances, card float, navigation and dismissal. Dark button text no longer receives a heavy dark shadow; unsupported typographic punctuation renders as native-font equivalents. Disabled states and the five-digit amount remain readable. Tests use private profiles and fixture rewards rather than natural balance. No Steam invite or desktop input was sent, and live files remained untouched. See UI_POLISH_QA_EVIDENCE.txt.

Setup 5 keeps the existing pinned dependencies and reversible upgrade engine. Its payload, archive integrity and 23 synthetic install/backup/rollback scenarios are validated during packaging. Controller navigation, arbitrary extra mods and cross-account Steam remain outside this local UI check.

## 0.5.1-dev — typed pot amounts — 2026-10-22

All 150 Lua checks and syntax for 51 files pass. The existing real-screen regression now covers typing/replacing an amount, switching team/personal tabs, select-all, Backspace, empty/over-limit values, formatted dollar paste, refusing a negative paste and Enter without a deposit.

Two private native clients used the actual pot field and text/key callbacks. Host team $7 and guest team $11 produced an $18 wager; host personal deposits $3 and $2 produced a $5 personal wager. Starting from $14 each, native wallets ended at $2/$3. The over-limit $10,001 and unaffordable $5 buttons were disabled. Enter finished editing without spending. Layouts with the maximum five-digit amount were inspected at 960x600 and 1280x800. See TYPED_POT_QA_EVIDENCE.txt. No live installation or desktop keyboard/mouse was changed.

The separate patch installer keeps the same pinned loaders/dependencies and backup engine. Its embedded payload, extraction checks and 23 synthetic installer scenarios are validated during packaging. Earlier full expansion/deck/endless evidence below is unchanged; these checks focus on the amount-entry change.

## 0.5.0-dev — deck repairs and endless expansion — 2026-10-22

- 150 Lua checks pass; all 51 Lua files compile under LuaJIT/Lua 5.1. Added personal/team accounting, ownership/privacy, retry/restart, 48-blind default endless, QTE success/timeout/repeat/rate/ownership and forced-pointer regressions. A native completion regression covers suppressing victory before queued round evaluation.
- All 38 selectable decks passed initial native start and same-seed restart: 76 initializations. Edition, Enhancement, Suit and Seal decks applied their selected starting effects; Antimatter initialized without the reported missing-choice crash. Details: DECK_QA_EVIDENCE.txt. This does not certify every later deck/card interaction.
- Two isolated native clients earned actual wheel spins. Real captured key callbacks ignored auto-repeat and counted a held key once. Thirty-two distinct presses produced slot 100 and exactly $100 native cash; the peer timed out and received its normal slot 61 reward. Both completed native reward delivery.
- Native team bets of $8 each saved $22; personal bets of $10/$20 saved $11/$23. Each owner collected only their own bank; the host split $11 per player from the team bank. Actual wallet increments were $22/$34, with no duplicate delivery. A guest snapshot omitted the other personal ledger.
- The pair then played an actual native ante-eight final boss from a controlled QA jump, cashed out normally and entered ante nine with G.GAME.won true, native/shared ante matching and no victory overlay. This tests the transition rather than a natural full eight-ante run. The fixture uses 12 Cavendish per client; it is not a balance test. Details: EXPANSION_QA_EVIDENCE.txt.
- Setup 4 retains the pinned five-component bundle and reversible cleanup. All 23 synthetic installer scenarios passed; archive hashes/CRC/extraction and an isolated launch from its exact payload were checked. No live install, Steam lobby or user input takeover occurred.

An initial native test exposed a second adapter completion path that bypassed the endless preparation. Both paths now share the same preparation before native end_round. Another early QTE rate check rejected valid batched presses; an accumulated host allowance now tolerates network batching. The final native pair was rerun after both fixes. Cross-account Steam behavior, unrestricted extra mods, later Cryptid combinations and extreme endless builds remain outside this evidence.

## 0.4.0-dev Cryptid compatibility — 2026-10-22

- 140 Lua checks pass; 49 Lua files compile under LuaJIT/Lua 5.1. Fourteen integration regressions use the real pinned Amulet Omega backend: huge-score JSON, malformed payloads, contribution accounting, donation state, plain graphics ratios, scoring coroutines, content/ruleset signatures, deck registration, co-op ante rules and hidden-bot prompts. Existing admin/dice/pot/Steam/progression checks remain green.
- Two real local TCP clients loaded Cryptid 0.5.17c and Amulet 3.6.1. They won four blinds, including Cryptid's Joke boss, and reached native/shared ante two without a progression mismatch. A real Cryptid M Joker with QA-granted x_mult=1e1000 and Mosaic edition transferred from host to guest; a Code Multiply card also transferred. The next hand produced a shared score approximately 1.435e1008, with identical snapshots, summed contributions and both native contribution comparisons matching. This is a transfer/arithmetic/progression fixture, not an ordinary balanced victory: each client had 12 granted Cavendish Jokers and a forced boss identity.
- The native Boss Reward Wheel jackpot delivered cash, every hand level and refresh/next-blind effects under Cryptid. The fixed reward seed exercises delivery, not random reward fairness.
- One hidden companion on the native Cryptid Misprint Deck completed two blinds alongside a controlled host, scored 6,092 chips in two hands without granted bot Jokers, discarded, bought Jokers and exited shops. It inherited Mainline rules, had zero visible game/console windows and exited on host Leave. The test found and fixed fresh-profile Cryptid onboarding and ordinary Blue Deck unlock notices that otherwise waited for input.
- All 23 enabled Cryptid decks were listed in the native selector. Runtime deck/gameplay coverage is narrower than this registration list; every deck and effect is not certified.
- Native UI layouts were inspected at 960x600, 1280x800 and 1920x1080. A 50-frame native capture demonstrates modal spring motion and drifting diamonds. Huge scores remained readable and graphics calls received ordinary numeric coordinates.
- Installer: 23 synthetic scenarios pass with all four Mods components plus Lovely. Verified old/repeated/renamed/nested Cryptid, Steamodded, Amulet and standalone Talisman replacement; preserved saves/unrelated libraries; original-game refusal; deliberate rollback failures; archive and legacy-script cleanup; shortcut creation. The installer UI was rendered and inspected. No live install was performed during this task.

Native tests use isolated owned-game copies and save identities on one PC/account. The human preview is a separate visible window; companion processes are hidden. No keyboard focus/input was taken over. Final scope/limits are in CRYPTID.md. Cross-account Steam internet delivery, every Cryptid effect, all extra mods, ordinary eight-ante balance/victory, and admin elevation on every Windows configuration remain unverified.

## Historical 0.3.6-dev owner admin panel

126 Lua checks pass and 46 Lua files compile. Eight admin cases verify identity rather than host/name/status claims, owner guest authority, denied bot/forged requests, preset grants and delivery barriers, action deduplication, phase/target restrictions, recovery without bypassing entry/shop checks, retirement restrictions, same-seed restart acknowledgements and stale-run rejection, native retry latch boundaries, and `/` behavior including text-input exceptions.

Two real isolated native TCP clients verified the owner's actual Steam ID and successful slash toggle. The unverified peer could neither open the panel nor execute a forged admin grant. Owner UI buttons delivered $100 and +1 level to every native hand to the peer, awarded a saved wheel spin and queued +20 Mult. Retry reached both clients without advancing their blind. The restart button first displayed confirmation and left the run unchanged; Confirm Restart rebuilt both native games with the original seed, cleared run rewards and retained slash access. No game/harness errors occurred. Panel/confirmation layouts were inspected at 960x600 and 1920x1080; an overflowing hand-level label was shortened and the native test repeated. Both processes use the same machine's Steam account, so the peer was deliberately an unverified TCP seat; this is not a claim of live second-account Steam admin testing. The final installer reruns its 20 synthetic backup/rollback cases.


## Historical 0.3.6-dev Boss Reward Wheel

The wheel-only checkpoint passed 118 Lua checks across 42 Lua files; the combined build above passes 126 checks across 46 files. Eight added regressions cover the 100 positive outcome slots and copy-safe prize catalog, once-per-boss personal spin awards, deterministic slowing wheel trajectories and final pointer agreement across 1,600 seeds (covering all 100 slots), ownership/deduplication and native-effect receipts, temporary effect activation/expiry, partial hand-level delivery, one-time hands/discards/chips/Mult, and banked rerolls preserving native freebies and paid reroll prices. Existing gold/red physics, Steam, donation, Pot and progression regressions remain green.

Two isolated native TCP clients completed five controlled-fixture blinds. Winning the real first Boss Blind awarded both a spin and preserved the d6/d20 pair from win 2. Fixed wheel seed 147 intentionally exercised slot 100: both players received $100, +3 levels to every native poker hand and six free refreshes. A withheld guest effect receipt did not duplicate levels or refresh credits. One actual native shop refresh consumed one credit without spending money. On blind 4, native scoring received +400 chips and +100 Mult, with +3 hands and +3 discards applied once; all temporary fields were zero on blind 5 while the hand levels and remaining refreshes persisted. No game/harness errors occurred. The fixture uses 12 Cavendish per player and a declared jackpot seed, proving reward delivery/progression rather than normal-build balance or natural jackpot frequency. Host preview was visible; peer was hidden. Screens inspected at 960x600 and 1920x1080, with spin animation frames recorded.

The user changed the proposed d100 to a wheel during development. The final build contains the original weighted wheel, not percentile dice. A compact prize table and separate pointer/title spacing were checked visually. The installed game remains 0.3.5-dev and Balatro.exe's original fingerprint is unchanged. This task did not install the new build, edit live game files or create a Steam lobby. Separate-account Steam wheel delivery still needs human testing. The installer uses the existing backup/rollback engine; its 20 synthetic cases are rerun during this package build.


## 0.3.5-dev reward dice

110 Lua checks pass and 40 Lua files compile. Sixteen new cases cover the every-two-wins award and deduplication, gold/red ownership and rewards, next-blind activation/expiry, action replay, invalid states, payout/restart barriers, reconnect ownership, bounded unsettled-throw retries, deterministic cube/icosahedron trajectories across 480 seeds (including every possible face), native payout retries, reduced motion, disconnect/spending locks, native Mult injection, restart isolation and the loader's nil-backbuffer canvas wrapper.

Two native TCP clients completed four controlled-fixture blinds and earned pairs after wins 2 and 4. The host preview was visible at the user's explicit request; the peer remained hidden. Gold face 4 delivered exactly $20. Red face 13 changed a real native Two Pair scoring input from Mult 2 to 15 on blind 3; active reward Mult was 0 on blind 4. A withheld guest payout receipt retried without duplicating native dollars. Final clients had no game/harness errors. The fixture used 12 Cavendish per player, so this proves mechanics/progression rather than ordinary balance. Screens were inspected at 960x600 and 1920x1080, and native roll frames were recorded.

The initial preview crashed when Steamodded's getCanvas wrapper dereferenced a nil backbuffer during d20 number-texture creation. A local protected canvas query fixes it without altering the loader; a render regression simulates that exact failure. Earlier private controller attempts also needed to wait for real cash-out buttons and tolerate partial state JSON reads. The final native run continued successfully after a controller-only partial-read exception; its original game processes were retained and audited through round 4. Installed/live game files, user saves and Steam lobbies were not modified. New dice actions still need cross-account Steam testing. The dice art and physics are original; Dice A Million was consulted only as a stylistic reference, with no imported assets.


## 0.3.4-dev Bet Pot

94 Lua regressions pass; 33 Lua files compile under LuaJIT/Lua 5.1. Eighteen new cases cover rounded pooled bonuses, protected winnings after a loss, action/transaction replay, illegal/nonfinite/poor bets, host-only equal splits, connected-seat selection and remainders, pending-payout progression/restart barriers, reconnect receipts, stale-run isolation, shop wagers, bounded volume, 120-round currency conservation, native debit/refund/delivery, delayed acknowledgements, completed paused results overlays, restart isolation and actual UI rendering with editable amounts/reduced motion.

Two real hidden native game copies with separate profiles used TCP and Yellow Deck. Actual UI bets of $5 and $6 reduced wallets from [14,14] to [9,8]. A controlled native shared win saved $13 ($11 stake + $2 rounded bonus). The host split $6 each, retaining $1; native wallets became [15,14]. Suppressing the guest payout receipt caused retries with no duplicate dollars. Both players then bet $1 from their actual native shops and completed the second shared blind. A private command moved the completed native games into their real game-over menus; the remaining bank split delivered through the paused results overlays. An actual party restart restored the selected deck's $14 wallets and an empty pot. No game or harness errors occurred in the final run. The progression fixture used 12 Cavendish per player and is not a balance/strategy claim. Screens were inspected at 960x600 and 1920x1080. No Steam lobby, invite or installed/live game was modified. Cross-account Steam delivery of the new pot actions still needs human testing.

An initial native UI run exposed a bet-amount/opening-animation name collision. It was fixed before final testing, and the actual screen factory now has a render regression. UI tests also exposed a footer/toast overlap, corrected by moving the footer controls. Installer validation is separate: 20 synthetic setup/backup/rollback tests pass for the bundled Setup 2 installer.


## 0.3.3-dev regression candidate

76 Lua tests pass and 28 Lua files compile. Added six real-adapter/real-session handshake regressions for missed cash-out sampling, rejected/delayed shop completion, manual ready after Unready, invalid native positions and rejected entry retry. Five additional Steam/name cases cover direct friend targeting without overlay use, invite refusal/cooldown, same-seat rename synchronization and UTF-8 limits. Two native human-adapter clients completed seven controlled-fixture blinds with matching score ledgers, after deliberate first-entry and first-shop-exit rejections on each client. Both crossed Ante 1 and Ante 2 without harness/game errors. Host and guest names were edited through the actual UI and synchronized. Read-only Steam friend enumeration succeeded; friend-picker screens used anonymized list fixtures and no invitations were sent. The initial four-round polling wait was only 60 seconds and expired before the fourth round finished; the same running pair continued and was subsequently audited without restarting. Native results are recorded in QA_EVIDENCE.txt. A user screenshot confirms two Steam seats connected under 0.3.2, but the new direct invite API still needs an observed receipt/acceptance test. The developer did not send test invitations to friends.


## 0.3.2-dev experimental Steam transport

65 Lua regressions pass; 27 Lua runtime/test files compile under LuaJIT/Lua 5.1. Thirteen new cases execute the real transport and client/session modules against a simulated native Steam service: four identities, no-PIN join, seeded start, outsider/stale-room rejection, reconnect/identity binding, malformed links, disabled overlay, explicit invite consent, owner loss, version refusal, cancelled creation cleanup and nonblocking timeout. The eight PIN regressions also pass.

On the real installed Steam library in an isolated hidden game, a friends-only lobby was created, metadata round-tripped, and membership/leave completed. A final Steam-mode host opened its lobby, accepted one hidden native bot through its loopback ephemeral listener and completed the first native blind (target 635, team 984) with zero game log errors. The actual Steam callback pump ran throughout. A later private probe sent and received one same-account Steam message and invoked the retained callback ABI 10,000 times plus one presence callback without overflow. The SDK emitted a nonfatal pipe-unlink assertion during that self-send probe; it is not cross-account/relay evidence. Host, join and lobby UI were captured at 960×600 and 1920×1080 and inspected. This is host/API and local bot evidence; it does not demonstrate a second Steam account or internet relay traffic.

**Not yet verified:** a friend receiving/accepting an actual invite, cold-launch invites, reliable packets between distinct Steam accounts, NAT/relay paths or an entire Steam multiplayer run. These require a second licensed account/device. This release is explicitly an experimental candidate for that test. Earlier sections below are historical checks.

## 0.3.1-dev progression handshake

The reported screenshot showed shared Ante 4 against native Ante 3. The adapter previously allowed shared scoring before every client acknowledged native entry and treated ready at blind selection as sufficient shop completion. The updated handshake adds native entry and shop-exit barriers, matches native positions when readying, canonicalizes blind slot states and prevents repeated cash-out. Two new state regressions pass, bringing the Lua suite to 44 tests / 24 syntax-checked files. Two native clients completed all 24 fixture blinds with 46 matching pre-cashout ledger audits and zero harness errors. This candidate preceded the final cash-out wrapper, which received its own unit regression and a final four-client donation/entry run. The final four-client check also verified donations, reconnect and native Tarot use. Thirteen installer scenarios passed against synthetic temporary game/profile fixtures, and its UI was rendered for inspection. Native verification and installer checks are recorded in QA_EVIDENCE.txt; fixture progression is not ordinary balance evidence. An already desynchronized live run requires party restart after updating. The developer did not modify or terminate the user's running game.

## 0.3.0-dev Donation Box and animations

- All 41 LuaJIT/Lua 5.1 tests pass; 24 Lua runtime/test files compile. Fourteen new regressions cover bounded card state, duplicate deposits, competing claims, recipient-only payloads, idempotent commit, reconnect/cancel/retire, targeting, capacity/readiness, stale-run reset, spring stability/reduced motion, and native reconstruction rollback/Negative slot accounting.
- Four real native clients: the donor lost ownership before publication; two competing claims produced one Green Joker. Mult 17, Foil, Perishable tally 3 and Rental survived. Eternal donation was refused. A full consumable inventory could not take a gift.
- A Negative Juggler entered a full five-Joker inventory: six cards and six slots after delivery. The donor's hand size fell from 9 to 8 and recipient's grew from 8 to 9. Native testing caught and fixed Steamodded's edition-slot bonus being applied twice.
- A real TCP disconnect during a held reservation retained the gift. The original token/process reconnected and received exactly one Hermit. Its actual native use doubled money from 4 to 8 after the queued effect settled. The final complete rerun passed with zero native errors.
- Additional native Planet (Jupiter) and Spectral (Aura) deliveries reconstructed the correct consumables. One actual bot left a public Jupiter untouched, automatically unreadied/received/readied for addressed Foil Green Joker and Hermit, used the Hermit natively, and scored enough to clear the two-seat first blind. No test or bot windows were visible; host Leave stopped the child. No bot log errors.
- Native UI inspected at 960×600, 1920×1080 and 3840×1080. Captured five entry and six confirmed-transfer frames, plus Reduced Motion. Card art, locked Eternal state, box counts, paging and transfer flight rendered correctly. Small-window notifications were moved below footer controls and rechecked at 960×600 and 1920×1080.
- Final installed-original-game launch loaded 0.3.0-dev with zero runtime log errors, no private harness, one visible native game window and zero console windows. The original executable digest is unchanged; installed files match the verified final ZIP.
- Four-client party restart cleared the escrow and native inventories before the subsequent UI fixture. The unit suite also rejects old-run transfers.

Transfer/animation tests granted specific cards in the private lab. The bot's donated-build first-blind success is not an ordinary bot-strength benchmark. Earlier harness command-file reads raced non-atomic writes and one Tarot assertion sampled before the queued money effect; the instrumentation now writes commands atomically and waits for settled effects. No private harness, granted-card code or game assets are packaged. Older gameplay and callback stress records below are historical evidence, not a newly repeated full progression run.


## 0.2.1-dev callback-overflow hotfix

- The released 0.2.0 window polling path created a fresh LuaJIT callback every update. The user's table-overflow crash pointed to that allocation. Short earlier bot checks did not establish safe callback lifetime.
- Replaced per-frame casts/frees with one persistent EnumWindows callback and PID buffer. Kept the C-to-Lua path outside JIT traces.
- The regression detects repeated allocation in released 0.2 code; 20,000 simulated polls use one callback and hide only current target PIDs. All 27 tests pass; 18 Lua source/test files compile under LuaJIT/Lua 5.1.
- Actual Windows API stress: 21,000 EnumWindows calls through LuaJIT FFI, including calls after garbage collection, with no overflow. PID zero was used so the stress run never hid desktop windows.
- Final native hotfix check: three bots added through the lobby buttons, first-blind success, party Fast Restart, four clean fixed-seed Blue decks/zero scores and builds, zero bot log errors, zero visible bot game/console windows during play and after restart, and all three child processes exited on host Leave.

The older 0.2 and 0.1 records below remain historical evidence; they did not catch this resource-lifetime defect.


## 0.2.0-dev bots, setup and menu changes

- 26 Lua tests pass: 15 base invariants, one native event-boundary regression, ten bot/setup regressions. Syntax checked for 17 Lua files including tests.
- Native normal-build bot candidate: one old baseline test player plus three companions automatically launched by the shipped manager. Blue Deck, fixed seed BOTTEST1, no score grants or fixture jokers. Cleared ten blinds, coherent defeat on blind eleven. Each bot earned 44,932 lifetime chips in 29 hands; baseline player earned 4,388 in 42 hands. Ten host ledger audits matched. Three native bot logs contained zero errors after the shop event-queue fix.
- That run exercised 87 bot plays, 72 discards, 30 purchases, three vouchers, nine consumable uses, three sales, fifteen rerolls and thirty shop exits. All three bots began with the same seeded deck and can make the same decisions; this is not a multi-seed strength benchmark.
- First blind comparison: each new bot scored 504 in two hands; old rank-first baseline scored 281 in three. This is a specific reproducible comparison, not proof of optimal play.
- Final 0.2 native deck matrix: all fifteen selected deck identities and fixed seed matched native start_run across fourteen restarts. Verified Red extra discard, Blue extra hand, Black reduced hands, Abandoned 40 cards/no faces, Checkered only Spades/Hearts and Plasma double target scaling. Full eight-ante gameplay on every deck is not certified.
- Companion initialization now uses separate Mods/log/save directories containing only Steamodded/Together. An earlier private harness nil-folder crash and a shared Lovely dump-directory race were test setup failures; those paths were removed from companions. A native premature-shop-exit callback failure was fixed by waiting for native event queues and guarding one-shot cash-out/leave transactions.

- Final 0.2 native companion gate: three Add Bot UI callbacks, native first-blind success, host Fast Restart, four fresh Blue decks/zero scores and builds, same fixed seed, zero child log errors, zero visible bot game/console windows during play and after restart. Host Leave stopped all three child processes. Native Together → Host callbacks verified; seed/deck setup inspected at 960×600 and 1920×1080.

- Installed final 0.2 ZIP on this PC and launched the original game with --disable-console: Together load marker present, no log errors or private harness, exactly one visible native game window and zero console windows. Installed files match the final archive; original executable SHA256 unchanged.

Bot estimates cover many common vanilla interactions but are heuristic. No ordinary eight-ante bot victory, every boss/joker combination, other platforms or four-PC internet certification is claimed. BOTS.md documents decision strategy and remaining gaps. Current metrics are in QA_EVIDENCE.txt; the historical foundation checks below predate this feature work.

## Historical 0.1 foundation checks



Date: 2026-10-21. Build: 0.1.0-dev. Windows x64; Steam Balatro 1.0.1o-FULL; LÖVE 11.5; Lovely 0.10.0; Steamodded 26.1002.0. Native tests used private copies and isolated save identities on one PC/account. No game source or private harness is shipped.

| Check | Observed result |
| --- | --- |
| Pure session/layout/framing | 15 tests pass, including 150 randomized scenarios, 24 simulated blinds, all seat counts, privacy, reconnect, duplicates and restart epochs. |
| Native event regression | 1 test passes; contributions captured after queued native scoring/easing. |
| Syntax | 13 runtime Lua files checked under LuaJIT/Lua 5.1. |
| Four native clients, controlled progression | All four reached victory after 24 blinds/eight antes; 92 pre-cashout ledger audits, zero mismatches; 24 hands per seat. Fixture grants 12 Cavendish jokers per client: this is not a normal balanced victory. |
| Four native clients, normal starting builds | All agreed on defeat at ante 1 boss The Manacle, round 3; team lifetime score 6,640. Seven pre-cashout ledger audits, zero mismatches; one discard and two purchase requests exercised. |
| Transport chaos | Guest four had 80 ms delay each direction. One busy acknowledgement dropped and connection cut; reconnect succeeded (two connections). Nine duplicate score frames were not double counted. |
| Native 1/2-player gates | First blind succeeded at targets 300/635; one/two score audits, zero mismatches. |
| Native 3-player gate | All three reached coherent first-blind defeat: target 983, score 576, four hands each. Success-only controller timed out on legitimate defeat; three-player native first-blind victory remains unverified. |
| Ordinary single player | Without a Together session, native blind completed at score 360; no network state. |
| Four-client Fast Restart | Two host restarts, during a hand and from shop/defeat. Eight fresh-deck audits: 52 cards, zero score/jokers, matching seed per epoch. Old-run score 999,999,999 ignored; guest restart refused. |
| Actual TCP negative checks | Wrong PIN, wrong version, late/fifth join, malformed JSON, oversized frame and deep nesting rejected; no snapshots sent to unauthenticated peers. |
| Native visuals | Custom menus, four-seat HUD, inspector, results, restart and animation settings inspected. 1920×1080 and 3840×1080 captures plus smaller-window checks. Static captures cannot prove every animation path. |
| Steam | Runtime Lua bindings expose overlay/persona helpers, no lobby/invite API. Native DLL exports exist; an additional bridge is possible but unimplemented. |
| Installed game smoke check | Real Mods installation loaded Steamodded 26.1002.0 and Together 0.1.0-dev in a normal original-game launch; process remained running. No private LabHarness. Original executable digest unchanged. |
| Packaging | Builder checks required files, vendor digest, prohibited game/binary payloads, CRC, safe paths, loader entry points and byte-identical clean Mods extraction. |

The controlled 24-blind run preceded final restart/UI refinements; those received separate restart, visual and pure regression checks. The restart screenshot controller initially raced PNG creation after gameplay assertions passed; capture synchronization was corrected separately. No harness errors occurred in the controlled progression or normal-build chaos runs.

Not verified: four separate PCs/accounts, internet/NAT combinations, Steam invites, ordinary unassisted eight-ante victory, every boss/joker combination, controller custom menus or content/big-number mods. See MANUAL_TEST_PLAN.md. Sanitized metrics are in QA_EVIDENCE.txt; private raw logs and owned game copies remain outside this distribution.
