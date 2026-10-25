# Government Man — 0.8.6-dev

Native Legendary Joker, base cost $20, starting X2 Mult. Every newly acquired
Negative Joker adds X0.5 to this multiplier. On every second acquisition, a
random owned non-Negative Joker becomes Negative using the native edition/slot
logic. Government Man can be selected. If all Jokers are already Negative,
the multiplier still grows and the conversion has no target.

Acquisitions are local to the owner and occur while Government Man is owned
and active. Shop/pack/generated Jokers and received donations use Steamodded's
native card-added event. Changing an already-owned card's edition does not
count as a pickup. Blueprint copies scoring; it does not duplicate growth.
Existing Negatives are not retroactively counted. Saved and donated copies
retain their exact multiplier and two-pickup progress.

The supplied artwork is registered as a native atlas. Government Man appears
in the Legendary collection and normal Legendary generation (including The
Soul's generation route); he is not added to the ordinary Common shop pool.
Native popups, juice animations and Negative edition effects are used.

All party members must update to gameplay 0.8.6-dev. Native 2-client verification
passed 13 cases including Legendary generation, X2/X2.5/X3/X4 progression,
real slot bonuses, donation replay/rejection, save/restore and actual hand
scoring. Unit regressions also cover Blueprint, retriggers and failed pickups.

Installer and launcher now say: come on in and join the coop fest!
The 0.8.5 game-DLL preflight, public signed updater, backups and running-game
protection remain in place. No live game or save was modified during testing.

# 0.8.2-dev — Saved Runs hub and free pack tags

- Add a paginated Saved Runs hub. Save once per run; later saves replace that
  visible checkpoint. Different parties and fast restarts keep separate entries
  even with the same seed. Legacy archives are grouped by party/run identity.
- Keep one verified fallback per run, never globally prune another run, and
  scan/catalog archives incrementally so the hub remains responsive.
- Let native tag packs open during prepare/skip/shop transitions and let their
  native card choices resolve between blinds. Previously the use_card action
  guard silently consumed the tag without opening its materialized pack.
- Retain the skip barrier until every player's pack is closed and native blind
  selection is settled. Clear obsolete ready flags before pack interactions.
- Cover Spectral/Ethereal, Arcana/Charm, Celestial/Meteor, Standard and Buffoon
  packs plus consecutive pack tags. Do not unlock checkpoint mutation or banned
  individual progression effects. No replacement pack art or generated rewards.

# 0.8.1-dev — Chromatic scoring and in-game credits

- Accept finite signed native hand deltas, including The Chromatic's negative
  Mult hands. Preserve negative score debt and count every hand once; both
  clients return to play. Keep nonfinite/malformed score and blind validation.
- Normalize Cryptid/Amulet ante numbers before sending a host blind proposal.
- Add animated Credits beside Together Options and in the party lobby/mod tab.
- Save local crash reports before the existing crash screen, with version,
  native boss, party round and traceback. A failed report write never replaces
  the crash handler. No tokens, PINs, names or complete saves are serialized.
- Report unsupported scores once per hand instead of spamming each frame.
- Checkpoints remain manual; the original 0.8 Harbinger behavior is retained.

# 0.7.1-dev â€” Steam invitation repair and reward-table polish

- Repair the Windows Steam callback vtable: normal accepted invitations were calling the empty call-result slot. Preserve exact 64-bit IDs and route accepted lobby/rich-presence events from the main menu.
- Add regression checks through the Windows vtable slots, plus a real Steam-dispatched lobby event in the private QA lab.
- Refresh the reward table with native cut-corner panels, separate die previews, spring roll entrances, impact squash and landing rings, a beveled wheel rim, spring pointer ticks and payout stamps. Existing physics and authoritative reward outcomes stay the same.
- Fuck the Table now requires 32 separate Space presses in **five seconds**, timed by the host. Add a tactile Space keycap, press meter and countdown. Reduced Motion remains supported.
- Clearly mark the lobby as **BETA** beside its version.

# 0.7.0-dev â€” saved parties, table codes and skip votes

- Fix Cryptid Jimbo nil crashes by waiting for native tutorials/menu wipes instead of clearing their pending construction events. Native onboarding retains its screen and input.
- Add automatic per-build checkpoints, host Save Checkpoint / Save & Leave, original-seat restoration and an all-player native-load barrier. Preserve previous complete saves on failure.
- Replace pasted lobby links with ephemeral six-digit Steam codes, exact worldwide lookup, collision checks and code rotation. Clear stale joining state and fix stale connecting flags after leaving.
- Add majority human skip voting for Small/Big Blinds, per-client native tags and acknowledgment barriers; no won-blind rewards for skips.
- Rebuild teammate inspection with native joker thumbnails and Build/Deck/Shop tabs, smoother saved-party progress and tactile native-font controls.
- Keep account-authorized admin grants/sync retries quiet. Preserve authorization and exactly-once native receipts.
- Add held Backspace/Delete, UTF-8 cursor/selection, Home/End, Shift+arrows and clipboard shortcuts across Together inputs. Keep Space QTE repeat rules unchanged.
- All players update together. Cross-account Steam acceptance and closed-game launching still need party verification.

# 0.6.5-dev â€” Steam invite handoff

- Send explicit Steam game invites with the lobby connect string; retain ordinary lobby invites as a fallback.
- Recover invites from SteamApps launch parameters, Windows command line and LÃ–VE arguments, including quoted IDs.
- Handle NewUrlLaunchParameters and both running-game invite callbacks. Register before the first vanilla callback pump and retry temporary Steam startup/offline failures.
- Join accepted invites directly from the menu; confirm before replacing a party or solo run. Suppress duplicate in-flight joins and prefer fresh accepted invites over stale startup arguments.
- All party members must update. Real cross-account acceptance and Steam's closed-game launch still require party verification.

# 0.6.1-dev â€” native menu overlap fix

- Hide the Together HUD, feed, inspector and toast while a native deck/run-info/options menu owns the screen.
- Clear cached hit regions and pass native mouse/scroll input through, including the first frame a menu opens.
- Restore the HUD when the native menu closes; explicitly opened Together menus remain available.

# 0.6.0-dev â€” felt-table UI refresh

- Rebuild the home screen around a card fan and a simpler seat/join form.
- Add compact Table/Gifts/Bet Pots/Rewards navigation and remove redundant in-run lobby controls.
- Refine felt colors, typography, secondary buttons, disabled states, spacing and empty donation slots.
- Add staggered panel/card entrances, smooth modal open/close, ready-state springs, subtle card/pot float and cleaner hover/press feedback.
- Fit long titles/names and normalize punctuation supported by the native font.
- Match click bounds to transformed animated controls; remove duplicate button springs.
- Preserve the original gameplay, economy and motion/accessibility settings.

# 0.5.1-dev â€” exact bet amounts

- Type an exact deposit into either personal or team pots, with select-all, paste and Backspace support.
- Keep quick presets and +/- controls; require an explicit Bet click and disable invalid/unaffordable amounts.
- Package the update separately; do not modify a live game.

# 0.5.0-dev â€” endless, jackpot challenge and deck repairs

- Initialize and share native run-selection choices before applying decks, fixing Cryptid Antimatter and special-deck effects.
- Continue automatically beyond the ante-eight boss, preserving builds, rewards and pots.
- Add Fuck the Table: 32 Space presses in eight seconds turns one earned boss spin into a guaranteed jackpot; misses resolve normally.
- Add private personal bets with a 15% bonus and owner-only collection; increase the team bonus from 25% to 37.5%, with host-only equal splitting.
- Add native-font cream lettering, raised pixel borders, shadows, hover sounds/lift, press squish and softer floating panels.
- Bundle the same pinned Lovely, Steamodded, Cryptid and Amulet versions in Setup 4 with reversible upgrade cleanup.

# 0.4.0-dev â€” Cryptid co-op compatibility

- Pin Cryptid 0.5.17c and Amulet 3.6.1; negotiate active mod/ruleset signatures.
- Preserve bounded finite Omega scores and contribution accounting through JSON.
- Wait for Amulet scoring to finish before publishing a hand.
- Offer enabled Cryptid decks and transfer supported Jokers, editions and Code cards.
- Keep shared ante progression through Cryptid bosses; guard individual rewinds/skips.
- Copy Cryptid/Amulet into hidden bot companions and inherit the host ruleset.
- Add spring hover lift, button squish, modal bounce/glow and drifting diamonds.
- Bundle five matched components with reversible old-version cleanup and save backups.

# Changelog

## 0.4.0-dev â€” Boss Reward Wheel and owner admin panel

- Bind `/` to an owner Steam account admin panel, with host-validated grants and native sync/retire/confirmed-restart recovery.
- Award each player a saved wheel spin after every won Boss Blind.
- Add 21 entirely positive prize packages: native cash, hand levels, banked free shop refreshes, and next-blind hands/discards/chips/Mult.
- Draw an original spinning wheel with weighted prize sectors, pointer ticks, rim lights, a gradual slowdown and bouncy reward reveal.
- Publish the complete in-game prize table and preserve existing gold d6/red d20 rewards.
- Protect native reward delivery from duplicate receipts and partial hand-upgrade failures; include wheel chips in bot scoring.

## 0.3.5-dev â€” physical reward dice

- Award one gold d6 and red d20 per player after every two won team blinds.
- Pay $5 per gold pip; apply the red d20 face as additive Mult on every hand in the next blind, expiring at the following blind.
- Add host-simulated cube/icosahedron physics with replayed throws and protected personal reward receipts.
- Draw original gold/red models, dynamic shadows, trails, collision shake, coin/shard bursts, face numbers and spring reward reveals.
- Add Reward Dice HUD/lobby controls, teammate viewing and bot scoring awareness of the active Mult.
- Protect number-texture creation from Steamodded's nil-backbuffer getCanvas wrapper.

## 0.3.4-dev â€” Bet Pot

- Add voluntary in-game dollar bets on the next shared blind, with a rounded-down 25% win bonus.
- Keep saved winnings safe from later losing bets; let the host split them evenly among connected seats and retain whole-dollar remainders.
- Debit native wallets before publishing bets; deduplicate host receipts and cumulative native payouts across retries.
- Hold ready/shop progression until allocated money arrives, and clear the old pot on party restart.
- Add a spring-animated pot, counted winnings, flying coins, hover/press bounce and reduced motion support.
- Preserve Setup 2 automatic backup of old Steamodded/smods and Cryptid installations.

## 0.3.3-dev â€” invite picker, names and waiting recovery

- Send Steam lobby invites from an in-game searchable friend list instead of the overlay invite menu.
- Add own-seat Change Name with host-synchronized names and UTF-8-safe limits.
- Retry rejected native-entry and shop-exit acknowledgements; validate the settled next-blind position directly.
- Add explicit Ready for Next Blind after native shop completion and clear Steam/Direct IP selectors.
- Preserve human Unready-to-Trade behavior and all native shop/entry barriers.


## 0.3.2-dev â€” experimental Steam tables

- Add friends-only Steam lobbies, Invite Friends, invite acceptance and table-link joining.
- Carry game traffic with reliable Steam networking; retain Direct IP as an option.
- Keep bots on a private loopback listener with an automatically allocated port.
- Bind reconnects to Steam identities; reject stale-lobby traffic and fail clearly on host loss.
- Add custom/live-changing six-digit PINs for Direct IP.
- Verify real Steam lobby creation and native bot gameplay; add 13 simulated-service transport regressions. Cross-account invites/internet packets remain unverified.

## 0.3.1-dev â€” native progression barriers

- Wait for every client to acknowledge actual native blind entry before enabling play. A fast teammate cannot finish a blind that another native game has not loaded.
- Require a matching native shop-exit acknowledgement before shared progression. Plain Ready cannot skip native cash-out or shopping.
- Canonicalize native blind slot states before queued selection; check native ante/index when readying. Guard repeated cash-out callbacks.
- Add regressions for delayed entry, premature readiness and stale/wrong native positions.
- Supply a separate double-click Windows installer with pinned Lovely/Steamodded, backups, rollback and a quiet-launch shortcut.

## 0.3.0-dev â€” Donation Box and spring animations

- Add an eight-slot team donation box for owned vanilla Jokers, Tarot, Planet and Spectral cards. Public gifts, addressed gifts and donor recovery are supported.
- Transfer native ability state, editions, stickers and passive effects through host escrow, recipient reservations and acknowledged commits. Block simultaneous claims, full inventories and stale-run requests; preserve same-process reconnect reservations.
- Let bots accept addressed gifts without taking public gifts. Keep parent-process monitoring active during pending donations.
- Add springy screen/card entrances, hover lift/tilt, pressed-button squish, gift-box pulses, curved transfer flights and particles. Respect Reduced Motion and motion intensity.
- Keep donation notices clear of footer controls in small windows. Add native transfer/reconnect/bot verification and 14 donation/motion regressions.
- Retain the 0.2.1 callback-overflow fix and hidden bot lifecycle.

## 0.2.1-dev â€” bot window callback hotfix

- Fix the reported table-overflow crash in bots/process.lua by allocating one persistent EnumWindows callback and reusing its PID buffer.
- Disable JIT tracing for the C-to-Lua callback path.
- Add a 20,000-poll regression that detects the released codeâ€™s repeated callback allocation and verifies PID isolation.
- Stress-test 21,000 actual Windows API calls through LuaJIT, including after garbage collection.


## 0.2.0-dev â€” native bots and run setup

- Add/remove up to three native bot companions in host lobbies. Expected-score play/discard search, purchases, upgrades, vouchers, selected consumables, bounded rerolls and automatic progression.
- Add host seed entry and 15 vanilla party-deck choices; fixed seeds persist through Fast Restart.
- Move Together from the crowded native menu row into a dedicated top-right button.
- Isolate each botâ€™s Mods/logs/save identity; exclude private test harness and unrelated mods.
- Guard native shop transactions against unfinished event queues and repeated cash-out/leave calls.
- Add planner/setup regressions and native companion/deck verification.


## 0.1.0-dev â€” 2026-10-21

- Initial original cooperative testing implementation for up to four simultaneous native clients.
- Host-owned ordered/deduplicated score ledger, scaled targets and shared blind/shop barriers.
- Direct TCP worker transport, private room PINs, bounded messages and transient reconnection snapshots.
- Original lobby, four-seat HUD, shared score meter, activity feed, inspection and team result screen.
- Saved accessibility/privacy settings and optional existing Steam friends overlay/persona integration.
- Animated lobby entrances, score counters/celebrations, sliding inspection and adjustable motion intensity.
- Host Fast Restart button and Ctrl+R; native restart routes to the whole party. Per-run epochs isolate delayed traffic; seats and connection sequence numbers persist.
- Development tests, compatibility research, install/uninstall/troubleshooting and source included.
- Production acceptance remains incomplete; see TEST_RESULTS.md and KNOWN_ISSUES.md.
