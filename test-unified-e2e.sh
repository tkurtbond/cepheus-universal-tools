#!/usr/bin/env bash
# test-unified-e2e.sh -- End-to-end smoke test for cu-unified.scm.
#
# Starts a throwaway awful server for the unified app and checks:
#   1. The hub page at "/" offers all three sub-apps.
#   2. Each sub-app's own entry page is reachable at its mounted path
#      ("/arcs", "/worlds", "/systems") rather than "/" (table/wizard
#      correctness for each app is already covered by test-e2e.sh,
#      test-worlds-e2e.sh and test-systems-e2e.sh -- this only checks
#      the unification wiring itself).
#   3. A quick walk of the Alien Race Creation wizard through the
#      unified server reaches its final page, which offers "Return to
#      ARCS" (back to "/arcs") and "Return to Start" (back to "/"),
#      not the old single-app "Start Over" button.
#
# Usage: ./test-unified-e2e.sh
set -u

cd "$(dirname "$0")"

PORT=8200
BASE="http://127.0.0.1:$PORT"
COOKIES=$(mktemp)
LOG=$(mktemp)
FAILURES=0

cleanup() {
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null
  rm -f "$COOKIES" "$LOG"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$desc"
  else
    fail "$desc (expected to find: $needle)"
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    fail "$desc (did not expect to find: $needle)"
  else
    pass "$desc"
  fi
}

# --- start the server ---
awful --ip-address=127.0.0.1 --port=$PORT cu-unified.scm > "$LOG" 2>&1 &
SERVER_PID=$!

for i in $(seq 1 20); do
  if curl -s -o /dev/null "$BASE/"; then
    break
  fi
  sleep 0.5
done
if ! curl -s -o /dev/null "$BASE/"; then
  echo "Server never came up; log:"
  cat "$LOG"
  exit 1
fi

echo "== Hub page =="
HUB=$(curl -s "$BASE/")
assert_contains "hub page links to /arcs" "$HUB" 'action="/arcs"'
assert_contains "hub page links to /worlds" "$HUB" 'action="/worlds"'
assert_contains "hub page links to /systems" "$HUB" 'action="/systems"'

echo
echo "== Each sub-app is mounted at its own path =="
ARCS=$(curl -s "$BASE/arcs")
assert_contains "cu-arcs entry page reachable at /arcs" "$ARCS" "Alien Race Creation - Major or Minor Race"

WORLDS=$(curl -s "$BASE/worlds")
assert_contains "cu-worlds entry page reachable at /worlds" "$WORLDS" "Creating Worlds"

SYSTEMS=$(curl -s "$BASE/systems")
assert_contains "cu-systems entry page reachable at /systems" "$SYSTEMS" "System Generation"

echo
echo "== Alien Race Creation wizard walked through the unified server =="
curl -s -c "$COOKIES" -b "$COOKIES" "$BASE/major-minor-result?major-or-minor=Major" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result" \
  --data-urlencode "world-size=Roll" --data-urlencode "atmosphere=Roll" \
  --data-urlencode "hydrographics=Roll" --data-urlencode "population=Roll" \
  --data-urlencode "government=Roll" --data-urlencode "law-level=Roll" \
  --data-urlencode "tech-level=Roll" --data-urlencode "starport=Roll" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-2" \
  --data-urlencode "biotype=Roll" --data-urlencode "subtype=Roll" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-3" \
  --data-urlencode "sex=Roll" --data-urlencode "reproduction=Roll" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-4" \
  --data-urlencode "amphibious=Roll" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-5" \
  --data-urlencode "locomotion=Roll" --data-urlencode "symmetry=Roll" --data-urlencode "legs=Roll" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-6" \
  --data-urlencode "size=Roll" --data-urlencode "str-modifier=Roll" --data-urlencode "dex-modifier=Roll" \
  --data-urlencode "end-modifier=Roll" --data-urlencode "int-modifier=Roll" --data-urlencode "edu-modifier=Roll" \
  --data-urlencode "soc-modifier=Roll" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-7" \
  --data-urlencode "armour=Roll" --data-urlencode "natural-weapon=Roll" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-8" \
  --data-urlencode "vision=Roll" --data-urlencode "audio=Roll" --data-urlencode "olfactory=Roll" \
  --data-urlencode "special-sense=Roll" -o /dev/null
FINAL=$(curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-9" \
  --data-urlencode "lifespan=Roll" --data-urlencode "physiological-advantage=Roll")

assert_contains "final page offers Return to ARCS" "$FINAL" '<form action="/arcs">'
assert_contains "Return to ARCS is labelled correctly" "$FINAL" 'value="Return to ARCS"'
assert_contains "final page offers Return to Start" "$FINAL" '<form action="/">'
assert_contains "Return to Start is labelled correctly" "$FINAL" 'value="Return to Start"'
assert_not_contains "final page no longer offers the old Start Over button" "$FINAL" 'value="Start Over"'

MD_TABLE=$(curl -s -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-markdown-table")
assert_contains "Markdown table export also offers Return to ARCS" "$MD_TABLE" 'value="Return to ARCS"'
assert_contains "Markdown table export also offers Return to Start" "$MD_TABLE" 'value="Return to Start"'

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All end-to-end checks passed."
  exit 0
else
  echo "$FAILURES end-to-end check(s) failed."
  exit 1
fi
