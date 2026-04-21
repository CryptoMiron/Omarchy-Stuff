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
  brightnessctl_cmd --machine-readable --list 2>/dev/null |
    while IFS=, read -r class name _; do
      if [ "$class" = "backlight" ] && [ -n "$name" ]; then
        printf 'backlight:%s\n' "$name"
        return 0
      fi
    done
}

brightness_detect_ddc() {
  local line bus seen

  while IFS= read -r line; do
    case "$line" in
      Display\ *)
        bus=${line#Display }
        case " ${seen:-} " in
          *" $bus "*) ;;
          *)
            printf 'ddc:bus-%s\n' "$bus"
            return 0
            ;;
        esac
        seen="${seen:-} $bus"
        ;;
    esac
  done < <(ddcutil_cmd detect --brief 2>/dev/null)
}

brightness_get_ddc_levels() {
  local bus="$1"

  ddcutil_cmd --bus "$bus" getvcp 10 2>/dev/null |
    perl -ne 'print "$1 $2\n" if /current value =\s*([0-9]+), max value =\s*([0-9]+)/'
}

brightness_detect_active() {
  local found

  found="$(brightness_detect_backlight || true)"
  if [ -n "$found" ] && brightness_get_percent "$found" >/dev/null 2>&1; then
    printf '%s\n' "$found"
    return 0
  fi

  found="$(brightness_detect_ddc || true)"
  if [ -n "$found" ] && brightness_get_percent "$found" >/dev/null 2>&1; then
    printf '%s\n' "$found"
    return 0
  fi

  printf 'unsupported:none\n'
}

brightness_get_percent() {
  local target="$1"
  local kind="${target%%:*}"
  local name="${target#*:}"
  local percent=""

  if [ "$kind" = "backlight" ]; then
    percent="$(brightnessctl_cmd --machine-readable --device "$name" info 2>/dev/null |
      perl -ne 'print "$1\n" if /\(([0-9]+)%\)/')"
    [ -n "$percent" ] || return 1
    printf '%s\n' "$percent"
    return 0
  fi

  if [ "$kind" = "ddc" ]; then
    local current max

    read -r current max <<EOF || true
$(brightness_get_ddc_levels "${name#bus-}")
EOF
    [ -n "${current:-}" ] || return 1
    [ -n "${max:-}" ] || return 1
    [ "$max" -gt 0 ] || return 1
    percent="$(( current * 100 / max ))"
    printf '%s\n' "$percent"
    return 0
  fi

  return 1
}

brightness_change() {
  local target="$1"
  local direction="$2"
  local kind="${target%%:*}"
  local name="${target#*:}"
  local delta=""
  local ddc_op=""
  local ddc_amount=""

  case "$direction" in
    up)
      delta='5%+'
      ddc_op='+'
      ddc_amount='5'
      ;;
    down)
      delta='5%-'
      ddc_op='-'
      ddc_amount='5'
      ;;
    *)
      return 1
      ;;
  esac

  if [ "$kind" = "backlight" ]; then
    brightnessctl_cmd --device "$name" set "$delta"
    return 0
  fi

  if [ "$kind" = "ddc" ]; then
    local current max

    read -r current max <<EOF || true
$(brightness_get_ddc_levels "${name#bus-}")
EOF
    [ -n "${max:-}" ] || return 1
    [ "$max" -gt 0 ] || return 1
    ddc_amount="$(( (max * 5 + 99) / 100 ))"
    [ "$ddc_amount" -ge 1 ] || ddc_amount=1
    ddcutil_cmd --bus "${name#bus-}" setvcp 10 "$ddc_op" "$ddc_amount"
    return 0
  fi

  return 1
}
