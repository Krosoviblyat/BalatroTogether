# Future releases: data only

Do not rebuild or upload another installer for normal mod patches. Keep the
launcher tag and its BalatroTogether.exe asset permanently available.

1. Update the gameplay metadata/version and source; run its appropriate tests.
2. Run tools/build_update.py with the previous verified full data ZIP as --base.
3. Sign the resulting ZIP with the existing publisher key:
   SignUpdate.exe --sign-bundle <ZIP> <version> <release-folder> <game-sha256> <lovely-sha256>
4. Publish the versioned gameplay release with its ZIP, Update-v3.json and
   Update-v3.sig. Upload all three before publishing. Preserve the permanent
   launcher release and the final legacy-upgrade assets.
5. Verify anonymous downloads and the permanent binary's real update test.

The schema-3 metadata signs the version, exact asset, package size/hash and
supported game/loader hashes. Cached ZIPs remain signed repair references.
Do not publish game files or any private key. The release title/body can change
without changing the signed metadata; the tag must match the gameplay version.
