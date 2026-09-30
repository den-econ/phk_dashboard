#!/usr/bin/env bash
# Menyalin dashboard HTML terbaru + seluruh file data .js ke folder static/.
# Ganti VERSI bila memakai versi HTML yang lain.
set -euo pipefail
VERSI="PHK Early Warning Dashboard — Dewan Ekonomi update v12.html"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../dashboard"
cp "$SRC/$VERSI" "$HERE/static/index.html"
cp "$SRC"/*.js "$HERE/static/"
echo "static/ diperbarui dari: $VERSI"
