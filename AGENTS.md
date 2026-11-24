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
  originals live in the private repo `bamorgans/app-gallery-private`, whose
  workflow encrypts and publishes them here. Protected apps (Sideline, Daily
  Fit, and any whose `apps/<name>/index.html` is a StatiCrypt page) and
  `admin/` are encrypted output: don't edit them here. To change one, work in
  the private repo.
- Don't break apps you weren't asked to change. If you change one that has a
  service worker (Fretwork), bump `VERSION` in its `sw.js`.

## Checking your work

`./serve.sh` builds the catalogue and serves the gallery at
<http://localhost:8000>. The new card should appear, launch the app, and the
Download link should produce a file that runs on its own.

## Commits and pull requests

Don't reference AI agents anywhere in the repo's history: no AI attribution
trailers (`Co-Authored-By`, session links), no "generated with" footers, and
no agent or tool names in branch names (`add-ride-scan`, not
`claude/add-ride-scan`). Some tools append a footer to PR descriptions on
their own, so re-read the PR after creating it and remove any footer added.

Commit messages say what changed and why, briefly.

PR descriptions are concise and use these headings:

- **What**: one line on what the PR does.
- **Changes**: the files or areas changed, one bullet each.
- **Why**: the reason for the change.
- **Testing**: how it was checked, and anything not yet checked.
- **Acceptance criteria**: a checklist the reviewer can verify.

Every app change bumps `APP_VERSION` (SPA-GUIDE §3.2.1); put the new version
in the PR title.
