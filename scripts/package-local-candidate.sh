#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
app_path="${1:-$project_root/.build/stability/Octapuss.app}"
output_root="${2:-$project_root/.build/local-candidate}"
[[ -d "$app_path/Contents" ]] || { print -u2 "Build the app first with scripts/build-phase0.sh"; exit 1; }
codesign --verify --deep --strict "$app_path"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Contents/Info.plist")
architecture=$(uname -m)
mkdir -p "$output_root"
archive="$output_root/Octapuss-$version-local-$architecture.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
cp "$project_root/docs/STABILITY_REPORT.md" "$output_root/VALIDATION.md"
cat > "$output_root/READ-ME-FIRST.txt" <<'NOTE'
Octapuss experimental local candidate

This app is locally ad-hoc signed, not Developer ID signed or notarized.
It is intended for evaluation on the development Mac. Do not treat local
signature verification as Gatekeeper approval for another Mac.

Open Octapuss, select a cursor pack, and choose Apply explicitly.
Restore system pointer restores owned registrations and pauses preview.
Dock Quit / Command-Q keeps Octapuss running in the menu bar.
Menu-bar icon > Quit Octapuss restores the pointer and fully exits.

If restoration fails, keep the recovery journal and retry Restore after
stopping other cursor utilities. Relaunch checks unresolved recovery.
No login item is installed. Protected macOS cursors can remain native.

Read VALIDATION.md for passed checks and remaining acceptance gates.
NOTE
git -C "$project_root" rev-parse HEAD > "$output_root/SOURCE-REVISION.txt"
if [[ -n "$(git -C "$project_root" status --porcelain --untracked-files=all -- Octapuss Octapuss.xcodeproj scripts)" ]]; then
    print 'Built with uncommitted source changes; see the stability milestone commit.' >> "$output_root/SOURCE-REVISION.txt"
fi
print "$archive"
