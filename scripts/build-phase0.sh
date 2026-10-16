#!/bin/zsh

set -euo pipefail

# Retain the original entry point for existing local workflows.
project_root="${0:A:h:h}"
output_root="${OCTAPUSS_BUILD_DIR:-/tmp/octapuss-phase0}"
app_path="$output_root/Octapuss.app"
contents_path="$app_path/Contents"
# Keep the executable name compatible with existing packages and resource tools.
executable_path="$contents_path/MacOS/OctapussProof"
default_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
sdk_path="${OCTAPUSS_SDK_PATH:-$default_sdk}"

if [[ -n "${OCTAPUSS_MODULE_CACHE:-}" ]]; then
    module_cache="$OCTAPUSS_MODULE_CACHE"
else
    module_cache="$(mktemp -d /tmp/octapuss-phase0-module-cache.XXXXXX)"
    trap 'rm -rf "$module_cache"' EXIT
fi
if [[ ! -d "$sdk_path" ]]; then
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
fi
mkdir -p "$module_cache"

architecture="$(uname -m)"
case "$architecture" in
    arm64|x86_64) ;;
    *) print -u2 "Unsupported build architecture: $architecture"; exit 1 ;;
esac

source_files=("$project_root"/Octapuss/**/*.swift(N.))
compiler_flags=(-parse-as-library -target "$architecture-apple-macos14.0" -sdk "$sdk_path"
    -module-cache-path "$module_cache" -framework AppKit -framework SwiftUI)
check_sources=()
case "${1:-}" in
    --check)
        runner=RegressionChecks
        check_sources=("$project_root/OctapussTests/RegressionChecks.swift"
            "$project_root/OctapussTests/CursorImportChecks.swift"
            "$project_root/OctapussTests/CursorPackChecks.swift") ;;
    --render-library) runner=LibraryRenderChecks ;;
    --probe-system) runner=SystemCursorProbe ;;
    --check-system-live) runner=SystemCursorLiveCheck ;;
    "") runner="" ;;
    *) print -u2 "Unknown build option: $1"; exit 1 ;;
esac

if [[ -n "$runner" ]]; then
    if (( ${#check_sources} == 0 )); then
        check_sources=("$project_root/OctapussTests/$runner.swift")
    fi
    xcrun swiftc "${compiler_flags[@]}" -D OCTAPUSS_CHECKS \
        "${source_files[@]}" "${check_sources[@]}" -o "$module_cache/$runner"
    "$module_cache/$runner"
    exit
fi

mkdir -p "$contents_path/MacOS"
cp "$project_root/Octapuss/Resources/Info.plist" "$contents_path/Info.plist"
xcrun swiftc "${compiler_flags[@]}" "${source_files[@]}" -o "$executable_path"
sh "$project_root/scripts/package-cursor-helper.sh" "$executable_path" \
    "$project_root/Octapuss/Resources/CursorHelper-Info.plist" "$contents_path"
codesign --force --sign - --timestamp=none "$app_path"
print "$app_path"
