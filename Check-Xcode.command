#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source ./Build-Identity.sh
source ./Check-Toolchain.sh
mode="${1:-native}"
case "$mode" in native|swift6) ;; *) echo "Usage: bash Check-Xcode.command [native|swift6] (macOS 27 / arm64)"; exit 1 ;; esac
check_dir="$PWD/.build/compatibility-$mode"
mkdir -p "$check_dir"
printf 'Version: %s\nMode: %s\nStatus: running\n' "$PUBLIC_VERSION" "$mode" > "$check_dir/result.txt"
trap 'status=$?; if [ "$status" -ne 0 ]; then printf "Version: %s\nMode: %s\nStatus: failed (%s)\n" "$PUBLIC_VERSION" "$mode" "$status" > "$check_dir/result.txt"; fi' EXIT
# Capture the report without putting preflight in a pipeline subshell: it sets
# the SDK, deployment target and argument array used by the commands below.
if ! cinder_check_toolchain > "$check_dir/toolchain.txt" 2>&1; then cat "$check_dir/toolchain.txt"; exit 1; fi
cat "$check_dir/toolchain.txt"
cinder_check_identity
cinder_check_resources Sources/CinderApp/Resources
export CINDER_SWIFT6=0
if [ "$mode" = swift6 ]; then export CINDER_SWIFT6=1; fi
xcrun swift build "${CINDER_SWIFT_ARGS[@]}" --scratch-path "$check_dir/package" 2>&1 | tee "$check_dir/build.log"
xcrun swift test "${CINDER_SWIFT_ARGS[@]}" --scratch-path "$check_dir/package" 2>&1 | tee "$check_dir/tests.log"
printf 'Version: %s\nMode: %s\nBuild and XCTest completed: %s\nManual audio/UI/energy validation: pending\n' "$PUBLIC_VERSION" "$mode" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$check_dir/result.txt"
echo "Commands completed. Review warnings in $check_dir. UI, audio and long-duration checks remain manual."
