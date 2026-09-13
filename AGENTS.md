# Cepheus Universal Tools

A small, work-in-progress collection of Chicken Scheme scripts for
generating RPG content, built on the `awful` web framework. Primarily
targets the *Cepheus Universal* / *Cepheus Engine* ruleset (a
Traveller-based sci-fi system). This is personal GM-prep tooling, not a
finished product — several files are stubs or mid-rewrite.

## Files

- `cu-arcs.scm` — "Cepheus Universal Alien Race Creation System," v1.
  Single-page `awful` web app: one HTML form collects choices (Major/Minor
  race, world size, atmosphere, hydrographics, population, government, law
  level, tech level, starport — each either "roll" or manually chosen).
  `/alien-creation-result` computes the rolls (2D6, 1D6, etc. via `D`/`nD`
  helpers) following classic Traveller/Cepheus world-generation tables and
  prints the results. Superseded by `cu-arcs-v2.scm`; kept as-is.

- `cu-arcs-v2.scm` — The active app. A full implementation of the
  rulebook's "Alien Race Creation" section (Cepheus Universal pp. 326-329),
  as a 9-page `awful` wizard chained via `define-session-page` /
  `$session-set!` / `$session`: Major or Minor Race → Homeworld (World
  Size, Atmosphere, Hydrographics, Population, Government, Law Level, Tech
  Level, Starport) → Biotype/Subtype → Reproduction (Sex, Reproduction
  method) → Amphibious? → Body Form (Locomotion, Symmetry, Number of Legs)
  → Size & Characteristics (Str/Dex/End/Int/Edu/Soc as dice formulas, e.g.
  "2D6-1") → Armour & Natural Weapons → Senses (Vision, Audio, Olfactory,
  Special Sense) → Life Cycle (Lifespan, Physiological Advantage), ending
  on the book's Interpretation prompt. Breathing and Interpretation have
  no rollable table in the book and are narrative-only, with no form step.
  Run with `./cu-arcs-local.sh` (below), or directly via
  `awful --port=2020 cu-arcs-v2.scm` (per the file's header comment).

- `alien-tables.scm` — All the rules tables and resolvers behind the
  wizard, factored out into their own Chicken module (`alien-tables`) so
  they can be unit-tested independently of the web front-end. `D`/`nD`
  (dice primitives) live here too. `cu-arcs-v2.scm` pulls this in via
  `(include "alien-tables.scm")` + `(import alien-tables)` — see "Local
  modules" below for why the `include` is necessary.

- `roll-tables.scm` — A small DSL, built on `define-syntax`, for defining
  the rulebook's roll-range lookup tables succinctly instead of
  hand-writing a `cond` (and separately hand-writing the matching HTML
  form and prose) for each one:
  - `define-roll-table` / `define-keyed-roll-table` — a roll (or a
    roll plus a prior result as a key, e.g. Subtype keyed on Biotype)
    looked up against literal ranges to a fixed result.
  - `define-formula-table` / `define-keyed-formula-table` — as above,
    but a range selects a further dice formula (e.g. "1D3+3") rather
    than a fixed value.
  - `roll-field-li` / `keyed-roll-field-li` / `formula-field-li` /
    `keyed-formula-field-li` — generate the Roll/Choose `<li>` HTML
    fragment for a table-backed field, with min/max and descriptive
    text derived from the table itself.
  - `resolve-field` / `resolve-keyed-field` / `resolve-value` /
    `resolve-formula-field` / `resolve-keyed-formula-field` plus
    `resolved-field!` — collapse a page's "read Roll-vs-Choose, roll or
    parse, look up, `$session-set!`" logic for one field down to a
    single line.
  Not a module itself (see "Local modules" below); `(include
  "roll-tables.scm")` it into whichever module needs it. A few tables in
  `alien-tables.scm` don't fit this DSL (Sex's "1D3+1 sexes", Armour,
  Natural Weapons, Special Sense, Lifespan, Physiological Advantage all
  need a modified-roll-vs-threshold check, or a roll embedded in a fixed
  result) and use small bespoke resolver functions instead, noted in
  comments there.

- `cu-arcs-consp.sh` — Launcher script for `cu-arcs.scm`
  (`awful --ip-address=71.19.158.45 --port=8080 cu-arcs.scm`). Has a
  broken shebang (`#1` instead of `#!`), so it likely doesn't run as-is —
  treat as an experimental/personal script.

- `cu-arcs-local.sh` — Launcher for `cu-arcs-v2.scm` bound to
  `127.0.0.1:8080`, for local interactive use.

- `sa-acs.scm` — "Stellar Adventures Alien Creation System." Explicitly
  marked "Just a reminder, for now." Stub module that only imports
  libraries (including `awful`) but defines nothing yet — a placeholder
  for an alien-creation generator (intelligent and unintelligent
  creatures) for a different game, "Stellar Adventures."

- `tables.scm` — Data tables for alien creation (chemical basis of life;
  land/water habitat and sub-habitats) using a `defstruct`-based
  `section`/`table` model, built on `d6`/`make-d` from `dice.scm`.
  Incomplete: unclosed parens and a typo (`talbes:` for `tables:`) partway
  through — cuts off mid-definition. Predates `alien-tables.scm`/
  `roll-tables.scm` and hasn't been ported to that DSL.

- `dice.scm` — General-purpose dice-rolling library: `make-d` (die
  constructor), `make-roll` (roll N dice), `highest`/`lowest`
  (keep-N-drop-rest with human-readable descriptions), and an "OVA"
  die-pool mechanic (`ova-roll`: sum matching dice for positive pool
  sizes, take the lowest of a negative pool). The OVA mechanic supports a
  different system (OVA, a diceless/dice-pool anime RPG) rather than
  Cepheus itself.

## Testing

- `test-alien-tables.scm` — Unit tests (Chicken's `test` egg;
  `chicken-install test` if not already installed) for every table/
  resolver in `alien-tables.scm`. Run with `csi -s test-alien-tables.scm`.
  Most tables take an explicit roll and are deterministic, so they're
  checked with exact expected values at every range boundary. The handful
  of resolvers that roll further dice internally (Sex, Armour, Natural
  Weapons, Special Sense, Lifespan, Physiological Advantage) are checked
  with repeated trials against the valid range/set instead.

- `test-e2e.sh` — End-to-end smoke test. Starts a throwaway `awful`
  instance on port 18080, walks the full 9-page wizard over HTTP with
  `curl`, and checks that every expected field label appears on the final
  page (catches routing/session/template mistakes, not table
  correctness), plus a few deterministic boundary cases via the "Choose"
  path (e.g. Major Race Starport is always "A" regardless of roll). Run
  with `./test-e2e.sh`; it starts and tears down its own server, so it
  won't collide with `cu-arcs-local.sh` on port 8080.

There is no test coverage for `cu-arcs.scm` (v1, superseded), `tables.scm`,
`sa-acs.scm`, or `dice.scm`.

## Local modules

This project has no build system or egg packaging — `awful` just loads a
single `.scm` file directly, so cross-file code reuse works via Chicken's
`include`, not by installing local eggs. The pattern used throughout:
define a `(module foo (...) ...)` in its own file, then `(include
"foo.scm")` it as a *sibling* top-level form (not nested inside another
module) before the form that does `(import foo)`. `roll-tables.scm`
deliberately isn't wrapped in a module — it's just `(include
"roll-tables.scm")`d directly into whichever module needs its macros.
