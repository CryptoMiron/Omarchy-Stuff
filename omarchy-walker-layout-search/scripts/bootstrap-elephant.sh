#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT/vendor/elephant"
PATCH_DIR="$ROOT/patches/desktopapplications"
UPSTREAM_URL="https://github.com/abenz1267/elephant.git"
UPSTREAM_COMMIT="376ee71c66db38683daabd57350bf3f6f086eaf8"
TMP_DIR="$(mktemp -d "$ROOT/vendor/elephant.tmp.XXXXXX")"
BACKUP_DIR=""
OVERLAY_FILES=(layout.go layout_test.go query.go query_test.go)

cleanup() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi

	if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ] && [ ! -e "$VENDOR_DIR" ]; then
		mv "$BACKUP_DIR" "$VENDOR_DIR"
	fi
}

trap cleanup EXIT

git clone "$UPSTREAM_URL" "$TMP_DIR"
git -C "$TMP_DIR" checkout "$UPSTREAM_COMMIT"
rm -rf "$TMP_DIR/.git"

PROVIDER_DIR="$TMP_DIR/internal/providers/desktopapplications"

if [ ! -d "$PROVIDER_DIR" ]; then
	printf 'expected upstream provider directory at %s\n' "$PROVIDER_DIR" >&2
	exit 1
fi

for file in "${OVERLAY_FILES[@]}"; do
	if [ ! -f "$PATCH_DIR/$file" ]; then
		printf 'expected overlay source file at %s\n' "$PATCH_DIR/$file" >&2
		exit 1
	fi
	done

for file in query.go; do
	if [ ! -f "$PROVIDER_DIR/$file" ]; then
		printf 'expected upstream provider file at %s\n' "$PROVIDER_DIR/$file" >&2
		exit 1
	fi
done

for file in "${OVERLAY_FILES[@]}"; do
	install -m644 "$PATCH_DIR/$file" "$PROVIDER_DIR/$file"
	if [ ! -f "$PROVIDER_DIR/$file" ]; then
		printf 'expected overlay target file at %s\n' "$PROVIDER_DIR/$file" >&2
		exit 1
	fi
done

if [ -d "$VENDOR_DIR" ]; then
	BACKUP_DIR="$ROOT/vendor/elephant.backup.$$"
	mv "$VENDOR_DIR" "$BACKUP_DIR"
fi

mv "$TMP_DIR" "$VENDOR_DIR"
TMP_DIR=""

if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
	rm -rf "$BACKUP_DIR"
	BACKUP_DIR=""
fi

trap - EXIT
