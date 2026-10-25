# Public Zero Crew setup / launcher 0.8.6-dev

BALATRO TOGETHER SETUP 0.8.6 / GAMEPLAY 0.8.2 BETA

1. Close Balatro.
2. Open BalatroTogether-Setup-0.8.6-dev.exe.
3. Click Check & install latest. The game is normally found automatically.
4. Use Play Balatro Together on your desktop after installation.

PUBLIC UPDATES: no GitHub account, token or invitation is required.
Setup checks published signed releases before installing. The desktop launcher
checks on opening and again before Play when automatic updates are enabled.
Old saved tokens are ignored. The Releases button opens the public download page.
RSA-SHA256 signatures, package hashes, downgrade protection, backups and the
running-game guard remain enabled. If a download/check fails, setup offers an
explicit OFFLINE install and does not claim the latest version was checked.

This setup installs gameplay 0.8.6 with the Government Man Legendary Joker.
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

INSTALL LOCATIONS: only winmm.dll goes next to the original Balatro.exe.
Together, Cryptid, Amulet and Steamodded go in %AppData%\Balatro\Mods.
This split is normal. The game executable must stay in its full Steam folder.

Setup and Play now refuse an EXE-only folder or missing/invalid x64 game DLLs,
including SDL2.dll, love.dll and lua51.dll, before installing or launching.
Repair missing owned files through Steam > Properties > Installed Files >
Verify integrity of game files. Use Browse to select that full game folder.
The mod installer does not include or download Balatro's own runtime files.

GOVERNMENT MAN: native Legendary Joker, base $20, starts at X2 Mult.
Every acquired Negative Joker adds X0.5; every second acquisition turns an
owned non-Negative Joker Negative. Existing cards changing edition do not
count as acquisitions. Donation and manual saves preserve its full state.
All players need gameplay 0.8.6-dev. Uses the supplied artwork.

Installer welcome: come on in and join the coop fest!

Build.cmd rebuilds using .NET Framework 4.8 and the exported Manual Install.zip.
No player Python dependency. Use --public-update-self-test only with a fresh isolated
test output directory; it downloads a release and tests its engine using a private
copy of the owned supported executable. It never installs into the live game.
