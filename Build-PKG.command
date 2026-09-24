#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source ./Build-Identity.sh
bash Build-App.command
version="$(tr -d '\r\n' < VERSION)"
pkgbuild --component "dist/$APP_NAME.app" --install-location /Applications --identifier "$BUNDLE_ID" --version "$BUILD_VERSION" "dist/${PRODUCT_NAME}-v${version}-personal.pkg"
echo "Built personal unsigned installer. Installation does not start playback."
