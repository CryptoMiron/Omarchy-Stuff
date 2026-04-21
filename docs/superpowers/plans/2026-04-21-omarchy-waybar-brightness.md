# Omarchy Waybar Brightness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить в репозиторий переносимую Omarchy-фичу `omarchy-waybar-brightness`, которая устанавливает в Waybar модуль яркости с иконкой солнца, процентами и регулировкой колесом мыши для `backlight` и DDC/CI.

**Architecture:** Фича живет в отдельном каталоге проекта и состоит из небольшой shell-библиотеки, статусного и управляющего скриптов, а также install/uninstall-скриптов, которые аккуратно патчат `~/.config/waybar/config.jsonc` и `style.css` через помеченные блоки. Тестирование выполняется простыми shell-тестами с подменой внешних команд через переменные окружения, чтобы проверить выбор устройства, JSON-вывод Waybar и идемпотентность установки.

**Tech Stack:** POSIX shell/bash, `brightnessctl`, `ddcutil`, Waybar JSONC/CSS, `jq` для проверки JSON в тестах, `perl` для точечных текстовых вставок в install/uninstall.

---

## Структура файлов

- Создать: `omarchy-waybar-brightness/README.md`
- Создать: `omarchy-waybar-brightness/install.sh`
- Создать: `omarchy-waybar-brightness/uninstall.sh`
- Создать: `omarchy-waybar-brightness/waybar/brightness/brightness-lib.sh`
- Создать: `omarchy-waybar-brightness/waybar/brightness/brightness-status.sh`
- Создать: `omarchy-waybar-brightness/waybar/brightness/brightness-control.sh`
- Создать: `omarchy-waybar-brightness/waybar/brightness/brightness.css`
- Создать: `omarchy-waybar-brightness/tests/test-brightness-lib.sh`
- Создать: `omarchy-waybar-brightness/tests/test-brightness-status.sh`
- Создать: `omarchy-waybar-brightness/tests/test-brightness-control.sh`
- Создать: `omarchy-waybar-brightness/tests/test-install.sh`
- Создать: `omarchy-waybar-brightness/tests/fixtures/config.jsonc`
- Создать: `omarchy-waybar-brightness/tests/fixtures/style.css`
- Создать: `omarchy-waybar-brightness/tests/fixtures/bin/brightnessctl-backlight`
- Создать: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-single`
- Создать: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-multi`
- Создать: `omarchy-waybar-brightness/tests/fixtures/bin/brightnessctl-none`
- Создать: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-none`
- Изменить: `.gitignore` — перестать игнорировать `docs/superpowers/`, сохранив остальное поведение

### Ответственность файлов

- `brightness-lib.sh` — единая точка определения устройства, чтения процента и изменения яркости
- `brightness-status.sh` — Waybar JSON-вывод (`text`, `class`, `tooltip`)
- `brightness-control.sh` — команды `up` и `down` для колеса мыши
- `install.sh` — копирование файлов, вставка `custom/brightness` перед `battery`, подключение CSS, рестарт Waybar
- `uninstall.sh` — обратное удаление marker-блоков и файлов фичи
- `tests/*.sh` — автономные регрессионные shell-тесты без внешнего test framework

### Task 1: Подготовить каталог фичи и разблокировать документацию

**Files:**
- Create: `omarchy-waybar-brightness/README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Написать падающую проверку, что `docs/superpowers` можно коммитить и каталог фичи существует**

```sh
#!/usr/bin/env bash
set -euo pipefail

test -d docs/superpowers/specs
test -f .gitignore
if git check-ignore -q docs/superpowers/specs/2026-04-21-omarchy-waybar-brightness-design.md; then
  echo "docs/superpowers все еще игнорируется"
  exit 1
fi
test -d omarchy-waybar-brightness
```
```

- [ ] **Step 2: Запустить проверку и убедиться, что она падает**

Run: `bash -lc 'test -d docs/superpowers/specs && test -f .gitignore && ! git check-ignore -q docs/superpowers/specs/2026-04-21-omarchy-waybar-brightness-design.md && test -d omarchy-waybar-brightness'`

Expected: FAIL, потому что `docs/` сейчас игнорируется, а каталога `omarchy-waybar-brightness/` еще нет.

- [ ] **Step 3: Внести минимальные изменения в `.gitignore` и создать каркас фичи**

```gitignore
# docs по умолчанию не коммитим, кроме superpowers-артефактов проекта
docs/
!docs/
docs/*
!docs/superpowers/
!docs/superpowers/**
```

```text
omarchy-waybar-brightness/
├── README.md
├── tests/
└── waybar/brightness/
```

- [ ] **Step 4: Повторно запустить проверку**

Run: `bash -lc 'test -d docs/superpowers/specs && test -f .gitignore && ! git check-ignore -q docs/superpowers/specs/2026-04-21-omarchy-waybar-brightness-design.md && test -d omarchy-waybar-brightness'`

Expected: PASS

- [ ] **Step 5: Закоммитить подготовку структуры**

```bash
git add .gitignore docs/superpowers/specs/2026-04-21-omarchy-waybar-brightness-design.md docs/superpowers/plans/2026-04-21-omarchy-waybar-brightness.md omarchy-waybar-brightness
git commit -m "chore: scaffold waybar brightness feature"
```

### Task 2: Реализовать библиотеку выбора устройства через TDD

**Files:**
- Create: `omarchy-waybar-brightness/waybar/brightness/brightness-lib.sh`
- Create: `omarchy-waybar-brightness/tests/test-brightness-lib.sh`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/brightnessctl-backlight`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/brightnessctl-none`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-single`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-multi`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-none`

- [ ] **Step 1: Написать падающий тест на приоритет `backlight` над DDC/CI, fallback на DDC и unsupported**

```sh
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

run_detect() {
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$1" \
  WAYBAR_BRIGHTNESS_DDCUTIL="$2" \
  bash -lc '. "$0"; brightness_detect_active' "$LIB"
}

assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-backlight" "$ROOT/tests/fixtures/bin/ddcutil-single")" "backlight:intel_backlight"
assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-none" "$ROOT/tests/fixtures/bin/ddcutil-single")" "ddc:bus-3"
assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-none" "$ROOT/tests/fixtures/bin/ddcutil-none")" "unsupported:none"
assert_eq "$(run_detect "$ROOT/tests/fixtures/bin/brightnessctl-none" "$ROOT/tests/fixtures/bin/ddcutil-multi")" "ddc:bus-1"

printf 'ok\n'
```

- [ ] **Step 2: Запустить тест и убедиться, что он падает по отсутствующему `brightness_detect_active`**

Run: `./omarchy-waybar-brightness/tests/test-brightness-lib.sh`

Expected: FAIL with `brightness_detect_active: command not found`

- [ ] **Step 3: Реализовать минимальную библиотеку для прохождения теста**

```sh
#!/usr/bin/env bash

brightnessctl_cmd() {
  if [ -n "${WAYBAR_BRIGHTNESS_BRIGHTNESSCTL:-}" ]; then
    "$WAYBAR_BRIGHTNESS_BRIGHTNESSCTL" "$@"
  else
    brightnessctl "$@"
  fi
}

ddcutil_cmd() {
  if [ -n "${WAYBAR_BRIGHTNESS_DDCUTIL:-}" ]; then
    "$WAYBAR_BRIGHTNESS_DDCUTIL" "$@"
  else
    ddcutil "$@"
  fi
}

brightness_detect_backlight() {
  brightnessctl_cmd --machine-readable --list 2>/dev/null \
    | while IFS=, read -r class name _; do
        if [ "$class" = "backlight" ] && [ -n "$name" ]; then
          printf 'backlight:%s\n' "$name"
          return 0
        fi
      done
}

brightness_detect_ddc() {
  ddcutil_cmd detect --brief 2>/dev/null \
    | perl -ne 'print "ddc:bus-$1\n" if /Display\s+([0-9]+)/' \
    | sort -u \
    | head -n 1
}

brightness_detect_active() {
  local found
  found="$(brightness_detect_backlight || true)"
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  found="$(brightness_detect_ddc || true)"
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  printf 'unsupported:none\n'
}
```

- [ ] **Step 4: Запустить тест и убедиться, что он проходит**

Run: `./omarchy-waybar-brightness/tests/test-brightness-lib.sh`

Expected: PASS with `ok`

- [ ] **Step 5: Закоммитить библиотеку выбора устройства**

```bash
git add omarchy-waybar-brightness/waybar/brightness/brightness-lib.sh omarchy-waybar-brightness/tests/test-brightness-lib.sh omarchy-waybar-brightness/tests/fixtures/bin
git commit -m "feat: detect brightness devices for waybar module"
```

### Task 3: Добавить чтение процента и JSON-статус для Waybar

**Files:**
- Modify: `omarchy-waybar-brightness/waybar/brightness/brightness-lib.sh`
- Create: `omarchy-waybar-brightness/waybar/brightness/brightness-status.sh`
- Create: `omarchy-waybar-brightness/tests/test-brightness-status.sh`

- [ ] **Step 1: Написать падающий тест на JSON-вывод для active и unsupported состояний**

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS="$ROOT/waybar/brightness/brightness-status.sh"

active_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-backlight"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none"
  "$STATUS"
})"

unsupported_json="$({
  WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none"
  WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none"
  "$STATUS"
})"

printf '%s' "$active_json" | jq -e '.text == "☀ 73%" and .class == "active"' >/dev/null
printf '%s' "$unsupported_json" | jq -e '.text == "☀" and .class == "unsupported"' >/dev/null

printf 'ok\n'
```

- [ ] **Step 2: Запустить тест и убедиться, что он падает из-за отсутствующего статусного скрипта**

Run: `./omarchy-waybar-brightness/tests/test-brightness-status.sh`

Expected: FAIL with `No such file or directory` or non-zero exit for missing script

- [ ] **Step 3: Реализовать чтение процента в библиотеке и статусный скрипт**

```sh
# brightness-lib.sh
brightness_get_percent() {
  local target="$1"
  local kind="${target%%:*}"
  local name="${target#*:}"

  if [ "$kind" = "backlight" ]; then
    brightnessctl_cmd --machine-readable --device "$name" info 2>/dev/null \
      | perl -ne 'print "$1\n" if /\(([0-9]+)%\)/'
    return 0
  fi

  if [ "$kind" = "ddc" ]; then
    ddcutil_cmd --bus "${name#bus-}" getvcp 10 2>/dev/null \
      | perl -ne 'print "$1\n" if /current value =\s*([0-9]+)/'
    return 0
  fi

  return 1
}
```

```sh
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/brightness-lib.sh"

target="$(brightness_detect_active)"
if [ "$target" = "unsupported:none" ]; then
  printf '{"text":"☀","class":"unsupported","tooltip":"Яркость недоступна"}\n'
  exit 0
fi

percent="$(brightness_get_percent "$target")"
printf '{"text":"☀ %s%%","class":"active","tooltip":"Яркость %s%%"}\n' "$percent" "$percent"
```

- [ ] **Step 4: Запустить тест и убедиться, что он проходит**

Run: `./omarchy-waybar-brightness/tests/test-brightness-status.sh`

Expected: PASS with `ok`

- [ ] **Step 5: Закоммитить статусный вывод Waybar**

```bash
git add omarchy-waybar-brightness/waybar/brightness/brightness-lib.sh omarchy-waybar-brightness/waybar/brightness/brightness-status.sh omarchy-waybar-brightness/tests/test-brightness-status.sh
git commit -m "feat: add brightness waybar status output"
```

### Task 4: Добавить управление яркостью вверх/вниз

**Files:**
- Modify: `omarchy-waybar-brightness/waybar/brightness/brightness-lib.sh`
- Create: `omarchy-waybar-brightness/waybar/brightness/brightness-control.sh`
- Create: `omarchy-waybar-brightness/tests/test-brightness-control.sh`

- [ ] **Step 1: Написать падающий тест, что `up` и `down` вызывают нужные backend-команды**

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTROL="$ROOT/waybar/brightness/brightness-control.sh"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/log" \
WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-backlight" \
WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-none" \
"$CONTROL" up

grep -q 'set 5%+' "$LOG_DIR/log"

WAYBAR_BRIGHTNESS_LOG="$LOG_DIR/log2" \
WAYBAR_BRIGHTNESS_BRIGHTNESSCTL="$ROOT/tests/fixtures/bin/brightnessctl-none" \
WAYBAR_BRIGHTNESS_DDCUTIL="$ROOT/tests/fixtures/bin/ddcutil-single" \
"$CONTROL" down

grep -q 'setvcp 10 5-' "$LOG_DIR/log2"

printf 'ok\n'
```

- [ ] **Step 2: Запустить тест и убедиться, что он падает из-за отсутствующего control-скрипта**

Run: `./omarchy-waybar-brightness/tests/test-brightness-control.sh`

Expected: FAIL for missing script or missing commands

- [ ] **Step 3: Реализовать изменение яркости и управляющий скрипт**

```sh
# brightness-lib.sh
brightness_change() {
  local target="$1"
  local direction="$2"
  local kind="${target%%:*}"
  local name="${target#*:}"
  local delta

  case "$direction" in
    up) delta='5%+' ;;
    down) delta='5%-' ;;
    *) return 1 ;;
  esac

  if [ "$kind" = 'backlight' ]; then
    brightnessctl_cmd --device "$name" set "$delta"
    return 0
  fi

  if [ "$kind" = 'ddc' ]; then
    ddcutil_cmd --bus "${name#bus-}" setvcp 10 "${delta%%%}"
    return 0
  fi

  return 1
}
```

```sh
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/brightness-lib.sh"

direction="${1:-}"
target="$(brightness_detect_active)"

[ "$target" != 'unsupported:none' ] || exit 0
brightness_change "$target" "$direction"
```

- [ ] **Step 4: Запустить тест и убедиться, что он проходит**

Run: `./omarchy-waybar-brightness/tests/test-brightness-control.sh`

Expected: PASS with `ok`

- [ ] **Step 5: Закоммитить управление яркостью**

```bash
git add omarchy-waybar-brightness/waybar/brightness/brightness-lib.sh omarchy-waybar-brightness/waybar/brightness/brightness-control.sh omarchy-waybar-brightness/tests/test-brightness-control.sh
git commit -m "feat: add brightness scroll controls"
```

### Task 5: Реализовать установку, удаление, CSS и README

**Files:**
- Create: `omarchy-waybar-brightness/install.sh`
- Create: `omarchy-waybar-brightness/uninstall.sh`
- Create: `omarchy-waybar-brightness/waybar/brightness/brightness.css`
- Create: `omarchy-waybar-brightness/tests/test-install.sh`
- Create: `omarchy-waybar-brightness/tests/fixtures/config.jsonc`
- Create: `omarchy-waybar-brightness/tests/fixtures/style.css`
- Modify: `omarchy-waybar-brightness/README.md`

- [ ] **Step 1: Написать падающий тест на идемпотентную установку и корректное удаление**

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/.config/waybar"
cp "$ROOT/tests/fixtures/config.jsonc" "$WORKDIR/.config/waybar/config.jsonc"
cp "$ROOT/tests/fixtures/style.css" "$WORKDIR/.config/waybar/style.css"

HOME="$WORKDIR" "$ROOT/install.sh"
HOME="$WORKDIR" "$ROOT/install.sh"

grep -q 'custom/brightness' "$WORKDIR/.config/waybar/config.jsonc"
grep -q 'brightness.css' "$WORKDIR/.config/waybar/style.css"

count="$(grep -o 'custom/brightness' "$WORKDIR/.config/waybar/config.jsonc" | wc -l)"
[ "$count" = '2' ] || { echo "ожидалось 2 вхождения: в modules-right и в объекте модуля"; exit 1; }

HOME="$WORKDIR" "$ROOT/uninstall.sh"

! grep -q 'custom/brightness' "$WORKDIR/.config/waybar/config.jsonc"
! grep -q 'brightness.css' "$WORKDIR/.config/waybar/style.css"

printf 'ok\n'
```

- [ ] **Step 2: Запустить тест и убедиться, что он падает из-за отсутствующих install/uninstall**

Run: `./omarchy-waybar-brightness/tests/test-install.sh`

Expected: FAIL for missing scripts

- [ ] **Step 3: Реализовать CSS и install/uninstall с marker-блоками**

```css
#custom-brightness {
  min-width: 12px;
  margin: 0 7.5px;
}

#custom-brightness.active {
  color: @foreground;
}

#custom-brightness.unsupported {
  color: #888;
}
```

```sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.config/waybar/brightness"
CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

mkdir -p "$TARGET_DIR"
cp -f "$ROOT/waybar/brightness/brightness-lib.sh" "$TARGET_DIR/brightness-lib.sh"
cp -f "$ROOT/waybar/brightness/brightness-status.sh" "$TARGET_DIR/brightness-status.sh"
cp -f "$ROOT/waybar/brightness/brightness-control.sh" "$TARGET_DIR/brightness-control.sh"
cp -f "$ROOT/waybar/brightness/brightness.css" "$TARGET_DIR/brightness.css"
chmod +x "$TARGET_DIR/brightness-status.sh" "$TARGET_DIR/brightness-control.sh"

perl -0pi -e 's/"battery"/"custom\/brightness", "battery"/' "$CONFIG" unless grep -q 'custom/brightness' "$CONFIG"

if ! grep -q '"custom/brightness"' "$CONFIG"; then
  exit 1
fi

if ! grep -q '# opencode' "$STYLE"; then
  :
fi

if ! grep -q 'brightness.css' "$STYLE"; then
  printf '\n@import "./brightness/brightness.css";\n' >> "$STYLE"
fi

omarchy-restart-waybar
```

```sh
#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

perl -0pi -e 's/\s*"custom\/brightness",\s*"battery"/"battery"/g' "$CONFIG"
perl -0pi -e 's/\n@import "\.\/brightness\/brightness\.css";\n?/\n/g' "$STYLE"
rm -rf "$HOME/.config/waybar/brightness"

omarchy-restart-waybar
```

- [ ] **Step 4: Дописать README с установкой, проверкой и удалением**

```md
# Omarchy Waybar Brightness

## Что делает

Добавляет в Waybar модуль яркости с иконкой солнца и процентами.

## Установка

```bash
cd Omarchy-Stuff/omarchy-waybar-brightness
./install.sh
```

## Проверка

```bash
~/.config/waybar/brightness/brightness-status.sh
brightnessctl --machine-readable --list
ddcutil detect --brief
```

## Удаление

```bash
./uninstall.sh
```
```

- [ ] **Step 5: Запустить тест установки и убедиться, что он проходит**

Run: `./omarchy-waybar-brightness/tests/test-install.sh`

Expected: PASS with `ok`

- [ ] **Step 6: Закоммитить установку, стили и документацию**

```bash
git add omarchy-waybar-brightness/install.sh omarchy-waybar-brightness/uninstall.sh omarchy-waybar-brightness/waybar/brightness/brightness.css omarchy-waybar-brightness/tests/test-install.sh omarchy-waybar-brightness/tests/fixtures omarchy-waybar-brightness/README.md
git commit -m "feat: add installer for waybar brightness module"
```

### Task 6: Сквозная проверка фичи в репозитории и на локальной Omarchy-конфигурации

**Files:**
- Modify: `omarchy-waybar-brightness/README.md` (если всплывут реальные команды/заметки)

- [ ] **Step 1: Прогнать все автоматические shell-тесты**

Run: `bash -lc './omarchy-waybar-brightness/tests/test-brightness-lib.sh && ./omarchy-waybar-brightness/tests/test-brightness-status.sh && ./omarchy-waybar-brightness/tests/test-brightness-control.sh && ./omarchy-waybar-brightness/tests/test-install.sh'`

Expected: PASS with four `ok`

- [ ] **Step 2: Установить фичу в текущую Omarchy-конфигурацию и проверить Waybar**

Run: `bash -lc 'cd omarchy-waybar-brightness && ./install.sh'`

Expected: PASS, `custom/brightness` появляется в `~/.config/waybar/config.jsonc`, а Waybar перезапускается без ошибок.

- [ ] **Step 3: Проверить статусный JSON вживую**

Run: `~/.config/waybar/brightness/brightness-status.sh | jq .`

Expected: JSON с `text` и `class`; либо `active` с процентами, либо `unsupported` с одной иконкой.

- [ ] **Step 4: Проверить удаление и обратимость**

Run: `bash -lc 'cd omarchy-waybar-brightness && ./uninstall.sh'`

Expected: PASS, модуль и CSS-импорт удалены, Waybar перезапущен.

- [ ] **Step 5: Закоммитить финальные правки после верификации**

```bash
git add omarchy-waybar-brightness/README.md
git commit -m "docs: finalize waybar brightness usage notes"
```

## Самопроверка плана

- Покрытие спецификации: отдельный каталог фичи, выбор `backlight`/DDC, JSON-статус, скролл-управление, серое состояние, install/uninstall, идемпотентность и проверка на живой Omarchy включены в Task 1-6.
- Плейсхолдеров вида `TODO`/`TBD` нет; каждый кодовый шаг содержит конкретный файл, код и команду проверки.
- Имена интерфейсов согласованы по всему плану: `brightness_detect_active`, `brightness_get_percent`, `brightness_change`, `brightness-status.sh`, `brightness-control.sh`.
