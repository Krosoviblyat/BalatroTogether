# Together setup / launcher 0.8.3-dev

Gameplay stays **0.8.2-dev**. The executable version and installed gameplay
version are shown separately. This is an installer/update-flow repair.

The old 0.8.0 setup installs its own embedded 0.8.0 bundle. Signature checks
showed it could accept a signed update; they did not prove its install button
fetched a later release. Old downloaded EXEs cannot gain the repair retroactively.
Get the 0.8.3 full setup once, then use its desktop launcher.

**Check & install latest** checks published signed releases before installation.
A newer setup is downloaded, hash/signature verified, and handed off to install.
GitHub access is available in setup. This repository is private: each player
needs their own account access/token. Browser login alone is not updater access.
The encrypted token stays under that Windows account; no owner token is bundled.

If verification or access fails, setup does not silently install an old local
bundle. It offers a separate offline link labelled **latest NOT checked**. The
launcher performs a new check on Play when automatic updates are enabled. A
failed check offers **Play installed** explicitly. Opening the launcher checks
without launching the game. Local bundle installation respects version floors.

Setup bundles Lovely, Steamodded, Cryptid, Amulet and Together gameplay 0.8.2.
It refuses to change a running game and backs up/rolls back recognized replaced
mods and saves. No owned game executable or runtime files are distributed.
Signatures on update metadata are separate from Windows Authenticode.

The top manual/source export contains Manual Install.zip and InstallerSource.
Build.cmd compiles Installer.cs, SelfTests.cs, Updater.cs, UpdaterTests.cs,
UpdateKey.cs, StudioUI.cs, UIShowcase.cs, Build.cs, SetupUpdates.cs,
GitHubAccess.cs and SetupFlowTests.cs with .NET Framework 4.8. It regenerates
the user-supplied icon and source resource. No Python is required by players.
The private publisher signing key is never included.

Setup-flow checks drive the actual Windows buttons using fixture HTTP responses
with real signed releases, and execute the downloaded installer's production
engine/shortcut commit in isolated paths. Authenticated internet downloading
is not claimed by those fixtures. A separate real unauthenticated GitHub API
probe confirms private-access refusal. Reports state these limits explicitly.

Original code MIT. AI-assisted development with Codex. Dependencies retain
their included licenses and exact upstream sources. See LICENSE.txt and notices.


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
