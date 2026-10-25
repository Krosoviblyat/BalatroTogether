# Together public setup / launcher 0.8.6-dev

Government Man and the coop fest

Native Legendary Joker, base $20, starting X2 Mult. Each newly acquired
Negative Joker adds X0.5. Every second acquisition turns one random owned
non-Negative Joker Negative, including native slot bonuses and animation.
Legendary pool/collection, Blueprint scoring, donations and native manual
saves are supported. Blueprint/debuff/rejected donations cannot farm growth.
Supplied art is preserved in the native 1x/2x atlas.

The installer and launcher welcome now reads:
come on in and join the coop fest!

Everyone must update to gameplay 0.8.6-dev. The normal installer updates the
main mod only when Balatro is closed. No live game was changed during QA.

Missing game-file and wrong-folder protection

Setup now checks the original game's required Windows x64 runtime DLLs,
including SDL2.dll, love.dll and lua51.dll. An EXE-only or incomplete folder
stops before downloads, backups, mod installation or launch and shows the
selected folder, missing filenames and Steam verification instructions.
The game folder gets Lovely's winmm.dll; the separate AppData mod destination
is now shown in setup and opens on click after installation.
The launcher validates the same game and explicitly uses its directory when
starting Balatro. No owned game DLLs are bundled.

Public updates without GitHub login

The repository is public. Setup and the desktop launcher now use anonymous
release downloads, ignore old stored tokens, and show Releases instead of a
GitHub-access dialog. No account or token is required to install/update.

Use Check & install latest with Balatro closed, then the desktop Play Together
shortcut. Existing 0.7+ launchers can receive the signed update; very old setup
EXEs still only install their original bundle, so download this setup once.

Installer/launcher and bundled gameplay: 0.8.6-dev. Update every player.
Different Cryptid gamesets still cannot join the same party. Match the host's
gameset and custom/experimental rules. Profile choices are intentionally preserved.

Integrity checks, signed manifests, backups and running-game protection remain.
Real anonymous-network production-button tests download the published signed
installer and execute its engine only inside isolated test game/profile folders.
No live game, profile, Steam lobby or save is modified by those tests.

Download the newest full EXE from [Releases](https://github.com/Krosoviblyat/BalatroTogether/releases).

## Gameplay source

# Balatro Together 0.8.6-dev

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

Use the full 0.8.6 setup with Balatro closed. The normal desktop launcher can
receive this signed update from 0.7 once published. Private-repository access is
still required for online updates. Every player must use the same gameplay build.
Native saves remain in the ordinary Balatro profile; the Harbinger Lab is separate.

Pinned Windows Steam Balatro 1.0.1o / Lovely 0.10.0 / Steamodded 26.1002.0 /
Cryptid 0.5.17c / Amulet 3.6.1. User-owned game files are never redistributed.
Original code MIT; upstream components retain their licenses. AI-assisted work.

See SAVES.md, CRYPTID.md, BOTS.md, and the included installer guide for details.
