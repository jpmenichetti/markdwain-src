#!/bin/bash
# make-diagrams.sh — regenerates docs/diagrams/*.svg from the Graphviz .dot sources next to them.
# Requires Graphviz (brew install graphviz). SVGs are committed so the docs render without it.
set -e
cd "$(dirname "$0")/../docs/diagrams"
for f in *.dot; do dot -Tsvg "$f" -o "${f%.dot}.svg"; echo "built ${f%.dot}.svg"; done
