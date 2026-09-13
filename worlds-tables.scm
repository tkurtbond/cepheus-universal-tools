;;; worlds-tables.scm -- Rules tables for Cepheus Universal Creating Worlds
;;; (pp. 281-302), factored out of cu-worlds.scm so they can be
;;; unit-tested independently of the web front-end (see
;;; test-worlds-tables.scm).

(module worlds-tables
  (D nD
   roll-world-size size-name
   roll-atmosphere atmosphere-name
   roll-hydrographics hydrographics-name
   roll-population population-name
   roll-starport starport-class-name starport-description
   roll-government government-name
   roll-law-level law-level-name
   starport-tl-dm size-tl-dm atmosphere-tl-dm hydrographics-tl-dm
   population-tl-dm government-tl-dm tech-level-minimum roll-tech-level
   trade-codes
   gas-giant-present? naval-base-present? scout-base-present? scout-base-dm bases-code
   uwp-line)

(import scheme)
(import (chicken base))
(import (chicken random))
(import (math base))
(import loop)
(import srfi-1)

(include "roll-tables.scm")

(define (D num-sides) (+ 1 (pseudo-random-integer num-sides)))
(define (nD num-dice num-sides)
  (sum (loop repeat num-dice collect (D num-sides))))

;; World Size, Cepheus Universal p. 281. Roll 1D6; on a 6 the world is a
;; rare 'super-Earth' (roll 2D6+4), otherwise roll 2D6-2. Both branches
;; land in 0-16 already, so no clamping is needed. The Size digit uses
;; letters for 10+ (via uwp-char), up to 16 (G); Z (Megastructure) is a
;; GM-placed special case, never randomly generated, so it has no entry
;; here.
(define (roll-world-size)
  (if (= (D 6) 6)
      (+ 4 (nD 2 6))
      (- (nD 2 6) 2)))

(define-roll-table (size-name digit)
  ((0) "800 km (typically an asteroid or space habitat), negligible surface gravity")
  ((1) "1,600 km (Pluto), surface gravity 0.05g")
  ((2) "3,200 km (Europa or the Moon), surface gravity 0.15g")
  ((3) "4,800 km (Mercury), surface gravity 0.25g")
  ((4) "6,400 km (Mars), surface gravity 0.35g")
  ((5) "8,000 km, surface gravity 0.45g")
  ((6) "9,600 km, surface gravity 0.7g")
  ((7) "11,200 km, surface gravity 0.9g")
  ((8) "12,800 km (Earth, Venus), surface gravity 1.0g")
  ((9) "14,400 km, surface gravity 1.25g")
  ((10) "16,000 km, surface gravity 1.5g")
  ((11) "17,600 km, surface gravity 1.8g")
  ((12) "19,200 km, surface gravity 2.0g")
  ((13) "20,800 km, surface gravity 2.2g")
  ((14) "22,400 km, surface gravity 2.3g")
  ((15) "24,000 km, surface gravity 2.5g")
  ((16) "25,600 km, surface gravity 2.6g"))

;; Atmosphere, Cepheus Universal p. 285. Roll 2D6 plus a DM that depends
;; on World Size; Size 0-2 skips the roll entirely (Atmosphere is always
;; 0). Clamped to 0-12, the digit's full defined range.
(define (roll-atmosphere size)
  (cond ((<= 0 size 2) 0)
        ((<= 3 size 4) (clamp (- (nD 2 6) 5) 0 12))
        ((<= 5 size 7) (clamp (nD 2 6) 0 12))
        (else (clamp (+ (nD 2 6) 2) 0 12))))

(define-roll-table (atmosphere-name digit)
  ((0) "None (vacuum; requires a vacc suit)")
  ((1) "Trace (requires a vacc suit)")
  ((2) "Very Thin, Tainted (requires a survival mask)")
  ((3) "Very Thin (requires a survival mask)")
  ((4) "Thin, Tainted (requires a survival mask)")
  ((5) "Thin")
  ((6) "Standard")
  ((7) "Standard, Tainted (requires a survival mask)")
  ((8) "Dense")
  ((9) "Dense, Tainted (requires a survival mask)")
  ((10) "Exotic (requires an air supply/vacc suit)")
  ((11) "Corrosive (requires a vacc suit)")
  ((12) "Insidious (requires a vacc suit)"))

;; Hydrographics, Cepheus Universal p. 290. Roll 2D6 plus a DM that
;; depends on World Size and Atmosphere; Size 0-2 skips the roll (always
;; 0). The rulebook caps this at 0-10 explicitly.
(define (roll-hydrographics size atmosphere)
  (cond ((<= 0 size 2) 0)
        ((memv atmosphere '(2 3 11 12)) (clamp (- (nD 2 6) 6) 0 10))
        (else (clamp (nD 2 6) 0 10))))

(define-roll-table (hydrographics-name digit)
  ((0) "0%-5%, Desert world")
  ((1) "6%-15%, Dry world")
  ((2) "16%-25%, a few small seas")
  ((3) "26%-35%, small seas and oceans")
  ((4) "36%-45%, wet world")
  ((5) "46%-55%, large oceans")
  ((6) "56%-65%, large oceans")
  ((7) "66%-75%, Earth-like world")
  ((8) "76%-85%, water world")
  ((9) "86%-95%, few small islands")
  ((10) "96%-100%, almost entirely water"))

;; Population, Cepheus Universal p. 293. Roll 2D6-2. The rulebook's
;; Condition/DM column for this table is inconsistent (its last two rows
;; describe complementary, always-true conditions rather than optional
;; ones) and the book's own worked example (Lorcan, p. 301) applies no DM
;; at all -- "We roll 2D6 minus 2 for a 5 result" -- so, matching that
;; example, no DM is applied here either. A Population of 0 means the
;; world is uninhabited, with Government, Law Level and Tech Level all 0
;; (a GM/caller responsibility, not enforced by this procedure).
(define (roll-population)
  (clamp (- (nD 2 6) 2) 0 10))

(define-roll-table (population-name digit)
  ((0) "None")
  ((1) "Few")
  ((2) "Hundreds")
  ((3) "Thousands")
  ((4) "Tens of thousands")
  ((5) "Hundreds of thousands")
  ((6) "Millions")
  ((7) "Tens of millions")
  ((8) "Hundreds of millions")
  ((9) "Billions")
  ((10) "Tens of billions"))

;; Starport, Cepheus Universal p. 293. Roll 2D6-7, add Population, then
;; look up the class.
(define (roll-starport population)
  (+ (- (nD 2 6) 7) population))

(define-roll-table (starport-class-name roll)
  ((-999 . 2) "X")
  ((3 . 4) "E")
  ((5 . 6) "D")
  ((7 . 8) "C")
  ((9 . 10) "B")
  ((11 . 999) "A"))

(define (starport-description class)
  (cond ((string=? class "A") "Excellent -- refined fuel, can construct all ship types, possible Naval or Scout base")
        ((string=? class "B") "Good -- refined fuel, can construct non-starships, possible Naval or Scout base")
        ((string=? class "C") "Routine -- unrefined fuel, can perform reasonable repairs, possible Scout base")
        ((string=? class "D") "Poor -- unrefined fuel, no construction capacity, possible Scout base")
        ((string=? class "E") "Frontier -- no fuel, no construction capacity, no bases")
        ((string=? class "X") "None -- no fuel, no construction capacity, no bases")
        (else (error 'starport-description "unknown starport class" class))))

;; Government, Cepheus Universal p. 294. Roll 2D6-7, add Population.
;; Clamped to 0-15, the digit's full defined range.
(define (roll-government population)
  (clamp (+ (- (nD 2 6) 7) population) 0 15))

(define-roll-table (government-name digit)
  ((0) "None")
  ((1) "Company/Corporation")
  ((2) "Participating Democracy")
  ((3) "Self-Perpetuating Oligarchy")
  ((4) "Representative Democracy")
  ((5) "Feudal Technocracy")
  ((6) "Captive Government")
  ((7) "Balkanization")
  ((8) "Civil Service Bureaucracy")
  ((9) "Impersonal Bureaucracy")
  ((10) "Charismatic Dictator")
  ((11) "Non-Charismatic Leader")
  ((12) "Charismatic Oligarchy")
  ((13) "Religious Dictatorship")
  ((14) "Religious Autocracy")
  ((15) "Totalitarian Oligarchy"))

;; Law Level, Cepheus Universal p. 294. Roll 2D6-7, add Government.
;; Clamped to a minimum of 0; the rulebook gives no explicit maximum, so
;; the descriptor table's top entry ("A+", digit 10 and up) is left
;; open-ended.
(define (roll-law-level government)
  (clamp (+ (- (nD 2 6) 7) government) 0 999))

(define-roll-table (law-level-name digit)
  ((0) "No Law -- no restrictions; candidate for Amber Zone status")
  ((1) "Low Law -- poison gas, explosives, undetectable weapons and weapons of mass destruction banned")
  ((2) "Low Law -- portable energy weapons banned (except ship-mounted weapons)")
  ((3) "Low Law -- heavy weapons banned")
  ((4) "Medium Law -- light assault weapons and submachine guns banned")
  ((5) "Medium Law -- personal concealable weapons banned")
  ((6) "Medium Law -- all firearms except shotguns and stunners banned; carrying weapons discouraged")
  ((7) "High Law -- shotguns banned")
  ((8) "High Law -- all bladed weapons and stunners banned")
  ((9) "High Law -- any weapons outside one's residence banned; candidate for Amber Zone status")
  ((10 . 999) "Extreme -- no weapons allowed at all; candidate for Amber Zone status"))

;; Technology Level, Cepheus Universal p. 295. Roll 1D6, add DMs for
;; Starport, Size, Atmosphere, Hydrographics, Population and Government.
;; This is the standard Cepheus/Traveller TL DM table; cross-checked
;; against the Lorcan example (p. 301), whose Starport E, Size 5,
;; Atmosphere A, Hydrographics 6, Population 5 and Government 9 combine
;; for a stated total DM of +2 -- matching (+1 for Atmosphere, +1 for
;; Population) below.
(define (starport-tl-dm class)
  (cond ((string=? class "A") 6)
        ((string=? class "B") 4)
        ((string=? class "C") 2)
        ((string=? class "X") -4)
        (else 0)))

(define (size-tl-dm size)
  (cond ((<= 0 size 1) 2)
        ((<= 2 size 4) 1)
        (else 0)))

(define (atmosphere-tl-dm atmosphere)
  (if (or (<= 0 atmosphere 3) (<= 10 atmosphere 15)) 1 0))

(define (hydrographics-tl-dm hydrographics)
  (cond ((= hydrographics 0) 1)
        ((= hydrographics 9) 1)
        ((= hydrographics 10) 2)
        (else 0)))

(define (population-tl-dm population)
  (cond ((<= 1 population 5) 1)
        ((= population 9) 1)
        ((= population 10) 2)
        ((= population 11) 3)
        ((= population 12) 4)
        (else 0)))

(define (government-tl-dm government)
  (cond ((= government 0) 1)
        ((= government 5) 1)
        ((= government 7) 2)
        ((= government 13) -2)
        ((= government 14) -2)
        (else 0)))

;; Certain atmospheres impose a minimum Tech Level regardless of the
;; roll (p. 295): 7+ for Atmosphere 3 or less, or 10-12 (A-C); 5+ for
;; Atmosphere 4, 7 or 9.
(define (tech-level-minimum atmosphere)
  (cond ((or (<= atmosphere 3) (<= 10 atmosphere 12)) 7)
        ((memv atmosphere '(4 7 9)) 5)
        (else 0)))

(define (roll-tech-level starport-class size atmosphere hydrographics population government)
  (max (tech-level-minimum atmosphere)
       (+ (D 6)
          (starport-tl-dm starport-class)
          (size-tl-dm size)
          (atmosphere-tl-dm atmosphere)
          (hydrographics-tl-dm hydrographics)
          (population-tl-dm population)
          (government-tl-dm government))))

;; Trade Codes, Cepheus Universal pp. 295-297. Derived entirely from a
;; world's other characteristics -- no roll of its own. A world may
;; qualify for several codes at once (as Lorcan does, in the worked
;; example: Fluid Oceans and Non-Industrial). Ice-Capped follows the
;; prose ("a Hydrographic value of 1") rather than the summary table's
;; "1+", since the two disagree and the prose is more specific.
(define (trade-codes size atmosphere hydrographics population)
  (filter
   (lambda (x) x)
   (list
    (and (<= 4 atmosphere 9) (<= 4 hydrographics 8) (<= 5 population 7) "Agricultural")
    (and (= size 0) (= atmosphere 0) (= hydrographics 0) "Asteroid")
    (and (>= atmosphere 2) (= hydrographics 0) "Desert")
    (and (>= atmosphere 10) (>= hydrographics 1) "Fluid Oceans")
    (and (memv atmosphere '(5 6 8)) (<= 4 hydrographics 9) (<= 4 population 8) "Garden")
    (and (<= 0 atmosphere 1) (= hydrographics 1) "Ice-Capped")
    (and (memv atmosphere '(0 1 2 4 7 9)) (>= population 9) "Industrial")
    (and (<= 0 hydrographics 3) (>= population 6) "Non-Agricultural")
    (and (<= 1 population 6) "Non-Industrial")
    (and (<= 2 atmosphere 5) (<= 0 hydrographics 3) "Poor")
    (and (memv atmosphere '(6 8)) (<= 6 population 8) "Rich")
    (and (= hydrographics 10) "Water World")
    (and (= atmosphere 0) "Vacuum"))))

;; Gas Giants and Bases, Cepheus Universal pp. 294, 297. Gas giant
;; presence is rolled once per star system (not per world). Naval and
;; Scout bases each depend on the mainworld's Starport class.
(define (gas-giant-present?)
  (>= (nD 2 6) 5))

(define (naval-base-present? starport-class)
  (and (member starport-class '("A" "B"))
       (>= (nD 2 6) 8)))

(define (scout-base-dm starport-class)
  (cond ((string=? starport-class "A") -3)
        ((string=? starport-class "B") -2)
        ((string=? starport-class "C") -1)
        (else 0)))

(define (scout-base-present? starport-class)
  (and (not (member starport-class '("E" "X")))
       (>= (+ (nD 2 6) (scout-base-dm starport-class)) 7)))

(define (bases-code naval? scout?)
  (cond ((and naval? scout?) "A")
        (naval? "N")
        (scout? "S")
        (else "")))

;; Universal World Profile string, e.g. "D8676CA-7" (Cepheus Universal
;; p. 281) or "E5A6595-8" (the Lorcan example, p. 301-302).
(define (uwp-line starport-class size atmosphere hydrographics population government law-level tech-level)
  (string-append starport-class
                 (uwp-char size) (uwp-char atmosphere) (uwp-char hydrographics)
                 (uwp-char population) (uwp-char government) (uwp-char law-level)
                 "-" (number->string tech-level)))

)
