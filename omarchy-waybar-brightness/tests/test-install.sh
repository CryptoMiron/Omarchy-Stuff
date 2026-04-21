#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
UNINSTALL="$ROOT/uninstall.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

assert_config_sane() {
  local file="$1"
  local label="$2"

  python3 - <<'PY' "$file" "$label"
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
label = sys.argv[2]
text = path.read_text()

if '"custom/brightness"' in text:
    raise SystemExit(f'{label}: leftover custom/brightness entry found')

if 'omarchy-waybar-brightness' in text:
    raise SystemExit(f'{label}: leftover marker found')

if re.search(r',\s*([}\]])', text):
    raise SystemExit(f'{label}: trailing comma before closing delimiter')

if text.count('{') != text.count('}'):
    raise SystemExit(f'{label}: unbalanced curly braces')

if text.count('[') != text.count(']'):
    raise SystemExit(f'{label}: unbalanced square brackets')

match = re.search(r'"modules-right"\s*:\s*\[(.*?)\]', text, re.S)
if not match:
    raise SystemExit(f'{label}: modules-right missing after uninstall')

items = re.findall(r'"([^"]+)"', match.group(1))
expected = ['network', 'battery', 'clock']
if items != expected:
    raise SystemExit(f'{label}: expected modules-right {expected}, got {items}')
PY
}

link_system_tool() {
  local name="$1"
  local target="$2"

  ln -s "$target" "$TMPDIR/system-bin/$name"
}

require_system_tool() {
  local name="$1"
  local resolved

  resolved="$(command -v "$name")"
  if [ -z "$resolved" ]; then
    printf 'missing required system tool: %s\n' "$name" >&2
    exit 1
  fi

  link_system_tool "$name" "$resolved"
}

run_case() {
  local fixture_name="$1"
  local case_name="$2"
  local home_dir="$TMPDIR/$case_name/home"
  local bin_dir="$home_dir/bin"
  local waybar_dir="$home_dir/.config/waybar"
  local brightness_dir="$waybar_dir/brightness"
  local restart_log="$TMPDIR/$case_name/restart.log"

  mkdir -p "$bin_dir" "$waybar_dir"
  cp -f "$ROOT/tests/fixtures/$fixture_name" "$waybar_dir/config.jsonc"
  cp -f "$ROOT/tests/fixtures/style.css" "$waybar_dir/style.css"

  cat >"$bin_dir/omarchy-restart-waybar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'restart\n' >>"${WAYBAR_RESTART_LOG:?}"
EOF
  chmod +x "$bin_dir/omarchy-restart-waybar"

  export HOME="$home_dir"
  export PATH="$bin_dir:$PATH"
  export WAYBAR_RESTART_LOG="$restart_log"

  "$INSTALL"

  assert_contains "$waybar_dir/config.jsonc" '"custom/brightness": {' "$case_name-install-config-module"
  assert_contains "$waybar_dir/config.jsonc" '"modules-right": [' "$case_name-install-config-array"
  assert_contains "$waybar_dir/config.jsonc" '"custom/brightness"' "$case_name-install-config-placement"
  assert_contains "$waybar_dir/config.jsonc" '"battery"' "$case_name-install-config-battery"
  assert_contains "$waybar_dir/config.jsonc" '"on-scroll-up": "' "$case_name-install-config-scroll-up"
  assert_contains "$waybar_dir/config.jsonc" '"on-scroll-down": "' "$case_name-install-config-scroll-down"
  assert_not_contains "$waybar_dir/config.jsonc" '"on-click": "' "$case_name-install-config-no-click"
  assert_not_contains "$waybar_dir/config.jsonc" '"on-click-right": "' "$case_name-install-config-no-click-right"
  assert_contains "$waybar_dir/style.css" '@import "brightness/brightness.css";' "$case_name-install-style-import"
  assert_contains "$brightness_dir/brightness-status.sh" 'brightness_detect_active' "$case_name-install-status-script"
  assert_contains "$brightness_dir/brightness-control.sh" 'brightness_change' "$case_name-install-control-script"
  assert_contains "$brightness_dir/brightness-lib.sh" 'brightness_detect_backlight' "$case_name-install-lib-script"

  python3 - <<'PY' "$waybar_dir/config.jsonc"
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
needle = '"custom/brightness"'
battery = '"battery"'
first = text.index(needle)
second = text.index(battery)
if first > second:
    raise SystemExit('custom/brightness was not inserted before battery')
PY

  if [ "$fixture_name" = "config-array.jsonc" ]; then
    python3 - <<'PY' "$waybar_dir/config.jsonc"
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
matches = list(re.finditer(r'"modules-right"\s*:\s*\[(.*?)\]', text, re.S))
if len(matches) < 2:
    raise SystemExit('expected two modules-right arrays in array fixture')

second_items = re.findall(r'"([^"]+)"', matches[1].group(1))
if second_items != ['tray', 'clock']:
    raise SystemExit(f'second bar modules-right changed unexpectedly: {second_items}')
PY
  fi

  first_config_checksum="$(sha256sum "$waybar_dir/config.jsonc" | cut -d' ' -f1)"
  first_style_checksum="$(sha256sum "$waybar_dir/style.css" | cut -d' ' -f1)"

  "$INSTALL"

  second_config_checksum="$(sha256sum "$waybar_dir/config.jsonc" | cut -d' ' -f1)"
  second_style_checksum="$(sha256sum "$waybar_dir/style.css" | cut -d' ' -f1)"

  assert_eq "$second_config_checksum" "$first_config_checksum" "$case_name-install-idempotent-config"
  assert_eq "$second_style_checksum" "$first_style_checksum" "$case_name-install-idempotent-style"
  assert_eq "$(wc -l <"$restart_log")" '2' "$case_name-install-restart-count"

  "$UNINSTALL"

  assert_not_contains "$waybar_dir/config.jsonc" '"custom/brightness": {' "$case_name-uninstall-config-module"
  assert_not_contains "$waybar_dir/config.jsonc" '"custom/brightness"' "$case_name-uninstall-config-array"
  assert_not_contains "$waybar_dir/style.css" '@import "brightness/brightness.css";' "$case_name-uninstall-style-import"
  assert_eq "$(wc -l <"$restart_log")" '3' "$case_name-uninstall-restart-count"
  assert_config_sane "$waybar_dir/config.jsonc" "$case_name-uninstall-config-sane"

  if [ -e "$brightness_dir/brightness-status.sh" ] || [ -e "$brightness_dir/brightness-control.sh" ] || [ -e "$brightness_dir/brightness-lib.sh" ]; then
    printf '%s: expected brightness payload to be removed\n' "$case_name-uninstall-files" >&2
    exit 1
  fi
}

run_self_healing_case() {
  local case_name="$1"
  local ddcutil_fixture="$2"
  local expect_warning="$3"
  local expect_pkg_add="$4"
  local expect_modprobe="$5"
  local pkg_add_should_fail="${6:-0}"
  local modprobe_should_fail="${7:-0}"
  local expected_warning_fragment="${8:-warning:}"
  local expect_detect="${9:-yes}"
  local home_dir="$TMPDIR/$case_name/home"
  local bin_dir="$home_dir/bin"
  local waybar_dir="$home_dir/.config/waybar"
  local brightness_dir="$waybar_dir/brightness"
  local restart_log="$TMPDIR/$case_name/restart.log"
  local prep_log="$TMPDIR/$case_name/prep.log"
  local stderr_log="$TMPDIR/$case_name/install.stderr"

  mkdir -p "$bin_dir" "$waybar_dir"
  cp -f "$ROOT/tests/fixtures/config.jsonc" "$waybar_dir/config.jsonc"
  cp -f "$ROOT/tests/fixtures/style.css" "$waybar_dir/style.css"
  cp -f "$ROOT/tests/fixtures/bin/omarchy-pkg-add" "$bin_dir/omarchy-pkg-add"
  cp -f "$ROOT/tests/fixtures/bin/modprobe" "$bin_dir/modprobe"
  chmod +x "$bin_dir/omarchy-pkg-add" "$bin_dir/modprobe"

  cat >"$bin_dir/omarchy-restart-waybar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'restart\n' >>"${WAYBAR_RESTART_LOG:?}"
EOF
  chmod +x "$bin_dir/omarchy-restart-waybar"

  export HOME="$home_dir"
  export WAYBAR_RESTART_LOG="$restart_log"
  export WAYBAR_INSTALLER_PREP_LOG="$prep_log"
  export WAYBAR_INSTALLER_DDCUTIL_SOURCE="$ROOT/tests/fixtures/bin/$ddcutil_fixture"
  export WAYBAR_INSTALLER_PKG_ADD_SHOULD_FAIL="$pkg_add_should_fail"
  export WAYBAR_INSTALLER_MODPROBE_SHOULD_FAIL="$modprobe_should_fail"

  PATH="$bin_dir:$TMPDIR/system-bin" "$INSTALL" 2>"$stderr_log"

  assert_contains "$waybar_dir/config.jsonc" '"custom/brightness": {' "$case_name-install-config-module"
  assert_contains "$brightness_dir/brightness-status.sh" 'brightness_detect_active' "$case_name-install-status-script"
  assert_eq "$(wc -l <"$restart_log")" '1' "$case_name-install-restart-count"

  if [ "$expect_pkg_add" = 'yes' ]; then
    assert_contains "$prep_log" 'omarchy-pkg-add ddcutil' "$case_name-prep-pkg-add"
  else
    assert_not_contains "$prep_log" 'omarchy-pkg-add ddcutil' "$case_name-prep-no-pkg-add"
  fi

  if [ "$expect_modprobe" = 'yes' ]; then
    assert_contains "$prep_log" 'modprobe i2c-dev' "$case_name-prep-modprobe"
  else
    assert_not_contains "$prep_log" 'modprobe i2c-dev' "$case_name-prep-no-modprobe"
  fi

  if [ "$expect_detect" = 'yes' ]; then
    assert_contains "$prep_log" 'ddcutil detect --brief' "$case_name-prep-detect"
  else
    assert_not_contains "$prep_log" 'ddcutil detect --brief' "$case_name-prep-no-detect"
  fi

  if [ "$expect_warning" = 'yes' ]; then
    assert_contains "$stderr_log" 'warning:' "$case_name-warning-present"
    assert_contains "$stderr_log" "$expected_warning_fragment" "$case_name-warning-fragment"
  else
    assert_not_contains "$stderr_log" 'warning:' "$case_name-warning-absent"
  fi
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if ! grep -F -q -- "$needle" "$file"; then
    printf '%s: expected [%s] in %s\n' "$label" "$needle" "$file" >&2
    if [ -e "$file" ]; then
      printf '%s: actual contents [%s]\n' "$label" "$(tr '\n' '|' <"$file")" >&2
    else
      printf '%s: file missing\n' "$label" >&2
    fi
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if grep -F -q -- "$needle" "$file"; then
    printf '%s: did not expect [%s] in %s\n' "$label" "$needle" "$file" >&2
    printf '%s: actual contents [%s]\n' "$label" "$(tr '\n' '|' <"$file")" >&2
    exit 1
  fi
}

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"

  if [ "$got" != "$want" ]; then
    printf '%s: expected [%s], got [%s]\n' "$label" "$want" "$got" >&2
    exit 1
  fi
}

mkdir -p "$TMPDIR/system-bin"
require_system_tool bash
require_system_tool chmod
require_system_tool cp
require_system_tool dirname
require_system_tool grep
require_system_tool mkdir
require_system_tool python3

run_case config.jsonc multiline
run_case config-inline.jsonc inline
run_case config-array.jsonc array
run_self_healing_case self-heal-success ddcutil-detect-ok no yes yes 0 0 'warning:' yes
run_self_healing_case self-heal-detect-warning ddcutil-detect-fail yes yes yes 0 0 'ddcutil detect --brief failed' yes
run_self_healing_case self-heal-pkg-add-warning ddcutil-detect-ok yes yes yes 1 0 'failed to install ddcutil automatically' no
run_self_healing_case self-heal-modprobe-warning ddcutil-detect-ok yes yes yes 0 1 'failed to load i2c-dev' yes

printf 'ok\n'
