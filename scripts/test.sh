#!/usr/bin/env bash
# Single entry point — the SAME checks .github/workflows/ci.yml runs. Needs Xcode/Swift.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "→ build"; swift build
echo "→ test";  swift run ClioilTests
echo "✅ ALL GREEN"
