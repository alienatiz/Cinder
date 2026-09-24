#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source ./Build-Identity.sh
source ./Check-Toolchain.sh
mode="${1:-resolve}"
case "$mode" in resolve|--check-only) ;; *) echo "Usage: bash Setup-Mac.command [--check-only]"; exit 1 ;; esac
log_dir="$PWD/.build/mac-setup"
mkdir -p .build/mac-setup
printf 'Version: %s\nStatus: running\n' "$PUBLIC_VERSION" > "$log_dir/result.txt"
trap 'status=$?; if [ "$status" -ne 0 ]; then printf "Version: %s\nStatus: failed (%s)\n" "$PUBLIC_VERSION" "$status" > "$log_dir/result.txt"; fi' EXIT
if ! cinder_check_toolchain > "$log_dir/toolchain.txt" 2>&1; then cat "$log_dir/toolchain.txt"; exit 1; fi
cat "$log_dir/toolchain.txt"
cinder_check_identity
cinder_check_resources Sources/CinderApp/Resources
export CINDER_SWIFT6=0
if [ "$mode" = resolve ]; then
    xcrun swift package resolve 2>&1 | tee "$log_dir/dependencies.log"
    dependency_status=resolved
else
    dependency_status=not-checked
fi
printf 'Version: %s\nStatus: setup complete\nDependencies: %s\nChecked at: %s\nBuild/XCTest/audio: not executed by setup\n' \
    "$PUBLIC_VERSION" "$dependency_status" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$log_dir/result.txt"
echo "Development folder: $PWD"
echo "Next: bash Check-Xcode.command"
echo "Build an app after native checks: bash Build-App.command"
