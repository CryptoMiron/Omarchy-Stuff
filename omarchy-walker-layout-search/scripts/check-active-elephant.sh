#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$ROOT/dist/plugins"

exec_main_pid="$(systemctl --user show elephant.service --property=ExecMainPID --value)"
main_pid="$(systemctl --user show elephant.service --property=MainPID --value)"
pid="$exec_main_pid"

if [[ "$pid" == "0" || -z "$pid" ]]; then
	pid="$main_pid"
fi

if [[ "$pid" == "0" || -z "$pid" ]]; then
	printf 'elephant.service has no running main process\n' >&2
	exit 1
fi

if [[ ! -e "/proc/$pid/exe" ]]; then
	printf 'elephant.service main process %s is not available in /proc\n' "$pid" >&2
	exit 1
fi

printf 'Binary: '
readlink -f "/proc/$pid/exe"

plugin_count="$(ls "$PLUGIN_DIR"/*.so 2>/dev/null | wc -l)"
printf 'Plugins: %d in %s\n' "$plugin_count" "$PLUGIN_DIR"

printf '\nService properties:\n'
systemctl --user show elephant.service --property=MainPID --property=ExecMainPID --property=ExecStart --property=Environment
