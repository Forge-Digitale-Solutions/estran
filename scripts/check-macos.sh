#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for tool in xcodegen xcodebuild; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: $tool is not installed; macOS checks cannot run." >&2
        exit 1
    fi
done

xcodegen generate

# Pick the first available iPhone simulator instead of hard-coding a model
# name: the installed Xcode runtime decides which iPhones exist.
if [[ -z "${ESTRAN_DESTINATION:-}" ]]; then
    DEVICE_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys

devices = json.load(sys.stdin)["devices"]
# Prefer the reference device the mockups were matched on: a foldable or an
# unusual form factor can render the TabView without a tab bar and break the UI
# tour for reasons that are not regressions.
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    for device in devices[runtime]:
        if device["name"] == "iPhone 18 Pro" and device.get("isAvailable", True):
            print(device["udid"])
            sys.exit(0)
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    for device in devices[runtime]:
        if device["name"].startswith("iPhone") and device.get("isAvailable", True):
            print(device["udid"])
            sys.exit(0)
sys.exit("no available iPhone simulator found")
')"
    DESTINATION="id=$DEVICE_ID"
else
    DESTINATION="$ESTRAN_DESTINATION"
fi
echo "Using destination: $DESTINATION"

# Boot the simulator explicitly. After an Xcode update the device can be left
# shut down with a runtime whose disk image is mounted by a stale cryptex, and
# `xcodebuild test` then aborts with « The iOS <version> simulator runtime is not
# available » before running a single test. Booting first (idempotent) removes
# that cold-start failure.
if [[ "$DESTINATION" == id=* ]]; then
    DEVICE_ID="${DESTINATION#id=}"
    if ! xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null 2>&1; then
        echo "warning: could not boot $DEVICE_ID; xcodebuild will try on its own." >&2
    fi
fi

xcodebuild \
    -project Estran.xcodeproj \
    -derivedDataPath "$ROOT_DIR/build/DerivedData" \
    -scheme Estran \
    -configuration Debug \
    -destination "$DESTINATION" \
    build

xcodebuild \
    -project Estran.xcodeproj \
    -derivedDataPath "$ROOT_DIR/build/DerivedData" \
    -scheme Estran \
    -configuration Debug \
    -destination "$DESTINATION" \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 300 \
    test

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --strict --config .swiftlint.yml
else
    echo "warning: swiftlint is not installed; lint check skipped." >&2
fi

if command -v swiftformat >/dev/null 2>&1; then
    swiftformat --lint --exclude Packages/EstranCore/.build,build .
else
    echo "warning: swiftformat is not installed; format check skipped." >&2
fi

if [[ "${1:-}" == "--archive" ]]; then
    xcodebuild \
        -project Estran.xcodeproj \
    -derivedDataPath "$ROOT_DIR/build/DerivedData" \
        -scheme Estran \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ROOT_DIR/build/Estran.xcarchive" \
        archive \
        CODE_SIGNING_ALLOWED=NO
fi
