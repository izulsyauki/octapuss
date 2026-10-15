#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
output_root="${OCTAPUSS_BUILD_DIR:-/tmp/octapuss-phase0}"
app_path="$output_root/Octapuss.app"
contents_path="$app_path/Contents"
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

mkdir -p "$contents_path/MacOS"
mkdir -p "$module_cache"
cp "$project_root/Phase0/Info.plist" "$contents_path/Info.plist"

architecture="$(uname -m)"
case "$architecture" in
    arm64|x86_64) ;;
    *)
        print -u2 "Unsupported build architecture: $architecture"
        exit 1
        ;;
esac

if [[ "${1:-}" == "--check" ]]; then
    xcrun swiftc -parse-as-library -D OCTAPUSS_CHECKS \
        -target "$architecture-apple-macos14.0" -sdk "$sdk_path" \
        -module-cache-path "$module_cache" \
        -framework AppKit -framework SwiftUI \
        "$project_root/Phase0/OctapussProof.swift" \
        "$project_root/OctapussTests/RegressionChecks.swift" \
        -o "$module_cache/RegressionChecks"
    "$module_cache/RegressionChecks"
    exit
fi

CLANG_MODULE_CACHE_PATH="$module_cache" \
SWIFT_MODULECACHE_PATH="$module_cache" \
xcrun swiftc \
    -parse-as-library \
    -target "$architecture-apple-macos14.0" \
    -sdk "$sdk_path" \
    -framework AppKit \
    -framework SwiftUI \
    "$project_root/Phase0/OctapussProof.swift" \
    -o "$executable_path"

codesign --force --sign - --timestamp=none "$app_path"
print "$app_path"
