# Cepheus Universal Tools

A small, work-in-progress collection of Chicken Scheme scripts for
generating RPG content, built on the `awful` web framework. Primarily
targets the *Cepheus Universal* / *Cepheus Engine* ruleset (a
Traveller-based sci-fi system). This is personal GM-prep tooling, not a
finished product — several files are stubs or mid-rewrite.

## Files

- `cu-arcs.scm` — "Cepheus Universal Alien Race Creation System."
  Single-page `awful` web app: one HTML form collects choices (Major/Minor
  race, world size, atmosphere, hydrographics, population, government, law
  level, tech level, starport — each either "roll" or manually chosen).
  `/alien-creation-result` computes the rolls (2D6, 1D6, etc. via `D`/`nD`
  helpers) following classic Traveller/Cepheus world-generation tables and
  prints the results.

- `cu-arcs-v2.scm` — Rewrite of `cu-arcs.scm` using `define-session-page`
  and `$session-set!`/`$session` to carry state across multiple sequential
  forms instead of one big form. Adds a "Biotype" page (Scavenger /
  Herbivore / Omnivore / Carnivore) after the homeworld page; the
  "Subtype" list item on that page is left empty — mid-development.
  Run via `awful --port=2020 cu-arcs-v2.scm` (per the file's header
  comment).

- `cu-arcs-consp.sh` — Launcher script for `cu-arcs.scm`
  (`awful --ip-address=71.19.158.45 --port=8080 cu-arcs.scm`). Has a
  broken shebang (`#1` instead of `#!`), so it likely doesn't run as-is —
  treat as an experimental/personal script.

- `sa-acs.scm` — "Stellar Adventures Alien Creation System." Explicitly
  marked "Just a reminder, for now." Stub module that only imports
  libraries (including `awful`) but defines nothing yet — a placeholder
  for an alien-creation generator (intelligent and unintelligent
  creatures) for a different game, "Stellar Adventures."

- `tables.scm` — Data tables for alien creation (chemical basis of life;
  land/water habitat and sub-habitats) using a `defstruct`-based
  `section`/`table` model, built on `d6`/`make-d` from `dice.scm`.
  Incomplete: unclosed parens and a typo (`talbes:` for `tables:`) partway
  through — cuts off mid-definition.

- `dice.scm` — General-purpose dice-rolling library: `make-d` (die
  constructor), `make-roll` (roll N dice), `highest`/`lowest`
  (keep-N-drop-rest with human-readable descriptions), and an "OVA"
  die-pool mechanic (`ova-roll`: sum matching dice for positive pool
  sizes, take the lowest of a negative pool). The OVA mechanic supports a
  different system (OVA, a diceless/dice-pool anime RPG) rather than
  Cepheus itself.

## Status

Early-stage and unfinished. `cu-arcs.scm`/`cu-arcs-v2.scm` are the most
complete (working homeworld generation); `tables.scm` and `sa-acs.scm` are
stubs/placeholders.
