#!/usr/bin/env bash
# Rebuild the catalogue and serve the gallery at http://localhost:8000.
set -euo pipefail
cd "$(dirname "$0")"
node scripts/build-catalog.mjs
echo "Gallery at http://localhost:${1:-8000}  (Ctrl-C to stop)"
python3 -m http.server "${1:-8000}"
