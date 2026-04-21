#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTROL="$ROOT/waybar/brightness/brightness-control.sh"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if ! grep -F -q -- "$needle" "$file"; then
    printf '%s: expected [%s] in %s\n' "$label" "$needle" "$file" >&2
    if [ -e "$file" ]; then
      printf '%s: actual contents [%s]\n' "$label" "$(tr '\n' '|' <"$file")" >&2
    else
      printf '%s: file was not created\n' "$label" >&2
    fi
    exit 1
  fi
}

assert_missing() {
  local file="$1"
  local label="$2"

  if [ -e "$file" ]; then
    printf '%s: expected no file at %s, got [%s]\n' "$label" "$file" "$(tr '\n' '|' <"$file")" >&2
    exit 1
  fi
}

assert_command_fails() {
  local status=0

  set +e
  "$@"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    printf 'invalid-direction: expected failure for command: %s\n' "$*" >&2
    exit 1
  fi
}

WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/backlight.log" \
WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-backlight" \
WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none" \
"$CONTROL" up

assert_contains "$LOG_DIR/backlight.log" '--device intel_backlight set 5%+' 'backlight-up'

WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/ddc.log" \
WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none" \
WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-single" \
"$CONTROL" down

assert_contains "$LOG_DIR/ddc.log" '--bus 3 setvcp 10 - 5' 'ddc-down'

WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/fallback.log" \
WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-broken" \
WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-single" \
"$CONTROL" up

assert_contains "$LOG_DIR/fallback.log" '--bus 3 setvcp 10 + 5' 'fallback-up'

WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/ddc-scaled.log" \
WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none" \
WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-scaled" \
"$CONTROL" down

assert_contains "$LOG_DIR/ddc-scaled.log" '--bus 7 setvcp 10 - 10' 'ddc-scaled-down'

WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/unsupported.log" \
WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none" \
WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none" \
"$CONTROL" up

assert_missing "$LOG_DIR/unsupported.log" 'unsupported-up'

invalid_stderr="$LOG_DIR/invalid.stderr"
assert_command_fails env \
  WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/invalid.log" \
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-backlight" \
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none" \
  "$CONTROL" sideways 2>"$invalid_stderr"

assert_contains "$invalid_stderr" 'usage: up|down' 'invalid-direction'
assert_missing "$LOG_DIR/invalid.log" 'invalid-direction'

printf 'ok\n'
