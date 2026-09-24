#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source ./Build-Identity.sh
bash Build-App.command
version="$(tr -d '\r\n' < VERSION)"
architectures="$(lipo -archs "dist/$APP_NAME.app/Contents/MacOS/$PRODUCT_NAME")"
case "$architectures" in
    arm64) arch=arm64 ;;
    *) echo "Unexpected architecture: $architectures"; exit 1 ;;
esac
stage="$(mktemp -d "$PWD/.build/cinder-dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/content"
ditto "dist/$APP_NAME.app" "$stage/content/$APP_NAME.app"
ln -s /Applications "$stage/content/Applications"
cp README.md "$stage/content/README.md"
name="${PRODUCT_NAME}-v${version}-${arch}.dmg"
hdiutil create -volname "${PRODUCT_NAME} v${version}" -srcfolder "$stage/content" -format UDZO "$stage/$name"
hdiutil verify "$stage/$name"
mv -f "$stage/$name" "dist/$name"
(cd dist && shasum -a 256 "$name" > "$name.sha256")
echo "Built: $PWD/dist/$name"
