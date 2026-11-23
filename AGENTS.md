# Instructions for AI agents

This repo is a GitHub Pages launcher (<https://bamorgans.github.io/app-gallery/>)
for single-page apps. The repo is **public**.

## Building or changing an app

Read [`SPA-GUIDE.md`](SPA-GUIDE.md) first and follow it. Its MUST rules are
requirements, not suggestions. Run through its starter checklist (§12) before
you finish.

- A new app goes in `apps/<id>.html`, where `<id>` is short lowercase-kebab
  (`chore-chart`). Use `apps/<id>/index.html` only when the app needs extra
  files such as icons or a service worker.
- The `<head>` must carry the gallery tags from SPA-GUIDE §2 (`<title>`,
  description, `theme-color`, `gallery-tags`). The card is built from them.
- Don't edit `apps.js`. It's generated on deploy by `scripts/build-catalog.mjs`
  and git-ignored. Card overrides go in `gallery.json`.
- Every app shares one origin, so storage keys and cache names must be prefixed
  with the app's `<id>`, and an app must never clear storage it doesn't own.

## Things never to do

- Never commit secrets, API keys or personal data. The repo is public.
- Never put an unencrypted copy of a password-protected app in `apps/`. Those
  originals live in the git-ignored `private/` folder and are published only
  through `./protect.sh <name>`. Sideline is protected: don't edit
  `apps/sideline/index.html` directly, since it's encrypted output.
- Don't break apps you weren't asked to change. If you change one that has a
  service worker (Fretwork), bump `VERSION` in its `sw.js`.

## Checking your work

`./serve.sh` builds the catalogue and serves the gallery at
<http://localhost:8000>. The new card should appear, launch the app, and the
Download link should produce a file that runs on its own.

## Commits

Write commit messages about the change: what and why. No AI attribution
trailers (`Co-Authored-By`, session links) and no "generated with" footers.
