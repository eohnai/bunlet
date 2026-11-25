---
summary: Settings → About → Check for Updates installs signed releases through Sparkle, and a GitHub workflow packages them.
---

# Software updates

## How it works

Bunlet uses Sparkle for manual updates ([0028](../../decisions/0028-use-sparkle-for-app-updates.md)). **Settings →
About → Check for Updates** reads the appcast at
`https://github.com/eohnai/bunlet/releases/latest/download/appcast.xml`. Sparkle shows the release, downloads it,
checks its Ed25519 signature, asks to install and relaunches. Development builds have no feed and say so.

The bundle identifier and the install path stay the same across releases. Preferences live outside the bundle, and
the hooks point at helpers inside the bundle, so an in-place update keeps both working.

## Release a version

1. Open **Actions → Package Bunlet release → Run workflow** on `main` and enter a version without the `v`, such as
   `0.1.5`. Pushing a tag such as `v0.1.5` also works.
2. The workflow tests and builds that commit on Apple silicon with Sparkle enabled, signs the ZIP and the appcast with
   the `BUNLET_SPARKLE_SIGNING_KEY` secret, checks the signature against the key built into Bunlet, and creates the tag
   only after those checks pass. It refuses a version that is not `X.Y.Z` or a tag that already names another commit.
   The build number is the workflow run number plus two.
3. Review the draft release and its two assets, then publish it as **Latest**. Only then does Check for Updates offer it.

To package locally, build with `BUNLET_ENABLE_SPARKLE=1 BUNLET_BUILD_CONFIGURATION=release bash scripts/run.sh
--build-only`, then run `scripts/package-update.py` with the Sparkle tools. Keep the private key in the Keychain or a
protected file outside the repository.

## Requirements

- Publish the ZIP and the appcast together. Mark a release Latest only when it has both.
- Release builds have an ad-hoc code signature and are not notarized.

## Open work

- Version 0.1.2 crashes at launch, so its users must download a newer release by hand.

## Decisions

[0028](../../decisions/0028-use-sparkle-for-app-updates.md).
