;;; system-tables.scm -- Rules tables for Cepheus Universal System
;;; Generation (pp. 303-307), factored out of cu-systems.scm so they can
;;; be unit-tested independently of the web front-end (see
;;; test-system-tables.scm).

(module system-tables
  (D nD
   roll-num-bodies
   roll-star-count star-count-name star-count-number
   companion-orbits
   roll-mainworld-orbit resolve-mainworld-orbit
   mainworld-type-name mainworld-full-uwp?
   roll-gas-giant-count
   place-gas-giants
   asteroid-belt-roll?
   inner-planet-type outer-planet-type
   rock-size rock-atmosphere rock-hydrographics rock-temperature
   hellhole-atmosphere hellhole-hydrographics hellhole-temperature
   iceball-size iceball-atmosphere
   desert-atmosphere desert-temperature
   greek-letter-name
   generate-system)

(import scheme)
(import (chicken base))
(import (chicken random))
(import (math base))
(import loop)
(import srfi-1)
(import (prefix worlds-tables wt-))

(include "roll-tables.scm")

(define (D num-sides) (+ 1 (pseudo-random-integer num-sides)))
(define (nD num-dice num-sides)
  (sum (loop repeat num-dice collect (D num-sides))))

;; -------------------------------------------------------------------
;; Orbits & Planets, Other Stars; Cepheus Universal p. 303.

;; Number of planetary bodies (not counting the central star itself,
;; which is Orbit 0 and never numbered among them).
(define (roll-num-bodies) (+ 2 (nD 2 6)))

(define-roll-table (star-count-name roll)
  ((2 . 8) "Single")
  ((9 . 10) "Binary")
  ((11 . 12) "Trinary"))

(define (roll-star-count) (nD 2 6))

(define (star-count-number name)
  (cond ((string=? name "Single") 1)
        ((string=? name "Binary") 2)
        ((string=? name "Trinary") 3)
        (else (error 'star-count-number "unknown star count" name))))

;; Where companion stars sit, given a 1D6 placement roll. Orbit 1
;; displaces what would otherwise be a planetary body (it counts
;; against num-bodies); the orbit(s) "beyond the system's furthermost
;; planetary body" are additional orbits past num-bodies and don't.
;; Returns a list of the orbit number(s) occupied by companions (in
;; star-count order: star 2, then star 3), for star-count 2 or 3 --
;; the empty list for star-count 1 (no companions to place).
(define (companion-orbits star-count num-bodies placement-roll)
  (let ((beyond (+ num-bodies 1)))
    (cond
      ((= star-count 1) '())
      ((= star-count 2)
       (if (odd? placement-roll) (list 1) (list beyond)))
      ((= star-count 3)
       (if (odd? placement-roll)
           (list 1 beyond)
           (list beyond (+ beyond 1))))
      (else (error 'companion-orbits "star-count must be 1, 2 or 3" star-count)))))

;; -------------------------------------------------------------------
;; Mainworld Orbit & Type; Cepheus Universal pp. 303-304. The
;; mainworld's full profile is assumed already known (Creating Worlds,
;; pp. 281-302) when its type is Garden World or Waterworld -- there is
;; no Planetary Details row for either, so cu-systems.scm rolls a full
;; Creating Worlds UWP for those. Rock, Hellhole and Desert World
;; mainworlds instead use the (coarser) Planetary Details table below,
;; with Temperature forced to Temperate regardless of orbit.

(define (roll-mainworld-orbit) (+ 2 (D 3)))

;; A companion star's "beyond the furthest planetary body" orbit
;; (companion-orbits, above) is fixed before the mainworld orbit is
;; even rolled, so the two can coincide when num-bodies is small --
;; another case the book doesn't address. Resolved the same way a gas
;; giant landing on an occupied orbit is (p. 303): shift outward one
;; orbit at a time until free.
(define (resolve-mainworld-orbit mainworld-orbit star-orbits)
  (if (memv mainworld-orbit star-orbits)
      (resolve-mainworld-orbit (+ mainworld-orbit 1) star-orbits)
      mainworld-orbit))

(define-roll-table (mainworld-type-name roll)
  ((2 . 5) "Rock")
  ((6) "Hellhole")
  ((7) "Desert World")
  ((8 . 11) "Garden World")
  ((12) "Waterworld"))

(define (mainworld-full-uwp? type)
  (or (string=? type "Garden World") (string=? type "Waterworld")))

;; -------------------------------------------------------------------
;; Gas Giants; Cepheus Universal pp. 303-304. Presence itself is the
;; same 2D6, 5+ roll as Creating Worlds' gas-giant-present? (p. 297) --
;; System Generation assumes that roll already made for the mainworld's
;; system, so cu-systems.scm reuses wt-gas-giant-present? rather than
;; duplicating it here.

;; Rolls 1D6 for the initial gas giant count; a roll of 6 is rerolled,
;; and one of the resulting gas giants becomes a 'hot Jupiter' in
;; Orbit 1. Returns (count . hot-jupiter?).
(define (roll-gas-giant-count)
  (let ((first (D 6)))
    (if (= first 6)
        (cons (D 6) #t)
        (cons first #f))))

;; Places `count' non-hot-Jupiter gas giants by rolling 1D6 each and
;; counting out from the mainworld orbit (a roll of 1 means the
;; mainworld's own orbit). An orbit already in `occupied', or past
;; num-bodies (the system's fixed total planetary-body count, p. 303),
;; cancels that attempt -- the gas giant is simply not placed, no
;; retry. Landing exactly on the mainworld orbit triggers a further
;; 1D6: 4-6 means the mainworld becomes a moon of that gas giant
;; instead of keeping a separate orbit; 1-3 shifts the gas giant one
;; orbit further out (cancelled too, if that orbit is occupied or past
;; num-bodies).
;;
;; Returns (values placed-orbits mainworld-moon-orbit), where
;; placed-orbits is the list of orbits gas giants actually ended up in
;; (excluding a mainworld-moon placement, which isn't a separate
;; orbit), and mainworld-moon-orbit is the gas giant's orbit if the
;; mainworld became its moon, or #f otherwise.
(define (place-gas-giants count mainworld-orbit num-bodies occupied)
  (let loop ((n count) (occupied occupied) (placed '()) (moon-of #f))
    (if (= n 0)
        (values (reverse placed) moon-of)
        (let* ((roll (D 6))
               (target (+ mainworld-orbit (- roll 1))))
          (cond
            ((or (> target num-bodies) (memv target occupied))
             (loop (- n 1) occupied placed moon-of))
            ((and (= target mainworld-orbit) (not moon-of))
             (if (<= 4 (D 6) 6)
                 (loop (- n 1) (cons target occupied) placed target)
                 (let ((next (+ target 1)))
                   (if (or (> next num-bodies) (memv next occupied))
                       (loop (- n 1) occupied placed moon-of)
                       (loop (- n 1) (cons next occupied) (cons next placed) moon-of)))))
            (else
             (loop (- n 1) (cons target occupied) (cons target placed) moon-of)))))))

;; -------------------------------------------------------------------
;; Asteroid Belts; Cepheus Universal p. 304.
(define (asteroid-belt-roll? roll) (= roll 6))

;; -------------------------------------------------------------------
;; Other Planetary Types; Cepheus Universal p. 304.
(define-roll-table (inner-planet-type roll)
  ((2 . 8) "Rock")
  ((9 . 10) "Hellhole")
  ((11 . 12) "Desert"))

(define-roll-table (outer-planet-type roll)
  ((2 . 10) "Iceball")
  ((11 . 12) "Hellhole"))

;; -------------------------------------------------------------------
;; Planetary Details; Cepheus Universal p. 304. Cells marked "*" in the
;; book defer to the named Creating Worlds table (wt-roll-world-size et
;; al); Hellhole's Atmosphere ("A, B or C") is Exotic/Corrosive/
;; Insidious -- Creating Worlds digits 10-12 -- so it's expressed the
;; same way. Hydrographics here uses the coarse bands the book actually
;; gives (e.g. "10-20%") rather than forcing a Creating Worlds digit,
;; since those bands don't map to a single digit.

(define (rock-size) (if (<= (D 6) 4) 0 (D 2)))

;; +1 DM if Planetoid (Size 0).
(define (rock-atmosphere size)
  (let ((roll (+ (D 6) (if (= size 0) 1 0))))
    (if (<= roll 4) 1 3)))  ; 1: Trace: 3: Very Thin

;; +1 DM if Very Thin atmosphere (digit 3).
(define (rock-hydrographics atmosphere)
  (let ((roll (+ (D 6) (if (= atmosphere 3) 1 0))))
    (if (<= roll 6) "None" "10%-20%")))

(define (rock-temperature orbit mainworld-orbit)
  (cond ((= orbit mainworld-orbit) "Temperate")
        ((<= orbit 2) "Inferno")
        (else "Hot")))

;; Hellhole Atmosphere is always A, B or C (digits 10-12) with no
;; further weighting given in the book, so this picks uniformly.
(define (hellhole-atmosphere) (+ 9 (D 3)))

(define (hellhole-hydrographics)
  (let ((roll (D 6)))
    (cond ((<= roll 3) "None")
          ((<= roll 5) "10%-20%")
          (else "30%-80%"))))

(define (hellhole-temperature)
  (if (<= (D 6) 3) "Frozen" "Inferno"))

(define (iceball-size) (if (<= (D 6) 4) 0 (D 2)))

(define (iceball-atmosphere)
  (if (<= (D 6) 3) 1 3))  ; 1: Trace; 3: Very Thin

(define (desert-atmosphere)
  (let ((roll (D 6)))
    (cond ((<= roll 2) 3)   ; Very Thin
          ((= roll 3) 5)    ; Thin
          ((<= roll 5) 6)   ; Standard
          (else 8))))       ; Dense

(define (desert-temperature)
  (if (<= (D 6) 2) "Cold" "Hot"))

;; -------------------------------------------------------------------
;; Naming Planets; Cepheus Universal p. 305. Orbit 1 is Alpha, counting
;; up through the Greek alphabet (skipping no letters) to Omega at 24 --
;; comfortably past the highest possible orbit count in this system
;; (14 planetary bodies plus up to 2 outlying companion stars).
(define-roll-table (greek-letter-name n)
  ((1) "Alpha") ((2) "Beta") ((3) "Gamma") ((4) "Delta") ((5) "Epsilon")
  ((6) "Zeta") ((7) "Eta") ((8) "Theta") ((9) "Iota") ((10) "Kappa")
  ((11) "Lamda") ((12) "Mu") ((13) "Nu") ((14) "Xi") ((15) "Omicron")
  ((16) "Pi") ((17) "Rho") ((18) "Sigma") ((19) "Tau") ((20) "Upsilon")
  ((21) "Phi") ((22) "Chi") ((23) "Psi") ((24) "Omega"))

;; Puts the rest of the system together once the mainworld is known:
;; gas giants, asteroid belts, and minor planets (Rock/Hellhole/
;; Iceball/Desert) for every orbit not already spoken for by a
;; companion star or the mainworld. Returns a list of (orbit .
;; body-plist) pairs, where body-plist is one of:
;;   (star)                                  -- a companion star
;;   (mainworld)                             -- the mainworld's own orbit
;;   (gas-giant hot-jupiter?)
;;   (asteroid-belt)
;;   (minor-planet type size atmosphere hydrographics temperature)
;; plus a final (moon-of . orbit-or-#f): if the mainworld ended up a
;; moon of a gas giant, that gas giant's orbit rather than #f -- in
;; that case the mainworld does not get its own separate orbit entry
;; above, since it no longer has one.
;;
;; If a hot Jupiter is rolled but Orbit 1 is already a companion star,
;; the book doesn't say what happens; here it's simply treated as one
;; more ordinary gas giant to place normally, rather than lost.
;;
;; num-bodies (2D6+2, range 4-14) and mainworld-orbit (1D3+2, range
;; 3-5) are independent rolls, so mainworld-orbit can occasionally
;; exceed a minimum num-bodies -- widened here to fit the mainworld
;; rather than leaving it without a valid orbit, a case the book
;; doesn't address.
(define (generate-system num-bodies star-orbits mainworld-orbit)
  (let* ((num-bodies (max num-bodies mainworld-orbit))
         (gas-giant-roll (roll-gas-giant-count))
         (gg-count (car gas-giant-roll))
         (hot-jupiter? (and (cdr gas-giant-roll) (not (memv 1 star-orbits))))
         (occupied-before-gg (append star-orbits (list mainworld-orbit)
                                      (if hot-jupiter? (list 1) '())))
         (other-gg-count (if hot-jupiter? (- gg-count 1) gg-count)))
    (call-with-values
      (lambda () (place-gas-giants (max 0 other-gg-count) mainworld-orbit num-bodies occupied-before-gg))
      (lambda (gg-orbits moon-of)
        (let* ((occupied (append occupied-before-gg gg-orbits))
               (remaining (filter (lambda (o) (not (memv o occupied)))
                                   (iota num-bodies 1))))
          (let loop ((orbits remaining) (result '()))
            (if (null? orbits)
                (list
                  (cons 'bodies
                        (append
                          (map (lambda (o) (cons o (list 'star))) star-orbits)
                          (if moon-of '() (list (cons mainworld-orbit (list 'mainworld))))
                          (if hot-jupiter? (list (cons 1 (list 'gas-giant #t))) '())
                          (map (lambda (o) (cons o (list 'gas-giant #f))) gg-orbits)
                          result))
                  (cons 'moon-of moon-of))
                (let ((o (car orbits)))
                  (if (asteroid-belt-roll? (D 6))
                      (loop (cdr orbits) (cons (cons o (list 'asteroid-belt)) result))
                      (let* ((inner? (< o mainworld-orbit))
                             (type (if inner? (inner-planet-type (nD 2 6)) (outer-planet-type (nD 2 6)))))
                        (loop (cdr orbits)
                              (cons (cons o (minor-planet-body type o mainworld-orbit)) result))))))))))))

;; Builds a (minor-planet ...) body-plist for one minor planet.
(define (minor-planet-body type orbit mainworld-orbit)
  (cond
    ((string=? type "Rock")
     (let* ((size (rock-size))
            (atmosphere (rock-atmosphere size))
            (hydrographics (rock-hydrographics atmosphere))
            (temperature (rock-temperature orbit mainworld-orbit)))
       (list 'minor-planet type size atmosphere hydrographics temperature)))
    ((string=? type "Hellhole")
     (let* ((size (wt-roll-world-size))
            (atmosphere (hellhole-atmosphere))
            (hydrographics (hellhole-hydrographics))
            (temperature (hellhole-temperature)))
       (list 'minor-planet type size atmosphere hydrographics temperature)))
    ((string=? type "Iceball")
     (let* ((size (iceball-size))
            (atmosphere (iceball-atmosphere)))
       (list 'minor-planet type size atmosphere "None" "Frozen")))
    ((string=? type "Desert")
     (let* ((size (wt-roll-world-size))
            (atmosphere (desert-atmosphere))
            (temperature (desert-temperature)))
       (list 'minor-planet type size atmosphere "None" temperature)))
    (else (error 'minor-planet-body "unknown minor planet type" type))))

)
