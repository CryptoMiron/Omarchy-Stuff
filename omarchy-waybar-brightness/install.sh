#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$ROOT/waybar/brightness"
WAYBAR_DIR="$HOME/.config/waybar"
DEST_DIR="$WAYBAR_DIR/brightness"
CONFIG_FILE="$WAYBAR_DIR/config.jsonc"
STYLE_FILE="$WAYBAR_DIR/style.css"

warn_prepare() {
  printf 'warning: %s\n' "$1" >&2
}

prepare_ddc_support() {
  if ! command -v ddcutil >/dev/null 2>&1; then
    if command -v omarchy-pkg-add >/dev/null 2>&1; then
      if ! omarchy-pkg-add ddcutil; then
        warn_prepare 'failed to install ddcutil automatically; DDC brightness may stay unavailable'
      fi
    else
      warn_prepare 'ddcutil is missing and omarchy-pkg-add is unavailable; DDC brightness may stay unavailable'
    fi
  fi

  if command -v modprobe >/dev/null 2>&1; then
    if ! modprobe i2c-dev >/dev/null 2>&1; then
      warn_prepare 'failed to load i2c-dev; external monitor brightness may stay unavailable'
    fi
  fi

  if command -v ddcutil >/dev/null 2>&1; then
    if ! ddcutil detect --brief >/dev/null 2>&1; then
      warn_prepare 'ddcutil detect --brief failed; external monitor brightness may stay unavailable'
    fi
  else
    warn_prepare 'ddcutil is still unavailable after installer preparation; external monitor brightness may stay unavailable'
  fi
}

prepare_ddc_support

mkdir -p "$DEST_DIR"
cp -f "$SRC_DIR/brightness-lib.sh" "$DEST_DIR/brightness-lib.sh"
cp -f "$SRC_DIR/brightness-status.sh" "$DEST_DIR/brightness-status.sh"
cp -f "$SRC_DIR/brightness-control.sh" "$DEST_DIR/brightness-control.sh"
cp -f "$SRC_DIR/brightness.css" "$DEST_DIR/brightness.css"
chmod +x "$DEST_DIR/brightness-lib.sh" "$DEST_DIR/brightness-status.sh" "$DEST_DIR/brightness-control.sh"

python3 - "$CONFIG_FILE" <<'PY'
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
home = pathlib.Path.home()
module_name = 'custom/brightness'
marker_start = '  // omarchy-waybar-brightness:start'
marker_end = '  // omarchy-waybar-brightness:end'
module_block = (
    f'{marker_start}\n'
    '  "custom/brightness": {\n'
    '    "format": "{}",\n'
    f'    "exec": "{home}/.config/waybar/brightness/brightness-status.sh",\n'
    '    "return-type": "json",\n'
    '    "interval": 2,\n'
    f'    "on-scroll-up": "{home}/.config/waybar/brightness/brightness-control.sh up",\n'
    f'    "on-scroll-down": "{home}/.config/waybar/brightness/brightness-control.sh down",\n'
    '    "tooltip": true\n'
    '  },\n'
    f'{marker_end}'
)


def ensure_modules_right(text: str) -> str:
    if '"modules-right"' in text:
        return text

    closing = re.search(r'\}\s*$', text)
    if not closing:
        raise SystemExit('config.jsonc must end with }')

    prefix = text[:closing.start()].rstrip()
    suffix = text[closing.start():]
    needs_comma = prefix and not prefix.endswith('{')
    return (
        prefix
        + (',' if needs_comma else '')
        + '\n  "modules-right": [\n    "custom/brightness"\n  ]\n'
        + suffix
    )


def update_modules_right(text: str, add_module: bool) -> str:
    pattern = re.compile(r'("modules-right"\s*:\s*\[)(.*?)(\])', re.S)
    match = pattern.search(text)
    if not match:
        raise SystemExit('modules-right array not found')

    items_text = match.group(2)
    items = re.findall(r'"((?:[^"\\]|\\.)*)"', items_text)

    filtered = [item for item in items if item != module_name]
    if add_module:
        if 'battery' in filtered:
            index = filtered.index('battery')
            filtered.insert(index, module_name)
        else:
            filtered.append(module_name)

    if '\n' in items_text:
        indent_match = re.search(r'\n([ \t]*)"', items_text)
        indent = indent_match.group(1) if indent_match else '    '
        if filtered:
            new_items = '\n' + ''.join(
                f'{indent}"{item}"{"," if index < len(filtered) - 1 else ""}\n'
                for index, item in enumerate(filtered)
            )
        else:
            new_items = ''
    else:
        new_items = ', '.join(f'"{item}"' for item in filtered)

    return text[:match.start(2)] + new_items + text[match.end(2):]


def remove_existing_module_block(text: str) -> str:
    text = re.sub(
        r'\n?[ \t]*// omarchy-waybar-brightness:start\n.*?\n[ \t]*// omarchy-waybar-brightness:end',
        '',
        text,
        flags=re.S,
    )
    text = re.sub(
        r'\n?[ \t]*"custom/brightness"\s*:\s*\{[^{}]*\},?',
        '',
        text,
        flags=re.S,
    )
    text = re.sub(r',\s*(\})', r'\1', text)
    return text


def append_module_block(text: str) -> str:
    closing = re.search(r'\}\s*$', text)
    if not closing:
        raise SystemExit('config.jsonc must end with }')

    prefix = text[:closing.start()].rstrip()
    suffix = text[closing.start():]
    needs_comma = prefix and not prefix.endswith('{')
    return prefix + (',' if needs_comma else '') + '\n' + module_block + '\n' + suffix


def detect_root_kind(text: str) -> str | None:
    in_string = False
    escape = False
    line_comment = False
    block_comment = False

    for index, char in enumerate(text):
        next_char = text[index + 1] if index + 1 < len(text) else ''

        if line_comment:
            if char == '\n':
                line_comment = False
            continue

        if block_comment:
            if char == '*' and next_char == '/':
                block_comment = False
            continue

        if in_string:
            if escape:
                escape = False
            elif char == '\\':
                escape = True
            elif char == '"':
                in_string = False
            continue

        if char == '/' and next_char == '/':
            line_comment = True
            continue

        if char == '/' and next_char == '*':
            block_comment = True
            continue

        if char == '"':
            in_string = True
            continue

        if char in '{[':
            return char

    return None


def find_first_array_object_span(text: str) -> tuple[int, int] | None:
    in_string = False
    escape = False
    line_comment = False
    block_comment = False
    array_depth = 0
    object_depth = 0
    start = None

    for index, char in enumerate(text):
        next_char = text[index + 1] if index + 1 < len(text) else ''

        if line_comment:
            if char == '\n':
                line_comment = False
            continue

        if block_comment:
            if char == '*' and next_char == '/':
                block_comment = False
            continue

        if in_string:
            if escape:
                escape = False
            elif char == '\\':
                escape = True
            elif char == '"':
                in_string = False
            continue

        if char == '/' and next_char == '/':
            line_comment = True
            continue

        if char == '/' and next_char == '*':
            block_comment = True
            continue

        if char == '"':
            in_string = True
            continue

        if char == '[':
            array_depth += 1
            continue

        if char == ']':
            array_depth -= 1
            continue

        if char == '{':
            if array_depth == 1 and object_depth == 0 and start is None:
                start = index
            object_depth += 1
            continue

        if char == '}':
            object_depth -= 1
            if start is not None and array_depth == 1 and object_depth == 0:
                return start, index + 1

    return None

if config_path.exists():
    text = config_path.read_text()
else:
    text = '{\n}\n'

target_text = text
target_span = None

if config_path.exists() and detect_root_kind(text) == '[':
    target_span = find_first_array_object_span(text)
    if target_span is None:
        raise SystemExit('config.jsonc top-level array must contain an object to patch')
    target_text = text[target_span[0]:target_span[1]]

target_text = ensure_modules_right(target_text)
target_text = remove_existing_module_block(target_text)
target_text = update_modules_right(target_text, add_module=True)
target_text = append_module_block(target_text)

if target_span is not None:
    text = text[:target_span[0]] + target_text + text[target_span[1]:]
else:
    text = target_text

config_path.write_text(text.rstrip() + '\n')
PY

if [ -f "$STYLE_FILE" ]; then
  if ! grep -F -q -- '@import "brightness/brightness.css";' "$STYLE_FILE"; then
    printf '\n@import "brightness/brightness.css";\n' >>"$STYLE_FILE"
  fi
else
  printf '@import "brightness/brightness.css";\n' >"$STYLE_FILE"
fi

omarchy-restart-waybar
