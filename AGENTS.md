# Instructions for AI agents

This repo is a GitHub Pages launcher (<https://bamorgans.github.io/app-gallery/>)
for single-page apps. The repo is **public**, so it holds no app source: only
the gallery itself and the production build of each app.

## Building or changing an app

Not here. Every app's source lives in the private repo
`bamorgans/app-gallery-private`. Its publish workflow minifies each app,
encrypts the password-protected ones, and writes the result into `apps/` here,
along with the app's entry in `gallery.json`. If you were asked to build or
change an app while working in this repo, stop and say it has to be done in
the private repo.

[`SPA-GUIDE.md`](SPA-GUIDE.md) is the build guide for those apps. It lives here
so a chat AI can be pointed at its public URL.

## Changing the gallery

- `index.html` is the gallery page, `scripts/build-catalog.mjs` builds its
  card list, and `protect.sh` is the encryption step the private repo's
  workflow runs.
- Don't edit `apps.js` or `apps.json`. They're generated on deploy by
  `scripts/build-catalog.mjs` and git-ignored.
- `gallery.json` is mostly written by the publish workflow (card details of
  protected apps, `version`, `added`, `updated`, `hash`). Hand edits to card
  details are fine; leave the other fields alone.

## Things never to do

- Never commit secrets, API keys or personal data. The repo is public.
- Never add or edit anything in `apps/` or `admin/`. It's build output, and
  the next publish overwrites it. Above all, never put an app's source here,
  even briefly: once pushed, it stays readable in the public history.

## Checking your work

`./serve.sh` builds the catalogue and serves the gallery at
<http://localhost:8000>. Every card should appear and launch its app, and the
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

Changes to an app happen in the private repo, where every app change bumps
`APP_VERSION` (SPA-GUIDE §3.2.1).
