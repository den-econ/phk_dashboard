#!/usr/bin/env bash
# Menyalin dashboard versi terbaru + seluruh file data ke folder docs/ (GitHub Pages).
# Ganti VERSI bila sudah pindah ke versi HTML berikutnya.
set -euo pipefail
VERSI="PHK Early Warning Dashboard — Dewan Ekonomi update v12.html"
HERE="$(cd "$(dirname "$0")" && pwd)"
cp "$HERE/dashboard/$VERSI" "$HERE/docs/index.html"
cp "$HERE"/dashboard/*.js "$HERE/docs/"
echo "docs/ diperbarui dari: $VERSI"
echo "Selanjutnya: git add docs && git commit -m 'update dashboard' && git push"
