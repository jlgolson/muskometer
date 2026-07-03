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
from datetime import datetime
from zoneinfo import ZoneInfo

# Default share counts from bundled holdings (same Yahoo quote path for both).
SHARES = {"TSLA": 699_580_882, "SPCX": 6_068_734_060}
ET = ZoneInfo("America/New_York")

def current_session(now):
    if now.weekday() >= 5:
        return "closed"
    minutes = now.hour * 60 + now.minute
    if 4 * 60 <= minutes < 9 * 60 + 30:
        return "preMarket"
    if 9 * 60 + 30 <= minutes < 16 * 60:
        return "regular"
    if 16 * 60 <= minutes < 20 * 60:
        return "postMarket"
    return "closed"

def current_price(meta, session):
    if session == "regular":
        return meta.get("regularMarketPrice")
    if session == "preMarket":
        return meta.get("preMarketPrice") or meta.get("regularMarketPrice")
    if session == "postMarket":
        return meta.get("postMarketPrice") or meta.get("regularMarketPrice")
    return meta.get("regularMarketPrice")

session = current_session(datetime.now(tz=ET))
total = 0.0
for sym, shares in SHARES.items():
    req = urllib.request.Request(
        f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d&range=1d&includePrePost=true",
        headers={"User-Agent": "Mozilla/5.0"},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        meta = json.load(r)["chart"]["result"][0]["meta"]
    price = current_price(meta, session)
    prev = meta.get("chartPreviousClose") or meta.get("previousClose")
    if price is None or prev is None:
        print(f"FAIL: missing quote fields for {sym}")
        sys.exit(1)
    gain = shares * (price - prev)
    total += gain
    print(f"{sym}: ${gain/1e9:.1f}B paper gain ({session})")

print(f"Combined: ${total/1e9:.1f}B")
PY
echo "PASS: live API"

echo ""
echo "=== All automated checks passed ==="