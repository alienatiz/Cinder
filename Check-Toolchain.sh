#!/bin/bash
# Shared preflight for the macOS 27 / Apple Silicon 1.0 development line.
# Callers source Build-Identity.sh first. No global xcode-select changes.
cinder_check_toolchain() {
    local system architecture host host_major xcode sdk swift_version swift_minor
    system="$(uname -s)"
    if [ "$system" != Darwin ]; then
        echo "Cinder 1.0 must be built and tested on macOS 27 with Xcode 27." >&2; return 1
    fi
    architecture="$(uname -m)"
    if [ "$architecture" != "$TARGET_ARCH" ]; then
        echo "Use a native Apple Silicon terminal (arm64), not an Intel/Rosetta process." >&2; return 1
    fi
    host="$(sw_vers -productVersion)"; host_major="${host%%.*}"
    if [[ ! "$host_major" =~ ^[0-9]+$ ]] || [ "$host_major" -lt 27 ]; then
        echo "Cinder's tests and app require macOS $MINIMUM_MACOS or later. Host: $host" >&2; return 1
    fi
    if ! xcode="$(xcodebuild -version 2>&1)"; then
        echo "Select a full Xcode 27 installation, or set DEVELOPER_DIR for this invocation." >&2; return 1
    fi
    if ! printf '%s\n' "$xcode" | head -n 1 | grep -Eq '^Xcode 27([.]|$|[[:space:]])'; then
        echo "This development baseline requires Xcode 27.x. Selected: $xcode" >&2; return 1
    fi
    sdk="$(xcrun --sdk macosx --show-sdk-version)" || return 1
    if [[ ! "$sdk" =~ ^27([.][0-9]+)*$ ]]; then
        echo "Select a macOS 27.x SDK. Selected SDK: $sdk" >&2; return 1
    fi
    swift_version="$(xcrun swift --version)" || return 1
    if [[ "$swift_version" =~ Swift[[:space:]]version[[:space:]]6[.]([0-9]+) ]]; then
        swift_minor="${BASH_REMATCH[1]}"
    else
        echo "The package requires Swift 6.4 or later in the Swift 6 compiler family." >&2; return 1
    fi
    if [ "$swift_minor" -lt 4 ]; then echo "Swift 6.4 or later is required." >&2; return 1; fi
    export MACOSX_DEPLOYMENT_TARGET="$MINIMUM_MACOS"
    export SDKROOT
    SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" || return 1
    CINDER_SWIFT_ARGS=(--arch "$TARGET_ARCH" --sdk "$SDKROOT")
    printf '%s\n' "$xcode" "$swift_version" "SDK: $sdk" "SDK path: $SDKROOT" "Host: $host ($architecture)" "Deployment: $MINIMUM_MACOS"
}

cinder_check_identity() {
    local version
    version="$(tr -d '\r\n' < VERSION)"
    if [ "$version" != "$PUBLIC_VERSION" ]; then echo "VERSION and Build-Identity.sh disagree." >&2; return 1; fi
    if [[ "$PUBLIC_VERSION" != "$MARKETING_VERSION" && "$PUBLIC_VERSION" != "$MARKETING_VERSION"-* ]]; then
        echo "Public and bundle marketing versions disagree." >&2; return 1
    fi
    grep -Fq "public static let version = \"$PUBLIC_VERSION\"" Sources/CinderCore/Models.swift || return 1
    grep -Fq "public static let build = \"$BUILD_VERSION\"" Sources/CinderCore/Models.swift || return 1
    grep -Fq "public static let minimumMacOS = \"$MINIMUM_MACOS\"" Sources/CinderCore/Models.swift || return 1
    grep -Fq ".macOS(\"$MINIMUM_MACOS\")" Package.swift || return 1
}

cinder_check_resources() {
    local directory="$1" candidate manifest index name expected actual resource
    # SwiftPM resource bundles can be flat or use macOS bundle layout. Older
    # copies also used a Resources subdirectory. Do not assume a flat bundle.
    for candidate in "$1" "$1/Resources" "$1/Contents/Resources"; do
        if [ -f "$candidate/lang_en.json" ]; then directory="$candidate"; break; fi
    done
    for resource in lang_en.json lang_ko.json lang_jp.json changelog.json preset-music-v2.json preset-music-credits.txt cinder.png; do
        if [ ! -s "$directory/$resource" ]; then echo "Missing resource: $resource" >&2; return 1; fi
    done
    manifest="$directory/preset-music-v2.json"
    for index in 0 1 2 3 4 5 6; do
        case "$index" in 0) name=classic;; 1) name=balanced;; 2) name=electronic;; 3) name=acoustic;; 4) name=pop;; 5) name=rock;; 6) name=metal;; esac
        expected="$(plutil -extract "presets.$index.sha256" raw -o - "$manifest")" || return 1
        if [ ! -s "$directory/preset-$name.flac" ]; then echo "Missing preset: $name" >&2; return 1; fi
        actual="$(shasum -a 256 "$directory/preset-$name.flac")"; actual="${actual%% *}"
        if [ "$actual" != "$expected" ]; then echo "Preset integrity check failed: $name" >&2; return 1; fi
    done
}
