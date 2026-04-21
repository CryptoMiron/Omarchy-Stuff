# Omarchy Waybar Brightness

Portable Waybar brightness module for Omarchy.

## Files

- `waybar/brightness/brightness-status.sh` exposes the current brightness as Waybar JSON.
- `waybar/brightness/brightness-control.sh` increases or decreases brightness for the active backend.
- `waybar/brightness/brightness.css` adds a small width hint and a dimmed unsupported state.
- `install.sh` installs the module into `~/.config/waybar/` and updates Waybar config/CSS.
- `uninstall.sh` removes the module from Waybar config/CSS and deletes the installed payload.

## Install

Run:

```bash
./install.sh
```

The installer:

- copies the brightness payload into `~/.config/waybar/brightness/`
- adds `custom/brightness` to `modules-right` before `battery`
- appends the module definition to `~/.config/waybar/config.jsonc`
- imports `brightness/brightness.css` from `~/.config/waybar/style.css`
- configures scroll actions so wheel up increases brightness and wheel down decreases it
- checks whether `ddcutil` is available and tries `omarchy-pkg-add ddcutil` when it is missing
- tries `modprobe i2c-dev` when `modprobe` is available
- runs `ddcutil detect --brief` when `ddcutil` is available to preflight external-monitor support
- prints warnings to stderr if DDC preparation fails, but still completes the Waybar module install
- is safe to run multiple times
- calls `omarchy-restart-waybar`

## Dependencies

- `brightnessctl` is used for backlight devices exposed through `/sys/class/backlight`.
- `ddcutil` is used as a fallback for external displays that support DDC/CI.
- the installer now attempts to self-heal the common DDC prerequisites (`ddcutil` package and `i2c-dev` module)
- If both are unavailable, the module stays visible but switches to the unsupported state.

## Device Detection

Check what the scripts can see:

```bash
brightnessctl --machine-readable --list
ddcutil detect --brief
```

Expected behavior:

- if `brightnessctl` reports a `backlight,...` entry, that device is preferred
- otherwise the first detected DDC/CI display from `ddcutil detect --brief` is used

## Unsupported State

The module shows a dimmed gray appearance when it cannot read a usable brightness value.

That usually means one of these cases:

- no backlight device was found
- no DDC/CI monitor was detected
- a monitor was detected but brightness could not be read
- `brightnessctl` or `ddcutil` is missing from the system

In this state Waybar shows the sun icon without a percentage and the module gets the `unsupported` class from the status script.

## Basic Troubleshooting

If the module is unavailable or stays gray:

```bash
~/.config/waybar/brightness/brightness-status.sh
brightnessctl --machine-readable --list
ddcutil detect --brief
```

Look for:

- JSON with `"class":"active"` and a percentage from `brightness-status.sh`
- at least one `backlight` entry from `brightnessctl`
- at least one detected display from `ddcutil`

If none of those appear, install the missing tool or verify that the display exposes backlight or DDC/CI brightness control.

## Uninstall

Run:

```bash
./uninstall.sh
```

The uninstaller removes the copied files, CSS import, and `config.jsonc` entries, then calls `omarchy-restart-waybar`.

## Tests

Run:

```bash
./tests/test-install.sh
./tests/test-brightness-control.sh
./tests/test-brightness-status.sh
```
