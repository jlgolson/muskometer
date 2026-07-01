#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== 1. Swift typecheck ==="
SDK=$(xcrun --show-sdk-path)
swiftc -typecheck \
  -target arm64-apple-macos14.0 \
  -sdk "$SDK" \
  -module-name Muskometer \
  -parse-as-library \
  $(find Muskometer -name "*.swift" | sort)
echo "PASS: typecheck"

echo ""
echo "=== 2. Unit tests (xcodebuild test) ==="
TEST_DERIVED="$ROOT/build/verify-derived-$$"
mkdir -p "$ROOT/build"
xcodebuild test \
  -scheme Muskometer \
  -configuration Debug \
  -derivedDataPath "$TEST_DERIVED" \
  -destination 'platform=macOS' \
  -quiet
echo "PASS: unit tests"

echo ""
echo "=== 3. Release build ==="
xcodebuild build \
  -scheme Muskometer \
  -configuration Release \
  -quiet
echo "PASS: release build"

echo ""
echo "=== 4. Entitlements on built app ==="
APP=$(find "$TEST_DERIVED/Build/Products/Debug" -name "Muskometer.app" 2>/dev/null | head -1)
if [[ -z "$APP" ]]; then
  APP=$(find ~/Library/Developer/Xcode/DerivedData/Muskometer-*/Build/Products/Debug -name "Muskometer.app" 2>/dev/null | head -1)
fi
if [[ -n "$APP" ]]; then
  codesign -d --entitlements :- "$APP" 2>/dev/null | grep -E "app-sandbox|network.client" || {
    echo "WARN: could not verify entitlements"
  }
  echo "PASS: app bundle at $APP"
else
  echo "WARN: built app not found for entitlements check"
fi

echo ""
echo "=== 5. Live Yahoo API + paper gain math ==="
python3 <<'PY'
import json, urllib.request, sys

# TSLA uses bundled default (pre-SEC-sync); SPCX uses app default aggregate.
SHARES = {"TSLA": 699_580_882, "SPCX": 6_068_734_060}
total = 0.0
for sym, shares in SHARES.items():
    req = urllib.request.Request(
        f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d&range=1d",
        headers={"User-Agent": "Mozilla/5.0"},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        meta = json.load(r)["chart"]["result"][0]["meta"]
    price = meta["regularMarketPrice"]
    prev = meta.get("chartPreviousClose") or meta.get("previousClose")
    if prev is None:
        print(f"FAIL: missing previous close for {sym}")
        sys.exit(1)
    gain = shares * (price - prev)
    total += gain
    print(f"{sym}: ${gain/1e9:.1f}B paper gain")

print(f"Combined: ${total/1e9:.1f}B")
PY
echo "PASS: live API"

echo ""
echo "=== All automated checks passed ==="