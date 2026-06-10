#!/bin/bash
# Builds Glass.app (via make-app.sh) and packages it into build/Glass.dmg
# with an /Applications symlink for drag-and-drop install.
set -euo pipefail
cd "$(dirname "$0")"

./make-app.sh

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R build/Glass.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f build/Glass.dmg
hdiutil create -volname "Glass" -srcfolder "$STAGING" -ov -format UDZO build/Glass.dmg

echo "Built build/Glass.dmg"
