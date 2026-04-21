# Omarchy Walker Layout Search Design

## Summary

Add bidirectional keyboard-layout-aware application search to Omarchy's Walker menu.
The solution must let users find applications when the active keyboard layout does not match the application's name, while preserving normal search by English and Russian names.

Examples:

- `firefox` must match `ашкуащч`
- `ашкуащч` must match `firefox`
- `терминал` must match `nthvbyfk`
- Russian localized names must still be searchable directly

## Goals

- Support bidirectional physical-key layout matching between English and Russian keyboard layouts for desktop application search.
- Preserve existing direct search behavior for normal English and Russian names.
- Avoid modifying `~/.local/share/omarchy/`.
- Avoid generating `.desktop` override files in `~/.local/share/applications`.
- Ensure newly installed applications are covered automatically without regeneration steps.
- Produce a portable, separately buildable solution that can be reused on other Omarchy installations.

## Non-Goals

- Smart linguistic transliteration.
- Changes to Walker UI theme or visual layout.
- Changes to Omarchy upstream source tree.
- Supporting arbitrary keyboard layouts beyond the English/Russian physical-key mapping in the first version.

## Current State

The active Omarchy setup uses Walker with Elephant as the backend provider service.

Relevant local configuration:

- `~/.config/walker/config.toml` uses the `desktopapplications` provider.
- `~/.config/elephant/desktopapplications.toml` currently sets `only_search_title = true`.

Relevant upstream behavior confirmed from Elephant source:

- `desktopapplications` can search `Name`, `Exec`, `Parent`, `GenericName`, `Keywords`, and `Comment` when `only_search_title = false`.
- Current provider logic does not perform keyboard-layout conversion on either the query or indexed strings.

Because of that, pure config changes are insufficient for matching `firefox` <-> `ашкуащч`.

## Chosen Approach

Implement a small patch/fork of Elephant's `desktopapplications` provider and keep it as one solution inside the broader personal Omarchy repository under:

- repository root: `~/Omarchy-Stuff`
- solution directory: `~/Omarchy-Stuff/omarchy-walker-layout-search`

The `Omarchy-Stuff` repository will contain this solution alongside other Omarchy customizations. This specific solution directory will contain:

- the patched Elephant source or patch set
- repeatable build scripts
- installation instructions for Omarchy
- user-service integration notes
- produced artifacts for reuse on other systems

This approach is preferred over generated `.desktop` overrides because it:

- fixes the root cause in the search layer
- automatically covers newly installed applications
- keeps user application metadata untouched
- keeps the solution portable and reproducible

## Architecture

### Runtime Components

- `walker`: unchanged frontend launcher
- `elephant`: custom user-managed build with a patched `desktopapplications` provider
- `systemd --user`: starts and manages the custom Elephant service

### Integration Boundary

Omarchy continues to launch Walker normally.
Walker continues to talk to Elephant normally.
The only functional replacement is the Elephant build used by the user session.

No Omarchy source files under `~/.local/share/omarchy/` are edited.

## Search Design

### Matching Model

The provider will compare the original query and its layout-converted variants against the existing application metadata fields.

For each incoming query, the provider will derive up to three candidate search forms:

- original query
- query converted from Russian keyboard positions to English characters
- query converted from English keyboard positions to Russian characters

Application fields remain unchanged. The provider evaluates the query candidate set against the normal searchable fields that are already parsed from desktop entries.

The search remains a physical-key layout conversion, not semantic transliteration.

### Searchable Fields

The provider must search across:

- `Name`
- `GenericName`
- `Keywords`
- `Comment`
- `Exec`
- `Parent` when relevant to the existing provider logic

To enable this, local Elephant config must no longer restrict search to title only.
The effective configuration will set:

- `only_search_title = false`

### Scoring Rules

Normal exact or fuzzy matches on the original text must rank above layout-converted matches.

Proposed ranking policy:

- original direct match: no penalty beyond existing provider logic
- layout-converted match: apply an additional score penalty so it never outranks a comparable direct match
- if multiple variants match, keep the highest resulting score

This ensures:

- `firefox` still ranks as a stronger result for `firefox`
- `ашкуащч` still finds Firefox
- direct Russian names still rank strongly when the user types the real Russian name

### Duplicate Suppression

If a layout conversion produces the same string as the original query or repeats another variant, the provider must skip the duplicate comparison.

### Mixed Input

If the user enters mixed English and Russian characters, the provider still attempts normal matching first, then layout-derived variants.
No special-case linguistic heuristics are added in the first version.

## Implementation Outline

### Provider Changes

Patch Elephant's `internal/providers/desktopapplications` implementation.

Expected code changes:

- add a deterministic English/Russian physical-key mapping helper
- derive layout-normalized query variants
- update `calcScore` to evaluate original and converted query forms against the existing application fields
- apply a fixed penalty for layout-converted matches
- keep existing provider behavior intact outside scoring

The patch should stay local to `desktopapplications` unless a shared helper clearly reduces duplication without broadening scope.

### Configuration Changes

User-side config changes are limited to:

- ensuring the custom Elephant build is the one being started by the user service
- setting `only_search_title = false` in the effective Elephant desktop applications config if needed

Walker configuration should remain as close as possible to the current Omarchy setup.

### Service Integration

The `Omarchy-Stuff` repository must document how to run the custom Elephant build under `systemd --user` without editing Omarchy-managed files.

Preferred integration:

- provide a user service unit or override for the custom Elephant binary
- restart Elephant and Walker through user-level commands after installation

## Packaging And Repository Layout

The portable solution will live inside the shared Omarchy repository:

- repository root: `~/Omarchy-Stuff`
- solution path: `~/Omarchy-Stuff/omarchy-walker-layout-search`

Suggested repository structure:

- `docs/` for shared repository-level specs and documentation
- `omarchy-walker-layout-search/patches/` for source patches if patch-based
- `omarchy-walker-layout-search/scripts/` for build and install helpers
- `omarchy-walker-layout-search/dist/` for optional generated artifacts
- `omarchy-walker-layout-search/examples/` for example service files or config snippets

The repository must support additional Omarchy solutions over time while keeping this solution separately reusable on other systems.

## Verification Plan

### Automated Tests

Add tests around the provider scoring/matching layer for pairs such as:

- `firefox` <-> `ашкуащч`
- `terminal` <-> `еуьштад`
- `терминал` <-> `nthvbyfk`

Tests must also verify ranking expectations:

- direct original match ranks above layout-converted match when both are available
- Russian direct matches remain functional
- non-converted search still behaves correctly

### Manual Verification

On a running Omarchy session, verify:

- Walker starts correctly with the custom Elephant backend
- installed applications appear normally
- English application names match when typed with Russian layout
- Russian names match when typed with English layout
- newly installed applications are searchable without generating overrides

## Failure Modes And Diagnostics

Potential failure cases:

- custom Elephant service not running
- Walker still connected to the wrong Elephant binary
- layout penalty causing poor ranking
- local config still forcing `only_search_title = true`

Required diagnostics:

- documented service status checks
- clear restart instructions for Elephant and Walker
- logs or debug steps for confirming which Elephant binary is active

## Risks

- upstream Elephant changes may require rebasing a small patch over time
- ranking may need small tuning after real-world testing
- user-service integration details may differ slightly across Omarchy setups

These risks are acceptable because the patch surface is intentionally narrow and isolated.

## Rollout Plan

1. Use `~/Omarchy-Stuff/` as the shared repository root.
2. Create `omarchy-walker-layout-search/` as the solution directory inside it.
3. Bring in Elephant source or a patch workflow.
4. Add failing tests for layout-based matching.
5. Implement the provider patch.
6. Build the custom Elephant binary.
7. Integrate it with user services on the current Omarchy machine.
8. Verify behavior manually in Walker.
9. Document installation for other Omarchy systems.

## Success Criteria

The design is successful when all of the following are true:

- `firefox` can be found with `ашкуащч`
- `ашкуащч` can be found with `firefox`
- Russian app names still match directly
- no `.desktop` override generation is required
- newly installed applications work automatically
- the solution can be built and reused independently on another Omarchy installation
