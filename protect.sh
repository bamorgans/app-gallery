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

# The password page's <title> is the only readable text in the encrypted file,
# and the gallery takes the card name from it, so reuse the app's own title.
# Only the first match: a minified app is one line, and grep -o prints every
# match on the line, including "<title>" inside the app's own scripts (feed
# parsers), which then showed up in the password page's heading.
title="$(grep -o -i -m1 '<title[^>]*>[^<]*' "$src" | head -n1 | sed 's/<[^>]*>//' || true)"
title="${title:-$name}"
# The part before the tagline, as the gallery card does it ("Sideline").
short="$(printf '%s' "$title" | perl -pe 's/\s*(?::|—|–|\s-\s|\|).*//; s/"/&quot;/g')"

# Home-screen tags, so the app can be added to an iPhone's home screen and
# open full-screen under its short name. They go into both the plain app (the
# head an unlocked page ends up with) and the password page, since either may
# be on screen when "Add to Home Screen" is tapped. Each is skipped if the app
# already has it.
#  - Icon: without one, iOS uses bamorgans.github.io's profile photo. It's a
#    relative file, so a downloaded copy just goes without it.
#  - Title: without it, iOS offers the whole <title>, tagline included.
#  - Capable: opens without Safari's toolbars on iOS versions that don't
#    already do so for every home-screen site.
add_home_tags() {
  local tags=""
  [[ -f "$out/icon-180.png" ]] && ! grep -q 'rel="apple-touch-icon"' "$1" && tags+='<link rel="apple-touch-icon" href="icon-180.png">'$'\n'
  grep -q 'name="apple-mobile-web-app-title"' "$1" || tags+="<meta name=\"apple-mobile-web-app-title\" content=\"$short\">"$'\n'
  grep -q 'name="apple-mobile-web-app-capable"' "$1" || tags+='<meta name="apple-mobile-web-app-capable" content="yes">'$'\n'
  # Passed through the environment so nothing in the title is read as Perl.
  [[ -n "$tags" ]] && TAGS="$tags" perl -0pi -e 's{</head>}{$ENV{TAGS}</head>}i' "$1"
  return 0
}
add_home_tags "$tmp/index.html"

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

add_home_tags "$out/index.html"

# The password box must not take focus by itself. iOS ignores focus that
# doesn't come from a tap, and in a home-screen app a box focused that way
# then won't raise the keyboard when tapped either, so the password can't be
# typed at all. Drop the autofocus attribute, and keep the on-load focus()
# for mouse-and-keyboard devices only, where it saves a click.
perl -0pi -e 's/\n\s*autofocus\b//; s/(document\.getElementById\("staticrypt-password"\)\.focus\(\);)/if (!matchMedia("(pointer: coarse)").matches) $1/' "$out/index.html"
grep -q '<input[^>]*autofocus' "$out/index.html" && { echo "Couldn't remove autofocus; StatiCrypt's template may have changed." >&2; exit 1; }
grep -q 'matches) document.getElementById("staticrypt-password").focus();' "$out/index.html" || { echo "Couldn't guard the on-load focus; StatiCrypt's template may have changed." >&2; exit 1; }

# The template's card is a fixed 360px wide with 45px padding, which crowds a
# phone and leaves no margin. Let it shrink, and let the page scroll so iOS
# can move the box above the keyboard.
mobile_css='<style>
.staticrypt-page{width:auto;max-width:360px;padding:max(24px,6vh) 16px 0}
.staticrypt-form{padding:32px 24px;margin-bottom:40vh}
.staticrypt-content,.staticrypt-body,.staticrypt-html{height:auto;min-height:100%}
</style>'
MOBILE_CSS="$mobile_css" perl -0pi -e 's{</head>}{$ENV{MOBILE_CSS}\n</head>}i' "$out/index.html"

# A Cancel button under Decrypt, for someone who opened the app by mistake
# or doesn't have the password: back to where they came from (the gallery),
# or to the gallery itself when the page was opened directly.
cancel='<button type="button" class="staticrypt-cancel-button" onclick="history.length > 1 ? history.back() : location.assign(&#39;../../&#39;)">Cancel</button>'
cancel_css='<style>
.staticrypt-cancel-button{margin-top:10px;width:100%;padding:13px;background:transparent;color:#2b6cb0;border:2px solid #2b6cb0;font-size:14px;text-transform:uppercase;cursor:pointer}
.staticrypt-cancel-button:hover,.staticrypt-cancel-button:focus{background:#2b6cb0;color:#fff;outline:0}
</style>'
CANCEL="$cancel" perl -0pi -e 's{(<input type="submit" class="staticrypt-decrypt-button"[^>]*>)}{$1\n$ENV{CANCEL}}' "$out/index.html"
grep -q 'class="staticrypt-cancel-button"' "$out/index.html" || { echo "Couldn't add the Cancel button; StatiCrypt's template may have changed." >&2; exit 1; }
CANCEL_CSS="$cancel_css" perl -0pi -e 's{</head>}{$ENV{CANCEL_CSS}\n</head>}i' "$out/index.html"

echo "Encrypted → $out/index.html"
