# Building single-page apps for the App Gallery

Rules for building an app that lives in this gallery. Written for an AI coding
agent: follow the **MUST** rules exactly, follow the **SHOULD** rules unless
there's a stated reason not to, and use the code in this guide as the starting
point rather than inventing new patterns.

The rules come from three existing apps in `apps/`:

- **Fretwork**, a guitar trainer with a user library, audio, TV mode and a service worker
- **Ronan's Playbook**, an animated kids' football app built on SVG scenes
- **Sideline**, a fantasy football tool with large embedded data and live feeds

Where one of them shows a pattern well, it's named. Section 13 lists what to
copy from each and what not to repeat.

---

## 1. What an app is

An app is **one self-contained HTML file** that:

1. runs by double-clicking the downloaded file (`file://`) with no network;
2. runs from GitHub Pages at `https://bamorgans.github.io/app-gallery/apps/<id>…`;
3. works with touch, mouse, keyboard and a TV remote (D-pad);
4. keeps user data in the browser and can export it to a file and import it back;
5. reaches all saved data through one data-access layer, so a cloud backend can
   replace browser storage later without touching the rest of the app.

**MUST**
- One `.html` file with all CSS, JS, icons and data inline. No build step, no
  bundler, no npm packages, no CDN `<script>` tags.
- No file loaded by relative path that the app needs to function. Extra files
  such as icons, a manifest or a service worker are allowed only as
  enhancements that fail quietly when missing; Fretwork's are.
- No secrets in the file. The repo is public: no API keys, tokens or personal
  data. A user who needs a key types it into Settings, and it's stored locally
  and left out of exports (see §7).

**SHOULD**
- Stay under about 1.5 MB. Large reference data goes in a JSON data block (§3.4).
- Use the system font stack. Web fonts are allowed only as an enhancement with
  a system fallback named in the same `font-family`.

---

## 2. Gallery integration

The gallery builds each card from the app's own `<head>`. **MUST** include:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>AppName — short tagline</title>          <!-- card name is the text before " — " -->
<meta name="description" content="One sentence shown on the gallery card.">
<meta name="theme-color" content="#127A70">     <!-- card accent colour -->
<meta name="gallery-tags" content="music, guitar">
```

**SHOULD** also give the app its own home-screen icon. Without one, an iPhone
falls back to `bamorgans.github.io/apple-touch-icon.png`, which is the account
site's profile photo:

```html
<link rel="apple-touch-icon" href="data:image/png;base64,…">  <!-- 180×180 PNG -->
```

Inline it as a data URL so the single file keeps working offline. iOS ignores
SVG touch icons, so it has to be a PNG. A folder app may use
`<link rel="apple-touch-icon" href="icon-180.png">` instead; the gallery card
also picks up an `icon-192.png` from the folder.

For a clean install from the gallery's **Install** button (Safari → Share →
Add to Home Screen), also give the home-screen name and full-screen launch.
Without the title, iOS offers the whole `<title>`, tagline included:

```html
<meta name="apple-mobile-web-app-title" content="AppName">
<meta name="apple-mobile-web-app-capable" content="yes">
```

File placement:

- `apps/<id>.html` for a single file. This is what a phone upload produces.
- `apps/<id>/index.html` when the app has optional extras (icons, manifest, `sw.js`).

`<id>` is lowercase-kebab (`ronans-playbook`). It is also the app's `APP_ID`
(§3.2), which prefixes every storage key, cache name and export filename.

Every app on `bamorgans.github.io` **shares one origin**. That means one
`localStorage` of about 5 MB for all apps together, one Cache Storage, and one
IndexedDB namespace. Therefore:

- **MUST** prefix every storage key and cache name with `APP_ID`.
- **MUST NOT** call `localStorage.clear()`, delete caches or databases the app
  doesn't own, or iterate other apps' keys. Fretwork's service worker deletes
  only caches starting with `fretwork-`; copy that.
- **MUST** handle quota errors (§6.4). Another app may have used the space.

---

## 3. File layout

Always this order, with numbered section banners so an agent or a person can
jump around a large file. Ronan's Playbook does this well.

```
<head>   meta (§2) · <style> (§4)
<body>   static shell markup: header, <main id="app">, nav, overlay hosts
         <script type="application/json" id="seed-data"> … </script>   (optional, §3.4)
         <script>  'use strict' app, sections 1–11 below  </script>
```

### 3.1 Script sections

```js
(() => {
'use strict';
/* ===== 1. CONFIG ===== */        everything tunable (§3.2)
/* ===== 2. UTILITIES ===== */     $, esc, html, safeUrl, clamp, debounce, uid
/* ===== 3. STORE ===== */         data-access layer: the ONLY code that touches storage (§6)
/* ===== 4. STATE ===== */         persisted `data` + ephemeral `ui` (§5.1)
/* ===== 5. DOMAIN ===== */        pure logic: no DOM, no storage
/* ===== 6. COMPONENTS ===== */    presentation-only helpers returning markup (§5.3)
/* ===== 7. VIEWS ===== */         one function per screen, composing components
/* ===== 8. ACTIONS ===== */       the action map: every user intent lives here (§5.4)
/* ===== 9. IMPORT / EXPORT ===== */                                     (§7)
/* ===== 10. INPUT & NAVIGATION ===== */  pointer, keyboard, D-pad, back (§8)
/* ===== 11. START ===== */        load → migrate → render → bind
})();
```

Wrap the script in an IIFE with `'use strict'` so nothing leaks onto `window`.
Fretwork's single-letter globals (`S`, `A`, `P`, `F`) and two different things
both named `ctx` are what this prevents. If a debug handle is useful, expose
exactly one: `window[CONFIG.APP_ID] = { state, store }`.

### 3.2 Config block at the top

**MUST**: every value someone might want to change lives here, named and
commented. No storage keys, URLs, timings or limits typed inline elsewhere.
Sideline had six storage keys and a dozen endpoints scattered through 4,600
lines. Ronan's Playbook's `TIMING`/`LEAGUE` blocks are the model.

```js
/* ===== 1. CONFIG ===== */
const CONFIG = Object.freeze({
  APP_ID: 'fretwork',            // storage-key prefix, export filename, cache names
  APP_NAME: 'Fretwork',
  APP_VERSION: '1.4.0',          // shown in Settings; bump on every release
  SCHEMA: 2,                     // version of the saved-data shape; bump + add a migration (§6.3)

  STORAGE: {
    backend: 'local',            // 'local' today; 'remote' when a cloud store exists (§6.5)
    saveDebounceMs: 400,
    keepBackups: 1,              // rotated copies kept before each write (§6.4)
  },

  EXPORT: { maxImportBytes: 5e6 },

  NET: {                         // optional features that need a connection
    timeoutMs: 8000,
    cacheTtlMs: 30 * 60e3,
    cacheMaxEntries: 200,
    endpoints: { search: 'https://example.com/api/search?q=' },
  },

  UI: {
    toastMs: 2300,
    longPressMs: 450,
    idleHideMs: 3500,            // auto-hide controls in TV / full-screen mode
  },

  FEATURES: { tvMode: true, audio: true },
});
```

Design values (colours, spacing, radii) are **not** here; they're CSS custom
properties (§4). When JS needs one, read it back from CSS so there's one
source of truth, as Ronan's Playbook does for its SVG field:

```js
const css = getComputedStyle(document.documentElement);
const token = (name, fallback) => css.getPropertyValue('--' + name).trim() || fallback;
```

### 3.3 Content as data

Lists of things (chords, plays, rules, quiz questions, presets) are **data
tables**, not code. A view renders whatever the table holds. Ronan's Playbook
describes every animation as a declarative scene (`{ actors, ball, marks,
beats }`) played by one generic renderer. That is the strongest pattern in the
three apps; use it whenever an app has many similar items.

### 3.4 Large embedded data

Put large read-only data in a JSON block, not a JS literal. It isn't
executed, it parses quickly, and it can be swapped wholesale. Sideline keeps
1 MB of player data this way, with a `built` date:

```html
<script type="application/json" id="seed-data">{"built":"2026-08-11","players":[…]}</script>
```
```js
function loadSeed() {
  try { return JSON.parse(document.getElementById('seed-data').textContent); }
  catch { return { built: null, items: [] }; }
}
```

Seed data is never saved to storage. Storage holds only the user's own changes.

---

## 4. Styling

**MUST**
- Define design tokens as custom properties on `:root`: surfaces, text, accent,
  status colours, spacing scale, type scale, radii, `--tap: 44px`. No literal
  colours elsewhere in the CSS or in generated SVG.
- Light and dark themes. The default follows the OS, and a user override sets
  `data-theme` on `<html>` and is saved as a preference (§6). **Wire the
  override up:** Fretwork defines `[data-theme]` rules that nothing ever sets,
  and Sideline's two theme functions default to different themes.

```css
:root { --bg:#f6f5f2; --surface:#fff; --text:#1c1c1a; --muted:#6b6a66;
        --accent:#127A70; --accent-ink:#fff; --danger:#b3261e; --focus:#2b6cb0;
        --s1:4px; --s2:8px; --s3:12px; --s4:16px; --s5:24px;
        --r:12px; --tap:44px; color-scheme: light dark; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --bg:#121312; --surface:#1c1d1c; --text:#ecebe7; --muted:#9b9a95; --focus:#7fb0ff; }
}
:root[data-theme="dark"] { --bg:#121312; --surface:#1c1d1c; --text:#ecebe7; --muted:#9b9a95; --focus:#7fb0ff; }
```

- Mobile-first, then widen with `min-width` queries. Handle safe areas with
  `env(safe-area-inset-*)`, and use `100dvh` with a `100vh` fallback.
- A visible focus ring on everything focusable:
  `:focus-visible { outline: 3px solid var(--focus); outline-offset: 2px; }`
- `@media (prefers-reduced-motion: reduce)` turns off CSS animations **and
  transitions**, and JS checks the same query before autoplaying or animating
  (§8.6). Ronan's Playbook disabled transitions but left a keyframe animation
  running.

**SHOULD**
- Style state through ARIA attributes (`.chip[aria-pressed="true"]`) so the
  visual state and the accessible state can't drift apart.
- Use a component class vocabulary (`.btn`, `.btn--primary`, `.chip`, `.card`,
  `.seg`, `.sheet`, `.toast`) shared by every view. Avoid inline `style=""`
  except for computed geometry.

---

## 5. Code structure

### 5.1 Two kinds of state

Copy Fretwork's split:

```js
/* ===== 4. STATE ===== */
const defaultUi = () => ({ view: 'home', selectedId: null, sheet: null, query: '' });
let data;               // persisted user data: loaded from and saved through the store (§6)
let ui = defaultUi();   // ephemeral: never saved, except the few prefs listed in data.prefs
```

- `data` is the only thing that's saved, exported and (later) synced. It has
  one documented shape with a `schema` number.
- `ui` is rebuilt on load. Resetting it is `ui = defaultUi()`.
- Preferences worth keeping (theme, last view, tempo, voice on/off) go in
  `data.prefs`, not in loose extra storage keys.
- Don't hang private fields on data objects (`item._el`). Keep DOM references in
  a separate `Map` keyed by id.

### 5.2 Rendering

Use the simplest model that stays fast:

- **Structure changes:** the view function returns markup, and `render()`
  swaps the view's container.
- **High-frequency updates** (animation frames, playback position, sliders):
  patch only the affected elements with a `paint()` function. Never re-render
  the view 60 times a second. Fretwork's `render()`/`paint()` split is the
  model.
- Re-render **the current view only**, not every view. Sideline's
  `renderAll()` rebuilds five screens after each click.
- **Preserve focus across re-renders,** or keyboard and TV users lose their
  place after every action. Give focusable elements a stable `data-key`:

```js
function render() {
  const key = document.activeElement?.dataset.key;
  $('#app').innerHTML = VIEWS[ui.view]().__raw;          // views return html`` results (§5.3)
  const again = key && $(`[data-key="${CSS.escape(key)}"]`);
  (again || $('#app [autofocus]') || $('#app h1'))?.focus({ preventScroll: true });
}
```

### 5.3 Components: presentation only

A component is a function that takes plain values and returns markup. **It
reads no global state, touches no storage and attaches no listeners.**
Behaviour is declared with `data-act` attributes and handled by the action map
(§5.4).

Interpolated values are escaped by default with a tagged template, so
forgetting `esc()` can't create an injection bug:

```js
/* ===== 2. UTILITIES ===== */
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const raw = (s) => ({ __raw: String(s) });          // only for markup built by html``
const html = (strings, ...vals) => raw(strings.reduce((out, s, i) => {
  const v = vals[i - 1];
  const part = Array.isArray(v) ? v.map((x) => x?.__raw ?? esc(x)).join('')
             : v?.__raw ?? (v === false || v == null ? '' : esc(v));
  return out + part + s;
}));
const safeUrl = (u) => { try { const x = new URL(u, location.href);
  return /^https?:$/.test(x.protocol) ? x.href : ''; } catch { return ''; } };
const $ = (sel, root = document) => root.querySelector(sel);   // null when missing; never a dummy
// Coalesces bursts of calls into one, and every caller awaits the same run.
const debounceAsync = (fn, ms) => { let t, p, res;
  return () => { clearTimeout(t); p ??= new Promise((r) => (res = r));
    t = setTimeout(async () => { const r = res; p = null; r(await fn()); }, ms); return p; }; };
```

Helpers this guide calls but leaves to each app: `toast(text, opts)`,
`confirmSheet(text)` and `chooseSheet(title, options)`, which resolve to the
user's choice and are built on one accessible sheet component, and
`sanitize(data)` and `mergeData(a, b)`, which are specific to each data shape.
```js
/* ===== 6. COMPONENTS ===== */
const Button = ({ label, act, value = '', kind = '', icon = '', key = act + value }) => html`
  <button class="btn ${kind && 'btn--' + kind}" data-act="${act}" data-v="${value}" data-key="${key}">
    ${icon ? Icon(icon) : ''}<span>${label}</span></button>`;

const Chips = ({ act, options, current }) => html`
  <div class="chips" role="group">${options.map((o) => html`
    <button class="chip" data-act="${act}" data-v="${o.value}" data-key="${act}:${o.value}"
            aria-pressed="${String(o.value === current)}">${o.label}</button>`)}</div>`;

const Empty = (text, action) => html`<div class="empty"><p>${text}</p>${action || ''}</div>`;
const Link  = (href, text) => html`<a href="${safeUrl(href)}" target="_blank" rel="noopener">${text}</a>`;
```

Rules:
- **One component per UI idea, used everywhere.** If two screens show a chip
  list, both use `Chips`. Fretwork's `seg()` sets `aria-pressed` but its
  hand-written chip lists don't. Sideline's `C.link`, used for every player
  name, is the model.
- Icons are inline SVG from one `ICONS` map. A missing name throws in
  development rather than rendering blank; Sideline shipped a blank delete
  button because `ico('trash')` wasn't in its map.
- `$` returns `null` for a missing element. Never a dummy object that silently
  swallows calls, as Sideline's does.
- Building DOM with a hyperscript helper `h(tag, props, children)` and
  `textContent`, as Ronan's Playbook does, is equally acceptable and needs no
  escaping. Pick one style per app.

### 5.4 Actions: one map, delegated events

Every user intent is a named function in one object. A single delegated
listener per event type routes to it. Never attach listeners in components;
avoid one big `bind()` that wires individual ids (Sideline's ran to 440 lines).

```js
/* ===== 8. ACTIONS ===== */
const ACTIONS = {
  'go':          (v) => { ui.view = v; render(); },
  'select':      (v) => { ui.selectedId = v; render(); },
  'item-delete': async (v) => {
    if (!(await confirmSheet('Delete this item?'))) return;
    data.items = data.items.filter((i) => i.id !== v);
    await save(); render(); toast('Deleted');
  },
  'export':      () => exportData(),
  'import-file': (_, el) => { importFile(el.files[0]); el.value = ''; },   // <input type="file" data-act-change="import-file">
};

for (const type of ['click', 'change', 'input', 'submit']) {
  document.addEventListener(type, (e) => {
    const el = e.target.closest(`[data-act${type === 'click' ? '' : '-' + type}]`);
    if (!el) return;
    const name = type === 'click' ? el.dataset.act : el.dataset['act' + type[0].toUpperCase() + type.slice(1)];
    const fn = ACTIONS[name];
    if (!fn) return console.warn('No action', name);
    if (type === 'click' || type === 'submit') e.preventDefault();
    fn(el.dataset.v, el, e);
  });
}
```

`<input data-act-input="search">` uses the same map. Actions change state,
call the store, then `render()` or `paint()`. **Views never mutate state.**
Fretwork clamped state inside a view function.

### 5.5 Navigation and the back button

Keep the current view in the URL hash (`#/songs`, `#/song/abc123`) so reload,
deep links and the back button work. Map the Back key on TV remotes to the
same handler (§8.4). Sideline's `#p/<id>` links don't work because nothing
listens for `hashchange`.

```js
const route = () => { const [view = 'home', id = null] = location.hash.slice(2).split('/');
                      ui.view = VIEWS[view] ? view : 'home'; ui.selectedId = id; render(); };
addEventListener('hashchange', route);
```

### 5.6 Comments

Comments explain **constraints and decisions**: why the code is this way and
what breaks if it changes. Examples from Ronan's Playbook: "must run inside a
tap", and "some engines drop speak() in the same tick as cancel()". Don't
narrate history or authorship.

---

## 6. Data access layer

**MUST**: the store module is the *only* code that touches `localStorage`,
IndexedDB, Cache Storage or any future remote API. Views, components and
domain logic call repository functions (`loadData`, `saveData`), never storage
directly. All three existing apps scatter storage calls; this is the main
thing to do better.

### 6.1 Async from day one

The store API returns Promises even though `localStorage` is synchronous. A
future cloud backend is async, and an async API now means no call site has to
change when it arrives.

### 6.2 Shape

```js
/* ===== 3. STORE ===== */
// Backends implement get/set/remove for string values under the app's prefix.
const backends = {
  local: {
    async get(k)    { try { return localStorage.getItem(k); } catch { return null; } },
    async set(k, v) { localStorage.setItem(k, v); },          // throws on quota; caller handles it
    async remove(k) { try { localStorage.removeItem(k); } catch {} },
  },
  // remote: { get, set, remove } — added when a cloud store exists (§6.5)
};

const store = (() => {
  const be = backends[CONFIG.STORAGE.backend];
  const key = (name) => `${CONFIG.APP_ID}:${name}`;           // e.g. "fretwork:data"
  return {
    async read(name) {
      const s = await be.get(key(name));
      if (s == null) return null;
      try { return JSON.parse(s); }
      catch { await be.set(key(name + ':corrupt'), s).catch(() => {}); return undefined; }
    },
    async write(name, value) {
      const s = JSON.stringify(value);
      try {
        const prev = await be.get(key(name));
        if (prev && prev !== s && CONFIG.STORAGE.keepBackups) await be.set(key(name + ':bak'), prev);
        await be.set(key(name), s);
        return true;
      } catch (e) {
        toast('Couldn’t save — storage is full. Export a backup now.', { action: 'export' });
        return false;
      }
    },
    remove: (name) => be.remove(key(name)),
  };
})();
```

Repository functions sit on top and own the data shape:

```js
async function loadData() {
  let d = await store.read('data');
  if (d === undefined) {                               // corrupt: try the backup
    d = await store.read('data:bak');
    if (d) toast('Recovered your data from a backup.');
  }
  return migrate(d ?? emptyData());
}
const save = debounceAsync(() => store.write('data', data), CONFIG.STORAGE.saveDebounceMs);
addEventListener('pagehide', () => store.write('data', data));     // flush on leave
document.addEventListener('visibilitychange', () => document.hidden && store.write('data', data));
```

### 6.3 Schema versions and migrations

Saved data always carries `schema`. On load, run migrations in order. Never
throw away data you don't understand; keep unknown fields.

```js
const emptyData = () => ({ schema: CONFIG.SCHEMA, items: [], prefs: { theme: 'auto' } });
const MIGRATIONS = {
  // 1 → 2: songs gained a bpm field
  2: (d) => ({ ...d, items: d.items.map((s) => ({ bpm: 90, ...s })) }),
};
function migrate(d) {
  const from = d.schema || 1;            // read before merging defaults, which carry the current schema
  d = { ...emptyData(), ...d, prefs: { ...emptyData().prefs, ...d.prefs } };
  for (let v = from + 1; v <= CONFIG.SCHEMA; v++) if (MIGRATIONS[v]) d = MIGRATIONS[v](d);
  d.schema = CONFIG.SCHEMA;
  return sanitize(d);                                   // the same validator import uses (§7)
}
```

Merging defaults on load, as Sideline's `hydrate()` does, means new settings
appear without a migration. Migrations are for changes in shape.

### 6.4 Robustness rules

- **Never overwrite data you failed to read.** Fretwork treats corrupt JSON as
  "no data", and its next save overwrites what might have been recoverable.
  The store above moves it aside to `:corrupt`.
- Keep one rotated backup (`:bak`) and restore from it with a visible message.
  Sideline keeps two, which triples its storage use; one is enough when export
  exists.
- **Tell the user when a save fails,** and offer Export. Never use a silent
  `catch {}` on writes.
- Validate everything read from storage with the same `sanitize()` used for
  imports. Storage can be edited by hand, or written by an older version.
- Caches of network responses use a separate key prefix
  (`<APP_ID>:cache:<k>`), store `{ t, d }`, enforce `NET.cacheTtlMs` **and**
  `NET.cacheMaxEntries` (evict the oldest), and are never exported. Sideline's
  cache has no size limit.
- "Clear cache" removes only cache keys. "Erase everything" removes only this
  app's keys, after a confirm that says what will be lost, and offers Export
  first.

### 6.5 Planning for real storage

When a cloud backend arrives, it becomes a new entry in `backends` with the
same `get/set/remove` contract, or a sync layer behind `loadData`/`save`.
Nothing outside the store changes. Until then:

- Make every record identifiable: a stable `id` (`crypto.randomUUID()` with a
  fallback), plus `updatedAt` (ISO string) on records the user edits. That
  makes later sync and import-merge possible.
- Keep `data` JSON-serialisable: no `Date` objects, `Map`s, functions or DOM
  references.
- Keep export/import working even after sync exists. It's the offline and
  disaster-recovery path.

---

## 7. Export and import

**MUST**: every app with any user data has Export and Import in its Settings
(or equivalent) screen. An app with no persistent data says so instead of
showing the buttons.

### 7.1 The file format

```json
{
  "app": "fretwork",
  "schema": 2,
  "appVersion": "1.4.0",
  "exported": "2026-11-22T18:04:00.000Z",
  "data": { "items": [], "prefs": {} }
}
```

- The filename is `<APP_ID>-backup-YYYY-MM-DD.json`.
- Pretty-print it (2-space indent) so a person can read it.
- **Never include secrets or caches.** API keys, tokens and `cache:` entries
  are stripped before export. Sideline's exports carry the user's API keys.

### 7.2 Export

```js
/* ===== 9. IMPORT / EXPORT ===== */
const SECRET_FIELDS = ['apiKey', 'token'];
function exportData() {
  const clean = JSON.parse(JSON.stringify(data, (k, v) => SECRET_FIELDS.includes(k) ? undefined : v));
  const { schema, ...rest } = clean;
  const file = { app: CONFIG.APP_ID, schema, appVersion: CONFIG.APP_VERSION,
                 exported: new Date().toISOString(), data: rest };
  const name = `${CONFIG.APP_ID}-backup-${new Date().toISOString().slice(0, 10)}.json`;
  const blob = new Blob([JSON.stringify(file, null, 2)], { type: 'application/json' });
  const f = new File([blob], name, { type: 'application/json' });
  if (navigator.canShare?.({ files: [f] }) && matchMedia('(pointer: coarse)').matches) {
    return navigator.share({ files: [f], title: name }).catch(() => download(blob, name));
  }
  download(blob, name);
}
function download(blob, name) {
  const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: name });
  document.body.append(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}
```

On phones, the share sheet lets the user save the file to Files or Drive, or
send it to themselves. Fretwork offers both routes.

### 7.3 Import

**MUST**
- Accept a file from a visible button. Use a `<label class="btn">` wrapping a
  hidden `<input type="file" accept=".json,application/json">`, and reset
  `input.value = ''` afterwards so the same file can be picked twice. Drag and
  drop onto the window is a bonus.
- Reject files over `CONFIG.EXPORT.maxImportBytes`.
- **Check `app` and `schema`.** Refuse another app's file with a clear message.
  Migrate an older schema with the same `MIGRATIONS`. Refuse a newer schema
  ("This backup is from a newer version"). Neither Fretwork nor Sideline
  checks these fields.
- **Sanitize every field** with type checks, length limits, numeric ranges and
  `safeUrl` for links. Fretwork's `cleanLib()` is the model: it clamps frets to
  −1..24, checks strum strings against a pattern and bounds bpm to 40–220.
- Let the user choose **Merge** (add new items, dedupe by `id` or a natural
  key) or **Replace**. Show what will happen ("Adds 12 songs, replaces
  settings") and confirm Replace.
- Take a `:bak` snapshot before applying, then save, re-render and report the
  result in a toast.

```js
async function importFile(file) {
  if (!file) return;
  if (file.size > CONFIG.EXPORT.maxImportBytes) return toast('That file is too large.');
  let f;
  try { f = JSON.parse(await file.text()); } catch { return toast('That isn’t a backup file.'); }
  if (f?.app !== CONFIG.APP_ID) return toast(`That backup is for ${f?.app || 'another app'}.`);
  if ((f.schema || 1) > CONFIG.SCHEMA) return toast('That backup is from a newer version.');
  const incoming = migrate({ ...f.data, schema: f.schema || 1 });
  const mode = await chooseSheet('Import backup', [['merge', 'Merge with my data'], ['replace', 'Replace my data']]);
  if (!mode) return;
  await store.write('data:bak', data);
  data = mode === 'replace' ? incoming : mergeData(data, incoming);
  await save(); render(); toast('Backup imported.');
}
```

CSV import and export are welcome where the data is tabular, as in Sideline's
draft results. Quote fields properly, and match headers by name, not position.

---

## 8. Input: touch, pointer, keyboard and TV

Every feature must be usable with **each** of: a finger, a mouse, a keyboard,
and a TV remote that has only arrows, OK/Enter and Back.

### 8.1 Use native controls

- Anything clickable is a `<button>` or `<a href>`. Never a `<div onclick>`, and
  never a click-only SVG `<g>`. Fretwork's fretboard dots can't be reached by
  keyboard. For an SVG target, put `tabindex="0"`, `role="button"` and
  `aria-label` on it, and handle Enter and Space.
- Form controls have a `<label>`.

### 8.2 Touch

- Targets are at least `var(--tap)` (44px) in both directions. Fretwork's
  segmented buttons (38px) and Ronan's Playbook's pills (38px) are too small.
- `touch-action: manipulation` on controls (removes the double-tap zoom delay).
  On swipe surfaces use `touch-action: pan-y`, so vertical scrolling still
  works and the app handles horizontal swipes.
- Use **Pointer Events** (`pointerdown/move/up`) rather than separate touch and
  mouse handlers. That way one code path covers finger, mouse and pen.
- Every gesture has a visible alternative. A swipe has Prev/Next buttons; a
  long-press menu also opens from a "⋯" button and from right-click
  (Sideline maps `contextmenu` to its long-press sheet).
- Ignore fake pointer moves, which some touch browsers fire on tap. Ronan's
  Playbook applies a 6px threshold before treating a move as real.

### 8.3 Mouse and pointer

- Hover effects only inside `@media (hover: hover) and (pointer: fine)`. Never
  put information or actions *only* in a hover state.
- Show the pointer cursor on clickable non-buttons.

### 8.4 Keyboard and TV remote (D-pad)

TV browsers and remotes send arrow keys, `Enter`, and a Back key (`Escape`,
`Backspace`, `GoBack` or `BrowserBack`, depending on the device).

**MUST**
- Arrow keys move focus spatially between focusable elements, so a D-pad can
  reach every control. Include this helper:

```js
/* ===== 10. INPUT & NAVIGATION ===== */
const FOCUSABLE = 'button:not([disabled]),a[href],input,select,textarea,[tabindex]:not([tabindex="-1"])';
const DIRS = { ArrowUp: [0, -1], ArrowDown: [0, 1], ArrowLeft: [-1, 0], ArrowRight: [1, 0] };

function moveFocus(dir) {
  const scope = $('.sheet[open]') || document;          // stay inside an open dialog
  const items = [...scope.querySelectorAll(FOCUSABLE)].filter((el) => el.offsetParent !== null);
  const cur = document.activeElement;
  if (!items.includes(cur)) return items[0]?.focus();
  const a = cur.getBoundingClientRect(), [dx, dy] = DIRS[dir];
  const ax = a.left + a.width / 2, ay = a.top + a.height / 2;
  let best = null, bestScore = Infinity;
  for (const el of items) {
    if (el === cur) continue;
    const b = el.getBoundingClientRect(), bx = b.left + b.width / 2, by = b.top + b.height / 2;
    const along = (bx - ax) * dx + (by - ay) * dy;       // distance in the pressed direction
    if (along <= 1) continue;
    const across = Math.abs((bx - ax) * dy) + Math.abs((by - ay) * dx);
    const score = along + across * 2;                    // prefer elements straight ahead
    if (score < bestScore) { best = el; bestScore = score; }
  }
  best?.focus(); best?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
}

const BACK_KEYS = ['Escape', 'Backspace', 'GoBack', 'BrowserBack'];
document.addEventListener('keydown', (e) => {
  const typing = e.target.matches('input,textarea,select,[contenteditable]');
  if (DIRS[e.key] && !typing && !e.altKey && !e.metaKey && !e.ctrlKey) {
    if (handleViewKey?.(e)) return;                      // a view may claim arrows (e.g. scrub a timeline)
    e.preventDefault(); moveFocus(e.key);
    document.documentElement.classList.add('kbd-nav');
  } else if (BACK_KEYS.includes(e.key) && !(typing && e.key === 'Backspace')) {
    if (goBack()) e.preventDefault();                    // close sheet → leave detail → previous view
  }
});
document.addEventListener('pointerdown', () => document.documentElement.classList.remove('kbd-nav'));
```

- `goBack()` closes the top overlay first, then the detail view, then follows
  history. At the home screen it returns `false` so the platform can exit.
- After `render()`, focus is restored (§5.2) or moved to the view's main
  heading or first control. Focus must never end up on `<body>` while a TV
  user is navigating.
- Dialogs and sheets move focus inside on open, keep Tab and arrows inside
  (`inert` on the background is simplest), and return focus to the opener on
  close. None of the three apps does all of this.
- Media and playback keys: Space/Enter (or `k`) toggles play, and arrows seek
  or change value **only when the player has focus**. Fretwork's TV mode is a
  good model: it focuses Play on open and hides its controls when idle, then
  wakes them on any key or pointer movement.

**SHOULD**
- `html.kbd-nav` enlarges focus rings (`outline-width: 4px`) for ten-foot
  viewing.
- Offer a TV or presentation layout (larger type through `clamp()`/`vmin`,
  fewer controls) when a TV is likely: a `?tv=1` URL flag, a Settings toggle,
  or the first arrow-key press on a large screen.
- Roving `tabindex` (arrows within a tab bar or grid, Tab to leave it) where a
  group has many items. The spatial helper above is the fallback that always
  works.

### 8.5 Full screen and screen wake

Wrap these APIs with feature detection, webkit prefixes, Promise and
non-Promise returns, and a CSS fallback class for iPhone, which has no element
fullscreen. Ronan's Playbook does all of that, and it listens for
`fullscreenchange` so the UI stays in sync when the browser exits on its own.
Request fullscreen, orientation lock, audio unlock and speech only **inside a
user gesture**. Re-acquire a Wake Lock on `visibilitychange`, as Fretwork does.

### 8.6 Motion and background tabs

- Check `matchMedia('(prefers-reduced-motion: reduce)')` before autoplaying
  animations or smooth-scrolling.
- Pause animation loops, audio scheduling and polling when
  `document.hidden`. Ronan's Playbook pauses on `visibilitychange`.
- Clamp the frame delta in `requestAnimationFrame` loops
  (`Math.min(100, ts - last)`), so returning to the tab doesn't jump the
  animation.

---

## 9. Offline and downloadable

**MUST**
- The app's core works with no network, opened from `file://`. Network
  features (search, live data, images from CDNs) are enhancements:
  - Wrap every `fetch` with a timeout using `AbortController` and
    `NET.timeoutMs`. Sideline has no timeouts.
  - Use `Promise.allSettled` for parallel requests, so one failure doesn't
    sink the rest.
  - Show honest state ("Offline — using built-in data", "Updated 5 min ago").
    Sideline's persistent live/stale indicator is better than a passing toast.
  - Images from the network have a local fallback, such as initials or an
    inline SVG badge. Sideline's image chain ends in a local SVG.

```js
async function fetchJSON(url, { timeoutMs = CONFIG.NET.timeoutMs } = {}) {
  const ctrl = new AbortController(), t = setTimeout(() => ctrl.abort(), timeoutMs);
  try { const r = await fetch(url, { signal: ctrl.signal });
        if (!r.ok) throw new Error(`HTTP ${r.status}`); return await r.json(); }
  finally { clearTimeout(t); }
}
```

- A service worker is optional. If present: register it only over http(s)
  (`/^https?:$/.test(location.protocol)`), name caches `<APP_ID>-v<n>`, delete
  only caches with that prefix, and use network-first for the app's own files
  so updates show up. Tie the cache version to `CONFIG.APP_VERSION` rather
  than a second hand-edited number in `sw.js`.
- Remember that the hosted copy and a downloaded copy have **separate
  storage**: different origins. Export/import is how data moves between them.
  Say so in the Settings screen near the buttons.

---

## 10. Accessibility

- `lang` on `<html>`. Landmarks: `header`, `nav`, `main`.
- Each screen has one `h1`.
- Toggles use `aria-pressed`. Tabs use `role="tablist"/"tab"/"tabpanel"` with
  `aria-selected` and `aria-controls`, or are plain buttons with
  `aria-current`. Don't use half the tab pattern, which two of the three apps
  do.
- Live regions announce results: toasts are `role="status"`, errors are
  `role="alert"`, and quiz feedback and "now playing" are `aria-live="polite"`.
  Right and wrong are never shown by colour alone.
- SVG pictures have `role="img"` and an `aria-label`. Decorative icons and emoji
  are `aria-hidden="true"`.
- `aria-label` values are human words, never internal ids. Fretwork labels a
  section "progs".

---

## 11. Security

- Interpolate only through `html\`\`` or `esc()`; use `textContent` for DOM-built
  nodes. No `eval`, no `new Function`, no inline `on…=""` attributes in
  generated markup.
- Every user- or network-supplied URL goes through `safeUrl()`, which allows
  only `http:` and `https:`, before landing in `href` or `src`. Escaping alone
  doesn't stop a `javascript:` link. Sideline escapes feed links but doesn't
  check the scheme.
- External links get `rel="noopener"`.
- To restrict who can open an app, use `protect.sh` (StatiCrypt encryption, see
  the README). Never commit an unencrypted private app, not even briefly.

---

## 12. Starter checklist

Before calling an app done, verify each point:

- [ ] One HTML file; opens from `file://` with Wi-Fi off and core features work
- [ ] `<title>`, `description`, `theme-color`, `gallery-tags` set (§2)
- [ ] `CONFIG` block at the top; no storage keys, URLs or timings inline elsewhere
- [ ] Every storage key and cache name starts with `APP_ID`; no `localStorage.clear()`
- [ ] All storage goes through the store module; the store API is async
- [ ] Saved data has `schema`; migrations run on load; corrupt data is kept aside, not overwritten
- [ ] A failed save shows a message offering Export
- [ ] Export writes `{ app, schema, appVersion, exported, data }` with no secrets or caches
- [ ] Import checks `app` and `schema`, sanitizes every field, offers Merge or Replace, keeps a backup
- [ ] Components are presentation-only; all behaviour goes through the `data-act` action map
- [ ] All interpolation escaped; URLs go through `safeUrl`
- [ ] Light and dark themes both work; the user override is wired up and saved
- [ ] Every control is reachable and usable with arrows + Enter + Back alone; focus survives re-render
- [ ] Dialogs trap focus and return it on close
- [ ] Touch targets ≥ 44px; every gesture has a button alternative; no hover-only features
- [ ] Reduced motion respected in CSS **and** JS; loops pause when the tab is hidden
- [ ] Every `fetch` has a timeout and an offline fallback with an honest status message
- [ ] Hash routing: reload and the back button return to the same screen

---

## 13. Lessons from the existing apps

| Copy this | From | Section |
|---|---|---|
| Numbered section banners; `TIMING`/`LEAGUE` config objects with commented flags | Ronan's Playbook | §3 |
| Content as data tables; declarative scenes played by one renderer | Ronan's Playbook | §3.3 |
| Reading design tokens from CSS into JS (`tok()`) | Ronan's Playbook | §3.2 |
| Never using `innerHTML`; `h()` + `textContent` | Ronan's Playbook | §5.3 |
| Robust fullscreen wrapper, `visibilitychange` pause, clamped frame delta | Ronan's Playbook | §8.5–8.6 |
| `data-act` action map with delegated listeners | Fretwork | §5.4 |
| Persisted `lib` vs ephemeral `S` with a `defaultState()` factory | Fretwork | §5.1 |
| `render()` for structure, `paint()` for high-frequency updates | Fretwork | §5.2 |
| `cleanLib()`: sanitizing every imported field with ranges and patterns | Fretwork | §7.3 |
| Export with Web Share and download fallback; Merge/Replace on import | Fretwork | §7 |
| Service worker cleans up only its own prefixed caches | Fretwork | §9 |
| TV mode: focus Play on open, idle auto-hide, wake on key or pointer | Fretwork | §8.4 |
| Large data in `<script type="application/json">` with a `built` date | Sideline | §3.4 |
| try/catch storage wrapper; backup before write; restore chain with a message | Sideline | §6.4 |
| Merging `DEFAULTS` on load; legacy-key migration | Sideline | §6.3 |
| `Promise.allSettled` + honest offline indicator; image fallback ending in local SVG | Sideline | §9 |
| A small component library (`C.link`, `C.btn`, `C.empty`) used everywhere | Sideline | §5.3 |
| Prefix-scoped "clear cache" vs confirmed "erase everything" | Sideline | §6.4 |

| Avoid this | Seen in | Instead |
|---|---|---|
| Storage keys, endpoints and magic numbers scattered through the file | all three | `CONFIG` (§3.2) |
| `localStorage` called from many places | all three | store module (§6) |
| Silent `catch {}` on save; corrupt data overwritten | Fretwork | §6.4 |
| Import ignores the file's `app`/version fields | Fretwork, Sideline | §7.3 |
| API keys included in exports | Sideline | §7.1 |
| Cache with no size limit; fetch with no timeout | Sideline | §6.4, §9 |
| Re-rendering every view after each change; 440-line `bind()` | Sideline | §5.2, §5.4 |
| `$` returning a dummy object; missing icon rendering blank | Sideline | §5.3 |
| Hash links with no router; reload always opens the first tab | Sideline, Fretwork | §5.5 |
| Single-letter globals; shadowed names (`ctx`, `C`) | Fretwork, Ronan's Playbook | §3.1 |
| Theme hooks that nothing sets; theme defaults that disagree | Fretwork, Sideline | §4 |
| Click-only SVG targets; no focus management; half-implemented tab roles | all three | §8.4, §10 |
| Touch targets under 44px | Fretwork, Ronan's Playbook | §8.2 |
| Reduced motion handled only for transitions | Ronan's Playbook | §4, §8.6 |
| Personal data hard-coded as first-run defaults | Sideline | §1 |
