#!/bin/bash
# Optional SDK integration check, separate from app build and runtime behavior.
set -euo pipefail
cd "$(dirname "$0")"

require_supported=false
case "${1:-}" in
    "") ;;
    --require-supported) require_supported=true ;;
    *) echo "Usage: bash Check-LiveActivities.command [--require-supported]" >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then echo "Expected at most one option." >&2; exit 1; fi

source ./Build-Identity.sh
source ./Check-Toolchain.sh
mkdir -p .build/live-activities-sdk
report_dir="$(mktemp -d "$PWD/.build/live-activities-sdk/check.XXXXXX")"
printf 'Status: checking\n' > "$report_dir/result.txt"
echo "SDK report: $report_dir"

report_error() {
    printf 'Status: error\nReason: %s\n' "$1" > "$report_dir/result.txt"
    cat "$report_dir/result.txt" >&2
    exit 1
}

if ! cinder_check_toolchain > "$report_dir/toolchain.txt" 2>&1; then
    cat "$report_dir/toolchain.txt" >&2
    report_error "Toolchain preflight failed; API support was not determined."
fi
cat "$report_dir/toolchain.txt"
target="$TARGET_ARCH-apple-macos$MINIMUM_MACOS"
compiler_args=(-typecheck -parse-as-library -target "$target" -sdk "$SDKROOT"
    -module-cache-path "$PWD/.build/live-activities-sdk/ModuleCache")

# Importability alone does not mean the APIs are available on this platform.
printf 'import ActivityKit\nimport WidgetKit\nimport SwiftUI\n' > "$report_dir/Imports.swift"
if ! xcrun swiftc "${compiler_args[@]}" "$report_dir/Imports.swift" > "$report_dir/imports.log" 2>&1; then
    cat "$report_dir/imports.log" >&2
    report_error "SDK imports failed; review imports.log."
fi

if xcrun swiftc "${compiler_args[@]}" Tools/Probes/LiveActivities.swift > "$report_dir/api.log" 2>&1; then
    printf 'Status: compile-supported\nTarget: %s\nRuntime authorization and presentation: not tested\n' "$target" > "$report_dir/result.txt"
elif awk '
    /error:/ { found = 1; if ($0 !~ /is unavailable in macOS/) unexpected = 1 }
    END { exit (found && !unexpected ? 0 : 1) }
' "$report_dir/api.log"; then
    printf 'Status: unsupported\nTarget: %s\nReason: Live Activities APIs are unavailable on macOS in the selected SDK.\n' "$target" > "$report_dir/result.txt"
    cat "$report_dir/result.txt"
    echo "Compiler diagnostics: $report_dir/api.log"
    if "$require_supported"; then exit 2; fi
    exit 0
else
    cat "$report_dir/api.log" >&2
    report_error "Unexpected API compile failure; support was not determined."
fi

cat "$report_dir/result.txt"
if [ -s "$report_dir/api.log" ]; then cat "$report_dir/api.log"; fi
