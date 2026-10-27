#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/Packages/EstranCore"

if ! command -v swift >/dev/null 2>&1; then
    echo "error: swift is not installed; Linux package checks cannot run." >&2
    exit 1
fi

swift --version
swift build --package-path "$PACKAGE_DIR"
swift test --package-path "$PACKAGE_DIR"
