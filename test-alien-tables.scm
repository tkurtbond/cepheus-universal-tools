;;; test-alien-tables.scm -- Unit tests for alien-tables.scm, the rules
;;; tables behind cu-arcs.scm's Alien Race Creation wizard (Cepheus
;;; Universal pp. 326-329).
;;;
;;; Run with: csi -s test-alien-tables.scm
;;;
;;; Every table procedure here takes an explicit roll and returns a
;;; deterministic result, so most of this is plain expected-value
;;; testing. A handful of resolve-* procedures roll further dice
;;; internally (Sex's "1D3+1 sexes", Armour, Natural Weapons, Special
;;; Sense, Lifespan, Physiological Advantage); those are checked with
;;; repeated trials against the valid range/set instead of an exact
;;; value, since the result is genuinely random.

(import scheme)
(import (chicken base))
(import (chicken random))
(import (chicken string))
(import srfi-13)
(import test)
(include "alien-tables.scm")
(import alien-tables)

;; Run `thunk' `n' times and assert every result satisfies `pred'.
(define (test-all-satisfy name pred thunk #!optional (n 200))
  (test-assert name
    (let loop ((i 0))
      (or (= i n)
          (and (pred (thunk)) (loop (+ i 1)))))))

(test-group "Biotype & Subtype (p. 329)"
  (test "biotype 2" "Scavenger" (biotype-name 2))
  (test "biotype 3" "Scavenger" (biotype-name 3))
  (test "biotype 4" "Herbivore" (biotype-name 4))
  (test "biotype 5" "Herbivore" (biotype-name 5))
  (test "biotype 6" "Omnivore" (biotype-name 6))
  (test "biotype 10" "Omnivore" (biotype-name 10))
  (test "biotype 11" "Carnivore" (biotype-name 11))
  (test "biotype 12" "Carnivore" (biotype-name 12))
  (test-error "biotype 1 out of range" (biotype-name 1))
  (test-error "biotype 13 out of range" (biotype-name 13))

  (test "subtype Scavenger 2" "Reducer" (subtype-name "Scavenger" 2))
  (test "subtype Scavenger 3" "Reducer" (subtype-name "Scavenger" 3))
  (test "subtype Scavenger 4" "Hijacker" (subtype-name "Scavenger" 4))
  (test "subtype Scavenger 7" "Hijacker" (subtype-name "Scavenger" 7))
  (test "subtype Scavenger 8" "Intimidator" (subtype-name "Scavenger" 8))
  (test "subtype Scavenger 9" "Intimidator" (subtype-name "Scavenger" 9))
  (test "subtype Scavenger 10" "Carrion Eater" (subtype-name "Scavenger" 10))
  (test "subtype Scavenger 12" "Carrion Eater" (subtype-name "Scavenger" 12))
  (test "subtype Herbivore 2" "Filter" (subtype-name "Herbivore" 2))
  (test "subtype Herbivore 3" "Intermittent" (subtype-name "Herbivore" 3))
  (test "subtype Herbivore 7" "Intermittent" (subtype-name "Herbivore" 7))
  (test "subtype Herbivore 8" "Grazer" (subtype-name "Herbivore" 8))
  (test "subtype Herbivore 12" "Grazer" (subtype-name "Herbivore" 12))
  (test "subtype Omnivore 2" "Gatherer" (subtype-name "Omnivore" 2))
  (test "subtype Omnivore 7" "Gatherer" (subtype-name "Omnivore" 7))
  (test "subtype Omnivore 8" "Hunter" (subtype-name "Omnivore" 8))
  (test "subtype Omnivore 10" "Hunter" (subtype-name "Omnivore" 10))
  (test "subtype Omnivore 11" "Eater" (subtype-name "Omnivore" 11))
  (test "subtype Omnivore 12" "Eater" (subtype-name "Omnivore" 12))
  (test "subtype Carnivore 2" "Pouncer" (subtype-name "Carnivore" 2))
  (test "subtype Carnivore 5" "Pouncer" (subtype-name "Carnivore" 5))
  (test "subtype Carnivore 6" "Chaser" (subtype-name "Carnivore" 6))
  (test "subtype Carnivore 8" "Chaser" (subtype-name "Carnivore" 8))
  (test "subtype Carnivore 9" "Killer" (subtype-name "Carnivore" 9))
  (test "subtype Carnivore 11" "Killer" (subtype-name "Carnivore" 11))
  (test "subtype Carnivore 12" "Siren" (subtype-name "Carnivore" 12))
  (test-error "subtype unknown biotype" (subtype-name "Robot" 5)))

(test-group "Homeworld: Starport, Government, Tech Level (p. 326)"
  (test-all-satisfy "starport Major always A"
    (lambda (roll) (string=? roll "A"))
    (lambda () (starport-name 'Major (+ 1 (pseudo-random-integer 6)))))
  (test "starport Minor 1" "X" (starport-name 'Minor 1))
  (test "starport Minor 2" "X" (starport-name 'Minor 2))
  (test "starport Minor 3" "E" (starport-name 'Minor 3))
  (test "starport Minor 4" "D" (starport-name 'Minor 4))
  (test "starport Minor 5" "C" (starport-name 'Minor 5))
  (test "starport Minor 6" "B" (starport-name 'Minor 6))
  (test-error "starport unknown key" (starport-name 'Unknown 3))

  (test "government roll 1-3 formula" '(1 6 1) (cdr (car (government-formula))))
  (test "government roll 4-6 formula" '(1 6 7) (cdr (cadr (government-formula))))
  (test-all-satisfy "government roll 1-3 in [2,7]"
    (lambda (v) (<= 2 v 7))
    (lambda () (government-formula 2)))
  (test-all-satisfy "government roll 4-6 in [8,13]"
    (lambda (v) (<= 8 v 13))
    (lambda () (government-formula 5)))

  (test-all-satisfy "tech-level Major always 10-15"
    (lambda (v) (<= 10 v 15))
    (lambda () (tech-level-formula 'Major (+ 1 (pseudo-random-integer 6)))))
  (test-all-satisfy "tech-level Minor 1-3 (Primitive) in [1,3]"
    (lambda (v) (<= 1 v 3))
    (lambda () (tech-level-formula 'Minor 2)))
  (test-all-satisfy "tech-level Minor 4-5 (Low Tech) in [4,6]"
    (lambda (v) (<= 4 v 6))
    (lambda () (tech-level-formula 'Minor 4)))
  (test-all-satisfy "tech-level Minor 6 (Mid Tech) in [7,9]"
    (lambda (v) (<= 7 v 9))
    (lambda () (tech-level-formula 'Minor 6))))

(test-group "Reproduction (p. 327)"
  (test "sex 2" "Asexual" (sex-name 2))
  (test "sex 3" "Asexual" (sex-name 3))
  (test "sex 4" "Hermaphrodite" (sex-name 4))
  (test "sex 5" "Two sexes" (sex-name 5))
  (test "sex 10" "Two sexes" (sex-name 10))
  (test "sex 11" "1D3+1 sexes" (sex-name 11))
  (test "sex 12" "1D3+1 sexes" (sex-name 12))
  (test "resolve-sex passes through non-special rolls" "Asexual" (resolve-sex 2))
  (test "resolve-sex passes through Two sexes" "Two sexes" (resolve-sex 7))
  (test-all-satisfy "resolve-sex 11-12 rolls 1D3+1 (2-4 sexes)"
    (lambda (s) (member s '("2 sexes" "3 sexes" "4 sexes")))
    (lambda () (resolve-sex (if (zero? (pseudo-random-integer 2)) 11 12))))

  (test "reproduction 1" "External budding" (reproduction-name 1))
  (test "reproduction 2" "Live-bearing" (reproduction-name 2))
  (test "reproduction 4" "Live-bearing" (reproduction-name 4))
  (test "reproduction 5" "Egg-laying" (reproduction-name 5))
  (test "reproduction 6" "Egg-laying" (reproduction-name 6)))

(test-group "Amphibious? (p. 327)"
  (test "hydrographic-band 0" 'low (hydrographic-band 0))
  (test "hydrographic-band 3" 'low (hydrographic-band 3))
  (test "hydrographic-band 4" 'medium (hydrographic-band 4))
  (test "hydrographic-band 6" 'medium (hydrographic-band 6))
  (test "hydrographic-band 7" 'high (hydrographic-band 7))
  (test "hydrographic-band 9" 'high (hydrographic-band 9))
  (test "hydrographic-band 10" 'total (hydrographic-band 10))

  (test "amphibious low 2" "Amphibious" (amphibious-name 'low 2))
  (test "amphibious low 3" "Amphibious" (amphibious-name 'low 3))
  (test "amphibious low 4" "Land-dweller" (amphibious-name 'low 4))
  (test "amphibious low 12" "Land-dweller" (amphibious-name 'low 12))
  (test "amphibious medium 2" "Aquatic" (amphibious-name 'medium 2))
  (test "amphibious medium 3" "Amphibious" (amphibious-name 'medium 3))
  (test "amphibious medium 4" "Amphibious" (amphibious-name 'medium 4))
  (test "amphibious medium 5" "Land-dweller" (amphibious-name 'medium 5))
  (test "amphibious high 2" "Aquatic" (amphibious-name 'high 2))
  (test "amphibious high 3" "Aquatic" (amphibious-name 'high 3))
  (test "amphibious high 4" "Amphibious" (amphibious-name 'high 4))
  (test "amphibious high 5" "Land-dweller" (amphibious-name 'high 5))
  (test "amphibious total 2" "Aquatic" (amphibious-name 'total 2))
  (test "amphibious total 6" "Aquatic" (amphibious-name 'total 6))
  (test "amphibious total 7" "Amphibious" (amphibious-name 'total 7))
  (test "amphibious total 12" "Amphibious" (amphibious-name 'total 12)))

(test-group "Body Form (p. 328)"
  (test "locomotion 2" "Walker" (locomotion-name 2))
  (test "locomotion 9" "Walker" (locomotion-name 9))
  (test "locomotion 10" "Flyer" (locomotion-name 10))
  (test "locomotion 11" "Flyer" (locomotion-name 11))
  (test "locomotion 12" "Triphibian" (locomotion-name 12))

  (test "symmetry 2" "Trilateral" (symmetry-name 2))
  (test "symmetry 4" "Trilateral" (symmetry-name 4))
  (test "symmetry 5" "Bilateral" (symmetry-name 5))
  (test "symmetry 9" "Bilateral" (symmetry-name 9))
  (test "symmetry 10" "Radial" (symmetry-name 10))
  (test "symmetry 12" "Radial" (symmetry-name 12))

  (test "legs 2" 2 (legs-count 2))
  (test "legs 9" 2 (legs-count 9))
  (test "legs 10" 4 (legs-count 10))
  (test "legs 11" 3 (legs-count 11))
  (test "legs 12" 6 (legs-count 12)))

(test-group "Size & Characteristics (p. 328)"
  (test "size 2" "Small" (size-name 2))
  (test "size 4" "Small" (size-name 4))
  (test "size 5" "Medium" (size-name 5))
  (test "size 9" "Medium" (size-name 9))
  (test "size 10" "Large" (size-name 10))
  (test "size 12" "Large" (size-name 12))

  (test "size-tier Small" 1 (size-tier 3))
  (test "size-tier Medium" 2 (size-tier 7))
  (test "size-tier Large" 3 (size-tier 11))
  (test "size-dex-dice Small" 3 (size-dex-dice 3))
  (test "size-dex-dice Medium" 2 (size-dex-dice 7))
  (test "size-dex-dice Large" 2 (size-dex-dice 11))

  (test "characteristic-modifier 2" -2 (characteristic-modifier 2))
  (test "characteristic-modifier 3" -1 (characteristic-modifier 3))
  (test "characteristic-modifier 5" -1 (characteristic-modifier 5))
  (test "characteristic-modifier 6" 0 (characteristic-modifier 6))
  (test "characteristic-modifier 8" 0 (characteristic-modifier 8))
  (test "characteristic-modifier 9" 1 (characteristic-modifier 9))
  (test "characteristic-modifier 11" 1 (characteristic-modifier 11))
  (test "characteristic-modifier 12" 2 (characteristic-modifier 12))

  (test "biotype-stat-modifier Carnivore Str" 2 (biotype-stat-modifier "Carnivore" 'Str))
  (test "biotype-stat-modifier Carnivore Dex" 2 (biotype-stat-modifier "Carnivore" 'Dex))
  (test "biotype-stat-modifier Carnivore End" 0 (biotype-stat-modifier "Carnivore" 'End))
  (test "biotype-stat-modifier Herbivore Str" 3 (biotype-stat-modifier "Herbivore" 'Str))
  (test "biotype-stat-modifier Herbivore Soc" 3 (biotype-stat-modifier "Herbivore" 'Soc))
  (test "biotype-stat-modifier Herbivore Dex" -2 (biotype-stat-modifier "Herbivore" 'Dex))
  (test "biotype-stat-modifier Omnivore none" 0 (biotype-stat-modifier "Omnivore" 'Str))
  (test "biotype-stat-modifier Scavenger none" 0 (biotype-stat-modifier "Scavenger" 'Dex))

  ;; The rulebook's own Ixion example (p. 330): Medium, Omnivore, with
  ;; modifiers Str -1, Dex -1, End +1, Int +2, Edu 0, Soc +1.
  (test "characteristic-formula Str (Ixion)" "2D6-1" (characteristic-formula 2 -1 0))
  (test "characteristic-formula Dex (Ixion)" "2D6-1" (characteristic-formula 2 -1 0))
  (test "characteristic-formula End (Ixion)" "2D6+1" (characteristic-formula 2 1 0))
  (test "characteristic-formula Int (Ixion)" "2D6+2" (characteristic-formula 2 2 0))
  (test "characteristic-formula Edu (Ixion)" "2D6" (characteristic-formula 2 0 0))
  (test "characteristic-formula Soc (Ixion)" "2D6+1" (characteristic-formula 2 1 0))
  ;; Carnivore/Small: Str tier 1 +2 biotype = 1D6+2; Dex 3D6+2; End 1D6+0.
  (test "characteristic-formula Carnivore Small Str" "1D6+2" (characteristic-formula 1 0 2))
  (test "characteristic-formula Carnivore Small Dex" "3D6+2" (characteristic-formula 3 0 2))
  ;; Herbivore/Large: Str tier 3 +3 biotype = 3D6+3; Dex 2D6-2; Soc 2D6+3.
  (test "characteristic-formula Herbivore Large Str" "3D6+3" (characteristic-formula 3 0 3))
  (test "characteristic-formula Herbivore Large Dex" "2D6-2" (characteristic-formula 2 0 -2))
  (test "characteristic-formula Herbivore Large Soc" "2D6+3" (characteristic-formula 2 0 3)))

(test-group "Armour & Natural Weapons (p. 328)"
  (test "armour-modifier Omnivore Medium" 0 (armour-modifier "Omnivore" "Medium"))
  (test "armour-modifier Scavenger Medium" 2 (armour-modifier "Scavenger" "Medium"))
  (test "armour-modifier Herbivore Medium" 2 (armour-modifier "Herbivore" "Medium"))
  (test "armour-modifier Omnivore Large" 4 (armour-modifier "Omnivore" "Large"))
  (test "armour-modifier Scavenger Large" 6 (armour-modifier "Scavenger" "Large"))

  (test "resolve-armour below threshold" "None" (resolve-armour 11 "Omnivore" "Medium"))
  (test-all-satisfy "resolve-armour at threshold gives Armour Value 2-4"
    (lambda (s) (member s '("Yes (Armour Value 2)" "Yes (Armour Value 3)" "Yes (Armour Value 4)")))
    (lambda () (resolve-armour 12 "Omnivore" "Medium")))

  (test "natural-weapon-modifier Carnivore" 3 (natural-weapon-modifier "Carnivore"))
  (test "natural-weapon-modifier Scavenger" 1 (natural-weapon-modifier "Scavenger"))
  (test "natural-weapon-modifier Herbivore" -2 (natural-weapon-modifier "Herbivore"))
  (test "natural-weapon-modifier Omnivore" 0 (natural-weapon-modifier "Omnivore"))

  (test "natural-weapon 2" "Hooves" (natural-weapon-name 2))
  (test "natural-weapon 4" "Hooves" (natural-weapon-name 4))
  (test "natural-weapon 5" "Horns" (natural-weapon-name 5))
  (test "natural-weapon 6" "Teeth" (natural-weapon-name 6))
  (test "natural-weapon 7" "Teeth" (natural-weapon-name 7))
  (test "natural-weapon 8" "Claws (possibly retractable)" (natural-weapon-name 8))
  (test "natural-weapon 9" "Teeth & Claws" (natural-weapon-name 9))
  (test "natural-weapon 10" "Teeth & Claws" (natural-weapon-name 10))
  (test "natural-weapon 11" "Stinger" (natural-weapon-name 11))
  (test "natural-weapon 12" "Thrasher" (natural-weapon-name 12))

  (test "resolve-natural-weapon below threshold" "Fist (no retained natural weapon)"
    (resolve-natural-weapon 5 "Omnivore"))
  (test-all-satisfy "resolve-natural-weapon at threshold gives a weapon"
    (lambda (s) (member s '("Hooves" "Horns" "Teeth" "Claws (possibly retractable)"
                             "Teeth & Claws" "Stinger" "Thrasher")))
    (lambda () (resolve-natural-weapon 9 "Omnivore"))))

(test-group "Senses (p. 328-329)"
  (test "vision 2" "Blind" (vision-name 2))
  (test "vision 3" "Colour blind" (vision-name 3))
  (test "vision 4" "Poor vision (-1)" (vision-name 4))
  (test "vision 5" "Cat's Eyes" (vision-name 5))
  (test "vision 6" "Cat's Eyes" (vision-name 6))
  (test "vision 7" "Acute vision (+2)" (vision-name 7))
  (test "vision 8" "Human-level" (vision-name 8))
  (test "vision 12" "Human-level" (vision-name 12))

  (test "audio 2" "Deaf" (audio-name 2))
  (test "audio 3" "Mute" (audio-name 3))
  (test "audio 4" "Poor hearing" (audio-name 4))
  (test "audio 5" "Poor hearing" (audio-name 5))
  (test "audio 6" "Parabolic hearing" (audio-name 6))
  (test "audio 7" "Human-level" (audio-name 7))
  (test "audio 12" "Human-level" (audio-name 12))

  (test "olfactory 2" "No ability" (olfactory-name 2))
  (test "olfactory 3" "No ability" (olfactory-name 3))
  (test "olfactory 4" "Poor ability (-2)" (olfactory-name 4))
  (test "olfactory 5" "Poor ability (-2)" (olfactory-name 5))
  (test "olfactory 6" "Acute ability (+2)" (olfactory-name 6))
  (test "olfactory 7" "Human-level" (olfactory-name 7))
  (test "olfactory 11" "Human-level" (olfactory-name 11))
  (test "olfactory 12" "Pheromone Sense" (olfactory-name 12))

  (test "special-sense 1" "Radio transmission sensing" (special-sense-name 1))
  (test "special-sense 2" "Vibration sensing" (special-sense-name 2))
  (test "special-sense 3" "Echo location" (special-sense-name 3))
  (test "special-sense 4" "Uncanny prescience (\"intuition\")" (special-sense-name 4))
  (test "special-sense 5" "Thermal vision" (special-sense-name 5))
  (test "special-sense 6" "Telepathy" (special-sense-name 6))

  (test "resolve-special-sense below threshold" "None" (resolve-special-sense 10))
  (test-all-satisfy "resolve-special-sense at threshold gives a sense"
    (lambda (s) (member s '("Radio transmission sensing" "Vibration sensing" "Echo location"
                             "Uncanny prescience (\"intuition\")" "Thermal vision" "Telepathy")))
    (lambda () (resolve-special-sense 11))))

(test-group "Life Cycle (p. 329)"
  (test "lifespan 5" "Short (40 years)" (lifespan-name 5))
  (test "lifespan 6" "Human-level (80 years)" (lifespan-name 6))
  (test "lifespan 7" "Human-level (80 years)" (lifespan-name 7))
  (test "lifespan 8" "Long (200 years)" (lifespan-name 8))
  (test "lifespan 10" "Long (200 years)" (lifespan-name 10))
  (test "lifespan 11" "Very Long (1000 years)" (lifespan-name 11))
  (test "lifespan 12" "Immortal?" (lifespan-name 12))

  (test "resolve-lifespan passes through non-special rolls" "Short (40 years)" (resolve-lifespan 5))
  (test "resolve-lifespan passes through Immortal" "Immortal?" (resolve-lifespan 12))
  (test-all-satisfy "resolve-lifespan 2-4 rolls 2D6 years"
    (lambda (s)
      (and (string-prefix? "Very Short (" s)
           (string-suffix? " years)" s)))
    (lambda () (resolve-lifespan 3)))

  (test "physiological-advantage 1" "Regeneration" (physiological-advantage-name 1))
  (test "physiological-advantage 2" "Poison Immunity" (physiological-advantage-name 2))
  (test "physiological-advantage 3" "Metabolic Accelerator" (physiological-advantage-name 3))
  (test "physiological-advantage 4" "Metabolic Decelerator" (physiological-advantage-name 4))
  (test "physiological-advantage 5" "Transmorph" (physiological-advantage-name 5))
  (test "physiological-advantage 6" "High Pain Threshold" (physiological-advantage-name 6))

  (test "resolve-physiological-advantage below threshold" "None" (resolve-physiological-advantage 8))
  (test-all-satisfy "resolve-physiological-advantage at threshold gives an advantage"
    (lambda (s) (member s '("Regeneration" "Poison Immunity" "Metabolic Accelerator"
                             "Metabolic Decelerator" "Transmorph" "High Pain Threshold")))
    (lambda () (resolve-physiological-advantage 9))))

(test-exit)
