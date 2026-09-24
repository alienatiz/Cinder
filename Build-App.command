#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source ./Build-Identity.sh
source ./Check-Toolchain.sh
cinder_check_toolchain
cinder_check_identity
cinder_check_resources Sources/CinderApp/Resources
version="$PUBLIC_VERSION"
# Development apps use the reviewed Swift 5 source mode plus complete checks.
# The explicit Swift 6 migration probe uses its own scratch directory.
export CINDER_SWIFT6=0
scratch="$PWD/.build/golden-gate-app"
mkdir -p "$scratch"
xcrun swift test "${CINDER_SWIFT_ARGS[@]}" --scratch-path "$scratch/package" 2>&1 | tee "$scratch/tests.log"
xcrun swift build "${CINDER_SWIFT_ARGS[@]}" --scratch-path "$scratch/package" -c release 2>&1 | tee "$scratch/build.log"
bin="$(xcrun swift build "${CINDER_SWIFT_ARGS[@]}" --scratch-path "$scratch/package" -c release --show-bin-path)"
if [ "$(lipo -archs "$bin/Cinder")" != "$TARGET_ARCH" ]; then echo "Expected an arm64 app."; exit 1; fi
stage="$(mktemp -d "$PWD/.build/cinder-app.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/$APP_NAME.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" dist
cp "$bin/Cinder" "$app/Contents/MacOS/$PRODUCT_NAME"
ditto "$bin/Cinder_CinderApp.bundle" "$app/Contents/Resources/Cinder_CinderApp.bundle"
resources="$app/Contents/Resources/Cinder_CinderApp.bundle"
cinder_check_resources "$resources"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleDisplayName</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CinderSettingsDirectory</key><string>$SETTINGS_DIRECTORY</string>
<key>CFBundleExecutable</key><string>$PRODUCT_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$MARKETING_VERSION</string>
<key>CinderPublicVersion</key><string>$version</string>
<key>CinderReleaseChannel</key><string>$RELEASE_CHANNEL</string>
<key>CFBundleVersion</key><string>$BUILD_VERSION</string>
<key>LSMinimumSystemVersion</key><string>$MINIMUM_MACOS</string>
<key>LSArchitecturePriority</key><array><string>$TARGET_ARCH</string></array>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>Cinder</string>
</dict></plist>
PLIST
mkdir -p "$stage/Cinder.iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Sources/CinderApp/Resources/cinder.png --out "$stage/Cinder.iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" Sources/CinderApp/Resources/cinder.png --out "$stage/Cinder.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$stage/Cinder.iconset" -o "$app/Contents/Resources/Cinder.icns"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
if [ -e "dist/$APP_NAME.app" ]; then
    backup="$(mktemp -d "$PWD/.build/previous-app.XXXXXX")"
    mv "dist/$APP_NAME.app" "$backup/"
fi
mv "$app" "dist/$APP_NAME.app"
echo "Built: $PWD/dist/$APP_NAME.app"
echo "Development build: $PUBLIC_VERSION. macOS $MINIMUM_MACOS+, $TARGET_ARCH."
echo "Local ad-hoc signing only. Not Developer ID signed or notarized."
