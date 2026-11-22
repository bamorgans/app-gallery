#!/usr/bin/env bash
# Password-protect an app: encrypts private/<name>.html into apps/<name>/index.html.
#
#   ./protect.sh sideline
#   ./protect.sh sideline --short     # extra options go to StatiCrypt
#
# You'll be asked for the password, so it never ends up in shell history.
# Re-run after every edit to the private copy. The unencrypted originals live
# in private/, which is git-ignored: once a plain copy has been pushed to this
# public repo, anyone can read it from the history, even after encrypting.
#
# .staticrypt.json holds the salt. It isn't secret and is committed so the
# salt stays the same across runs; a new salt would sign out everyone who
# ticked "Remember me".
set -euo pipefail
cd "$(dirname "$0")"

name="${1:?usage: ./protect.sh <app-name>   (encrypts private/<app-name>.html)}"
shift
src="private/$name.html"
[[ -f "$src" ]] || { echo "No $src — put the unencrypted app there first." >&2; exit 1; }

# StatiCrypt names its output after the input file, so stage a copy called
# index.html and let it write straight into apps/<name>/.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp "$src" "$tmp/index.html"
mkdir -p "apps/$name"

# The password page's <title> is the only readable text in the encrypted file,
# and the gallery takes the card name from it, so reuse the app's own title.
title="$(grep -o -i -m1 '<title[^>]*>[^<]*' "$src" | sed 's/<[^>]*>//' || true)"
title="${title:-$name}"

npx --yes staticrypt@3.5.4 "$tmp/index.html" \
  -d "apps/$name" \
  --remember 30 \
  --template-title "$title" \
  --template-instructions "This app is private. Enter the password you were given." \
  --template-color-primary "#2b6cb0" \
  --template-color-secondary "#f6f5f2" \
  "$@"

# StatiCrypt can exit 0 without writing anything (e.g. when its short-password
# prompt is declined), so check for the output rather than trusting the status.
[[ -f "apps/$name/index.html" ]] || { echo "Encryption failed: apps/$name/index.html was not written." >&2; exit 1; }
echo "Encrypted → apps/$name/index.html"
