#!/bin/bash
# snapshot.sh — builds and runs tests/snapshot/main.swift. Usage: tests/snapshot/run.sh file.md out.png [light|dark] [sidebar]
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/snapshot"
mkdir -p "$OUT"
# The tool is a bare executable, so PageBuilder looks for Web/ next to it (Bundle.main = its folder).
rm -rf "$OUT/Web" && cp -R "$ROOT/Shared/Web" "$OUT/Web"
swiftc -o "$OUT/snapshot" "$ROOT/Shared/Swift/PageBuilder.swift" "$ROOT/Shared/Swift/TextLoader.swift" "$ROOT/tests/snapshot/main.swift" -framework AppKit -framework WebKit
"$OUT/snapshot" "$@"
