# Balatro Together

Private development source for the four-player cooperative Balatro mod and Windows installer. Current launcher/setup: **0.6.2-dev**; tested gameplay payload: **0.6.1-dev**.

Each player keeps their own build, cards, money and shop while contributing to a shared blind. Features include Steam tables, native companion bots, shared donations, personal/team Bet Pots, reward dice, a boss wheel with a Space challenge, automatic endless and animated UI.

## Install

Use the **Easy Installer** ZIP attached to this repository's releases when available. Extract it, close Balatro, then run **Install Balatro Together.exe**. Use the same build on every party member's PC. Backups and rollback are included. After this one-time install, the desktop shortcut checks and applies signed updates before play. Private GitHub downloads require each player to configure their own access once; see [Automatic updates](outputs/InstallerSource/UPDATES.md).

Supported bundle: Windows x64, owned Steam Balatro 1.0.1o-FULL, Lovely 0.10.0, Steamodded 26.1002.0, Cryptid 0.5.17c and Amulet 3.6.1.

## Source

- [Mod and player documentation](outputs/BalatroTogether/README.md)
- [Installer source and build instructions](outputs/InstallerSource/README.md)
- [Compatibility](outputs/BalatroTogether/CRYPTID.md)
- [Known limitations](outputs/BalatroTogether/KNOWN_ISSUES.md)
- [Verification and fixture limits](outputs/BalatroTogether/TEST_RESULTS.md)

The repository contains original mod/installer source and tests. It excludes game files, decompiled source, saves, private lab tools, credentials and earlier local Git history. Full installer releases separately retain exact dependency sources and licenses.

## Development

With Python 3.11+ and `lupa==2.8` installed, run `python outputs/BalatroTogether/tools/test.py`. Optional pinned Amulet integration tests need its source under `work/upstream-Amulet`; otherwise the runner reports them as skipped. Build the mod ZIP with `python outputs/BalatroTogether/tools/build.py`.

To rebuild the Windows installer, use its included Build.cmd beside the exact Manual Install.zip from the matching release. See InstallerSource/README.md for details. The full dependency bundle is distinct from the mod-only ZIP.

This is an AI-assisted development build, not a certified production release. Native tests use isolated controlled fixtures; they are not proof of all Cryptid combinations or ordinary run balance. Cross-account Steam behavior still needs real-party verification.

## Licensing

Original Together/installer code is MIT; vendored json.lua retains its MIT notice. Lovely is MIT. Steamodded, Cryptid and Amulet are separate GPLv3 components with their upstream sources/notices in full distributions. No Balatro or other proprietary game assets are redistributed.

Private GitHub releases require repository read access. The updater authenticates with each player's own token, encrypted using Windows DPAPI, and verifies signed update metadata with a compiled public key. No account token or private signing key is embedded in distributed software.
