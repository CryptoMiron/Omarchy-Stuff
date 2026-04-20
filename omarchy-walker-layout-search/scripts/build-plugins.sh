#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT/vendor/elephant"
PLUGIN_DIR="$ROOT/dist/plugins"

PROVIDERS=(bluetooth calc clipboard desktopapplications files menus providerlist runner symbols todo unicode websearch)

mkdir -p "$PLUGIN_DIR"

failed=()
built=()

for p in "${PROVIDERS[@]}"; do
	provider_src="$VENDOR_DIR/internal/providers/$p"
	if [ ! -f "$provider_src/makefile" ]; then
		printf 'SKIP %s (no makefile)\n' "$p"
		continue
	fi

	printf 'BUILD %s\n' "$p"
	if (cd "$provider_src" && make build 2>&1); then
		so_file="$provider_src/${p}.so"
		if [ -f "$so_file" ]; then
			cp -f "$so_file" "$PLUGIN_DIR/"
			built+=("$p")
		else
			failed+=("$p")
			printf 'FAIL %s: .so not found after build\n' "$p" >&2
		fi
	else
		failed+=("$p")
		printf 'FAIL %s: build error\n' "$p" >&2
	fi
done

printf '\n=== Plugin Build Summary ===\n'
printf 'Built:  %d/%d\n' "${#built[@]}" "${#PROVIDERS[@]}"
printf 'Output: %s\n' "$PLUGIN_DIR"
ls -la "$PLUGIN_DIR/"*.so 2>/dev/null | awk '{print "  " $NF}'

if [ "${#failed[@]}" -gt 0 ]; then
	printf '\nFailed providers:\n'
	for f in "${failed[@]}"; do
		printf '  - %s\n' "$f"
	done
	exit 1
fi
