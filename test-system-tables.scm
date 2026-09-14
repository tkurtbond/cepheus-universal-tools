;;; test-system-tables.scm -- Unit tests for system-tables.scm, the rules
;;; tables behind cu-systems.scm's System Generation wizard (Cepheus
;;; Universal pp. 303-307).
;;;
;;; Run with: csi -s test-system-tables.scm
;;;
;;; The name/descriptor tables (star-count-name, mainworld-type-name,
;;; greek-letter-name, inner-planet-type, outer-planet-type) take an
;;; explicit digit and return a deterministic result, so those are
;;; plain expected-value testing. Everything that rolls dice internally
;;; (roll-num-bodies, roll-mainworld-orbit, roll-gas-giant-count,
;;; place-gas-giants, the rock/hellhole/iceball/desert sub-rolls,
;;; generate-system) is checked with repeated trials against the valid
;;; range/invariants instead. companion-orbits and
;;; resolve-mainworld-orbit take their die roll as an explicit
;;; argument, so those get exact expected-value tests too.

(import scheme)
(import (chicken base))
(import (chicken random))
(import (chicken string))
(import (chicken sort))
(import (math base))
(import loop)
(import srfi-1)
(import srfi-13)
(import test)
(include "roll-tables.scm")
(include "worlds-tables.scm")
(import worlds-tables)
(include "system-tables.scm")
(import system-tables)

;; Run `thunk' `n' times and assert every result satisfies `pred'.
(define (test-all-satisfy name pred thunk #!optional (n 200))
  (test-assert name
    (let loop ((i 0))
      (or (= i n)
          (and (pred (thunk)) (loop (+ i 1)))))))

(test-group "Orbits & Other Stars (p. 303)"
  (test-all-satisfy "roll-num-bodies stays in 4-14"
    (lambda (v) (<= 4 v 14))
    roll-num-bodies)
  (test "star-count-name 2" "Single" (star-count-name 2))
  (test "star-count-name 8" "Single" (star-count-name 8))
  (test "star-count-name 9" "Binary" (star-count-name 9))
  (test "star-count-name 10" "Binary" (star-count-name 10))
  (test "star-count-name 11" "Trinary" (star-count-name 11))
  (test "star-count-name 12" "Trinary" (star-count-name 12))
  (test "star-count-number Single" 1 (star-count-number "Single"))
  (test "star-count-number Binary" 2 (star-count-number "Binary"))
  (test "star-count-number Trinary" 3 (star-count-number "Trinary"))
  (test "companion-orbits single has none" '() (companion-orbits 1 6 3))
  (test "companion-orbits binary odd takes Orbit 1" '(1) (companion-orbits 2 6 1))
  (test "companion-orbits binary even takes the outermost orbit" '(7) (companion-orbits 2 6 2))
  (test "companion-orbits trinary odd: Orbit 1 + outermost" '(1 7) (companion-orbits 3 6 1))
  (test "companion-orbits trinary even: two outermost orbits" '(7 8) (companion-orbits 3 6 2)))

(test-group "Mainworld Orbit & Type (pp. 303-304)"
  (test-all-satisfy "roll-mainworld-orbit stays in 3-5"
    (lambda (v) (<= 3 v 5))
    roll-mainworld-orbit)
  (test "resolve-mainworld-orbit unaffected when free" 3 (resolve-mainworld-orbit 3 '(1)))
  (test "resolve-mainworld-orbit shifts off one collision" 6 (resolve-mainworld-orbit 5 '(5)))
  (test "resolve-mainworld-orbit shifts off consecutive collisions" 7 (resolve-mainworld-orbit 5 '(5 6)))
  (test "mainworld-type-name 2" "Rock" (mainworld-type-name 2))
  (test "mainworld-type-name 5" "Rock" (mainworld-type-name 5))
  (test "mainworld-type-name 6" "Hellhole" (mainworld-type-name 6))
  (test "mainworld-type-name 7" "Desert World" (mainworld-type-name 7))
  (test "mainworld-type-name 8" "Garden World" (mainworld-type-name 8))
  (test "mainworld-type-name 11" "Garden World" (mainworld-type-name 11))
  (test "mainworld-type-name 12" "Waterworld" (mainworld-type-name 12))
  (test-assert "mainworld-full-uwp? Garden World" (mainworld-full-uwp? "Garden World"))
  (test-assert "mainworld-full-uwp? Waterworld" (mainworld-full-uwp? "Waterworld"))
  (test-assert "mainworld-full-uwp? Rock is false" (not (mainworld-full-uwp? "Rock")))
  (test-assert "mainworld-full-uwp? Hellhole is false" (not (mainworld-full-uwp? "Hellhole")))
  (test-assert "mainworld-full-uwp? Desert World is false" (not (mainworld-full-uwp? "Desert World"))))

(test-group "Gas Giants (pp. 303-304)"
  (test-all-satisfy "roll-gas-giant-count count stays in 1-6"
    (lambda (r) (<= 1 (car r) 6))
    roll-gas-giant-count)
  (test-assert "roll-gas-giant-count: a 6 always rerolls (hot-jupiter? #t iff first roll was 6)"
    (let loop ((i 0))
      (or (= i 500)
          (let ((r (roll-gas-giant-count)))
            (and (or (cdr r) (< (car r) 6))  ; a non-rerolled 6 would be indistinguishable, but the reroll itself is 1-6 too
                 (loop (+ i 1)))))))
  (test-assert "place-gas-giants never exceeds num-bodies or collides"
    (let loop ((i 0))
      (or (= i 500)
          (let*-values (((num-bodies) (+ 4 (nD 2 6)))
                        ((mw-orbit) (min num-bodies (+ 2 (D 3))))
                        ((orbits moon-of) (place-gas-giants (D 6) mw-orbit num-bodies (list mw-orbit))))
            (and (every (lambda (o) (<= 1 o num-bodies)) orbits)
                 (= (length orbits) (length (delete-duplicates orbits)))
                 (loop (+ i 1))))))))

(test-group "Asteroid Belts (p. 304)"
  (test-assert "asteroid-belt-roll? true only on 6"
    (and (asteroid-belt-roll? 6)
         (not (asteroid-belt-roll? 1))
         (not (asteroid-belt-roll? 5)))))

(test-group "Other Planetary Types (p. 304)"
  (test "inner-planet-type 2" "Rock" (inner-planet-type 2))
  (test "inner-planet-type 8" "Rock" (inner-planet-type 8))
  (test "inner-planet-type 9" "Hellhole" (inner-planet-type 9))
  (test "inner-planet-type 10" "Hellhole" (inner-planet-type 10))
  (test "inner-planet-type 11" "Desert" (inner-planet-type 11))
  (test "inner-planet-type 12" "Desert" (inner-planet-type 12))
  (test "outer-planet-type 2" "Iceball" (outer-planet-type 2))
  (test "outer-planet-type 10" "Iceball" (outer-planet-type 10))
  (test "outer-planet-type 11" "Hellhole" (outer-planet-type 11))
  (test "outer-planet-type 12" "Hellhole" (outer-planet-type 12)))

(test-group "Planetary Details (p. 304)"
  (test-all-satisfy "rock-size stays in {0,1,2}" (lambda (v) (memv v '(0 1 2))) rock-size)
  (test-all-satisfy "rock-atmosphere stays in {1,3}" (lambda (v) (memv v '(1 3))) (lambda () (rock-atmosphere 0)))
  (test-all-satisfy "rock-hydrographics stays in {None,10%-20%}"
    (lambda (v) (member v '("None" "10%-20%"))) (lambda () (rock-hydrographics 3)))
  (test "rock-temperature Orbit 1 is Inferno (not the mainworld)" "Inferno" (rock-temperature 1 4))
  (test "rock-temperature Orbit 2 is Inferno (not the mainworld)" "Inferno" (rock-temperature 2 4))
  (test "rock-temperature other inner orbit is Hot" "Hot" (rock-temperature 3 4))
  (test "rock-temperature at the mainworld's own orbit is Temperate" "Temperate" (rock-temperature 4 4))
  (test-all-satisfy "hellhole-atmosphere stays in {10,11,12} (A, B or C)"
    (lambda (v) (memv v '(10 11 12))) hellhole-atmosphere)
  (test-all-satisfy "hellhole-hydrographics stays in {None,10%-20%,30%-80%}"
    (lambda (v) (member v '("None" "10%-20%" "30%-80%"))) hellhole-hydrographics)
  (test-all-satisfy "hellhole-temperature stays in {Frozen,Inferno}"
    (lambda (v) (member v '("Frozen" "Inferno"))) hellhole-temperature)
  (test-all-satisfy "iceball-size stays in {0,1,2}" (lambda (v) (memv v '(0 1 2))) iceball-size)
  (test-all-satisfy "iceball-atmosphere stays in {1,3}" (lambda (v) (memv v '(1 3))) iceball-atmosphere)
  (test-all-satisfy "desert-atmosphere stays in {3,5,6,8}" (lambda (v) (memv v '(3 5 6 8))) desert-atmosphere)
  (test-all-satisfy "desert-temperature stays in {Cold,Hot}"
    (lambda (v) (member v '("Cold" "Hot"))) desert-temperature))

(test-group "Naming Planets (p. 305)"
  (test "greek-letter-name 1" "Alpha" (greek-letter-name 1))
  (test "greek-letter-name 5" "Epsilon" (greek-letter-name 5))
  (test "greek-letter-name 12" "Mu" (greek-letter-name 12))
  (test "greek-letter-name 24" "Omega" (greek-letter-name 24))
  (test-error "greek-letter-name 25 out of range" (greek-letter-name 25)))

;; generate-system ties every table above together; these are
;; structural invariants (no roll-by-roll expected values, since the
;; book's own worked examples don't state their intermediate rolls),
;; checked over many random systems: no orbit is used twice, and no
;; gas giant/asteroid belt/minor planet orbit falls outside 1..num-bodies
;; (mainworld-orbit may occasionally widen that range -- see
;; generate-system's own comment).
(test-group "generate-system (pp. 303-305)"
  (test-assert "no orbit is ever assigned twice, across 1000 random systems"
    (let loop ((i 0))
      (or (= i 1000)
          (let* ((num-bodies (roll-num-bodies))
                 (star-count (star-count-number (star-count-name (roll-star-count))))
                 (star-orbits (if (> star-count 1) (companion-orbits star-count num-bodies (D 6)) '()))
                 (mw-orbit (resolve-mainworld-orbit (roll-mainworld-orbit) star-orbits))
                 (result (generate-system num-bodies star-orbits mw-orbit))
                 (bodies (cdr (assq 'bodies result)))
                 (orbits (map car bodies)))
            (and (= (length orbits) (length (delete-duplicates orbits)))
                 (loop (+ i 1)))))))
  (test-assert "no gas giant/asteroid belt/minor planet orbit exceeds num-bodies, across 1000 random systems"
    (let loop ((i 0))
      (or (= i 1000)
          (let* ((num-bodies0 (roll-num-bodies))
                 (star-count (star-count-number (star-count-name (roll-star-count))))
                 (star-orbits (if (> star-count 1) (companion-orbits star-count num-bodies0 (D 6)) '()))
                 (mw-orbit (resolve-mainworld-orbit (roll-mainworld-orbit) star-orbits))
                 (num-bodies (max num-bodies0 mw-orbit))
                 (result (generate-system num-bodies0 star-orbits mw-orbit))
                 (bodies (cdr (assq 'bodies result))))
            (and (every (lambda (entry) (or (eq? (cadr entry) 'star) (<= 1 (car entry) num-bodies))) bodies)
                 (loop (+ i 1))))))))

(test-exit)
