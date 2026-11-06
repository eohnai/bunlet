# Use Bunlet as the visible product name

Status: done

## Goal

Make the built app and its visible labels agree with the Bunlet name already used in the README.
The user selected Bunlet and approved this task on 2026-11-06.
They also authorized launching the app for native validation.

## Done when

- The build produces `Bunlet.app` with Bunlet display and bundle names.
- Menu, session-window, Settings and provider-facing denial messages use Bunlet.
- CI archives, report validation and helper paths use the new app bundle name.
- The app builds, passes existing bundle validation and opens for a focused native rename check.
- Internal identifiers and stored-data locations retain their existing values.

## Out of scope

Internal target/helper renames, data migration, repository renaming, new artwork, provider setup changes and broad feature acceptance.
Native validation does not resume FM7, installed-provider checks or the failed screen-capture workflow.

## Decisions

- [0016: Use Bunlet as the app name](../../decisions/0016-use-bunlet-name.md).

## Tasks

- [x] BN1: Rename the visible app and bundle to Bunlet, align CI packaging, and verify the build, package and native labels.

## Verify

First confirm the existing mismatch. This assertion must fail before the change and pass afterward:

```bash
python3 -c 'import plistlib; from pathlib import Path; info = plistlib.loads(Path("Resources/Info.plist").read_bytes()); assert info["CFBundleDisplayName"] == "Bunlet", "display name still differs from README"'
```

Build without launching:

```bash
git diff --check
mkdir -p /private/tmp/bunlet-rename
env TMPDIR=/private/tmp/bunlet-rename \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash scripts/run.sh --build-only
```

The commands must exit 0. The build must print `/private/tmp/bunlet-rename/notch-pet-dev/Bunlet.app`.

Validate the actual bundle with the existing CI validator:

```bash
python3 -c 'import runpy; from pathlib import Path; runpy.run_path("scripts/ci/bundle.py")["source_entries"](Path("/private/tmp/bunlet-rename/notch-pet-dev/Bunlet.app")); print("Bundle validated")'
```

It must exit 0 and print `Bundle validated`.
Inspect the built plist and all four executables and both resource bundles.
Check shell/Python/workflow syntax for the changed packaging files:

```bash
bash -n scripts/run.sh
python3 -c 'import ast; from pathlib import Path; files = ["scripts/ci/bundle.py", "scripts/ci/reports.py", "scripts/ci/run-check.py", "scripts/check-event-bridge.py"]; [ast.parse(Path(p).read_text(), filename=p) for p in files]; print("Python syntax validated")'
python3 -c 'import yaml; from pathlib import Path; workflow = yaml.safe_load(Path(".github/workflows/ci.yml").read_text()); assert isinstance(workflow["jobs"], dict); assert "Bunlet.app" in str(workflow) and "Notch Pet.app" not in str(workflow); print("Workflow YAML and Bunlet bundle path validated")'
```

Launch the exact built bundle. Inspect the Bunlet menu and Settings labels, then quit through the Bunlet menu.
Use an isolated preferences suite with Pet only. Do not access installed provider configuration or run capture scripts.

## Compatibility

Keep `local.notchpet.dev`, `NotchPet` executables, resource names, preferences and Application Support paths.
Installed hook commands that reference `Notch Pet.app` are not rewritten.
Use the existing moved-helper Remove then Connect flow when adopting the new app path.

## Results

Checked 2026-11-06 on `feat/settings-product-name`, based on `d0d4639`, with the rename uncommitted.

- The initial display-name assertion failed with `display name still differs from README`. It passed after the rename.
- The build command above exited 0, completed in 26.17 seconds and printed the expected `Bunlet.app` path.
  The initial sandboxed attempt failed on compiler-cache access (`Operation not permitted`).
  The same command passed with approved compiler-cache access. No source repair was needed.
- The existing CI `source_entries` validator exited 0 and printed `Bundle validated`.
  It checked the actual bundle's paths, executable headers, plist identity and Pet resources.
  The validator now also requires Bunlet for both plist display-name fields.
- Built-plist inspection confirmed Bunlet display/bundle names, `NotchPet` executable and `local.notchpet.dev` identity.
  All four executables and both resource bundles were present.
- Shell syntax, Python syntax, workflow YAML parsing and the CI bundle-path check passed.
  `actionlint` was unavailable. Hosted workflow execution and archive round-trip checks were not run.
- Native launch used `NOTCH_PET_PREFERENCES_SUITE=local.notchpet.verify.bunlet-20261106` with the exact built executable.
  The native UI reported App: Bunlet. The Features page showed Desktop Pet installed, with Notch and Agents not installed.
  General displayed “Keep the parts of Bunlet you use.” The menu showed About Bunlet, Hide Bunlet and Quit Bunlet.
  About displayed “Bunlet Version 0.1.0 (1)”. Quit Bunlet closed the app and its process exited 0.
- Native checks used the UI accessibility tree. No screen capture, provider launch or installed configuration access was performed.
  This establishes the rename's startup, labels and quit behavior only. It does not establish broader feature or VoiceOver acceptance.
- The Notch title, recovery message and Claude denial text were inspected in source and compiled, without triggering those runtime cases.
- `git diff --check` passed. No Swift test suite was run for this label and packaging change.
