#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/stowsight-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/stowsight-swift-cache"
swift build --disable-sandbox --scratch-path .build
swift run --disable-sandbox --scratch-path .build --skip-build InventoryChecks
swift run --disable-sandbox --scratch-path .build --skip-build StowSight --check-app
