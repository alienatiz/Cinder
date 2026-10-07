#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source ./Build-Identity.sh
source ./Check-Toolchain.sh
cinder_configure_app_build "$@"
bash Build-App.command "$@"
version="$(tr -d '\r\n' < VERSION)"
architectures="$(lipo -archs "$CINDER_APP_OUTPUT/$APP_NAME.app/Contents/MacOS/$PRODUCT_NAME")"
if [ "$architectures" != "$TARGET_ARCH" ]; then echo "Unexpected architecture: $architectures"; exit 1; fi
arch="$architectures"
if [ "$CINDER_BUILD_VARIANT" = intel-experimental ]; then arch="$arch-experimental"; fi
stage="$(mktemp -d "$PWD/.build/cinder-dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/content"
ditto "$CINDER_APP_OUTPUT/$APP_NAME.app" "$stage/content/$APP_NAME.app"
ln -s /Applications "$stage/content/Applications"
cp "$CINDER_INSTALL_GUIDE" "$stage/content/README.md"
name="${PRODUCT_NAME}-v${version}-${arch}.dmg"
hdiutil create -volname "${PRODUCT_NAME} v${version}" -srcfolder "$stage/content" -format UDZO "$stage/$name"
hdiutil verify "$stage/$name"
mv -f "$stage/$name" "$CINDER_APP_OUTPUT/$name"
(cd "$CINDER_APP_OUTPUT" && shasum -a 256 "$name" > "$name.sha256")
echo "Built: $CINDER_APP_OUTPUT/$name"
