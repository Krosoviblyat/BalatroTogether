# Permanent Balatro Together installer / launcher

Download BalatroTogether.exe once from the permanent launcher release.
Close Balatro and click Check & install latest. Future gameplay updates are
signed ZIP bundles applied by the same launcher, without a new installer EXE.
The interface shows installed and GitHub gameplay versions, not an installer
build number. Internal build identifiers are retained for signature and
legacy-upgrade compatibility only.

Every opening and Play checks the newest published versioned GitHub release,
including beta/dev releases. Missing metadata on the newest release is an
error; an older release is never silently installed. Failed checks leave the
installed build untouched. Play installed is explicit and verifies its signed
cached receipt. The permanent launcher tag is excluded from gameplay selection.

Signed bundles include the supported Lovely, Steamodded, Cryptid, Amulet and
Together files, sources and licenses. The owned game/runtime DLLs are never
distributed. Backups, rollback, actual-file verification, anti-downgrade and
running-game guards remain. Requires the supported Windows Steam Balatro.

Build.cmd rebuilds the final engine from its exported source and full package.
Normal future releases only run the data-bundle builder and signing utility.
The publisher private key stays protected in the maintainer Windows account.
No token or GitHub account is needed for player updates.
