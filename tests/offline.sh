#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cd "$tmp"
source "$repo/google-timeline-download.sh"

# Intercept every HTTP call; these tests never contact Google or load real cookies.
fixture=valid
curl() {
  local headers='' body=''
  while (($#)); do
    case "$1" in
      -D) headers=$2; shift 2 ;;
      -o) body=$2; shift 2 ;;
      *) shift ;;
    esac
  done
  printf 'HTTP/1.1 200 OK\n' > "$headers"
  case "$fixture" in
    valid)
      printf '<?xml version="1.0"?><kml><Document><name>Offline fixture article with enough padding to exceed the minimum accepted file size.</name></Document></kml>' > "$body"
      printf '200|https://timeline.google.com/fixture' ;;
    html) printf '<!doctype html><html>Sign in</html>' > "$body"; printf '200|https://timeline.google.com/fixture' ;;
    empty) : > "$body"; printf '200|https://timeline.google.com/fixture' ;;
    small) printf '<?xml?><kml/>' > "$body"; printf '200|https://timeline.google.com/fixture' ;;
    invalid) printf 'Not KML' > "$body"; printf '200|https://timeline.google.com/fixture' ;;
    limited) : > "$body"; printf '429|https://timeline.google.com/fixture' ;;
    forbidden) : > "$body"; printf '403|https://timeline.google.com/fixture' ;;
    login) : > "$body"; printf '200|https://accounts.google.com/ServiceLogin' ;;
    *) return 99 ;;
  esac
}
sleep() { :; }

expect_failure() {
  if (download_kml fixture-cookies.txt https://example.invalid/fixture) > result.kml 2> errors.log; then
    printf 'Expected rejection for %s\n' "$fixture" >&2
    exit 1
  fi
}

download_kml fixture-cookies.txt https://example.invalid/fixture > result.kml 2> errors.log
test -s result.kml
grep -q '<kml>' result.kml
for fixture in html empty small invalid limited forbidden login; do expect_failure; done

test "$(date_range 2024-02-28 2024-03-01)" = $'2024-02-28\n2024-02-29\n2024-03-01'
test "$(date_range 2024-12-31 2025-01-01)" = $'2024-12-31\n2025-01-01'
rc=0
bash "$repo/google-timeline-download.sh" > usage.log 2>&1 || rc=$?
test "$rc" -eq 2
grep -q 'Usage:' usage.log
printf 'PASS: 11 offline download/date/usage checks (no network or real credentials)\n'
