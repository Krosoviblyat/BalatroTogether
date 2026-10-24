# Automatic updates (launcher/setup 0.7.2-dev)

Run the standalone setup EXE once, with Balatro closed. No extraction is needed. Then use **Play Balatro Together** on your desktop. The shortcut opens the launcher, checks for a newer signed release, downloads and verifies it, and starts installation automatically. After installation, click Play (or use the desktop shortcut if Windows requested administrator access). The launcher never opens the game during a failed update.

Launcher/setup **0.7.2-dev** bundles gameplay **0.7.1-dev**. These versions can differ: the footer identifies setup; the installed-mod line identifies the version players must match.

The launcher checks the original Windows user's installed Together metadata and compares the installed files with the hash-verified embedded package. A current launcher with an old, missing or damaged mod is **repair needed**, never up to date. With no newer eligible release, it stages its own full installer for repair; this local path works without GitHub access. Play also verifies the mod and uses this repair path before launching. A newer mod is preserved, and the trusted launcher high-water mark prevents an older embedded repair.

The update checkbox is enabled by default. Turn it off to skip online checks (installed-file verification and local repair still apply); **Check updates** still performs a manual update. Launching Balatro directly through Steam bypasses the launcher. Everyone in a party should use the same gameplay build. Start a fresh party after updating.

## One-time private GitHub access

The repository stays private. Each player needs their own GitHub account with repository access and their own token. Signing in to GitHub in a browser does not authenticate the Windows launcher.

1. In the launcher click **GitHub access**, then **Open GitHub token settings**.
2. For the repository owner, create a fine-grained token with access only to `Krosoviblyat/BalatroTogether` and **Contents: Read-only**. Choose an expiry date.
3. Invited collaborators may need a classic token with `repo` scope because of GitHub's fine-grained collaborator limitations. That scope grants broader access to their repositories; review it before creating one. A separate public downloads repository avoids needing tokens and can be added in a future release without making this source repository public.
4. Paste your token into the launcher's masked field and click Save, then Check updates. Never paste it into chat, send it to friends, or put it in a ZIP. Each person uses their own access. The launcher only makes read requests.

The token is encrypted using Windows DPAPI for the current Windows account in `%LocalAppData%\BalatroTogether\github-token.bin`. No token is included in the mod, installer, source or releases. Save an empty field to forget it. Expired/revoked access produces a useful error and leaves Play available. Do not run the launcher as administrator.

## Verification and installation

The launcher uses GitHub's release list (including published development prereleases), rather than `/latest`, which omits prereleases. Unsigned releases and drafts are ignored. It chooses the highest eligible version from the newest 100 releases and refuses downgrades/reinstall loops. Invalid signed-release metadata stops updating rather than falling back silently.

New launchers prefer `Update-v2.json` plus `Update-v2.sig`, whose schema 2 describes a standalone setup EXE. Its package and installer hash must agree; the verified EXE is staged directly. Schema 1 `Update.json`/`Update.sig` still describe the legacy ZIP for 0.6.2 clients. Both forms use the same pinned verification key.

`Update.json` (or `Update-v2.json`) is signed as exact UTF-8 bytes with RSA-3072/SHA256; `Update.sig` is the detached binary signature. The public key is compiled into `UpdateKey.cs`. The signed document binds repository, version, package name/size/SHA256, inner installer SHA256, issue time and expiry (90 days). The client checks the signature before interpreting the metadata, rejects expired/future metadata, and verifies the complete package before staging a standalone EXE or extracting only the exact installer filename from a legacy ZIP. It then separately verifies that executable. Requests use HTTPS; credentials are attached only to GitHub's API host and never to asset redirects. Downloads and metadata have size/time limits. This is a small custom signed updater, not a complete TUF implementation.

Balatro must be closed at the initial check, before download/installation handoff, and at the installer's existing mutation barriers. A running match is never terminated. Installation reuses the embedded pinned payload, backs up saves and recognized previous mods, validates every copied file and rolls back failures. Launcher replacement is atomic and retains its settings/access file. The new installed version becomes the replay floor only after successful installation. Temporary completed handoff downloads remain under `%LocalAppData%\BalatroTogether\Updates`; they can be removed when all setup windows are closed. Old mods/saves remain under `%AppData%\BalatroTogether\Backups`.

Offline or denied private access is shown as an unsuccessful online check, with the installed mod and launcher versions displayed separately. It never means a new version was installed. A valid existing build stays available; an older/damaged local mod can be repaired from the trusted embedded installer. Incomplete downloads, bad signatures and bad hashes never execute an unverified downloaded installer. The launcher does not resume a partial download; it retries from the beginning on the next check. The game and installer binaries remain Windows-unsigned: update signatures verify our package, and are separate from Authenticode/SmartScreen reputation. Do not disable Windows protections.

## Publishing future updates

Compile the maintainer utility from source (do not bundle its executable or private key):

```bat
%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:exe /out:SignUpdate.exe /reference:System.Security.dll /reference:System.Web.Extensions.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll SignUpdate.cs
SignUpdate.exe --init UpdateKey.cs
```

The first init generates a signing key encrypted with current-user DPAPI under `%LocalAppData%\BalatroTogetherPublisher\signing-key.dpapi`. Later init calls reuse it and export only the public key. Keep the publisher Windows profile/key protected and backed up securely. The private key never goes into Git or releases. If it is lost or compromised, distribute a new launcher manually with a new trust key; changing the online public key cannot silently replace a client's pinned key.

For a release, bump `Build.Version`, assembly/manifest versions and changelog, set the correct embedded payload hash, and rebuild/test the installer with Build.cmd. Keep `UpdateKey.cs` unchanged. Package as `BalatroTogether-<version>-Easy-Installer.zip`, including its source, dependency licenses and exact upstream sources. Then run:

```bat
SignUpdate.exe --sign BalatroTogether-0.7.2-dev-Easy-Installer.zip 0.7.2-dev release-assets
```

For the native EXE path also run:

```bat
SignUpdate.exe --sign BalatroTogether-Setup-0.7.2-dev.exe 0.7.2-dev release-assets
```

This produces Update-v2.json and Update-v2.sig. Publish the EXE and both v2 assets. Keep the legacy ZIP, Update.json and Update.sig on this transition release for 0.6.2 launchers. Never sign different EXE bytes from those packaged inside that ZIP.

Committing or pushing source code does not publish an update. The updater can only discover a published release with its required signed assets.

Publish the ZIP, `Update.json` and `Update.sig` together on the matching `v<version>` GitHub release, after reviewing the package. Drafts do not trigger updates. Never change the ZIP after signing; re-sign changed bytes. The checksum sidecar is useful for manual verification but is not a substitute for the signature. Refresh expired metadata by re-signing the same package when necessary; never reset the client version to force a reinstall.

## Validation

`Install Balatro Together.exe --updater-self-test <test directory>` runs updater fixtures, without network access or executing downloaded files. `--self-test <test directory>` runs synthetic install/rollback scenarios. `--verify-update <release directory>` prefers real Update-v2.json/Update-v2.sig when present, otherwise Update.json/Update.sig, and the signed ZIP with the compiled production public key; it extracts a verified installer for inspection but never executes it. See verification-result.json in that directory.

The release is checked with 41 updater fixtures, 24 installer scenarios and 9 native UI render checks (including Windows icon extraction, panel bounds, animation changes and reduced motion). Production private-token authentication and actual cross-PC update handoff need verification with each player's own GitHub access; browser login alone cannot prove those paths. Synthetic tests do not certify every antivirus, alternate Windows account or UAC configuration.

References: [GitHub release assets and required read permissions](https://docs.github.com/en/rest/releases/assets), [GitHub token creation and limitations](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens), [Windows DPAPI](https://learn.microsoft.com/en-us/dotnet/standard/security/how-to-use-data-protection).
