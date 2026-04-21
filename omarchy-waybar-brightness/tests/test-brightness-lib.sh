#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/waybar/brightness/brightness-lib.sh"

assert_eq() {
  local got="$1"
  local want="$2"

  if [ "$got" != "$want" ]; then
    printf 'expected [%s], got [%s]\n' "$want" "$got" >&2
    exit 1
  fi
}

assert_fails() {
  if "$@" >/dev/null 2>&1; then
    printf 'expected command to fail: %s\n' "$*" >&2
    exit 1
  fi
}

run_detect() {
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$1" \
  WAYBAR_BRIGHTNESS_DDCUTIL="$2" \
  bash -lc '. "$0"; brightness_detect_active' "$LIB"
}

run_percent() {
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$1" \
  WAYBAR_BRIGHTNESS_DDCUTIL="$2" \
  bash -lc '. "$0"; brightness_get_percent "$1"' "$LIB" "$3"
}

assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-backlight" "$ROOT/tests/fixtures/bin/ddcutil-single")" "backlight:intel_backlight"
assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-broken" "$ROOT/tests/fixtures/bin/ddcutil-single")" "ddc:bus-3"
assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-none" "$ROOT/tests/fixtures/bin/ddcutil-single")" "ddc:bus-3"
assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-none" "$ROOT/tests/fixtures/bin/ddcutil-none")" "unsupported:none"
assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-none" "$ROOT/tests/fixtures/bin/ddcutil-multi")" "ddc:bus-2"
assert_eq "$(run_percent "$ROOT/tests/fixtures/bin/brightnessctl-none" "$ROOT/tests/fixtures/bin/ddcutil-scaled" "ddc:bus-7")" "21"

assert_fails "$ROOT/tests/fixtures/bin/brightnessctl-backlight" unexpected
assert_fails "$ROOT/tests/fixtures/bin/brightnessctl-broken" unexpected
assert_fails "$ROOT/tests/fixtures/bin/brightnessctl-none" unexpected
assert_fails "$ROOT/tests/fixtures/bin/ddcutil-scaled" unexpected
assert_fails "$ROOT/tests/fixtures/bin/ddcutil-single" unexpected
assert_fails "$ROOT/tests/fixtures/bin/ddcutil-multi" unexpected
assert_fails "$ROOT/tests/fixtures/bin/ddcutil-none" unexpected

printf 'ok\n'
