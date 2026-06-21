#!/usr/bin/env bash
#
# lint-no-raw-tokens.sh
# ColimaStack
#
# Fails the build if raw color/font/systemImage literals appear in
# screen code outside of `ColimaStack/DesignSystem/`. The design
# system (see `openspec/changes/apple-design-award-ui/specs/design-system`)
# requires that every view consume tokens via `DesignSystem.*`,
# `Icon.*`, or the shared primitives.
#
# Also flags bare "No ..." text literals in view code (the
# empty-states pass requires `EmptyStateView`).
#
# Usage:
#   scripts/lint-no-raw-tokens.sh                 # check (fails on new violations)
#   scripts/lint-no-raw-tokens.sh --write-baseline  # write the current set as the baseline
#
# The baseline is stored at `scripts/.lint-no-raw-tokens.baseline` and
# is regenerated only when intentional design-system work is shipped.
# Subsequent runs fail only on violations that are not in the baseline.

set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCAN_ROOT="$REPO_ROOT/ColimaStack/Views"
BASELINE_FILE="$REPO_ROOT/scripts/.lint-no-raw-tokens.baseline"
ALLOWLIST=(
  "ColimaStack/DesignSystem/Icon.swift"
  "ColimaStack/Views/Tables/ResourceTables.swift"
  "ColimaStack/Views/MenuBarView.swift"
)

EXCLUDES=()
for path in "${ALLOWLIST[@]}"; do
  EXCLUDES+=(-e "$path")
done

WRITE_BASELINE=0
if [[ "${2:-}" == "--write-baseline" ]]; then
  WRITE_BASELINE=1
fi

scan() {
  local label="$1"
  local pattern="$2"
  rg --pcre2 --line-number --color=never "$pattern" "$SCAN_ROOT" 2>/dev/null \
     | rg -v "${EXCLUDES[@]}" || true
}

CURRENT_VIOLATIONS="$(
  {
    scan "Image(systemName:)" '\bImage\(\s*systemName\s*:'
    scan "Color() init" '\bColor\(\s*nsColor\s*:|\bColor\(\s*red\s*:|\bColor\(\s*green\s*:|\bColor\(\s*blue\s*:'
    scan ".foregroundStyle(Color.*)" '\.foregroundStyle\(\s*Color\.(blue|green|red|orange|yellow|purple|pink|secondary)\b'
    scan ".font(.system(size:" '\.font\(\s*\.system\(\s*size\s*:'
    scan "Text(\"No ...\")" 'Text\(\s*"No\s'
  } | sort -u
)"

if [[ $WRITE_BASELINE -eq 1 ]]; then
  printf '%s\n' "$CURRENT_VIOLATIONS" > "$BASELINE_FILE"
  echo "lint-no-raw-tokens: wrote baseline with $(printf '%s\n' "$CURRENT_VIOLATIONS" | wc -l | tr -d ' ') entries"
  exit 0
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "lint-no-raw-tokens: no baseline found at $BASELINE_FILE; run with --write-baseline to create one"
  exit 1
fi

NEW_VIOLATIONS=$(comm -23 <(printf '%s\n' "$CURRENT_VIOLATIONS") <(sort -u "$BASELINE_FILE"))

if [[ -n "$NEW_VIOLATIONS" ]]; then
  echo "::error::New design-system violations (not in baseline):"
  echo "$NEW_VIOLATIONS"
  echo
  echo "Move the offending code into ColimaStack/DesignSystem/ or rewrite"
  echo "to consume the design tokens. If this is intentional and the"
  echo "baseline should grow, run:"
  echo "  scripts/lint-no-raw-tokens.sh --write-baseline"
  exit 1
fi

echo "lint-no-raw-tokens: clean (no new violations)"
