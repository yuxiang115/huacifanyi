#!/usr/bin/env bash
# Package a built Huaci.app into a drag-to-install DMG (with an Applications shortcut).
#
#   scripts/make_dmg.sh path/to/Huaci.app Huaci-0.1.0.dmg
set -euo pipefail

APP="${1:?usage: make_dmg.sh path/to/Huaci.app output.dmg}"
DMG="${2:?usage: make_dmg.sh path/to/Huaci.app output.dmg}"

[ -d "$APP" ] || { echo "no app at $APP" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "Huaci" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "created $DMG ($(du -h "$DMG" | cut -f1))"
