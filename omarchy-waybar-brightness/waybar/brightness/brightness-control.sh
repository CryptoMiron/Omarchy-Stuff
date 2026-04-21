#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/brightness-lib.sh"

direction="${1:-}"

case "$direction" in
  up|down) ;;
  *)
    printf 'usage: up|down\n' >&2
    exit 1
    ;;
esac

target="$(brightness_detect_active)"

[ "$target" != "unsupported:none" ] || exit 0
brightness_change "$target" "$direction"
