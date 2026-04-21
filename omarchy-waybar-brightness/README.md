# Omarchy Waybar Brightness

Переносимый модуль яркости монитора для Waybar в Omarchy.

## Файлы

- `waybar/brightness/brightness-status.sh` — выводит текущую яркость в формате JSON для Waybar
- `waybar/brightness/brightness-control.sh` — увеличивает или уменьшает яркость через активный бэкенд
- `waybar/brightness/brightness.css` — стили: ширина, иконка, приглушённый режим для unsupported
- `install.sh` — устанавливает модуль в `~/.config/waybar/` и обновляет конфиг Waybar
- `uninstall.sh` — удаляет модуль из конфига Waybar и стирает установленные файлы

## Установка

Выполните:

```bash
./install.sh
```

Инсталлер:

- копирует файлы модуля в `~/.config/waybar/brightness/`
- добавляет `custom/brightness` в `modules-right` перед `battery`
- добавляет определение модуля в `~/.config/waybar/config.jsonc`
- подключает `brightness/brightness.css` из `~/.config/waybar/style.css`
- настраивает scroll-действия: колесо вверх — увеличить яркость, вниз — уменьшить
- проверяет наличие `ddcutil` и при отсутствии ставит через `omarchy-pkg-add ddcutil`
- пытается загрузить `i2c-dev` через `modprobe`
- запускает `ddcutil detect --brief` для проверки поддержки внешнего монитора
- выводит предупреждения в stderr при проблемах с DDC, но завершает установку модуля
- безопасен при повторном запуске (идемпотентный)
- вызывает `omarchy-restart-waybar`

## Зависимости

- `brightnessctl` — используется для backlight-устройств из `/sys/class/backlight`
- `ddcutil` — используется как fallback для внешних мониторов с поддержкой DDC/CI
- инсталлер автоматически пытается установить недостающие компоненты (`ddcutil`, `i2c-dev`)
- если оба метода недоступны, модуль остаётся видимым, но переходит в режим «unsupported»

## Определение устройства

Проверьте, что видят скрипты:

```bash
brightnessctl --machine-readable --list
ddcutil detect --brief
```

Ожидаемое поведение:

- если `brightnessctl` находит устройство `backlight,...`, оно используется优先
- иначе используется первый DDC/CI монитор из `ddcutil detect --brief`

## Состояние «unsupported»

Модуль показывает приглушённый серый вид, когда не может прочитать яркость.

Это обычно означает:

- backlight-устройство не найдено
- DDC/CI монитор не обнаружен
- монитор обнаружен, но яркость не удалось прочитать
- `brightnessctl` или `ddcutil` отсутствуют в системе

В этом состоянии Waybar показывает иконку солнца без процентов, модуль получает класс `unsupported`.

## Диагностика проблем

Если модуль недоступен или всегда серый:

```bash
~/.config/waybar/brightness/brightness-status.sh
brightnessctl --machine-readable --list
ddcutil detect --brief
```

Ищите:

- JSON с `"class":"active"` и процентами от `brightness-status.sh`
- хотя бы одну запись `backlight` от `brightnessctl`
- хотя бы один обнаруженный дисплей от `ddcutil`

Если ничего не найдено — установите недостающий инструмент или убедитесь, что дисплей поддерживает backlight или DDC/CI.

## Удаление

Выполните:

```bash
./uninstall.sh
```

Удаление стирает скопированные файлы, CSS-импорт и записи в `config.jsonc`, затем вызывает `omarchy-restart-waybar`.

## Тесты

Выполните:

```bash
./tests/test-install.sh
./tests/test-brightness-control.sh
./tests/test-brightness-status.sh
```
