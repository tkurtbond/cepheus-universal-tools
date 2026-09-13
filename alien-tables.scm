;;; alien-tables.scm -- Rules tables for Cepheus Universal Alien Race
;;; Creation (pp. 326-329), factored out of cu-arcs-v2.scm so they can be
;;; unit-tested independently of the web front-end (see test-alien-tables.scm).

(module alien-tables
  (D nD
   biotype-name subtype-name
   starport-name
   government-formula
   tech-level-formula
   sex-name resolve-sex
   reproduction-name
   hydrographic-band amphibious-name
   locomotion-name symmetry-name legs-count
   size-name size-tier size-dex-dice characteristic-modifier
   biotype-stat-modifier characteristic-formula
   armour-modifier resolve-armour
   natural-weapon-modifier natural-weapon-name resolve-natural-weapon
   vision-name audio-name olfactory-name
   special-sense-name resolve-special-sense
   lifespan-name resolve-lifespan
   physiological-advantage-name resolve-physiological-advantage)

(import scheme)
(import (chicken base))
(import (chicken random))
(import (math base))
(import loop)

(include "roll-tables.scm")

(define (D num-sides) (+ 1 (pseudo-random-integer num-sides)))
(define (nD num-dice num-sides)
  (sum (loop repeat num-dice collect (D num-sides))))

;; Race Biotype & Subtype, Cepheus Universal p. 329.
(define-roll-table (biotype-name roll)
  ((2 . 3) "Scavenger")
  ((4 . 5) "Herbivore")
  ((6 . 10) "Omnivore")
  ((11 . 12) "Carnivore"))

(define-keyed-roll-table (subtype-name biotype roll)
  ("Scavenger" ((2 . 3) "Reducer")
               ((4 . 7) "Hijacker")
               ((8 . 9) "Intimidator")
               ((10 . 12) "Carrion Eater"))
  ("Herbivore" ((2) "Filter")
               ((3 . 7) "Intermittent")
               ((8 . 12) "Grazer"))
  ("Omnivore" ((2 . 7) "Gatherer")
              ((8 . 10) "Hunter")
              ((11 . 12) "Eater"))
  ("Carnivore" ((2 . 5) "Pouncer")
               ((6 . 8) "Chaser")
               ((9 . 11) "Killer")
               ((12) "Siren")))

;; Starport, Cepheus Universal p. 326. A Major Race always gets Class A
;; regardless of the 1D6 roll -- modeled here as a single range covering
;; every possible roll, so it still fits the keyed-roll-table shape.
(define-keyed-roll-table (starport-name major-or-minor roll)
  ('Major ((1 . 6) "A"))
  ('Minor ((1 . 2) "X")
          ((3) "E")
          ((4) "D")
          ((5) "C")
          ((6) "B")))

;; Government, Cepheus Universal p. 326.
(define-formula-table (government-formula roll)
  ((1 . 3) (1 6 1))
  ((4 . 6) (1 6 7)))

;; Tech Level, Cepheus Universal p. 326. Major Race ignores the roll
;; entirely (a flat 1D6+9) -- modeled, as with Starport, as a single
;; range covering every possible roll.
(define-keyed-formula-table (tech-level-formula major-or-minor roll)
  ('Major ((1 . 6) (1 6 9)))
  ('Minor ((1 . 3) (1 3 0))
          ((4 . 5) (1 3 3))
          ((6) (1 3 6))))

;; Sex & Reproduction, Cepheus Universal p. 327. The 11-12 result ("1D3+1
;; sexes") is a formula wrapped in prose rather than a fixed name, so it
;; can't safely be a define-roll-table result (that would re-roll the
;; dice every time the table's description text is generated); the table
;; still carries that exact phrase for display, and resolve-sex re-rolls
;; the count only when actually resolving a roll into a final value.
(define-roll-table (sex-name roll)
  ((2 . 3) "Asexual")
  ((4) "Hermaphrodite")
  ((5 . 10) "Two sexes")
  ((11 . 12) "1D3+1 sexes"))

(define (resolve-sex roll)
  (if (<= 11 roll 12)
      (string-append (number->string (+ 1 (D 3))) " sexes")
      (sex-name roll)))

(define-roll-table (reproduction-name roll)
  ((1) "External budding")
  ((2 . 4) "Live-bearing")
  ((5 . 6) "Egg-laying"))

;; Amphibious?, Cepheus Universal p. 327. Keyed on a band of the world's
;; Hydrographics (already known by this point), rather than on a
;; previously-rolled trait.
(define-roll-table (hydrographic-band hydrographics)
  ((0 . 3) 'low)
  ((4 . 6) 'medium)
  ((7 . 9) 'high)
  ((10) 'total))

(define-keyed-roll-table (amphibious-name band roll)
  ('low ((2 . 3) "Amphibious")
        ((4 . 12) "Land-dweller"))
  ('medium ((2) "Aquatic")
           ((3 . 4) "Amphibious")
           ((5 . 12) "Land-dweller"))
  ('high ((2 . 3) "Aquatic")
         ((4) "Amphibious")
         ((5 . 12) "Land-dweller"))
  ('total ((2 . 6) "Aquatic")
          ((7 . 12) "Amphibious")))

;; Body Form, Cepheus Universal p. 328: Locomotion, Symmetry, and Number
;; of Legs are three independent tables (each its own 2D6 roll). Per the
;; rulebook, a water-breathing or amphibious race (previous step) should
;; ignore a Walker/Flyer Locomotion result -- a GM judgment call, not
;; enforced here.
(define-roll-table (locomotion-name roll)
  ((2 . 9) "Walker")
  ((10 . 11) "Flyer")
  ((12) "Triphibian"))

(define-roll-table (symmetry-name roll)
  ((2 . 4) "Trilateral")
  ((5 . 9) "Bilateral")
  ((10 . 12) "Radial"))

(define-roll-table (legs-count roll)
  ((2 . 9) 2)
  ((10) 4)
  ((11) 3)
  ((12) 6))

;; Size & Characteristics, Cepheus Universal p. 328. Unlike the tables
;; above, this doesn't resolve to a single value: Size picks a die type
;; for Strength, Dexterity and Endurance (Intelligence/Education/Social,
;; "Other", are always 2D6), each characteristic then gets its own
;; -2..+2 modifier roll, and Biotype adds a further fixed modifier. The
;; result recorded is a formula like "2D6-1", not a rolled number.
(define-roll-table (size-name roll)
  ((2 . 4) "Small")
  ((5 . 9) "Medium")
  ((10 . 12) "Large"))

;; Str and End dice-count both equal the size tier (1/2/3); Dex is 3D6
;; for Small, 2D6 otherwise. Internal to this step, not a rollable field
;; in its own right, so plain procedures rather than a table macro.
(define (size-tier roll)
  (cond ((<= 2 roll 4) 1)
        ((<= 5 roll 9) 2)
        ((<= 10 roll 12) 3)
        (else (error 'size-tier "roll out of range" roll))))
(define (size-dex-dice roll) (if (<= 2 roll 4) 3 2))

(define-roll-table (characteristic-modifier roll)
  ((2) -2)
  ((3 . 5) -1)
  ((6 . 8) 0)
  ((9 . 11) 1)
  ((12) 2))

;; Biotype modifier: Carnivore Str+2 Dex+2; Herbivore Str+3 Soc+3 Dex-2.
(define (biotype-stat-modifier biotype stat)
  (cond ((string=? biotype "Carnivore")
         (case stat ((Str) 2) ((Dex) 2) (else 0)))
        ((string=? biotype "Herbivore")
         (case stat ((Str) 3) ((Soc) 3) ((Dex) -2) (else 0)))
        (else 0)))

(define (characteristic-formula dice-count roll-modifier biotype-modifier)
  (formula-text (list dice-count 6 (+ roll-modifier biotype-modifier))))

;; Armour, Cepheus Universal p. 328: a 2D6 roll, modified by Biotype and
;; Size, checked against a fixed threshold (12) -- not a roll-range
;; table, since what varies is a bonus to the roll rather than the
;; ranges themselves.
(define (armour-modifier biotype size)
  (+ (if (member biotype '("Scavenger" "Herbivore")) 2 0)
     (if (string=? size "Large") 4 0)))

(define (resolve-armour roll biotype size)
  (if (>= (+ roll (armour-modifier biotype size)) 12)
      (string-append "Yes (Armour Value " (number->string (+ 1 (D 3))) ")")
      "None"))

;; Natural Weapons, Cepheus Universal p. 328: as Armour, a modified 2D6
;; roll (threshold 9) determines whether the race retains a natural
;; weapon at all; if so, a further unmodified 2D6 determines its form.
(define (natural-weapon-modifier biotype)
  (cond ((string=? biotype "Carnivore") 3)
        ((string=? biotype "Scavenger") 1)
        ((string=? biotype "Herbivore") -2)
        (else 0)))

(define-roll-table (natural-weapon-name roll)
  ((2 . 4) "Hooves")
  ((5) "Horns")
  ((6 . 7) "Teeth")
  ((8) "Claws (possibly retractable)")
  ((9 . 10) "Teeth & Claws")
  ((11) "Stinger")
  ((12) "Thrasher"))

(define (resolve-natural-weapon roll biotype)
  (if (>= (+ roll (natural-weapon-modifier biotype)) 9)
      (natural-weapon-name (nD 2 6))
      "Fist (no retained natural weapon)"))

;; Senses, Cepheus Universal p. 328-329: Vision, Audio and Olfactory are
;; three independent 2D6 tables; Special Sense is a fourth, unmodified
;; 2D6 threshold check (11+) like Armour/Natural Weapons above.
(define-roll-table (vision-name roll)
  ((2) "Blind")
  ((3) "Colour blind")
  ((4) "Poor vision (-1)")
  ((5 . 6) "Cat's Eyes")
  ((7) "Acute vision (+2)")
  ((8 . 12) "Human-level"))

(define-roll-table (audio-name roll)
  ((2) "Deaf")
  ((3) "Mute")
  ((4 . 5) "Poor hearing")
  ((6) "Parabolic hearing")
  ((7 . 12) "Human-level"))

(define-roll-table (olfactory-name roll)
  ((2 . 3) "No ability")
  ((4 . 5) "Poor ability (-2)")
  ((6) "Acute ability (+2)")
  ((7 . 11) "Human-level")
  ((12) "Pheromone Sense"))

(define-roll-table (special-sense-name roll)
  ((1) "Radio transmission sensing")
  ((2) "Vibration sensing")
  ((3) "Echo location")
  ((4) "Uncanny prescience (\"intuition\")")
  ((5) "Thermal vision")
  ((6) "Telepathy"))

(define (resolve-special-sense roll)
  (if (>= roll 11)
      (special-sense-name (D 6))
      "None"))

;; Life Cycle, Cepheus Universal p. 329. Lifespan's "Very Short" result is
;; itself a further roll (2D6 years), as with Sex above; Physiological
;; Advantage is a separate 2D6 threshold check (9+), as with Armour /
;; Natural Weapons / Special Sense.
(define-roll-table (lifespan-name roll)
  ((2 . 4) "Very Short (2D6 years)")
  ((5) "Short (40 years)")
  ((6 . 7) "Human-level (80 years)")
  ((8 . 10) "Long (200 years)")
  ((11) "Very Long (1000 years)")
  ((12) "Immortal?"))

(define (resolve-lifespan roll)
  (if (<= 2 roll 4)
      (string-append "Very Short (" (number->string (nD 2 6)) " years)")
      (lifespan-name roll)))

(define-roll-table (physiological-advantage-name roll)
  ((1) "Regeneration")
  ((2) "Poison Immunity")
  ((3) "Metabolic Accelerator")
  ((4) "Metabolic Decelerator")
  ((5) "Transmorph")
  ((6) "High Pain Threshold"))

(define (resolve-physiological-advantage roll)
  (if (>= roll 9)
      (physiological-advantage-name (D 6))
      "None"))

)
