#!/usr/bin/env bash
# Install Godot and the export templates the headset build needs
# (docs/HLD_HEADSET_BUILD_2026-09-30.md).  Used by the Godot and Pages
# workflows; everything goes under $GODOT_HOME so actions/cache can keep
# it between runs.  Usage: scripts/godot/ci_setup.sh [web|android|all]
set -euo pipefail
VERSION="${GODOT_VERSION:-4.7.1}"
WHAT="${1:-all}"
GODOT_HOME="${GODOT_HOME:-$HOME/godot}"
BASE="https://github.com/godotengine/godot-builds/releases/download"
TPL="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
mkdir -p "$GODOT_HOME" "$TPL"
BIN="$GODOT_HOME/Godot_v${VERSION}-stable_linux.x86_64"
if [ ! -x "$BIN" ]; then
  curl -sSfL -o "$GODOT_HOME/godot.zip" \
    "$BASE/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
  unzip -oq "$GODOT_HOME/godot.zip" -d "$GODOT_HOME"
  rm "$GODOT_HOME/godot.zip"
fi
need=()
case "$WHAT" in
  web) need=(web_nothreads_release.zip web_nothreads_debug.zip) ;;
  android) need=(android_debug.apk android_release.apk android_source.zip) ;;
  *) need=(web_nothreads_release.zip web_nothreads_debug.zip
      android_debug.apk android_release.apk android_source.zip) ;;
esac
missing=()
for f in "${need[@]}" version.txt; do
  [ -f "$TPL/$f" ] || missing+=("templates/$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  # The archive holds every platform (about 1.3 GB); only what this job
  # exports is unpacked.
  curl -sSfL -o "$GODOT_HOME/templates.tpz" \
    "$BASE/${VERSION}-stable/Godot_v${VERSION}-stable_export_templates.tpz"
  unzip -ojq "$GODOT_HOME/templates.tpz" "${missing[@]}" -d "$TPL"
  rm "$GODOT_HOME/templates.tpz"
fi
echo "GODOT=$BIN" >> "${GITHUB_ENV:-/dev/null}"
echo "$BIN"
