#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SCRIPT="$ROOT/scripts/bootstrap-elephant.sh"
PATCH_SOURCE_DIR="$ROOT/patches/desktopapplications"
TMP_ROOT="$(mktemp -d)"

cleanup() {
	rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

create_fake_git() {
	local fake_git_dir="$1"
	mkdir -p "$fake_git_dir"
	cat >"$fake_git_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "clone" ]; then
	from="$FAKE_UPSTREAM_DIR"
	to="$3"
	mkdir -p "$to"
	cp -rf "$from/." "$to"
	exit 0
fi

if [ "$1" = "-C" ] && [ "$3" = "checkout" ]; then
	exit 0
fi

printf 'unexpected git invocation: %s\n' "$*" >&2
	exit 1
EOF
	chmod +x "$fake_git_dir/git"
}

create_workspace() {
	local workspace="$1"
	local upstream_fixture="$2"
	mkdir -p "$workspace/scripts" "$workspace/patches/desktopapplications" "$workspace/vendor/elephant"
	cp -f "$SOURCE_SCRIPT" "$workspace/scripts/bootstrap-elephant.sh"
	cp -f "$PATCH_SOURCE_DIR"/*.go "$workspace/patches/desktopapplications/"
	printf 'old vendor\n' >"$workspace/vendor/elephant/RESTORE_SENTINEL"
	mkdir -p "$workspace/upstream"
	cp -rf "$upstream_fixture/." "$workspace/upstream"
}

assert_restored_vendor() {
	local workspace="$1"
	if [ ! -f "$workspace/vendor/elephant/RESTORE_SENTINEL" ]; then
		printf 'expected previous vendor tree to be restored\n' >&2
		return 1
	fi

	if compgen -G "$workspace/vendor/elephant.backup.*" >/dev/null; then
		printf 'expected no leftover backup directory\n' >&2
		return 1
	fi
}

test_restores_previous_vendor_when_overlay_copy_fails() {
	local test_dir="$TMP_ROOT/overlay-failure"
	local fake_git_dir="$test_dir/bin"
	local workspace="$test_dir/workspace"
	local upstream_fixture="$test_dir/upstream-fixture"

	mkdir -p "$upstream_fixture/internal/providers/desktopapplications"
	printf 'upstream query\n' >"$upstream_fixture/internal/providers/desktopapplications/query.go"
	printf 'upstream test\n' >"$upstream_fixture/internal/providers/desktopapplications/query_test.go"
	printf 'upstream layout test\n' >"$upstream_fixture/internal/providers/desktopapplications/layout_test.go"

	create_workspace "$workspace" "$upstream_fixture"
	rm -f "$workspace/patches/desktopapplications/layout.go"
	create_fake_git "$fake_git_dir"

	if PATH="$fake_git_dir:$PATH" FAKE_UPSTREAM_DIR="$workspace/upstream" "$workspace/scripts/bootstrap-elephant.sh"; then
		printf 'expected bootstrap to fail when an overlay file is missing\n' >&2
		return 1
	fi

	assert_restored_vendor "$workspace"
}

test_fails_when_upstream_provider_path_is_missing() {
	local test_dir="$TMP_ROOT/provider-path-missing"
	local fake_git_dir="$test_dir/bin"
	local workspace="$test_dir/workspace"
	local upstream_fixture="$test_dir/upstream-fixture"

	mkdir -p "$upstream_fixture/internal/providers"
	printf 'placeholder\n' >"$upstream_fixture/internal/providers/README"

	create_workspace "$workspace" "$upstream_fixture"
	create_fake_git "$fake_git_dir"

	if PATH="$fake_git_dir:$PATH" FAKE_UPSTREAM_DIR="$workspace/upstream" "$workspace/scripts/bootstrap-elephant.sh"; then
		printf 'expected bootstrap to fail when upstream provider path is missing\n' >&2
		return 1
	fi

	assert_restored_vendor "$workspace"
}

test_restores_previous_vendor_when_overlay_copy_fails
test_fails_when_upstream_provider_path_is_missing
