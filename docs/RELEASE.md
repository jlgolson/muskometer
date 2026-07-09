# Releasing Muskometer

Guide for maintainers shipping builds to [GitHub Releases](https://github.com/jlgolson/muskometer/releases).

## Primary path: unsigned DMG (current: v0.1.3)

**This is what we ship today.** No Apple Developer Program ($99) required. Examples below use **0.1.3**; substitute the version you are shipping.

```bash
./scripts/package-dmg.sh
```

Builds a Release `.app` with `CODE_SIGNING_ALLOWED=NO`, then outputs:

- `dist/Muskometer-<version>.dmg`
- `dist/Muskometer-<version>.zip`

No signing or notarization. Tell users to **right-click → Open** on first launch. See [INSTALL.md](INSTALL.md) for Gatekeeper steps.

**Sandbox honesty:** Because signing is disabled, the entitlements file is **not** embedded. These artifacts are **not App Sandboxed**. Development builds and optional signed Developer ID builds (`scripts/release.sh`) *do* run with App Sandbox + `network.client` — see [SECURITY.md](../SECURITY.md). Do not describe the public unsigned DMG as sandboxed.

### Tag and publish

1. Confirm `MARKETING_VERSION` matches the release (e.g. `0.1.3`) in the Xcode project / `Info.plist`.
2. Run `./scripts/package-dmg.sh`.
3. Tag and push:

```bash
git tag v0.1.3
git push origin v0.1.3
```

4. Create the GitHub Release and attach the artifacts:

```bash
gh release create v0.1.3 \
  dist/Muskometer-0.1.3.dmg \
  dist/Muskometer-0.1.3.zip \
  --title "Muskometer 0.1.3" \
  --notes "See CHANGELOG.md. Unsigned DMG — right-click → Open on first launch."
```

Or use the [New release](https://github.com/jlgolson/muskometer/releases/new) UI: choose tag `v0.1.3`, title **Muskometer 0.1.3**, attach `dist/Muskometer-0.1.3.dmg` (and optionally the `.zip`).

---

## Optional / future: signed + notarized DMG

When you have a **Developer ID Application** certificate and notarization credentials, end users get a normal double-click install. Use `scripts/release.sh` on your Mac — not required for the current unsigned release line.

The pipeline:

1. **Archive** a Release build with your **Developer ID Application** certificate
2. **Export** as `developer-id`
3. Package **`dist/Muskometer-<version>.dmg`** (drag-to-Applications layout) and a **`.zip`** fallback
4. **Notarize** with `xcrun notarytool` and staple the ticket (recommended)
5. **Upload** to a GitHub Release tagged `v<version>`

```bash
export APPLE_TEAM_ID=AB12CD34EF
export NOTARY_PROFILE=muskometer-notary   # after notarytool store-credentials

./scripts/release.sh
```

### One-time Apple setup

#### 1. Enroll in the Apple Developer Program

You need a paid [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year) to distribute outside the Mac App Store.

#### 2. Create a Developer ID Application certificate

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)
2. **+** → **Developer ID Application** → follow the CSR steps in Keychain Access
3. Download the `.cer` and double-click to install it in your **login** keychain

Verify:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

#### 3. Note your Team ID

At [Membership details](https://developer.apple.com/account#MembershipDetailsCard), copy your **Team ID** (10 characters, e.g. `AB12CD34EF`).

#### 4. Set up notarization credentials (pick one)

Apple requires **notarization** for Gatekeeper on modern macOS. Choose the method you prefer:

##### Option A — Keychain profile (recommended for local releases)

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

##### Option B — API key env vars (good for CI)

```bash
export APPLE_API_KEY_ID=XXXXXXXXXX
export APPLE_API_KEY_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export APPLE_API_KEY_PATH=/path/to/AuthKey_XXXXXXXX.p8
```

##### Option C — Apple ID + app-specific password (legacy)

1. [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → **App-Specific Passwords**
2. Generate a password for `notarytool`

```bash
export APPLE_ID=you@example.com
export APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
export APPLE_TEAM_ID=AB12CD34EF
```

### Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APPLE_TEAM_ID` | Yes (signed release) | 10-character Team ID |
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

### Version bump (when needed)

Update in Xcode or in `Muskometer.xcodeproj` / `Info.plist`:

- `MARKETING_VERSION` → `CFBundleShortVersionString` (e.g. `0.1.3`)
- `CURRENT_PROJECT_VERSION` → `CFBundleVersion` (e.g. `24`)

Commit the version bump before tagging.

---

## CI releases (unsigned, automatic)

Pushing a `v*` tag runs [`.github/workflows/release.yml`](../.github/workflows/release.yml):

1. `./scripts/verify.sh`
2. `./scripts/package-dmg.sh`
3. Upload `dist/Muskometer-*.dmg` and `.zip` to the GitHub Release

**Do not** manually upload artifacts for the same tag afterward — CI assets are canonical and include SHA-256 checksums in the release notes.

**Do not** delete and re-push a release tag without updating the GitHub Release body. Re-uploading assets changes file bytes; stale SHA-256 checksums in the release notes will no longer match. If you must replace artifacts on an existing tag, recompute checksums (`shasum -a 256` or `gh release view <tag> --json assets` for the `digest` field) and edit the release notes before announcing the build.

For local testing before tagging:

```bash
./scripts/package-dmg.sh
```

### Optional: signed + notarized CI

To automate `scripts/release.sh` instead, configure Apple secrets in the repo and replace the workflow steps. See workflow comments and the signed path above. Not required for the current unsigned release line.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `No identity found` | Install Developer ID Application cert; unlock keychain |
| `APPLE_TEAM_ID is not set` | Export env var or create `Config/Release.xcconfig` |
| Export fails provisioning | Ensure bundle ID `org.muskometer.app` is registered in your developer account |
| Gatekeeper blocks app (unsigned) | User right-click → **Open** once; or switch to signed + notarized path |
| Gatekeeper blocks app (signed) | Notarize and staple; re-upload DMG |
| `spctl` fails before notarize | Expected — stapling fixes it |

## Security notes

- Never commit `Config/Release.xcconfig`, `.p8` keys, or `.p12` files
- `dist/` and `build/` are gitignored
- Rotate API keys if exposed