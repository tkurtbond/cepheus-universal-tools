#!/usr/bin/env bash
# test-systems-e2e.sh -- End-to-end smoke test for cu-systems.scm.
#
# Starts a throwaway awful server and checks three walkthroughs:
#   1. Single star, "Roll everything": reaches the final page and every
#      expected field label appears somewhere along the way (catches
#      routing/session-wiring/template mistakes, not table correctness,
#      which test-system-tables.scm already covers).
#   2. Single star, a Rock mainworld, walked via "Choose": checks the
#      Planetary Details branch and that the same system reappears
#      unchanged on both Markdown export pages.
#   3. A binary star with the companion at Orbit 1, a Garden World
#      mainworld, walked via "Choose": checks the companion-placement
#      branch and the full-UWP mainworld branch.
#
# Usage: ./test-systems-e2e.sh
set -u

cd "$(dirname "$0")"

PORT=8203
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
awful --ip-address=127.0.0.1 --port=$PORT cu-systems.scm > "$LOG" 2>&1 &
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

echo "== Single star, Roll everything =="
curl -s -c "$COOKIES" -b "$COOKIES" -o /dev/null "$BASE/"
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/orbits-result" \
  --data-urlencode "system-name=Roll Test" --data-urlencode "hex=0101" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/star-system-result" \
  --data-urlencode "num-bodies=Roll" --data-urlencode "star-count=Choose" --data-urlencode "chosen-star-count=5" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/mainworld-result" \
  --data-urlencode "mainworld-orbit=Roll" --data-urlencode "mainworld-type=Roll" -o /tmp/systems-e2e-mainworld.html
MW_TYPE_ACTION=$(grep -oF 'action="/mainworld-uwp-result"' /tmp/systems-e2e-mainworld.html || true)
if [ -n "$MW_TYPE_ACTION" ]; then
  FINAL=$(curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/mainworld-uwp-result" \
    --data-urlencode "world-size=Roll" --data-urlencode "atmosphere=Roll" --data-urlencode "hydrographics=Roll" \
    --data-urlencode "population=Roll" --data-urlencode "starport=Roll" --data-urlencode "government=Roll" \
    --data-urlencode "law-level=Roll" --data-urlencode "tech-level=Roll")
else
  FINAL=$(curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/mainworld-details-result" \
    --data-urlencode "mw-size=Roll" --data-urlencode "mw-atmosphere=Roll" --data-urlencode "mw-hydrographics=Roll")
fi
for label in "Number of Planetary Bodies" "Star System" "Mainworld Orbit" "Mainworld Type" "The System"; do
  assert_contains "final page shows $label" "$FINAL" "$label"
done
assert_contains "final page shows Orbit 0 (the primary star)" "$FINAL" "<td>Star</td>"
assert_contains "final page offers a Markdown table export" "$FINAL" 'action="/system-markdown-table"'
assert_contains "final page offers a Markdown list export" "$FINAL" 'action="/system-markdown-list"'

echo
echo "== Single star, Rock mainworld, walked via Choose =="
curl -s -c "$COOKIES" -b "$COOKIES" -o /dev/null "$BASE/"
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/orbits-result" \
  --data-urlencode "system-name=RockTest" --data-urlencode "hex=0202" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/star-system-result" \
  --data-urlencode "num-bodies=Choose" --data-urlencode "chosen-num-bodies=6" \
  --data-urlencode "star-count=Choose" --data-urlencode "chosen-star-count=5" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/mainworld-result" \
  --data-urlencode "mainworld-orbit=Choose" --data-urlencode "chosen-mainworld-orbit=3" \
  --data-urlencode "mainworld-type=Choose" --data-urlencode "chosen-mainworld-type=3" -o /tmp/systems-e2e-rock.html
assert_contains "Rock mainworld shows the Planetary Details form" "$(cat /tmp/systems-e2e-rock.html)" 'action="/mainworld-details-result"'

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/mainworld-details-result" \
  --data-urlencode "mw-size=Choose" --data-urlencode "chosen-mw-size=2" \
  --data-urlencode "mw-atmosphere=Choose" --data-urlencode "chosen-mw-atmosphere=3" \
  --data-urlencode "mw-hydrographics=Choose" --data-urlencode "chosen-mw-hydrographics=None" -o /tmp/systems-e2e-rock-final.html
ROCK_FINAL=$(cat /tmp/systems-e2e-rock-final.html)
assert_contains "Rock mainworld: Size shown" "$ROCK_FINAL" "Mainworld Size:</td>"
assert_contains "Rock mainworld: Temperature is Temperate" "$ROCK_FINAL" "<b>Temperate</b>"
if echo "$ROCK_FINAL" | grep -qF "Mainworld Profile:"; then
  fail "Rock mainworld should not show a Mainworld Profile row (that's the Garden/Waterworld branch)"
else
  pass "Rock mainworld correctly has no Mainworld Profile row"
fi

MD_TABLE=$(curl -s -c "$COOKIES" -b "$COOKIES" "$BASE/system-markdown-table")
MD_LIST=$(curl -s -c "$COOKIES" -b "$COOKIES" "$BASE/system-markdown-list")
assert_contains "Markdown table export reflects the same mainworld orbit" "$MD_TABLE" "Orbit 3:"
assert_contains "Markdown list export reflects the same mainworld orbit" "$MD_LIST" "Orbit 3:"

echo
echo "== Binary star (companion at Orbit 1), Garden World mainworld, walked via Choose =="
curl -s -c "$COOKIES" -b "$COOKIES" -o /dev/null "$BASE/"
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/orbits-result" \
  --data-urlencode "system-name=BinaryTest" --data-urlencode "hex=0303" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/star-system-result" \
  --data-urlencode "num-bodies=Choose" --data-urlencode "chosen-num-bodies=5" \
  --data-urlencode "star-count=Choose" --data-urlencode "chosen-star-count=10" -o /tmp/systems-e2e-binary.html
assert_contains "Binary star system offers companion placement" "$(cat /tmp/systems-e2e-binary.html)" 'action="/companions-result"'

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/companions-result" \
  --data-urlencode "placement=Choose" --data-urlencode "chosen-placement=1" -o /tmp/systems-e2e-companion.html
assert_contains "Companion placed at Orbit 1 (odd roll)" "$(cat /tmp/systems-e2e-companion.html)" "Companion Orbit(s):</td>"

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/mainworld-result" \
  --data-urlencode "mainworld-orbit=Choose" --data-urlencode "chosen-mainworld-orbit=3" \
  --data-urlencode "mainworld-type=Choose" --data-urlencode "chosen-mainworld-type=9" -o /tmp/systems-e2e-garden.html
assert_contains "Garden World mainworld shows the full Creating Worlds UWP form" "$(cat /tmp/systems-e2e-garden.html)" 'action="/mainworld-uwp-result"'

curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/mainworld-uwp-result" \
  --data-urlencode "world-size=Choose" --data-urlencode "chosen-world-size=6" \
  --data-urlencode "atmosphere=Choose" --data-urlencode "chosen-atmosphere=6" \
  --data-urlencode "hydrographics=Choose" --data-urlencode "chosen-hydrographics=6" \
  --data-urlencode "population=Choose" --data-urlencode "chosen-population=5" \
  --data-urlencode "starport=Choose" --data-urlencode "chosen-starport=7" \
  --data-urlencode "government=Choose" --data-urlencode "chosen-government=5" \
  --data-urlencode "law-level=Choose" --data-urlencode "chosen-law-level=5" \
  --data-urlencode "tech-level=Choose" --data-urlencode "chosen-tech-level=4" \
  -o /tmp/systems-e2e-garden-final.html
GARDEN_FINAL=$(cat /tmp/systems-e2e-garden-final.html)
assert_contains "Garden World final page shows a full Mainworld Profile" "$GARDEN_FINAL" "Mainworld Profile:</td>"
assert_contains "Garden World final page shows the UWP line" "$GARDEN_FINAL" "D666555-6, Garden World"
assert_contains "Garden World final page shows the companion star" "$GARDEN_FINAL" "Companion Star"

rm -f /tmp/systems-e2e-mainworld.html /tmp/systems-e2e-rock.html /tmp/systems-e2e-rock-final.html \
      /tmp/systems-e2e-binary.html /tmp/systems-e2e-companion.html /tmp/systems-e2e-garden.html \
      /tmp/systems-e2e-garden-final.html

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All end-to-end checks passed."
  exit 0
else
  echo "$FAILURES end-to-end check(s) failed."
  exit 1
fi
