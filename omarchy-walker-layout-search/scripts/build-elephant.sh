#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT/vendor/elephant"
OUTPUT_DIR="$ROOT/dist/bin"

mkdir -p "$OUTPUT_DIR"
make -C "$SOURCE_DIR" clean build
install -Dm755 "$SOURCE_DIR/cmd/elephant/elephant" "$OUTPUT_DIR/elephant"

printf '\nBuilding provider plugins...\n'
"$ROOT/scripts/build-plugins.sh"
