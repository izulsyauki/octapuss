#!/bin/sh
set -eu

# Reuse the command-dispatch executable with background-only bundle metadata.
# This is a child process, not a login item or separately launched application.
helper_contents="$3/Helpers/OctapussCursorHelper.app/Contents"
mkdir -p "$helper_contents/MacOS"
cp "$1" "$helper_contents/MacOS/OctapussCursorHelper"
cp "$2" "$helper_contents/Info.plist"
codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --timestamp=none "$helper_contents/.."
