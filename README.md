# App Gallery

A launcher for my single-page apps, served by GitHub Pages at
<https://bamorgans.github.io/app-gallery/>. Every app lives in this repo under
`apps/<name>/`.

Building a new app? Point your AI agent at [`SPA-GUIDE.md`](SPA-GUIDE.md): the
rules every app here follows (single file, config block, components, data
layer, export/import, touch/TV input, offline). Agents working in this repo
pick it up automatically through `AGENTS.md` (and `CLAUDE.md`, which imports
it). From a phone, give a chat-based AI the raw link:
<https://raw.githubusercontent.com/bamorgans/app-gallery/main/SPA-GUIDE.md>.

## Running it

Online: open <https://bamorgans.github.io/app-gallery/>. Every push to `main`
redeploys it (see `.github/workflows/pages.yml`); the Actions tab shows progress.

On this machine:

```
cd /Volumes/MiniSSD/proj/app-gallery
./serve.sh
```

Then open <http://localhost:8000>. Ctrl-C stops it.

## Adding an app

Every HTML file in `apps/` becomes a card: either a loose file
(`apps/my-app.html`) or a folder (`apps/my-app/index.html`). The list
(`apps.js`) is generated on each deploy by `scripts/build-catalog.mjs`, so
there's nothing else to edit.

**From a phone or tablet:** on github.com open `app-gallery`, tap into the
`apps` folder, then **Add file → Upload files**, pick the HTML file and tap
**Commit changes**. The gallery updates a minute or two later. Give the file a
short lowercase name first (`my-app.html`): it becomes the app's address.

**From this Mac:** copy the file into `apps/`, then commit and push. Use a
folder when the app has extra files such as icons; Fretwork does.

The card's name, description and colour come from the app's own `<title>`,
`<meta name="description">` and `<meta name="theme-color">`. Tags come from
`<meta name="gallery-tags" content="music, guitar">`. An `icon-192.png` in the
folder becomes the card's icon. To change a card without touching the app, add
the folder name to `gallery.json`:

```json
{ "sideline": { "description": "…", "accent": "#b4532a", "tags": ["football"] } }
```

## Updating an app

Replace the app's file and push. On a phone, upload a file with the same name
into the same folder: GitHub replaces the old one. For a protected app, edit
`private/<name>.html` and re-run `./protect.sh <name>`.

Fretwork has a service worker: also bump `VERSION` in `apps/fretwork/sw.js`
when you change it, or installed copies keep serving the old version.

## Password-protecting an app

Protected apps are kept unencrypted in the private repo
[`bamorgans/app-gallery-private`](https://github.com/bamorgans/app-gallery-private),
which this account alone can see. Pushing there encrypts the changed apps and
publishes them here automatically, so they can be edited from a phone,
including by Claude Code on the web. Its README covers adding an app and
changing passwords. The gallery's **Admin** page (footer link) opens every
protected app with one master password.

On this Mac, `private/` is a clone of that repo, and `protect.sh` still works
for local testing:

GitHub Pages can't restrict who sees a page, so protected apps are encrypted
instead (StatiCrypt, AES-256). Only the encrypted file is published. Visitors
get a password box, and a downloaded copy stays encrypted but still works
offline once unlocked.

```
cp ~/Desktop/some-app.html private/some-app.html
./protect.sh some-app        # asks for the password
```

- `private/` is git-ignored. Never put the unencrypted file in `apps/`, even
  briefly: once it's pushed, it stays readable in the public history.
- From a phone, add or edit the app in the private repo instead (see above).
- One password per app. Anyone with it can get in, and revoking a person
  means changing the password and telling everyone else.
- Use a long passphrase. The encrypted file is public, so a short password
  can be guessed offline.
- "Remember me" lasts 30 days. `.staticrypt.json` holds the salt; it isn't
  secret and must stay committed, since a new salt signs everyone out.

## Offline use and storage

Each card has a Download button that saves the app as one HTML file, which
runs from disk with no network. On an iPhone or iPad, where a downloaded HTML
file won't run, the button is **Install** instead: it explains adding the app
to the home screen from Safari. A home-screen app keeps its own storage,
separate from Safari's. Apps must therefore stay self-contained:
inline CSS and JS, with no files loaded relative to the page.

Saved data lives in the browser, and different copies of an app don't see
each other's data:

- The copy on GitHub Pages and a downloaded copy each have their own,
  separate storage. Moving data between them is what each app's
  export and import is for.
- Every app served from `bamorgans.github.io` shares one localStorage,
  about 5 MB in total, and one cache storage. Each app must prefix its keys
  and cache names with its own name (`fretwork-`, `sideline_`/`sb_`, `rp-`)
  and never clear storage it doesn't own.

When real cloud storage arrives, keep each app's reads and writes behind one
small load/save module, so the backend can be swapped in without touching the
rest of the app. Export/import should stay as the offline fallback.
