#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/brightness-lib.sh"

target="$(brightness_detect_active)"
if [ "$target" = "unsupported:none" ]; then
  printf '{"text":"☀","class":"unsupported","tooltip":"Brightness unavailable"}\n'
  exit 0
fi

percent="$(brightness_get_percent "$target" || true)"
[ -n "$percent" ] || {
  printf '{"text":"☀","class":"unsupported","tooltip":"Brightness unavailable"}\n'
  exit 0
}

printf '{"text":"☀ %s%%","class":"active","tooltip":"Brightness %s%%"}\n' "$percent" "$percent"
