# Releasing Muskometer

Guide for maintainers shipping builds to [GitHub Releases](https://github.com/jlgolson/muskometer/releases).

## Unsigned DMG (free — no Apple Developer Program)

```bash
./scripts/package-dmg.sh
```

Builds a Release `.app`, then outputs:

- `dist/Muskometer-<version>.dmg`
- `dist/Muskometer-<version>.zip`

No signing or notarization. Tell users to **right-click → Open** on first launch. This is what we ship today.

Upload:

```bash
git tag v0.1.0 && git push origin v0.1.0
gh release create v0.1.0 dist/Muskometer-0.1.0.dmg dist/Muskometer-0.1.0.zip --title "Muskometer 0.1.0"
```

## Signed + notarized DMG ($99/year Apple Developer Program)

End users get a normal double-click install. The release pipeline:

1. **Archive** a Release build with your **Developer ID Application** certificate
2. **Export** as `developer-id`
3. Package **`dist/Muskometer-<version>.dmg`** (drag-to-Applications layout) and a **`.zip`** fallback
4. **Notarize** with `xcrun notarytool` and staple the ticket (recommended)
5. **Upload** to a GitHub Release tagged `v<version>`

`scripts/release.sh` automates steps 1–4 on your Mac.

## One-time Apple setup

### 1. Enroll in the Apple Developer Program

You need a paid [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year) to distribute outside the Mac App Store.

### 2. Create a Developer ID Application certificate

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)
2. **+** → **Developer ID Application** → follow the CSR steps in Keychain Access
3. Download the `.cer` and double-click to install it in your **login** keychain

Verify:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

### 3. Note your Team ID

At [Membership details](https://developer.apple.com/account#MembershipDetailsCard), copy your **Team ID** (10 characters, e.g. `AB12CD34EF`).

### 4. Set up notarization credentials (pick one)

Apple requires **notarization** for Gatekeeper on modern macOS. Choose the method you prefer:

#### Option A — Keychain profile (recommended for local releases)

Uses an [App Store Connect API key](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api):

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) → **+** to create a key (Admin or Developer role)
2. Download the `.p8` file (only available once)
3. Store the key and create a notarytool profile:

```bash
xcrun notarytool store-credentials "muskometer-notary" \
  --key-id "YOUR_KEY_ID" \
  --issuer "YOUR_ISSUER_ID" \
  --key "/path/to/AuthKey_XXXXXXXX.p8"
```

Set before releasing:

```bash
export NOTARY_PROFILE=muskometer-notary
```

#### Option B — API key env vars (good for CI)

```bash
export APPLE_API_KEY_ID=XXXXXXXXXX
export APPLE_API_KEY_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export APPLE_API_KEY_PATH=/path/to/AuthKey_XXXXXXXX.p8
```

#### Option C — Apple ID + app-specific password (legacy)

1. [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → **App-Specific Passwords**
2. Generate a password for `notarytool`

```bash
export APPLE_ID=you@example.com
export APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
export APPLE_TEAM_ID=AB12CD34EF
```

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APPLE_TEAM_ID` | Yes (release) | 10-character Team ID |
| `CODESIGN_IDENTITY` | No | Default: `Developer ID Application` |
| `NOTARY_PROFILE` | No | Keychain profile name from `notarytool store-credentials` |
| `APPLE_API_KEY_ID` | No | API key ID (with issuer + path) |
| `APPLE_API_KEY_ISSUER_ID` | No | API key issuer UUID |
| `APPLE_API_KEY_PATH` | No | Path to `AuthKey_*.p8` |
| `APPLE_ID` | No | Apple ID for legacy notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | No | App-specific password |
| `NOTARIZE=0` | No | Skip notarization even if creds exist |

Optional local config file (gitignored):

```bash
cp Config/Release.xcconfig.example Config/Release.xcconfig
# Edit DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

`release.sh` reads `DEVELOPMENT_TEAM` from `Config/Release.xcconfig` if `APPLE_TEAM_ID` is unset.

## Cut a release

### 1. Bump version (when needed)

Update in Xcode or in `Muskometer.xcodeproj` / `Info.plist`:

- `MARKETING_VERSION` → `CFBundleShortVersionString` (e.g. `0.1.0`)
- `CURRENT_PROJECT_VERSION` → `CFBundleVersion` (e.g. `2`)

Commit the version bump.

### 2. Build and notarize locally

```bash
export APPLE_TEAM_ID=AB12CD34EF
export NOTARY_PROFILE=muskometer-notary   # if using keychain profile

./scripts/release.sh
```

Outputs:

- `dist/Muskometer-<version>.dmg` — primary download (includes `/Applications` symlink)
- `dist/Muskometer-<version>.zip` — alternate download

Unsigned local development is unchanged; only `release.sh` requires signing credentials.

### 3. Tag and push

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 4. Create GitHub Release

1. Go to [New release](https://github.com/jlgolson/muskometer/releases/new)
2. Choose tag `v0.1.0`
3. Title: **Muskometer 0.1.0**
4. Attach `dist/Muskometer-0.1.0.dmg` (and optionally the `.zip`)
5. Short release notes (what changed)
6. **Publish release**

Users install by downloading the DMG, dragging **Muskometer** to **Applications**, and launching.

## CI releases (optional)

A [GitHub Actions workflow](../.github/workflows/release.yml) can build on tag push when repository secrets are configured. **Manual `release.sh` on your Mac is simpler** until you import your Developer ID certificate and notary API key into GitHub Secrets — see the workflow file comments.

Required secrets for automated releases:

| Secret | Purpose |
|--------|---------|
| `APPLE_TEAM_ID` | Team ID |
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded `.p12` (Developer ID cert + private key) |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` export password |
| `APPLE_API_KEY_ID` | Notarization API key |
| `APPLE_API_KEY_ISSUER_ID` | Notarization issuer |
| `APPLE_API_KEY_BASE64` | Base64-encoded `AuthKey_*.p8` |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `No identity found` | Install Developer ID Application cert; unlock keychain |
| `APPLE_TEAM_ID is not set` | Export env var or create `Config/Release.xcconfig` |
| Export fails provisioning | Ensure bundle ID `org.muskometer.app` is registered in your developer account |
| Gatekeeper blocks app | Notarize and staple; re-upload DMG |
| `spctl` fails before notarize | Expected — stapling fixes it |

## Security notes

- Never commit `Config/Release.xcconfig`, `.p8` keys, or `.p12` files
- `dist/` and `build/` are gitignored
- Rotate API keys if exposed