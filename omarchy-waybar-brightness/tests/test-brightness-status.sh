#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS="$ROOT/waybar/brightness/brightness-status.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

assert_nonempty() {
  local value="$1"
  local label="$2"

  if [ -z "$value" ]; then
    printf '%s was empty\n' "$label" >&2
    exit 1
  fi
}

active_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-backlight"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none"
  export WAYBAR_BRIGHTNESS_BRIGHTNESSCTL WAYBAR_BRIGHTNESS_DDCUTIL
  "$STATUS"
})"

ddc_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-single"
  export WAYBAR_BRIGHTNESS_BRIGHTNESSCTL WAYBAR_BRIGHTNESS_DDCUTIL
  "$STATUS"
})"

ddc_scaled_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-scaled"
  export WAYBAR_BRIGHTNESS_BRIGHTNESSCTL WAYBAR_BRIGHTNESS_DDCUTIL
  "$STATUS"
})"

unsupported_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none"
  export WAYBAR_BRIGHTNESS_BRIGHTNESSCTL WAYBAR_BRIGHTNESS_DDCUTIL
  "$STATUS"
})"

fallback_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-broken"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-single"
  export WAYBAR_BRIGHTNESS_BRIGHTNESSCTL WAYBAR_BRIGHTNESS_DDCUTIL
  "$STATUS"
})"

cat >"$TMPDIR/brightnessctl-missing-percent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 2 ] && [ "$1" = "--machine-readable" ] && [ "$2" = "--list" ]; then
  printf 'backlight,intel_backlight,platform\n'
  exit 0
fi

if [ "$#" -eq 4 ] \
  && [ "$1" = "--machine-readable" ] \
  && [ "$2" = "--device" ] \
  && [ "$3" = "intel_backlight" ] \
  && [ "$4" = "info" ]; then
  printf 'Device "intel_backlight" of class "backlight":\n'
  printf 'Current brightness: unknown\n'
  exit 0
fi

printf 'unexpected args: %s\n' "$*" >&2
exit 64
EOF
chmod +x "$TMPDIR/brightnessctl-missing-percent"

missing_percent_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$TMPDIR/brightnessctl-missing-percent"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none"
  export WAYBAR_BRIGHTNESS_BRIGHTNESSCTL WAYBAR_BRIGHTNESS_DDCUTIL
  "$STATUS"
})"

assert_nonempty "$active_json" "active_json"
assert_nonempty "$ddc_json" "ddc_json"
assert_nonempty "$ddc_scaled_json" "ddc_scaled_json"
assert_nonempty "$unsupported_json" "unsupported_json"
assert_nonempty "$fallback_json" "fallback_json"
assert_nonempty "$missing_percent_json" "missing_percent_json"

printf '%s' "$active_json" | jq -e '.text == "☀ 73%" and .class == "active"' >/dev/null
printf '%s' "$ddc_json" | jq -e '.text == "☀ 42%" and .class == "active"' >/dev/null
printf '%s' "$ddc_scaled_json" | jq -e '.text == "☀ 21%" and .class == "active"' >/dev/null
printf '%s' "$unsupported_json" | jq -e '.text == "☀" and .class == "unsupported"' >/dev/null
printf '%s' "$fallback_json" | jq -e '.text == "☀ 42%" and .class == "active"' >/dev/null
printf '%s' "$missing_percent_json" | jq -e '.text == "☀" and .class == "unsupported"' >/dev/null

printf 'ok\n'
