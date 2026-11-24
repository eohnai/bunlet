# Software updates

[Decision 0028](../../decisions/0028-use-sparkle-for-app-updates.md) adds manual updates through Sparkle.

## Install and check

Install the first update-enabled package in Applications. Open **Settings → About → Check for Updates**. Sparkle shows the available release and handles download, signature verification, confirmation and relaunch. The app checks when requested. Ordinary source builds show that no release feed is configured.

Keep the bundle identifier and the installed app path stable across releases. Preferences live outside the bundle. The provider hook records point to the helpers by their path inside the bundle, so an in-place replacement retains the addresses.

## Hosted release

Bunlet `0.1.1` (build `2`) is the first update-enabled release. GitHub Releases hosts the signed archive and appcast. The stable feed uses `https://github.com/eohnai/bunlet/releases/latest/download/appcast.xml`. Each appcast points at the archive under its versioned Git tag.

Publish the archive and appcast together. Mark a release as latest only when it includes both assets. Use the existing `bunlet` signing account for future releases. The public downloads for `v0.1.1` matched the locally signed artifacts byte for byte and passed Sparkle signature verification.

[Bunlet 0.1.1](https://github.com/eohnai/bunlet/releases/tag/v0.1.1)

## Package a tagged release in GitHub Actions

Set `BUNLET_SPARKLE_SIGNING_KEY` in the GitHub Actions `release` environment to the private key for the existing Bunlet signing account. The workflow verifies the generated ZIP against the public key already installed in Bunlet.

Push a version tag such as `v0.1.2` on the tested commit in `main`. GitHub Actions tests and builds that commit with Sparkle enabled on Apple silicon. It uses the workflow run number plus two for the bundle build number, so the first run starts after the published build 2. Re-running keeps the same build number.

Review the draft and its two assets, then publish it as Latest to make it available through **Check for Updates**. The ZIP uses the versioned tag URL. The appcast uses the same stable URL across releases. To ship previous code to users who already upgraded, package that code again with a new tag and a higher build number.

## Prepare a release locally

On Apple silicon, use a fresh build directory and build the update-enabled app:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
BUNLET_ENABLE_SPARKLE=1 BUNLET_BUILD_CONFIGURATION=release \
  BUNLET_BUILD_DIRECTORY="$build_directory" bash scripts/run.sh --build-only
```

Use the `bin` tools shipped with the pinned Sparkle distribution. Generate the Bunlet Ed25519 key once with `generate_keys --account bunlet`. Keep the private key in the release operator's Keychain or a protected key file outside the repository. Pass only the public key to the bundle.

```bash
python3 scripts/package-update.py \
  --app "$build_directory/Bunlet.app" --output "$release_directory" \
  --version "$version" --build "$build_number" \
  --feed-url "$feed_url" --download-prefix "$download_prefix" \
  --public-key "$public_key" --generate-appcast "$sparkle_tools/generate_appcast"
```

Choose an HTTPS feed URL ending in `/appcast.xml` and an HTTPS download prefix ending in `/`. Increase the numeric build number for each release. The command emits the ad-hoc signed app ZIP and signed appcast. Host the ZIP and appcast at their configured URLs. The test mode accepts HTTP only for a disposable bundle and one loopback origin.

## Acceptance

- [x] Link Sparkle in the update-enabled build and expose its manual check in About.
- [x] Generate a signed archive and appcast and package a relocatable Apple silicon bundle.
- [x] Install and relaunch an ad-hoc-signed update while preserving preferences and hook paths in a disposable profile.

On 2026-11-24, a loopback acceptance run invoked Bunlet's normal check action and Sparkle's **Install Update** and **Install and Relaunch** controls. Sparkle replaced build `9001` with `9002` at the same path. The restarted process loaded the fixture pet size of 166, the About selection and the paused monitoring choice persisted, and the three fixture hook files stayed byte-identical. Codex, Claude Code and Cursor CLI ownership checks still resolved the helper at the installed path. Production feed publication is separate from this test.
