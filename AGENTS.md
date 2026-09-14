# Cepheus Universal Tools

A small, work-in-progress collection of Chicken Scheme scripts for
generating RPG content, built on the `awful` web framework. Primarily
targets the *Cepheus Universal* / *Cepheus Engine* ruleset (a
Traveller-based sci-fi system). This is personal GM-prep tooling, not a
finished product — several files are stubs or mid-rewrite.

## Files

- `cu-unified.scm` — Combines `cu-arcs.scm`, `cu-worlds.scm` and
  `cu-systems.scm` into a single running site. `(include ...)`s all
  three sibling `.scm` files (each producing its own top-level module,
  as usual -- see "Local modules" below), then imports each module's
  `run` with a distinct prefix (`(import (prefix cu-arcs arcs-))`, and
  likewise for worlds/systems) to avoid a name clash with its own
  `run`. Registers a hub page at "/" with a button to each sub-app's
  own entry page ("/arcs", "/worlds", "/systems" -- see the note atop
  each of those files), then calls each sub-app's `run` in turn.
  Because each sub-app's own final-page and Markdown-export buttons
  already point at both its own entry page (relabelled "Return to
  ARCS"/"Return to Worlds"/"Return to Systems") and the unified hub
  ("Return to Start", pointing at `(main-page-path)`, which this
  module -- not the sub-apps -- registers), no per-app changes are
  needed to run standalone vs. unified; only the target of "Return to
  Start" differs (a 404 if that sub-app is run standalone, since
  nothing registers "/" in that case). Run with `./cu-unified-local.sh`
  (below), or directly via `awful --port=8100 cu-unified.scm`.

- `cu-unified-local.sh` — Launcher for `cu-unified.scm` bound to
  `127.0.0.1:8100`, for local interactive use.

- `cu-unified-main.scm` — `awful-main` entry point for `cu-unified.scm`;
  see "Static executables (awful-main)" below.

- `cu-unified-server-local.sh` — Runs the compiled
  `build/cu-unified-server` on port 8100 by default, mirroring
  `cu-arcs-server-local.sh`.

- `cu-unified-consp.sh` — Launcher script for `cu-unified.scm`, bound to
  a specific external address (consp.org)
  (`awful --ip-address=71.19.158.45 --port=8100 cu-unified.scm`).

- `cu-unified-static-consp.sh` — Runs the compiled
  `build/cu-unified-server` bound to that same consp.org address on
  port 8100 by default, mirroring `cu-unified-server-local.sh` but for
  the consp.org deployment; see "Static executables (awful-main)"
  below for why the wrapper -- not the binary itself -- supplies that
  default.

- `cu-arcs.scm` — "Cepheus Universal Alien Race Creation System." The
  active app. A full implementation of the rulebook's "Alien Race
  Creation" section (Cepheus Universal pp. 326-329), as an 11-page `awful`
  wizard chained via `define-session-page` / `$session-set!` /
  `$session`: Major or Minor Race → Homeworld (World Size, Atmosphere,
  Hydrographics, Population, Government, Law Level, Tech Level, Starport)
  → Biotype/Subtype → Reproduction (Sex, Reproduction method) →
  Amphibious? → Body Form (Locomotion, Symmetry, Number of Legs) → Size &
  Characteristics (Str/Dex/End/Int/Edu/Soc as dice formulas, e.g. "2D6-1")
  → Armour & Natural Weapons → Senses (Vision, Audio, Olfactory, Special
  Sense) → Life Cycle (Lifespan, Physiological Advantage), ending on the
  book's Interpretation prompt. Breathing and Interpretation have no
  rollable table in the book and are narrative-only, with no form step.
  Its own entry page is at "/arcs" (not "/"), so it can be mounted
  under `cu-unified.scm` alongside the other two apps; the final page
  and both Markdown exports offer "Return to ARCS" (back to "/arcs")
  and "Return to Start" (back to `(main-page-path)`, i.e. "/" -- only
  meaningful when mounted under `cu-unified.scm`; standalone, nothing
  is registered at "/"). Run with `./cu-arcs-local.sh` (below), or
  directly via `awful --port=8101 cu-arcs.scm` (per the file's header
  comment). This supersedes an earlier single-page v1 prototype, whose contents have
  since been replaced in place by this wizard. Each "story so far"
  summary renders as a two-column SXML table (`story-row`/`story-table`,
  defined in this file, mirroring the identical helpers in
  `cu-worlds.scm`), labels right-aligned and results left-aligned; the
  Homeworld characteristics also show each digit/letter's name or
  description, reusing `worlds-tables.scm`'s lookup tables (imported
  with a `wt-` prefix to avoid clashing with `alien-tables`' own
  `D`/`nD`/`size-name`) since the Homeworld step and `cu-worlds.scm`'s
  full Creating Worlds system share the same underlying rulebook tables.

- `alien-tables.scm` — All the rules tables and resolvers behind the
  wizard, factored out into their own Chicken module (`alien-tables`) so
  they can be unit-tested independently of the web front-end. `D`/`nD`
  (dice primitives) live here too. `cu-arcs.scm` pulls this in via
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
  Also provides two small generic helpers used by both `alien-tables.scm`
  and `worlds-tables.scm`: `clamp` and `uwp-char` (the latter renders a
  Universal Profile digit as its usual single character — 0-9 as
  themselves, then letters for 10+).
  Not a module itself (see "Local modules" below); `(include
  "roll-tables.scm")` it into whichever module needs it. A few tables in
  `alien-tables.scm` and `worlds-tables.scm` don't fit this DSL (e.g.
  Sex's "1D3+1 sexes", Armour, Natural Weapons and other
  modified-roll-vs-threshold checks, or a roll embedded in a fixed
  result) and use small bespoke resolver functions instead, noted in
  comments there.

- `cu-arcs-consp.sh` — Launcher script for `cu-arcs.scm`, bound to a
  specific external address
  (`awful --ip-address=71.19.158.45 --port=8101 cu-arcs.scm`).

- `cu-arcs-local.sh` — Launcher for `cu-arcs.scm` bound to
  `127.0.0.1:8101`, for local interactive use.

- `cu-arcs-main.scm` — `awful-main` entry point for `cu-arcs.scm`; see
  "Static executables (awful-main)" below.

- `cu-arcs-server-local.sh` — Runs the compiled `build/cu-arcs-server`
  on port 8101 by default (an explicit `--port=...` passed to the
  script still overrides it); see "Static executables (awful-main)"
  below for why this wrapper -- not the binary itself -- is what
  supplies that default.

- `cu-arcs-static-consp.sh` — Runs the compiled `build/cu-arcs-server`
  bound to `cu-arcs-consp.sh`'s same consp.org address on port 8101 by
  default, mirroring `cu-arcs-server-local.sh` but for the consp.org
  deployment.

- `cu-worlds.scm` — "Cepheus Universal Creating Worlds" app. A full
  implementation of the rulebook's "Creating Worlds" section (Cepheus
  Universal pp. 281-302), as an 11-page `awful` wizard producing a single
  mainworld's Universal World Profile (UWP): World Size → Atmosphere →
  Hydrographics → Population → Starport → Government → Law Level → Tech
  Level (with Trade Codes derived and shown alongside it, since they
  have no roll of their own) → Bases (Naval/Scout) and Gas Giants,
  ending on the UWP line itself plus the book's Travel
  Zone/Climate/hook and Interpretation prompts (all GM judgment calls
  with no dice mechanic, so narrative-only, as with `cu-arcs.scm`'s
  Breathing/Interpretation). Each "story so far" summary renders as a
  two-column SXML table (`story-row`/`story-table`, defined in this
  file), labels right-aligned and results left-aligned; for every
  characteristic that maps a digit to a name or short description, the
  wizard shows both — e.g. "World Size: 5 (8,000 km, surface gravity
  0.45g)". Verified end to end
  against the rulebook's own worked example, Lorcan (pp. 301-302): see
  "Lorcan worked example" in `test-worlds-tables.scm` and the second
  half of `test-worlds-e2e.sh`. Its own entry page is at "/worlds" (not
  "/"), so it can be mounted under `cu-unified.scm` alongside the other
  two apps; the final page and both Markdown exports offer "Return to
  Worlds" (back to "/worlds") and "Return to Start" (back to
  `(main-page-path)`, meaningful only when mounted under
  `cu-unified.scm`). Run with `./cu-worlds-local.sh` (below), or
  directly via `awful --port=8102 cu-worlds.scm`.

- `worlds-tables.scm` — All the rules tables and resolvers behind
  `cu-worlds.scm`, factored out into their own Chicken module
  (`worlds-tables`), mirroring `alien-tables.scm`'s split from
  `cu-arcs.scm`. `D`/`nD` live here too. The rulebook's Population
  Condition/DM table (p. 293) is internally inconsistent, and the
  book's own worked example applies no DM to Population at all, so
  `roll-population` follows the example and applies none either — noted
  in a comment there. `tech-level-name` (a digit-to-era/description
  table for Tech Level, e.g. "Early Stellar -- ...") comes from the
  general Technological Levels glossary (pp. 18-19), not the Creating
  Worlds section itself, but is the obvious pairing for a Tech Level
  result; it's shared with `cu-arcs.scm` for the same reason as the
  other Homeworld lookups below.

- `cu-worlds-local.sh` — Launcher for `cu-worlds.scm` bound to
  `127.0.0.1:8102`, for local interactive use (a different port from
  `cu-arcs-local.sh`'s 8101, so both can run at once).

- `cu-worlds-main.scm` — `awful-main` entry point for `cu-worlds.scm`; see
  "Static executables (awful-main)" below.

- `cu-worlds-server-local.sh` — Runs the compiled `build/cu-worlds-server`
  on port 8102 by default, mirroring `cu-arcs-server-local.sh`.

- `cu-worlds-consp.sh` — Launcher script for `cu-worlds.scm`, bound to
  the same consp.org address as `cu-arcs-consp.sh`, on port 8102
  (`awful --ip-address=71.19.158.45 --port=8102 cu-worlds.scm`).

- `cu-worlds-static-consp.sh` — Runs the compiled `build/cu-worlds-server`
  bound to that same consp.org address on port 8102 by default,
  mirroring `cu-worlds-server-local.sh` but for the consp.org
  deployment.

- `cu-systems.scm` — "Cepheus Universal System Generation" app. Populates
  the rest of a star system around an already-known mainworld (Cepheus
  Universal pp. 303-307): Orbits & Other Stars (2D6+2 planetary bodies;
  2D6 for Single/Binary/Trinary, then 1D6 to place any companion(s) at
  Orbit 1 or beyond the furthest planetary body) → Mainworld Orbit
  (1D3+2) & Type (2D6: Rock/Hellhole/Desert World/Garden World/
  Waterworld) → either a full Creating Worlds UWP (Garden World/
  Waterworld, which have no Planetary Details row) or the coarser
  Planetary Details sub-rolls (Rock/Hellhole/Desert World: Size,
  Atmosphere, Hydrographics, with Temperature forced to Temperate for
  the mainworld's own orbit) → the rest of the system generated in one
  shot (gas giants, including the "reroll on 6 + hot Jupiter at Orbit 1"
  case; asteroid belts; minor planets typed and detailed per the Other
  Planetary Types/Planetary Details tables) and shown as an Orbit/Body/
  Notes table matching the book's own worked-example layout, with
  bodies named "<hex> <Greek letter>" per p. 305 (`greek-letter-name`).
  Two rulebook ambiguities get a documented house-ruled resolution
  rather than being left to crash or silently misbehave: mainworld-orbit
  (3-5) can exceed a minimum num-bodies (4) roll, so num-bodies widens
  to fit it; and a companion star's "beyond the furthest body" orbit is
  fixed before the mainworld orbit is even rolled, so a collision
  between the two shifts the mainworld outward one orbit at a time
  (`resolve-mainworld-orbit`) — see the comments at both call sites and
  in `system-tables.scm`. Deliberately text-only, no rendered subsector
  map (p. 307's "SOL SUBSECTOR" is a map image with no extractable rules
  content, unlike the rest of the section). `bodies`/`moon-of` are
  generated once (`finish-system!`) and `$session-set!`, not
  re-rolled — every render after that (the result page, both Markdown
  exports) reads them back via `system-data`. Its own entry page is at
  "/systems" (not "/"), so it can be mounted under `cu-unified.scm`
  alongside the other two apps; the final page and both Markdown
  exports offer "Return to Systems" (back to "/systems") and "Return to
  Start" (back to `(main-page-path)`, meaningful only when mounted
  under `cu-unified.scm`). Run with `./cu-systems-local.sh` (below), or
  directly via `awful --port=8103 cu-systems.scm`.

- `system-tables.scm` — All the rules tables and resolvers behind
  `cu-systems.scm`, factored out into their own Chicken module
  (`system-tables`), mirroring `alien-tables.scm`'s split from
  `cu-arcs.scm`. `D`/`nD` live here too; Rock/Hellhole/Desert World
  Planetary Details cells marked "*" in the book defer to
  `worlds-tables.scm`'s own tables (imported with a `wt-` prefix), same
  as `cu-arcs.scm`'s Homeworld step.

- `cu-systems-local.sh` — Launcher for `cu-systems.scm` bound to
  `127.0.0.1:8103`, for local interactive use (a different port from
  `cu-arcs-local.sh`'s 8101 and `cu-worlds-local.sh`'s 8102, so all
  three can run at once).

- `cu-systems-main.scm` — `awful-main` entry point for `cu-systems.scm`;
  see "Static executables (awful-main)" below.

- `cu-systems-server-local.sh` — Runs the compiled `build/cu-systems-server`
  on port 8103 by default, mirroring `cu-arcs-server-local.sh`.

- `cu-systems-consp.sh` — Launcher script for `cu-systems.scm`, bound to
  the same consp.org address as `cu-arcs-consp.sh`, on port 8103
  (`awful --ip-address=71.19.158.45 --port=8103 cu-systems.scm`).

- `cu-systems-static-consp.sh` — Runs the compiled `build/cu-systems-server`
  bound to that same consp.org address on port 8103 by default,
  mirroring `cu-systems-server-local.sh` but for the consp.org
  deployment.

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

- `GNUmakefile` — Builds standalone static executables for `cu-arcs.scm`,
  `cu-worlds.scm`, `cu-systems.scm` and `cu-unified.scm` via the
  `awful-main` egg; see "Static executables (awful-main)" below.

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
  instance on port 8201 (the test suite's own port range, distinct from
  8101-8103 for interactive use, so a test run never collides with an
  already-running server), walks the full 10-page wizard over HTTP with
  `curl`, and checks that every expected field label appears on the final
  page (catches routing/session/template mistakes, not table
  correctness), plus a few deterministic boundary cases via the "Choose"
  path (e.g. Major Race Starport is always "A" regardless of roll). Run
  with `./test-e2e.sh`.

- `test-worlds-tables.scm` — Unit tests for `worlds-tables.scm`, mirroring
  `test-alien-tables.scm`'s approach: exact expected values for the
  deterministic name/descriptor tables, repeated trials for the
  dice-rolling resolvers, plus a dedicated "Lorcan worked example" group
  that replays the rulebook's own example (pp. 301-302) using its stated
  intermediate rolls and checks every derived value against the text.
  Run with `csi -s test-worlds-tables.scm`.

- `test-worlds-e2e.sh` — End-to-end smoke test for `cu-worlds.scm`, on
  port 8202 (the test suite's own port range; see `test-e2e.sh` above):
  the "Roll everything" path plus the Lorcan
  example again, this time walked over HTTP via the "Choose" path,
  checking the final page's UWP line matches the book's exactly
  ("Lorcan E5A6595-8 Fluid Oceans, Non-Industrial G"). Run with
  `./test-worlds-e2e.sh`.

- `test-system-tables.scm` — Unit tests for `system-tables.scm`. The
  name/descriptor tables (`star-count-name`, `mainworld-type-name`,
  `greek-letter-name`, `inner-planet-type`, `outer-planet-type`) get
  exact expected values; `companion-orbits` and `resolve-mainworld-orbit`
  take their die roll as an explicit argument, so those do too. Every
  dice-rolling resolver (including `generate-system` itself) is checked
  with repeated trials against the valid range/invariants instead, since
  the book's own "Example Uninhabited Star System LR806" (p. 305) and
  "The Solar System" (p. 306) worked examples don't state intermediate
  rolls the way Lorcan's does. Run with `csi -s test-system-tables.scm`.

- `test-systems-e2e.sh` — End-to-end smoke test for `cu-systems.scm`, on
  port 8203 (the test suite's own port range; see `test-e2e.sh` above):
  a single-star "Roll everything" walkthrough, a single-star
  Rock mainworld walked via "Choose" (checking the Planetary Details
  branch and that both Markdown exports reproduce the same
  already-generated system rather than rerolling it), and a binary-star
  (companion at Orbit 1) Garden World mainworld walked via "Choose"
  (checking the companion-placement and full-UWP branches, including the
  exact resulting UWP line). Run with `./test-systems-e2e.sh`.

- `test-unified-e2e.sh` — End-to-end smoke test for `cu-unified.scm`, on
  port 8200 (the test suite's own port range; see `test-e2e.sh` above):
  checks the hub page at "/" links to all three sub-apps, that each
  sub-app's own entry page is reachable at its mounted path ("/arcs",
  "/worlds", "/systems") rather than "/", and that a quick walk of the
  Alien Race Creation wizard through the unified server reaches a final
  page offering "Return to ARCS" and "Return to Start" (not the old
  single-app "Start Over" button). Doesn't re-check each sub-app's own
  table/wizard correctness -- that's already covered by `test-e2e.sh`,
  `test-worlds-e2e.sh` and `test-systems-e2e.sh` -- only the
  unification wiring itself. Run with `./test-unified-e2e.sh`.

There is no test coverage for `cu-arcs.scm`, `cu-worlds.scm`,
`cu-systems.scm` or `cu-unified.scm` themselves (the `awful`/HTML web
layer — the `test-*-e2e.sh` scripts exercise them indirectly over
HTTP), `tables.scm`, `sa-acs.scm`, or `dice.scm`.

`GNUmakefile` also has targets for all seven: `make test` runs everything;
`make test-unit` runs the three unit-test files; `make test-e2e` runs all
four end-to-end scripts; `make test-alien-tables`, `make test-worlds-tables`,
`make test-system-tables`, `make test-e2e-arcs`, `make test-e2e-worlds`,
`make test-e2e-systems`, and `make test-e2e-unified` run one each.

## Local modules

This project has no egg packaging — for interactive dev use, `awful`
just loads a single `.scm` file directly, so cross-file code reuse works
via Chicken's `include`, not by installing local eggs. The pattern used
throughout: define a `(module foo (...) ...)` in its own file, then
`(include "foo.scm")` it as a *sibling* top-level form (not nested inside
another module) before the form that does `(import foo)`. `roll-tables.scm`
deliberately isn't wrapped in a module — it's just `(include
"roll-tables.scm")`d directly into whichever module needs its macros.

## Static executables (awful-main)

`cu-arcs.scm`, `cu-worlds.scm`, `cu-systems.scm` and `cu-unified.scm`
can also be built into standalone binaries (no Chicken install needed
to run them) using the `awful-main` egg (`chicken-install awful-main`;
also requires `spiffy`, already an `awful` dependency):

- `cu-arcs-main.scm` / `cu-worlds-main.scm` / `cu-systems-main.scm` /
  `cu-unified-main.scm` are the `awful-main` entry points: each
  `(include ...)` its app's `.scm` file, then instantiates the `(awful
  main)` functor over that app's module (e.g. `(module main = ((awful
  main) cu-arcs))`). `awful-main` generates the CLI parsing (`--addr`,
  `--port`, `--access-log`, `--web-root`, `--dev`, etc.) and startup
  wiring around the app. `awful-main` only supports a single `S` module
  per binary, which is why `cu-unified.scm` combines all three apps'
  `run` procedures into one before being wrapped this way, rather than
  the functor being instantiated three times over.
- The functor requires the app's module to export a `run` procedure,
  which it calls *from inside* `awful-start`'s startup thunk — pages
  registered any earlier (e.g. purely as top-level side effects of
  importing the module, or of a helper function defined only *after*
  the `define-session-page` that references it — awful's macro doesn't
  resolve that kind of forward reference the way plain internal defines
  do) don't take effect. So every app wraps all its `define-session-page`
  calls, and every helper those pages call, in `(define (run . args)
  ...)` — helpers defined before the pages that use them — exported from
  the module, and then calls `(run)` once more at the very bottom of the
  module body (outside `run`'s definition). That bottom-level call is
  what registers pages for the plain interpreted `awful cu-arcs.scm` dev
  workflow, which never calls `run` itself; the compiled binary calls
  `run` a second time via `awful-start`, which is harmless (just
  re-registers the same handlers). `cu-unified.scm` follows the same
  shape: its own `run` registers the hub page at "/" and then calls
  each sub-app's `run` (imported with a distinct prefix -- `arcs-run`,
  `worlds-run`, `systems-run` -- to avoid colliding with its own `run`).
- Build all four with `make` (see `GNUmakefile`); executables land in
  `build/` (gitignored) as `build/cu-arcs-server`, `build/cu-worlds-server`,
  `build/cu-systems-server` and `build/cu-unified-server`, alongside an
  empty `build/static/` (the default `--web-root`). `make run-arcs` /
  `make run-worlds` / `make run-systems` / `make run-unified` build (if
  needed) and run one directly on its standard port
  (8101/8102/8103/8100); `make clean` removes `build/`. To build by
  hand: `csc -static -o build/cu-arcs-server cu-arcs-main.scm` (same
  pattern for the others).
- awful-main's own default port (8080) is hardcoded inside the egg's
  functor body -- there's no hook for a calling module like
  `cu-arcs-main.scm` to change it, so a bare `build/cu-arcs-server` with
  no arguments always binds to 8080, not 8101. `cu-arcs-server-local.sh`
  / `cu-worlds-server-local.sh` / `cu-systems-server-local.sh` /
  `cu-unified-server-local.sh` are thin wrappers that supply each app's
  standard port (8101/8102/8103/8100) themselves and then forward any
  of their own arguments; an explicit `--port=...` passed to the
  wrapper still wins, since awful-main's argument parser is a simple
  left-to-right pass where the last `--port=` seen is the one that
  sticks.
