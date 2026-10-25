#!/bin/bash
# watcher-test.sh — compiles and runs tests/watcher/main.swift against App/Sources/FileWatcher.swift.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$ROOT/build"
swiftc -o "$ROOT/build/watcher-test" "$ROOT/App/Sources/FileWatcher.swift" "$ROOT/tests/watcher/main.swift"
"$ROOT/build/watcher-test"
