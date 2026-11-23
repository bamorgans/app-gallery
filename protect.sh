#!/usr/bin/env bash
# Password-protect an app: encrypts private/<name>.html into apps/<name>/index.html.
#
#   ./protect.sh sideline
#   ./protect.sh sideline --short     # extra options go to StatiCrypt
#   PROTECT_OUT=admin ./protect.sh admin --short   # write somewhere other than apps/<name>
#
# You'll be asked for the password unless STATICRYPT_PASSWORD is set, so it
# never ends up in shell history. Re-run after every edit to the private copy.
# The unencrypted originals live in private/, a clone of the private
# app-gallery-private repo that this repo ignores: once a plain copy has been
# pushed to this public repo, anyone can read it from the history, even after
# encrypting. That repo's publish workflow runs this script too.
#
# .staticrypt.json holds the salt. It isn't secret and is committed so the
# salt stays the same across runs; a new salt would sign out everyone who
# ticked "Remember me".
set -euo pipefail
cd "$(dirname "$0")"

name="${1:?usage: ./protect.sh <app-name>   (encrypts private/<app-name>.html)}"
shift
src="private/$name.html"
out="${PROTECT_OUT:-apps/$name}"
[[ -f "$src" ]] || { echo "No $src — put the unencrypted app there first." >&2; exit 1; }

# StatiCrypt names its output after the input file, so stage a copy called
# index.html and let it write straight into the output folder.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp "$src" "$tmp/index.html"
mkdir -p "$out"
# Removed first so the check below can't be fooled by the previous version.
rm -f "$out/index.html"

# Home-screen icon. Without one, iOS uses bamorgans.github.io's profile photo.
# The link goes into both the plain app (the head an unlocked page ends up
# with) and the password page. It's a relative file, so a downloaded copy just
# goes without it.
icon_link='<link rel="apple-touch-icon" href="icon-180.png">'
add_icon() { [[ -f "$out/icon-180.png" ]] && ! grep -q 'rel="apple-touch-icon"' "$1" && perl -0pi -e "s{</head>}{$icon_link\n</head>}i" "$1"; return 0; }
add_icon "$tmp/index.html"

# The password page's <title> is the only readable text in the encrypted file,
# and the gallery takes the card name from it, so reuse the app's own title.
title="$(grep -o -i -m1 '<title[^>]*>[^<]*' "$src" | sed 's/<[^>]*>//' || true)"
title="${title:-$name}"

npx --yes staticrypt@3.5.4 "$tmp/index.html" \
  -d "$out" \
  --remember 30 \
  --template-title "$title" \
  --template-instructions "This app is private. Enter the password you were given." \
  --template-color-primary "#2b6cb0" \
  --template-color-secondary "#f6f5f2" \
  "$@"

# StatiCrypt can exit 0 without writing anything (e.g. when its short-password
# prompt is declined), so check for the output rather than trusting the status.
[[ -f "$out/index.html" ]] || { echo "Encryption failed: $out/index.html was not written." >&2; exit 1; }

# "Remember me" is saved in localStorage, which every app on this origin
# shares. StatiCrypt's default key is the same for every page, so unlocking
# one protected app would overwrite (and then fail) another's saved password.
# Give each app its own key; the template marks these values as editable.
perl -pi -e "s/rememberExpirationKey: \"staticrypt_expiration\"/rememberExpirationKey: \"$name:staticrypt_expiration\"/; s/rememberPassphraseKey: \"staticrypt_passphrase\"/rememberPassphraseKey: \"$name:staticrypt_passphrase\"/" "$out/index.html"
grep -q "\"$name:staticrypt_passphrase\"" "$out/index.html" || { echo "Couldn't set the Remember-me key; StatiCrypt's template may have changed." >&2; exit 1; }

add_icon "$out/index.html"
echo "Encrypted → $out/index.html"
