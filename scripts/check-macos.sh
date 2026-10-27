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

DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=latest"

xcodebuild \
    -project Estran.xcodeproj \
    -scheme Estran \
    -configuration Debug \
    -destination "$DESTINATION" \
    build

xcodebuild \
    -project Estran.xcodeproj \
    -scheme Estran \
    -configuration Debug \
    -destination "$DESTINATION" \
    test

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --strict --config .swiftlint.yml
else
    echo "warning: swiftlint is not installed; lint check skipped." >&2
fi

if command -v swiftformat >/dev/null 2>&1; then
    swiftformat --lint --exclude Packages/EstranCore/.build .
else
    echo "warning: swiftformat is not installed; format check skipped." >&2
fi

if [[ "${1:-}" == "--archive" ]]; then
    xcodebuild \
        -project Estran.xcodeproj \
        -scheme Estran \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ROOT_DIR/build/Estran.xcarchive" \
        archive \
        CODE_SIGNING_ALLOWED=NO
fi
