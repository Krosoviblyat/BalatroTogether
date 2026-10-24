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
