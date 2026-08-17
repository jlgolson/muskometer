# GitHub Pages site (`muskometer.org`)

Static landing page for Muskometer, served from this `/docs` folder.

| File | Purpose |
|------|---------|
| `index.html` | Landing page |
| `styles.css` | Styles |
| `favicon.png` | Favicon |
| `screenshots/app-capture.png` | Popover capture (source for preview/OG composites) |
| `screenshots/app-preview.png` | Landing page screenshot (menu bar + popover) |
| `screenshots/og-image.png` | Open Graph / Twitter card image |
| `screenshots/render-capture.html` | Faithful HTML mock of the 0.1.5 popover (source of `app-capture.png`) |
| `screenshots/render-popover.html` | Menu-bar scene compositing `app-capture.png` → `app-preview.png` |
| `screenshots/render-og.html` | Open Graph layout compositing `app-preview.png` → `og-image.png` |
| `CNAME` | Custom domain (`muskometer.org`) |

## Prerequisites

**The repo must be public** for GitHub Pages on a free plan. The API returns
`Your current plan does not support GitHub Pages for this repository` while the
repo is private. Either make the repo public or use a paid plan that includes
Pages for private repos.

Push `main` with this `docs/` folder before enabling Pages.

## Enable GitHub Pages

### Option A — GitHub UI (recommended)

1. Open **https://github.com/jlgolson/muskometer/settings/pages**
2. Under **Build and deployment** → **Source**, choose **Deploy from a branch**
3. **Branch:** `main` · **Folder:** `/docs` · **Save**
4. Under **Custom domain**, enter `muskometer.org` and save (GitHub will read
   `docs/CNAME` on the next deploy)
5. Enable **Enforce HTTPS** once the certificate is issued (can take up to 24 h)

### Option B — GitHub CLI (after repo is public)

```bash
gh api repos/jlgolson/muskometer/pages -X POST \
  -f "source[branch]=main" \
  -f "source[path]=/docs" \
  -f "build_type=legacy"
```

Then set the custom domain:

```bash
gh api repos/jlgolson/muskometer/pages -X PUT -f cname=muskometer.org
```

## DNS (Squarespace)

`muskometer.org` currently resolves to **Squarespace** (198.49.x / 198.185.x).
Point it at GitHub Pages instead.

### 1. Disconnect Squarespace hosting

In Squarespace: **Settings → Domains → muskometer.org** — remove or disconnect
the domain from any Squarespace site so Squarespace is no longer the web host.
(DNS can stay at Squarespace; only the site binding needs to change.)

### 2. Apex domain (`muskometer.org`)

In **Squarespace → Domains → muskometer.org → DNS Settings**, add **four A
records** for the host `@` (or leave host blank):

| Type | Host | Value |
|------|------|-------|
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |

Remove conflicting A records that point at Squarespace.

### 3. Optional `www` subdomain

| Type | Host | Value |
|------|------|-------|
| CNAME | `www` | `jlgolson.github.io` |

### 4. Verify in GitHub

Back in **Settings → Pages**, GitHub should show **DNS check successful** for
`muskometer.org`. Add any **TXT** verification record GitHub requests if the
check fails.

DNS propagation can take from a few minutes up to 48 hours.

## After launch

- Site URL: **https://muskometer.org**
- Default GitHub URL (before DNS): **https://jlgolson.github.io/muskometer/**
- Edit `index.html` and `styles.css` here; push to `main` to publish.

## Regenerate screenshots

PNGs are the shipped artifact. HTML under `screenshots/render-*.html` is the reviewable
source. Prefer regenerating from the HTML mock (matches the post-0.1.4 popover: single
**Copy** control, **9:30** next-open, market-cap **parity card**, no Post to X, no
comparison caption). A live AppKit capture of the running popover is welcome but not
required.

From the repo root, with Google Chrome installed:

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ROOT="$(pwd)"

# 1. Popover mock → app-capture.png
"$CHROME" --headless=new --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=360,920 \
  --screenshot="$ROOT/docs/screenshots/app-capture.png" \
  "file://$ROOT/docs/screenshots/render-capture.html"

# 2. Menu-bar composite → app-preview.png (depends on step 1)
"$CHROME" --headless=new --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=920,1154 \
  --screenshot="$ROOT/docs/screenshots/app-preview.png" \
  "file://$ROOT/docs/screenshots/render-popover.html"

# 3. Open Graph card → og-image.png (depends on step 2)
"$CHROME" --headless=new --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=1200,630 \
  --screenshot="$ROOT/docs/screenshots/og-image.png" \
  "file://$ROOT/docs/screenshots/render-og.html"
```

If Chrome is unavailable, `docs/screenshots/render-pngs.swift` can snapshot the same HTML
via WKWebView (`swift docs/screenshots/render-pngs.swift <html> <png> <w> <h>`). For
composites that reference local PNGs, inline the prior PNG as a `data:` URL first (file
URLs are blocked in some sandboxed agent environments). Prefer solid page backgrounds in
the HTML mocks — CSS gradients can glitch under WKWebView headless snapshots.

`scripts/verify.sh` rejects `Post to X` and `comparison caption` in `docs/index.html` and
`docs/screenshots/render-*.html` (case-insensitive). It does not OCR the PNGs.

## Local preview

```bash
cd docs && python3 -m http.server 8080
# open http://localhost:8080
```