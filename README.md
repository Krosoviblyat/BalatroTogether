# Together public setup / launcher 0.8.4-dev

Public updates without GitHub login

The repository is public. Setup and the desktop launcher now use anonymous
release downloads, ignore old stored tokens, and show Releases instead of a
GitHub-access dialog. No account or token is required to install/update.

Use Check & install latest with Balatro closed, then the desktop Play Together
shortcut. Existing 0.7+ launchers can receive the signed update; very old setup
EXEs still only install their original bundle, so download this setup once.

Installer/launcher: 0.8.4-dev. Bundled gameplay: unchanged 0.8.2-dev.
Different Cryptid gamesets still cannot join the same party. Match the host's
gameset and custom/experimental rules. Profile choices are intentionally preserved.

Integrity checks, signed manifests, backups and running-game protection remain.
Real anonymous-network production-button tests download the published signed
installer and execute its engine only inside isolated test game/profile folders.
No live game, profile, Steam lobby or save is modified by those tests.

Download the newest full EXE from [Releases](https://github.com/Krosoviblyat/BalatroTogether/releases).

## Gameplay source

# Balatro Together 0.8.2-dev

Saved Runs is the hub for every manual party checkpoint. Saving again updates
that run's entry; a different party or Fast Restart keeps a separate entry,
even when using the same seed. Select any entry to reopen its joinable lobby.

0.8.2 fixes free tag packs getting stranded between blinds. Open and choose
Spectral, Arcana, Celestial, Standard and Buffoon rewards normally. The party
waits for all pack choices before progressing.

0.8.1 fixes The Chromatic's negative hand scores and Amulet ante proposals.
Signed score debt is preserved, then positive hands repay it. Credits now sits
beside Together Options and in the lobby. Credits > Open Crash Reports opens
the local TogetherReports folder in the active save profile. Reports are never
uploaded automatically; share last-crash.txt when reporting an uncaught crash.

Four-player Cryptid co-op with Steam tables, native bots, donations, team/personal
bets, reward dice, a boss wheel and endless play.

This main release adds The Harbinger as a native Boss Blind with the supplied
purple chip. It plays five-card hands from its own deck; its score damages net
team chips after each team hand. CLASH uses native bouncing text and sound.
The first boss is protected. Mixed mode rolls a 20% encounter chance on later
regular bosses from Ante 2; finale bosses stay native. Boss Rules / Stakes offers
four difficulty tiers and an explicit Quick Duel test mode.

Checkpoints are **manual**. The host chooses F8 > Save Checkpoint or Save & Leave
between blinds. Continue Saved Party opens a new joinable lobby/code; the original
players recover their builds. The host presses Continue Saved Run when all builds
are restored. No automatic checkpoint interrupts a new run or blind transition.

Use the full 0.8.2 setup with Balatro closed. The normal desktop launcher can
receive this signed update from 0.7 once published. Private-repository access is
still required for online updates. Every player must use the same gameplay build.
Native saves remain in the ordinary Balatro profile; the Harbinger Lab is separate.

Pinned Windows Steam Balatro 1.0.1o / Lovely 0.10.0 / Steamodded 26.1002.0 /
Cryptid 0.5.17c / Amulet 3.6.1. User-owned game files are never redistributed.
Original code MIT; upstream components retain their licenses. AI-assisted work.

See SAVES.md, CRYPTID.md, BOTS.md, and the included installer guide for details.
