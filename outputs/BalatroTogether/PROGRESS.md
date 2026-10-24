# Progress

2026-10-22: Version 0.5.0-dev is implemented and ready for development testing. Runtime, original UI, party Fast Restart, tests, documentation and reproducible ZIP builder are complete. See TEST_RESULTS.md and KNOWN_ISSUES.md for actual verification and limits.

Installed game: Windows Steam Balatro 1.0.1o-FULL. Development used private workspace copies and isolated profiles. Lovely v0.10.0 and Steamodded 26.1002.0 (af0fdb1eb2c9e191262c128bc88bbc4da991e12d) were installed on this PC after backing up the original game and profiles. Original Balatro.exe remains unchanged.

Research: coop-anything AGENTS/playbooks/MCP configuration read. Its MCP is a read-only research server, not game networking. Balatro Multiplayer (GPLv3) and MultiplayerAPI (GPLv3) evaluated. The former assumes two seats throughout; the latter depends on an authenticated MQTT/API service. A standalone original TCP implementation was selected for reproducible local testing. No upstream multiplayer source or assets copied.

Complete: four-seat reducer, threaded TCP transport, acknowledgements/reconnect, native game bridge, shared progression, privacy controls, animated lobby/HUD/inspection/feed/results, host Fast Restart and run-epoch rejection of stale messages.

Four real local clients completed a controlled 24-blind fixture; a separate normal-build run reached coherent defeat under delay, duplicate frames and a lost acknowledgement/connection cut. Two party restarts passed eight fresh-deck audits. These are same-PC tests, not four-PC internet certification. The full progression fixture preceded final restart/UI refinements, which received separate regression/restart/visual checks.

Next gate: run MANUAL_TEST_PLAN.md across four PCs/accounts. Steam invitations and reliable messaging are implemented; cross-account acceptance/relay validation remains outstanding. No production certification or public publication is claimed. The mod-only ZIP includes no game files or loader binaries; the outer full installer separately includes the redistributable dependency bundle.

0.2 checkpoint: native bot strategy, hidden process lifecycle and isolated Mods caches implemented; host seed/deck setup and dedicated top-right Together menu button implemented. The first native bot test found a private harness/shared Lovely directory issue; companions now copy only required mods into separate directories. A subsequent native shop callback race led to explicit queue-settling and one-shot transaction guards. See new verification below TEST_RESULTS.md; older controlled/chaos results are historical 0.1 evidence.

Final 0.2 gates passed: all 15 native deck/seed starts, 26 Lua tests, visible-window count zero for all three active/restarted bots, native first-blind success, four clean fixed-seed Blue decks after Fast Restart, and all companion PIDs exited on host Leave. The long no-fixture candidate cleared ten blinds and lost on eleven. No complete eight-ante bot victory or four-PC certification is claimed.

0.2.1: fixed the user-reported bot-window table-overflow crash with one persistent Windows callback instead of per-frame allocation. Added a resource-lifetime regression and real Windows LuaJIT stress verification. Other 0.2 gameplay/setup features remain.

0.3 checkpoint: Donation Box, bounded host escrow, recipient-only payloads, addressed bot gifts and bouncy spring/flight UI are implemented. Four real clients verified competing claims, native stats/editions/stickers, Negative slots, passive effects, a reserved TCP reconnect and donated Tarot use. Planet/Spectral reconstruction and an actual bot receiving/using gifts also passed. Motion/layout inspected at 960×600, 1920×1080 and 3840×1080; the small-window notice now clears footer controls. All 41 Lua tests and syntax for 24 files pass. Private fixture grants establish transfer correctness, not balance. The callback-overflow hotfix remains included.

0.3.6 adds the Boss Reward Wheel, native hand-level/free-refresh delivery and next-blind hands/discards/chips/Mult rewards. This build is packaged separately; the installed 0.3.5 game is intentionally untouched.

The same 0.3.6 package now includes the requested owner-only `/` admin panel with native reward grants and recovery controls. Final regression total is 126 checks across 46 Lua files.

2026-10-22: 0.4.0 Cryptid/Amulet compatibility, bounded Omega networking, Cryptid donations/decks, progression guards, spring UI polish and Setup 3 reversible five-component installation are implemented. Tests and exact fixture limits are documented in TEST_RESULTS.md. The live 0.3.5 game remains untouched.

2026-10-22: 0.5.0 repairs native deck setup (38 decks/76 starts), adds automatic endless, optional Space jackpot QTE, personal bets and a 37.5% team bonus, with tactile pixel UI polish. Two native clients verified rewards/payouts and the ante-eight-to-nine transition. Setup 4 packages the update separately; this task did not modify the live game.

2026-10-22: 0.5.1 adds exact typed personal/team bets with native two-client amount/debit verification. Packaged separately; live game untouched.

2026-10-22: 0.6.0 refreshes the felt UI, navigation, home/lobby, grouped pots/rewards and motion. Native callback/visual checks passed; Setup 5 packages it separately.

2026-10-22: 0.6.1 hides the goal HUD and stale input regions under native deck/run-info/options overlays; verified native menus and automatic restoration.
