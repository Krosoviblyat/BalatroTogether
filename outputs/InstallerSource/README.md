# Public Zero Crew setup / launcher 0.8.4-dev

BALATRO TOGETHER SETUP 0.8.4 / GAMEPLAY 0.8.2 BETA

1. Close Balatro.
2. Open BalatroTogether-Setup-0.8.4-dev.exe.
3. Click Check & install latest. The game is normally found automatically.
4. Use Play Balatro Together on your desktop after installation.

PUBLIC UPDATES: no GitHub account, token or invitation is required.
Setup checks published signed releases before installing. The desktop launcher
checks on opening and again before Play when automatic updates are enabled.
Old saved tokens are ignored. The Releases button opens the public download page.
RSA-SHA256 signatures, package hashes, downgrade protection, backups and the
running-game guard remain enabled. If a download/check fails, setup offers an
explicit OFFLINE install and does not claim the latest version was checked.

This installer update keeps gameplay 0.8.2, so 0.8.2 in the lobby is expected.
All party members must have the same gameplay version and Cryptid gameset/rules.
Installing the same package does not reset each player's personal Cryptid profile.
The public-repository change fixes download access, not different gameset rules.

Includes Lovely 0.10.0, Steamodded 26.1002.0, Cryptid 0.5.17c, Amulet 3.6.1.
Manual Saved Runs hub, native Harbinger and pack/scoring fixes are included.
Saves and existing gameset choices are preserved. No owned game files bundled.
No administrator access is needed for normal play. Installation requests Windows
permission only if necessary to install the loader into the selected game folder.
Original code MIT. AI-assisted development with Codex. Upstream component sources
and licenses are included. Update signatures are separate from Windows signing.

Build.cmd rebuilds using .NET Framework 4.8 and the exported Manual Install.zip.
No player Python dependency. Use --public-update-self-test only with a fresh isolated
test output directory; it downloads a release and tests its engine using a private
copy of the owned supported executable. It never installs into the live game.
