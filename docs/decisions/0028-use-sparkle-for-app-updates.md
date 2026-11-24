# 0028: Use Sparkle for in-app updates

- Status: accepted
- Date: 2026-11-24
- Amends: [0021](0021-settings-scope.md)

The user approved a manual Check for Updates button in About and asked to verify an ad-hoc-signed update before setting up notarization. Use Sparkle for signed downloads, install confirmation, app replacement and relaunch. Hosting supplies the signed appcast and release archive. Use increasing bundle build numbers and retain the bundle identifier and installation path so preferences and installed hooks keep their existing identities.

Keep the dependency in update-enabled packages. The ordinary source and CI builds also show the About control and explain that the build has no configured feed. Prepare the local acceptance test with a disposable release key, app and profile. Public release configuration and signing keys belong to the release operator.
