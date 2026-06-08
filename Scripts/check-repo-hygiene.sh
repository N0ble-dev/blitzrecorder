#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

failures=0

pass() {
  printf 'ok: %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  failures=$((failures + 1))
}

tracked_files() {
  git ls-files
}

reject_tracked_path() {
  local path="$1"
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    fail "tracked local-only path: $path"
  else
    pass "not tracked: $path"
  fi
}

reject_tracked_glob() {
  local glob="$1"
  local matches
  matches="$(git ls-files "$glob")"
  if [[ -n "$matches" ]]; then
    fail "tracked local-only paths matching $glob"
    printf '%s\n' "$matches" >&2
  else
    pass "not tracked: $glob"
  fi
}

reject_literal() {
  local needle="$1"
  local label="$2"
  local matches
  matches="$(git grep -n -I -F -- "$needle" -- . ':!Scripts/check-repo-hygiene.sh' || true)"
  if [[ -n "$matches" ]]; then
    fail "$label"
    printf '%s\n' "$matches" >&2
  else
    pass "$label"
  fi
}

reject_regex() {
  local pattern="$1"
  local label="$2"
  local matches
  matches="$(git grep -n -I -E -- "$pattern" -- . ':!Scripts/check-repo-hygiene.sh' || true)"
  if [[ -n "$matches" ]]; then
    fail "$label"
    printf '%s\n' "$matches" >&2
  else
    pass "$label"
  fi
}

require_literal_in_file() {
  local file="$1"
  local needle="$2"
  if [[ ! -f "$file" ]]; then
    fail "missing file: $file"
  elif grep -Fq -- "$needle" "$file"; then
    pass "$file contains $needle"
  else
    fail "$file missing $needle"
  fi
}

reject_tracked_glob "docs/*"
reject_tracked_glob "Web/blitzrecorder/docs/*"
reject_tracked_path "CONTEXT.md"
reject_tracked_path "AppStore/CI.md"
reject_tracked_path "Scripts/check-open-source-readiness.sh"
reject_tracked_path "AG""ENTS.md"
reject_tracked_path "CLA""UDE.md"
reject_tracked_path "PRODUCT.md"
reject_tracked_glob "features/*"

reject_literal "blitzrecorder-public" "no stale public-repo URL"
reject_literal "not for the public repo" "no public-tree contradiction text"
reject_literal "private release handoff" "no private handoff language"
reject_literal "public snapshot" "no snapshot-publication language"
reject_literal "fresh-history" "no private-history publication language"
reject_literal "private history" "no private-history wording"
reject_literal "private repo" "no private-repo wording"
reject_literal "repo is private" "no private-repo status wording"
reject_literal "still private" "no stale private-status wording"
reject_literal "once public" "no stale publication-timing wording"
reject_literal "NEXT_PUBLIC_OPEN_SOURCE" "no open-source feature flag"

reject_regex 'price_1[[:alnum:]]{8,}' "no live Stripe price IDs"
reject_regex 'prod_[[:alnum:]]{8,}' "no live Stripe product IDs"

require_literal_in_file ".github/release.yml" "categories:"
require_literal_in_file ".github/workflows/macos-dmg.yml" "tags:"
require_literal_in_file ".github/workflows/macos-dmg.yml" "\"v*\""
require_literal_in_file ".github/workflows/macos-dmg.yml" "gh release create"
require_literal_in_file ".github/workflows/macos-dmg.yml" "--generate-notes"
require_literal_in_file ".github/workflows/macos-dmg.yml" "appcast.xml"
require_literal_in_file "Web/blitzrecorder/.env.example" "BLITZRECORDER_STRIPE_PRODUCT_ID="
require_literal_in_file "Web/blitzrecorder/.env.example" "BLITZRECORDER_STRIPE_PRICE_ID="

if (( failures > 0 )); then
  echo "Repository hygiene checks failed with $failures issue(s)." >&2
  exit 1
fi

echo "Repository hygiene checks passed."
