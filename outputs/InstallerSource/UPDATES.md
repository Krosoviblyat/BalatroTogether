# Public signed updates

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

The app never reads or transmits the old DPAPI token. No credential is embedded.
UpdateKey.cs is the unchanged public verification key. The private signing key
stays in the maintainer Windows account and is never packaged. No Authenticode
certificate is included. --network-self-test verifies a real anonymous manifest
check; --public-update-self-test additionally drives production Install/Play
buttons, downloads real release bytes, verifies them, and invokes the actual
installer engine inside isolated paths. Source fixtures still verify failures,
offline choice, signature rejection and downgrade handling.
