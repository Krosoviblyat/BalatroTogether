# Public signed updates

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

The app never reads or transmits the old DPAPI token. No credential is embedded.
UpdateKey.cs is the unchanged public verification key. The private signing key
stays in the maintainer Windows account and is never packaged. No Authenticode
certificate is included. --network-self-test verifies a real anonymous manifest
check; --public-update-self-test additionally drives production Install/Play
buttons, downloads real release bytes, verifies them, and invokes the actual
installer engine inside isolated paths. Source fixtures still verify failures,
offline choice, signature rejection and downgrade handling.
