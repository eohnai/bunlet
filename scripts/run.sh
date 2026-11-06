#!/bin/bash
set -euo pipefail

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--build-only" ) ]]; then
    echo "Usage: bash scripts/run.sh [--build-only]" >&2
    exit 2
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dev_dir="${TMPDIR:-/private/tmp}/notch-pet-dev"
build_dir="$dev_dir/build"
app_dir="$dev_dir/Bunlet.app"

# Keep compiler output on stderr so stdout contains only the app bundle path.
swift build --package-path "$project_dir" --scratch-path "$build_dir" >&2
binary_dir="$(swift build --package-path "$project_dir" --scratch-path "$build_dir" --show-bin-path)"

# Decision 0021 removed the built-in pet. Drop its bundle left by earlier builds in this reused folder.
rm -rf "$app_dir/Contents/Resources/NotchPet_Pet.bundle"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$binary_dir/NotchPet" "$app_dir/Contents/MacOS/NotchPet"
cp "$binary_dir/NotchPetHook" "$app_dir/Contents/MacOS/NotchPetHook"
cp "$binary_dir/NotchPetStatusLine" "$app_dir/Contents/MacOS/NotchPetStatusLine"
cp "$binary_dir/NotchPetActionHook" "$app_dir/Contents/MacOS/NotchPetActionHook"
cp -R "$binary_dir/NotchPet_NotchPet.bundle" "$app_dir/Contents/Resources/"
/usr/bin/plutil -lint "$app_dir/Contents/Info.plist" >&2

if [[ "${1:-}" == "--build-only" ]]; then
    printf '%s\n' "$app_dir"
else
    /usr/bin/open "$app_dir"
    printf 'Launched %s\n' "$app_dir"
fi
