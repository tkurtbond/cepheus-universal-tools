;;; test-worlds-tables.scm -- Unit tests for worlds-tables.scm, the rules
;;; tables behind cu-worlds.scm's Creating Worlds wizard (Cepheus
;;; Universal pp. 281-302).
;;;
;;; Run with: csi -s test-worlds-tables.scm
;;;
;;; Most of the name/descriptor tables take an explicit digit and return
;;; a deterministic result, so this is plain expected-value testing.
;;; roll-world-size, roll-atmosphere, roll-hydrographics, roll-population,
;;; roll-starport, roll-government, roll-law-level, roll-tech-level,
;;; gas-giant-present?, naval-base-present? and scout-base-present? roll
;;; dice internally, so those are checked with repeated trials against
;;; the valid range/set instead. The "Lorcan" test group replays the
;;; rulebook's own worked example (pp. 301-302) using its stated
;;; intermediate rolls, checking the derived values against those
;;; explicitly given in the text.

(import scheme)
(import (chicken base))
(import (chicken random))
(import (chicken string))
(import srfi-1)
(import srfi-13)
(import test)
(include "roll-tables.scm")
(include "worlds-tables.scm")
(import worlds-tables)

;; Run `thunk' `n' times and assert every result satisfies `pred'.
(define (test-all-satisfy name pred thunk #!optional (n 200))
  (test-assert name
    (let loop ((i 0))
      (or (= i n)
          (and (pred (thunk)) (loop (+ i 1)))))))

(test-group "World Size (p. 281)"
  (test-all-satisfy "roll-world-size stays in 0-16"
    (lambda (v) (<= 0 v 16))
    roll-world-size)
  (test "size 0" "800 km (typically an asteroid or space habitat), negligible surface gravity" (size-name 0))
  (test "size 5" "8,000 km, surface gravity 0.45g" (size-name 5))
  (test "size 8" "12,800 km (Earth, Venus), surface gravity 1.0g" (size-name 8))
  (test "size 10" "16,000 km, surface gravity 1.5g" (size-name 10))
  (test "size 16" "25,600 km, surface gravity 2.6g" (size-name 16))
  (test-error "size 17 out of range" (size-name 17)))

(test-group "Atmosphere (p. 285)"
  (test "roll-atmosphere Size 0 is always 0" 0 (roll-atmosphere 0))
  (test "roll-atmosphere Size 2 is always 0" 0 (roll-atmosphere 2))
  (test-all-satisfy "roll-atmosphere Size 3-4 stays in 0-12"
    (lambda (v) (<= 0 v 12))
    (lambda () (roll-atmosphere 3)))
  (test-all-satisfy "roll-atmosphere Size 5-7 stays in 0-12"
    (lambda (v) (<= 0 v 12))
    (lambda () (roll-atmosphere 6)))
  (test-all-satisfy "roll-atmosphere Size 8+ stays in 0-12"
    (lambda (v) (<= 0 v 12))
    (lambda () (roll-atmosphere 10)))
  (test "atmosphere 0" "None (vacuum; requires a vacc suit)" (atmosphere-name 0))
  (test "atmosphere 6" "Standard" (atmosphere-name 6))
  (test "atmosphere 10" "Exotic (requires an air supply/vacc suit)" (atmosphere-name 10))
  (test "atmosphere 12" "Insidious (requires a vacc suit)" (atmosphere-name 12))
  (test-error "atmosphere 13 out of range" (atmosphere-name 13)))

(test-group "Hydrographics (p. 290)"
  (test "roll-hydrographics Size 0 is always 0" 0 (roll-hydrographics 0 6))
  (test-all-satisfy "roll-hydrographics stays in 0-10 (no DM)"
    (lambda (v) (<= 0 v 10))
    (lambda () (roll-hydrographics 6 6)))
  (test-all-satisfy "roll-hydrographics stays in 0-10 (Atmosphere 2/3/11/12 DM)"
    (lambda (v) (<= 0 v 10))
    (lambda () (roll-hydrographics 6 11)))
  (test "hydrographics 0" "0%-5%, Desert world" (hydrographics-name 0))
  (test "hydrographics 6" "56%-65%, large oceans" (hydrographics-name 6))
  (test "hydrographics 10" "96%-100%, almost entirely water" (hydrographics-name 10))
  (test-error "hydrographics 11 out of range" (hydrographics-name 11)))

(test-group "Population (p. 293)"
  (test-all-satisfy "roll-population stays in 0-10"
    (lambda (v) (<= 0 v 10))
    roll-population)
  (test "population 0" "None" (population-name 0))
  (test "population 5" "Hundreds of thousands" (population-name 5))
  (test "population 10" "Tens of billions" (population-name 10))
  (test-error "population 11 out of range" (population-name 11)))

(test-group "Starport (p. 293)"
  (test "starport class at roll -3 (2 or less)" "X" (starport-class-name -3))
  (test "starport class at roll 2" "X" (starport-class-name 2))
  (test "starport class at roll 3" "E" (starport-class-name 3))
  (test "starport class at roll 4" "E" (starport-class-name 4))
  (test "starport class at roll 5" "D" (starport-class-name 5))
  (test "starport class at roll 6" "D" (starport-class-name 6))
  (test "starport class at roll 7" "C" (starport-class-name 7))
  (test "starport class at roll 8" "C" (starport-class-name 8))
  (test "starport class at roll 9" "B" (starport-class-name 9))
  (test "starport class at roll 10" "B" (starport-class-name 10))
  (test "starport class at roll 11" "A" (starport-class-name 11))
  (test "starport class at roll 20" "A" (starport-class-name 20))
  (test-assert "starport-description A mentions Excellent" (string-prefix? "Excellent" (starport-description "A")))
  (test-assert "starport-description X mentions None" (string-prefix? "None" (starport-description "X"))))

(test-group "Government (p. 294)"
  (test-all-satisfy "roll-government stays in 0-15"
    (lambda (v) (<= 0 v 15))
    (lambda () (roll-government 5)))
  (test "government 0" "None" (government-name 0))
  (test "government 9" "Impersonal Bureaucracy" (government-name 9))
  (test "government 15" "Totalitarian Oligarchy" (government-name 15))
  (test-error "government 16 out of range" (government-name 16)))

(test-group "Law Level (p. 294)"
  (test-all-satisfy "roll-law-level never negative"
    (lambda (v) (>= v 0))
    (lambda () (roll-law-level 9)))
  (test "law level 0" "No Law -- no restrictions; candidate for Amber Zone status" (law-level-name 0))
  (test "law level 5" "Medium Law -- personal concealable weapons banned" (law-level-name 5))
  (test "law level 9" "High Law -- any weapons outside one's residence banned; candidate for Amber Zone status" (law-level-name 9))
  (test "law level 10 (A+)" "Extreme -- no weapons allowed at all; candidate for Amber Zone status" (law-level-name 10))
  (test "law level 15 (still A+)" "Extreme -- no weapons allowed at all; candidate for Amber Zone status" (law-level-name 15)))

(test-group "Technology Level (p. 295)"
  (test "starport-tl-dm A" 6 (starport-tl-dm "A"))
  (test "starport-tl-dm B" 4 (starport-tl-dm "B"))
  (test "starport-tl-dm C" 2 (starport-tl-dm "C"))
  (test "starport-tl-dm X" -4 (starport-tl-dm "X"))
  (test "starport-tl-dm D is 0" 0 (starport-tl-dm "D"))
  (test "starport-tl-dm E is 0" 0 (starport-tl-dm "E"))
  (test "size-tl-dm 0" 2 (size-tl-dm 0))
  (test "size-tl-dm 1" 2 (size-tl-dm 1))
  (test "size-tl-dm 2" 1 (size-tl-dm 2))
  (test "size-tl-dm 4" 1 (size-tl-dm 4))
  (test "size-tl-dm 5 is 0" 0 (size-tl-dm 5))
  (test "atmosphere-tl-dm 0" 1 (atmosphere-tl-dm 0))
  (test "atmosphere-tl-dm 3" 1 (atmosphere-tl-dm 3))
  (test "atmosphere-tl-dm 4 is 0" 0 (atmosphere-tl-dm 4))
  (test "atmosphere-tl-dm 9 is 0" 0 (atmosphere-tl-dm 9))
  (test "atmosphere-tl-dm 10" 1 (atmosphere-tl-dm 10))
  (test "atmosphere-tl-dm 15" 1 (atmosphere-tl-dm 15))
  (test "hydrographics-tl-dm 0" 1 (hydrographics-tl-dm 0))
  (test "hydrographics-tl-dm 9" 1 (hydrographics-tl-dm 9))
  (test "hydrographics-tl-dm 10" 2 (hydrographics-tl-dm 10))
  (test "hydrographics-tl-dm 5 is 0" 0 (hydrographics-tl-dm 5))
  (test "population-tl-dm 1" 1 (population-tl-dm 1))
  (test "population-tl-dm 5" 1 (population-tl-dm 5))
  (test "population-tl-dm 6 is 0" 0 (population-tl-dm 6))
  (test "population-tl-dm 9" 1 (population-tl-dm 9))
  (test "population-tl-dm 10" 2 (population-tl-dm 10))
  (test "government-tl-dm 0" 1 (government-tl-dm 0))
  (test "government-tl-dm 5" 1 (government-tl-dm 5))
  (test "government-tl-dm 7" 2 (government-tl-dm 7))
  (test "government-tl-dm 13" -2 (government-tl-dm 13))
  (test "government-tl-dm 14" -2 (government-tl-dm 14))
  (test "government-tl-dm 9 is 0" 0 (government-tl-dm 9))
  (test "tech-level-minimum Atmosphere 3" 7 (tech-level-minimum 3))
  (test "tech-level-minimum Atmosphere 10 (A)" 7 (tech-level-minimum 10))
  (test "tech-level-minimum Atmosphere 12 (C)" 7 (tech-level-minimum 12))
  (test "tech-level-minimum Atmosphere 4" 5 (tech-level-minimum 4))
  (test "tech-level-minimum Atmosphere 7" 5 (tech-level-minimum 7))
  (test "tech-level-minimum Atmosphere 9" 5 (tech-level-minimum 9))
  (test "tech-level-minimum Atmosphere 6" 0 (tech-level-minimum 6))
  (test-all-satisfy "roll-tech-level never negative"
    (lambda (v) (>= v 0))
    (lambda () (roll-tech-level "E" 5 10 6 5 9)))
  (test "tech-level-name 0" "Primitive -- Stone Age." (tech-level-name 0))
  (test "tech-level-name 8" "Pre-Stellar -- Modern Day. The internet, smartphones, and an integrated network society. Possible to reach other worlds in the same star system with rocket technology. Basic robots now available. Earth 2000 onwards." (tech-level-name 8))
  (test "tech-level-name 10 (A)" "Early Stellar -- Development of gravity manipulation, as well as faster-than-light travel, nearby systems are opened up. Use of robots becomes widespread. The first primitive artificial intelligences become possible." (tech-level-name 10))
  (test "tech-level-name 18 (J)" "Quantum -- Energy transfer is now perfected. Sentience can travel without physical form, and snap in and out of planes of existence. Indistinguishable from magic." (tech-level-name 18))
  (test "tech-level-name 21 (beyond the book) still Quantum" "Quantum -- Energy transfer is now perfected. Sentience can travel without physical form, and snap in and out of planes of existence. Indistinguishable from magic." (tech-level-name 21))
  (test-error "tech-level-name -1 out of range" (tech-level-name -1)))

(test-group "Trade Codes (pp. 295-297)"
  (test "Agricultural" '("Agricultural") (trade-codes 6 7 5 7))
  (test "Vacuum" '("Vacuum") (trade-codes 6 0 0 0))
  (test "Water World" '("Water World") (trade-codes 6 6 10 9))
  (test "Non-Industrial + Fluid Oceans (Lorcan)" '("Fluid Oceans" "Non-Industrial") (trade-codes 5 10 6 5))
  (test "no codes for an unremarkable world" '() (trade-codes 6 6 5 0)))

(test-group "Gas Giants and Bases (pp. 294, 297)"
  (test-assert "gas-giant-present? returns a boolean"
    (boolean? (gas-giant-present?)))
  (test "naval-base-present? false for Starport C" #f (naval-base-present? "C"))
  (test "naval-base-present? false for Starport E" #f (naval-base-present? "E"))
  (test "scout-base-present? false for Starport E" #f (scout-base-present? "E"))
  (test "scout-base-present? false for Starport X" #f (scout-base-present? "X"))
  (test "bases-code neither" "" (bases-code #f #f))
  (test "bases-code naval only" "N" (bases-code #t #f))
  (test "bases-code scout only" "S" (bases-code #f #t))
  (test "bases-code both" "A" (bases-code #t #t)))

(test-group "UWP line and uwp-char"
  (test "uwp-char single digit" "7" (uwp-char 7))
  (test "uwp-char 10 is A" "A" (uwp-char 10))
  (test "uwp-char 12 is C" "C" (uwp-char 12))
  (test "Ceti Prime example UWP" "D8676CA-7"
    (uwp-line "D" 8 6 7 6 12 10 7))
  (test "Lorcan example UWP" "E5A6595-8"
    (uwp-line "E" 5 10 6 5 9 5 8)))

;; The rulebook's own worked example, Lorcan (pp. 301-302), replayed
;; using the specific intermediate rolls it states, checking that our
;; formulas reproduce the values the text gives at each step.
(test-group "Lorcan worked example (pp. 301-302)"
  (let* ((size 5)                                ; 1D6 rolled 4 (no Super-Earth); 2D6 rolled 7, minus 2.
         (atmosphere 10)                         ; rolled 10 directly (Size 5-7 DM is 0).
         (hydrographics 6)                       ; "60% surface oceans" (Atmosphere 10 gets no Hydrographics DM).
         (population 5)                          ; "We roll 2D6 minus 2 for a 5 result."
         (starport-roll 5)                       ; "We roll 5, minus 7 is -2. Then we add the 5 Population..."
         (starport (starport-class-name (+ starport-roll -7 population)))
         (government-roll 11)                    ; "we roll 11, take away 7 is 4. Then we add the Population value of 5..."
         (government (+ government-roll -7 population))
         (law-level-roll 3)                      ; "We roll 3, minus 7 is -4. Next we add 9 (the government value)..."
         (law-level (+ law-level-roll -7 government)))
    (test "Lorcan Size" 5 size)
    (test "Lorcan Atmosphere name" "Exotic (requires an air supply/vacc suit)" (atmosphere-name atmosphere))
    (test "Lorcan Hydrographics name" "56%-65%, large oceans" (hydrographics-name hydrographics))
    (test "Lorcan Population name" "Hundreds of thousands" (population-name population))
    (test "Lorcan Starport class" "E" starport)
    (test "Lorcan Government" 9 government)
    (test "Lorcan Government name" "Impersonal Bureaucracy" (government-name government))
    (test "Lorcan Law Level" 5 law-level)
    (test "Lorcan Law Level name" "Medium Law -- personal concealable weapons banned" (law-level-name law-level))
    (test "Lorcan Tech Level DM total" 2
      (+ (starport-tl-dm starport) (size-tl-dm size) (atmosphere-tl-dm atmosphere)
         (hydrographics-tl-dm hydrographics) (population-tl-dm population) (government-tl-dm government)))
    (test "Lorcan Trade Codes" '("Fluid Oceans" "Non-Industrial")
      (trade-codes size atmosphere hydrographics population))
    (test "Lorcan UWP" "E5A6595-8"
      (uwp-line starport size atmosphere hydrographics population government law-level 8))))

(test-exit)
