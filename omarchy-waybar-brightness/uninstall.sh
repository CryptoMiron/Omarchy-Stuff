#!/usr/bin/env bash
set -euo pipefail

WAYBAR_DIR="$HOME/.config/waybar"
DEST_DIR="$WAYBAR_DIR/brightness"
CONFIG_FILE="$WAYBAR_DIR/config.jsonc"
STYLE_FILE="$WAYBAR_DIR/style.css"

if [ -f "$CONFIG_FILE" ]; then
  python3 - "$CONFIG_FILE" <<'PY'
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
text = config_path.read_text()

module_name = 'custom/brightness'


def remove_module_block(text: str) -> str:
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


def update_modules_right(text: str) -> str:
    pattern = re.compile(r'("modules-right"\s*:\s*\[)(.*?)(\])', re.S)
    match = pattern.search(text)
    if not match:
        return text

    items_text = match.group(2)
    items = re.findall(r'"((?:[^"\\]|\\.)*)"', items_text)
    filtered = [item for item in items if item != module_name]

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


target_text = text
target_span = None

if detect_root_kind(text) == '[':
    target_span = find_first_array_object_span(text)
    if target_span is None:
        raise SystemExit('config.jsonc top-level array must contain an object to patch')
    target_text = text[target_span[0]:target_span[1]]

target_text = remove_module_block(target_text)
target_text = update_modules_right(target_text)

if target_span is not None:
    text = text[:target_span[0]] + target_text + text[target_span[1]:]
else:
    text = target_text

config_path.write_text(text.rstrip() + '\n')
PY
fi

if [ -f "$STYLE_FILE" ]; then
  python3 - "$STYLE_FILE" <<'PY'
import pathlib
import sys

style_path = pathlib.Path(sys.argv[1])
lines = style_path.read_text().splitlines()
filtered = [line for line in lines if line.strip() != '@import "brightness/brightness.css";']
text = '\n'.join(filtered).rstrip()
style_path.write_text((text + '\n') if text else '')
PY
fi

rm -f "$DEST_DIR/brightness-lib.sh"
rm -f "$DEST_DIR/brightness-status.sh"
rm -f "$DEST_DIR/brightness-control.sh"
rm -f "$DEST_DIR/brightness.css"
rmdir "$DEST_DIR" 2>/dev/null || true

omarchy-restart-waybar
