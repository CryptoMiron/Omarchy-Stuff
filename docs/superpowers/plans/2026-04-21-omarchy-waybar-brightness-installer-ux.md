# Omarchy Waybar Brightness Installer UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сделать `install.sh` самовосстанавливающимся для типовой DDC-настройки на свежей Omarchy-системе и визуально усилить иконку солнца в Waybar.

**Architecture:** Изменения остаются локальными для фичи `omarchy-waybar-brightness`: installer получает небольшой блок предварительной DDC-подготовки с мягкой деградацией, а CSS модуля получает минимальную визуальную корректировку без изменения архитектуры или формата данных. Поведение будет проверяться существующим shell-интеграционным тестом с расширенными фикстурами для package/modprobe/detect-сценариев.

**Tech Stack:** bash, Omarchy CLI (`omarchy-pkg-add`, `omarchy-restart-waybar`), `ddcutil`, `modprobe`, Waybar CSS, shell tests.

---

## Структура файлов

- Modify: `omarchy-waybar-brightness/install.sh`
- Modify: `omarchy-waybar-brightness/waybar/brightness/brightness.css`
- Modify: `omarchy-waybar-brightness/tests/test-install.sh`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/omarchy-pkg-add-ok`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/modprobe-ok`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-detect-ok`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-missing`
- Modify: `omarchy-waybar-brightness/README.md`

### Task 1: Добавить self-healing DDC-подготовку в installer

**Files:**
- Modify: `omarchy-waybar-brightness/install.sh`
- Modify: `omarchy-waybar-brightness/tests/test-install.sh`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/omarchy-pkg-add-ok`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/modprobe-ok`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-detect-ok`
- Create: `omarchy-waybar-brightness/tests/fixtures/bin/ddcutil-missing`
- Modify: `omarchy-waybar-brightness/README.md`

- [ ] **Step 1: Написать падающий тест на автоматическую DDC-подготовку без поломки установки**

```bash
test_case_prepare_external_ddc() {
  local home_dir="$TMPDIR/ddc/home"
  local bin_dir="$home_dir/bin"
  local waybar_dir="$home_dir/.config/waybar"
  local op_log="$TMPDIR/ddc/ops.log"

  mkdir -p "$bin_dir" "$waybar_dir"
  cp -f "$ROOT/tests/fixtures/config.jsonc" "$waybar_dir/config.jsonc"
  cp -f "$ROOT/tests/fixtures/style.css" "$waybar_dir/style.css"

  cp -f "$ROOT/tests/fixtures/bin/omarchy-pkg-add-ok" "$bin_dir/omarchy-pkg-add"
  cp -f "$ROOT/tests/fixtures/bin/modprobe-ok" "$bin_dir/modprobe"
  cp -f "$ROOT/tests/fixtures/bin/ddcutil-missing" "$bin_dir/ddcutil"
  cp -f "$ROOT/tests/fixtures/bin/ddcutil-detect-ok" "$bin_dir/ddcutil-after-install"

  export HOME="$home_dir"
  export PATH="$bin_dir:$PATH"
  export WAYBAR_TEST_OP_LOG="$op_log"

  "$INSTALL"

  grep -F -q 'omarchy-pkg-add ddcutil' "$op_log"
  grep -F -q 'modprobe i2c-dev' "$op_log"
  grep -F -q 'ddcutil detect --brief' "$op_log"
  grep -F -q 'custom/brightness' "$waybar_dir/config.jsonc"
}
```

- [ ] **Step 2: Запустить тест и убедиться, что он падает из-за отсутствующей DDC-подготовки**

Run: `./omarchy-waybar-brightness/tests/test-install.sh`

Expected: FAIL, потому что installer пока не вызывает `omarchy-pkg-add`, `modprobe` и DDC-проверку.

- [ ] **Step 3: Реализовать минимальную DDC-подготовку в installer**

```bash
ensure_external_ddc_ready() {
  local status=0

  if ! command -v ddcutil >/dev/null 2>&1; then
    if command -v omarchy-pkg-add >/dev/null 2>&1; then
      omarchy-pkg-add ddcutil || status=1
    else
      status=1
    fi
  fi

  if command -v modprobe >/dev/null 2>&1; then
    modprobe i2c-dev || status=1
  fi

  if command -v ddcutil >/dev/null 2>&1; then
    ddcutil detect --brief >/dev/null 2>&1 || status=1
  else
    status=1
  fi

  return "$status"
}

if ! ensure_external_ddc_ready; then
  printf 'warning: DDC setup is incomplete; module will still be installed\n' >&2
fi
```

- [ ] **Step 4: Обновить README под новое поведение installer**

```md
## Installer Behavior

On fresh systems, `install.sh` attempts to prepare DDC support automatically:

- installs `ddcutil` through `omarchy-pkg-add ddcutil` when needed
- tries to load `i2c-dev`
- probes `ddcutil detect --brief`

If this setup does not succeed, installation still completes and the module remains available in Waybar with diagnostic fallback.
```

- [ ] **Step 5: Запустить тесты и убедиться, что installer по-прежнему проходит старые сценарии**

Run: `bash -lc './omarchy-waybar-brightness/tests/test-install.sh && ./omarchy-waybar-brightness/tests/test-brightness-status.sh && ./omarchy-waybar-brightness/tests/test-brightness-control.sh'`

Expected: PASS with `ok` from all scripts.

- [ ] **Step 6: Закоммитить installer UX**

```bash
git add omarchy-waybar-brightness/install.sh omarchy-waybar-brightness/tests/test-install.sh omarchy-waybar-brightness/tests/fixtures/bin omarchy-waybar-brightness/README.md
git commit -m "feat: auto-prepare ddc support during install"
```

### Task 2: Сделать иконку солнца визуально заметной

**Files:**
- Modify: `omarchy-waybar-brightness/waybar/brightness/brightness.css`

- [ ] **Step 1: Написать падающую проверку CSS-правил для заметной иконки**

```bash
grep -F -q 'font-size:' omarchy-waybar-brightness/waybar/brightness/brightness.css
grep -F -q 'min-width: 72px;' omarchy-waybar-brightness/waybar/brightness/brightness.css
```

- [ ] **Step 2: Запустить проверку и убедиться, что она падает**

Run: `bash -lc 'grep -F -q "font-size:" omarchy-waybar-brightness/waybar/brightness/brightness.css && grep -F -q "min-width: 72px;" omarchy-waybar-brightness/waybar/brightness/brightness.css'`

Expected: FAIL, потому что CSS пока не содержит `font-size` и использует `min-width: 56px;`.

- [ ] **Step 3: Внести минимальный визуальный апдейт CSS**

```css
#custom-brightness {
  min-width: 72px;
  font-size: 16px;
  font-weight: 600;
}

#custom-brightness.unsupported {
  opacity: 0.6;
}
```

- [ ] **Step 4: Повторно запустить CSS-проверку**

Run: `bash -lc 'grep -F -q "font-size:" omarchy-waybar-brightness/waybar/brightness/brightness.css && grep -F -q "min-width: 72px;" omarchy-waybar-brightness/waybar/brightness/brightness.css'`

Expected: PASS

- [ ] **Step 5: Закоммитить визуальный апдейт модуля**

```bash
git add omarchy-waybar-brightness/waybar/brightness/brightness.css
git commit -m "style: make brightness icon easier to read"
```

## Самопроверка плана

- Покрытие спецификации: installer self-healing, мягкая деградация при неудаче DDC-подготовки, визуальное усиление иконки и README-обновление покрыты Task 1-2.
- Плейсхолдеров нет; у каждого шага есть точный файл, код и команда проверки.
- Имена интерфейсов согласованы: `ensure_external_ddc_ready`, `install.sh`, `brightness.css`.
