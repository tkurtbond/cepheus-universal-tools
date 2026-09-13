#!/usr/bin/env bash
# test-worlds-e2e.sh -- End-to-end smoke test for cu-worlds.scm.
#
# Starts a throwaway awful server, walks the full 9-page Creating Worlds
# wizard via curl, and checks:
#   1. The "Roll everything" path reaches the final page and every
#      expected field label appears somewhere along the way (catches
#      routing, session-wiring, and template mistakes -- not table
#      correctness, which test-worlds-tables.scm already covers).
#   2. The rulebook's own worked example, Lorcan (pp. 301-302), replayed
#      through the "Choose" path using its own stated intermediate
#      rolls, reproduces the exact UWP line given in the text.
#
# Usage: ./test-worlds-e2e.sh
set -u

cd "$(dirname "$0")"

PORT=18082
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

# --- start the server ---
awful --ip-address=127.0.0.1 --port=$PORT cu-worlds.scm > "$LOG" 2>&1 &
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

roll_all() {
  # Walk all 9 pages, choosing "Roll" for every field, ending on the
  # final page's HTML.
  curl -s -c "$COOKIES" -b "$COOKIES" -G "$BASE/world-size-result" \
    --data-urlencode "world-name=Roll Test" --data-urlencode "hex=0101" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/atmosphere-result" \
    --data-urlencode "world-size=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/hydrographics-result" \
    --data-urlencode "atmosphere=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/population-result" \
    --data-urlencode "hydrographics=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/starport-result" \
    --data-urlencode "population=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/government-result" \
    --data-urlencode "starport=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/law-level-result" \
    --data-urlencode "government=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/tech-level-result" \
    --data-urlencode "law-level=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/bases-result" \
    --data-urlencode "tech-level=Roll" -o /dev/null
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/world-result" \
    --data-urlencode "naval-base=Roll" --data-urlencode "scout-base=Roll" --data-urlencode "gas-giant=Roll"
}

echo "== Full walkthrough, all Roll =="
FINAL=$(roll_all)
for label in "World Size" "Atmosphere" "Hydrographics" "Population" "Starport" \
             "Government" "Law Level" "Tech Level" "Trade Codes" "Naval Base" \
             "Scout Base" "Gas Giant Present" "Universal World Profile" "Interpretation"; do
  assert_contains "final page shows $label" "$FINAL" "$label"
done

echo
echo "== Lorcan worked example (pp. 301-302), replayed via Choose =="

curl -s -c "$COOKIES" -b "$COOKIES" -G "$BASE/world-size-result" \
  --data-urlencode "world-name=Lorcan" --data-urlencode "hex=" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/atmosphere-result" \
  --data-urlencode "world-size=Choose" --data-urlencode "chosen-world-size=5" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/hydrographics-result" \
  --data-urlencode "atmosphere=Choose" --data-urlencode "chosen-atmosphere=10" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/population-result" \
  --data-urlencode "hydrographics=Choose" --data-urlencode "chosen-hydrographics=6" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/starport-result" \
  --data-urlencode "population=Choose" --data-urlencode "chosen-population=5" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/government-result" \
  --data-urlencode "starport=Choose" --data-urlencode "chosen-starport=5" -o /tmp/worlds-e2e-starport.html
assert_contains "Lorcan Starport is E" "$(cat /tmp/worlds-e2e-starport.html)" "Starport: <b>E</b>"

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/law-level-result" \
  --data-urlencode "government=Choose" --data-urlencode "chosen-government=11" -o /tmp/worlds-e2e-government.html
assert_contains "Lorcan Government is 9 (Impersonal Bureaucracy)" "$(cat /tmp/worlds-e2e-government.html)" "Government: <b>9</b> (9): Impersonal Bureaucracy"

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/tech-level-result" \
  --data-urlencode "law-level=Choose" --data-urlencode "chosen-law-level=3" -o /tmp/worlds-e2e-lawlevel.html
assert_contains "Lorcan Law Level is 5 (Medium Law)" "$(cat /tmp/worlds-e2e-lawlevel.html)" "Law Level: <b>5</b>"

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/bases-result" \
  --data-urlencode "tech-level=Choose" --data-urlencode "chosen-tech-level=6" -o /tmp/worlds-e2e-techlevel.html
assert_contains "Lorcan Tech Level is 8" "$(cat /tmp/worlds-e2e-techlevel.html)" "Tech Level: <b>8</b>"
assert_contains "Lorcan Trade Codes are Fluid Oceans, Non-Industrial" "$(cat /tmp/worlds-e2e-techlevel.html)" "Fluid Oceans, Non-Industrial"

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/world-result" \
  --data-urlencode "naval-base=Roll" --data-urlencode "scout-base=Roll" \
  --data-urlencode "gas-giant=Choose" --data-urlencode "chosen-gas-giant=6" -o /tmp/worlds-e2e-final.html
assert_contains "Lorcan final UWP line" "$(cat /tmp/worlds-e2e-final.html)" "Lorcan E5A6595-8 Fluid Oceans, Non-Industrial G"

rm -f /tmp/worlds-e2e-starport.html /tmp/worlds-e2e-government.html /tmp/worlds-e2e-lawlevel.html \
      /tmp/worlds-e2e-techlevel.html /tmp/worlds-e2e-final.html

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All end-to-end checks passed."
  exit 0
else
  echo "$FAILURES end-to-end check(s) failed."
  exit 1
fi
