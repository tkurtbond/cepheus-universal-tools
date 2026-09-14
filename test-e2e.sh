#!/usr/bin/env bash
# test-e2e.sh -- End-to-end smoke test for cu-arcs.scm.
#
# Starts a throwaway awful server, walks the full 10-page Alien Race
# Creation wizard via curl, and checks:
#   1. The "Roll everything" path reaches the final page and every
#      expected field label appears somewhere along the way (catches
#      routing, session-wiring, and template mistakes -- not table
#      correctness, which test-alien-tables.scm already covers).
#   2. A handful of "Choose" boundary cases resolve to the exact
#      values the rulebook specifies, exercising the same tables end
#      to end through the actual HTTP/session path rather than by
#      calling Scheme procedures directly.
#
# Usage: ./test-e2e.sh
set -u

cd "$(dirname "$0")"

PORT=8201
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
awful --ip-address=127.0.0.1 --port=$PORT cu-arcs.scm > "$LOG" 2>&1 &
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
  # Walk all 10 pages, choosing "Roll" for every field, ending on the
  # final page's HTML.
  curl -s -c "$COOKIES" -b "$COOKIES" "$BASE/major-minor-result?major-or-minor=$1" -o /dev/null
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
  curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-9" \
    --data-urlencode "lifespan=Roll" --data-urlencode "physiological-advantage=Roll"
}

echo "== Full walkthrough, Major race, all Roll =="
FINAL=$(roll_all Major)
for label in "Major or Minor Race" "World Size" "Atmosphere" "Hydrographics" "Population" \
             "Government" "Law Level" "Tech Level" "Star Port" "Biotype" "Subtype" "Sex" \
             "Reproduction" "Amphibious" "Locomotion" "Symmetry" "Number of Legs" "Size" \
             "Strength" "Dexterity" "Endurance" "Intelligence" "Education" "Social" \
             "Armour" "Natural Weapon" "Vision" "Audio" "Olfactory" "Special Sense" \
             "Lifespan" "Physiological Advantage" "Interpretation"; do
  assert_contains "final page shows $label" "$FINAL" "$label"
done

echo
echo "== Full walkthrough, Minor race, all Roll =="
FINAL_MINOR=$(roll_all Minor)
assert_contains "Minor race recorded" "$FINAL_MINOR" "<b>Minor</b>"

echo
echo "== Deterministic boundary checks via Choose =="

# Major race always gets Starport A and Tech Level 10-15, regardless of roll.
curl -s -c "$COOKIES" -b "$COOKIES" "$BASE/major-minor-result?major-or-minor=Major" -o /dev/null
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result" \
  --data-urlencode "world-size=Roll" --data-urlencode "atmosphere=Roll" \
  --data-urlencode "hydrographics=Roll" --data-urlencode "population=Roll" \
  --data-urlencode "government=Roll" --data-urlencode "law-level=Roll" \
  --data-urlencode "tech-level=Choose" --data-urlencode "chosen-tech-level=1" \
  --data-urlencode "starport=Choose" --data-urlencode "chosen-starport=6" -o /tmp/e2e-major.html
assert_contains "Major race: starport roll 6 still gives A" "$(cat /tmp/e2e-major.html)" '<b>A</b>'

# Biotype/Subtype boundary: roll 2/2 -> Scavenger/Reducer.
curl -s -G -c "$COOKIES" -b "$COOKIES" "$BASE/alien-creation-result-2" \
  --data-urlencode "biotype=Choose" --data-urlencode "chosen-biotype=2" \
  --data-urlencode "subtype=Choose" --data-urlencode "chosen-subtype=2" -o /tmp/e2e-biotype.html
assert_contains "biotype 2 -> Scavenger" "$(cat /tmp/e2e-biotype.html)" '<b>Scavenger</b>'
assert_contains "subtype 2 (Scavenger) -> Reducer" "$(cat /tmp/e2e-biotype.html)" '<b>Reducer</b>'

rm -f /tmp/e2e-major.html /tmp/e2e-biotype.html

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All end-to-end checks passed."
  exit 0
else
  echo "$FAILURES end-to-end check(s) failed."
  exit 1
fi
