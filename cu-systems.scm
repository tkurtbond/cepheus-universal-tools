;;; cu-systems.scm -- Cepheus Universal System Generation.
;;; Populates the rest of a star system around an existing mainworld.
;;;
;;; awful --port=8103 cu-systems.scm
(include "worlds-tables.scm")
(include "system-tables.scm")

(module cu-systems (run)

(import scheme)
(import (chicken base))
(import (chicken random))
(import (chicken sort))
(import (math base))
(import loop)
(import srfi-1)
(import srfi-13)
(import (only (chicken format) sprintf))
(import (only (chicken string) string-translate*))
(import awful)
(import (prefix worlds-tables wt-))
(import system-tables)

(include "roll-tables.scm")

;; A two-column "story so far" summary table: labels right-aligned in
;; the left column, results left-aligned in the right column, so the
;; running list of resolved characteristics stays tidy as it grows
;; longer with each page.
(define (story-row label . content)
  `(tr (td (@ (style "text-align:right; padding-right:0.5em")) ,(string-append label ":"))
       (td (@ (style "text-align:left")) ,@content)))

(define (story-table . rows)
  `(table (@ (style "border-collapse:collapse")) ,@rows))

;; Escapes literal "|" so a field's text can't be mistaken for a
;; Markdown pipe-table cell boundary.
(define (md-escape s) (string-translate* s '(("|" . "\\|"))))

;; Builds a (label . value-string) pair for one "story so far" field,
;; mirroring story-row's label/content shape so the Markdown export
;; tracks the HTML story table field-for-field. Content pieces are
;; stringified the same way SXML rendering would display them (numbers,
;; symbols, etc.). Shared by md-table-rows and md-bullet-rows below, so
;; the two Markdown export styles always show the same fields.
(define (md-field label . content)
  (cons label (apply string-append (map (lambda (x) (sprintf "~A" x)) content))))

;; Renders a list of md-field pairs as a GFM pipe table, with alignment
;; markers (---:/: ---) that right-align the Field column and
;; left-align the Value column -- the same layout story-row gives the
;; HTML table.
(define (md-table-rows fields)
  (string-append
    "| Field | Value |\n|---:|:---|\n"
    (apply string-append
      (map (lambda (f) (sprintf "| **~A** | ~A |\n" (md-escape (car f)) (md-escape (cdr f))))
        fields))))

;; Renders a list of md-field pairs as a plain "- **Label:** value"
;; bullet list, for a Markdown export without a table.
(define (md-bullet-rows fields)
  (apply string-append
    (map (lambda (f) (sprintf "- **~A:** ~A\n" (car f) (cdr f))) fields)))

;; -------------------------------------------------------------------
;; Presentation helpers shared across pages -- pure functions, no
;; session access, so they're equally usable from the HTML result page
;; and the Markdown export pages.

;; A planetary body's name: "<hex> <Greek letter>" for a numbered
;; orbit (Cepheus Universal p. 305), or plain "Star" for Orbit 0, the
;; primary.
(define (orbit-body-name hex orbit)
  (if (= orbit 0)
      "Star"
      (string-append hex " " (greek-letter-name orbit))))

;; One-line description of a minor planet's Planetary Details roll.
(define (minor-planet-description body)
  (let ((type (list-ref body 1))
        (size (list-ref body 2))
        (atmosphere (list-ref body 3))
        (hydrographics (list-ref body 4))
        (temperature (list-ref body 5)))
    (sprintf "~A -- Size ~A (~A), Atmosphere ~A (~A), Hydrographics: ~A, Temperature: ~A"
      type (uwp-char size) (wt-size-name size) (uwp-char atmosphere) (wt-atmosphere-name atmosphere)
      hydrographics temperature)))

;; One-line "Notes" cell for a single orbit entry, mirroring the
;; rulebook's own worked example layout (Orbit/Body/Notes, p. 305).
;; mainworld-profile is either a full UWP + type string (Garden
;; World/Waterworld) or #f (Rock/Hellhole/Desert World, whose
;; Planetary Details are summarised directly here instead).
(define (orbit-notes body mainworld-type mainworld-profile mw-size mw-atmosphere mw-hydrographics)
  (let ((kind (car body)))
    (cond
      ((eq? kind 'primary-star) "")
      ((eq? kind 'star) "Companion Star")
      ((eq? kind 'mainworld)
       (if mainworld-profile
           (sprintf "Mainworld ~A" mainworld-profile)
           (sprintf "Mainworld, ~A -- Size ~A (~A), Atmosphere ~A (~A), Hydrographics: ~A, Temperature: Temperate"
             mainworld-type (uwp-char mw-size) (wt-size-name mw-size)
             (uwp-char mw-atmosphere) (wt-atmosphere-name mw-atmosphere) mw-hydrographics)))
      ((eq? kind 'gas-giant) (if (cadr body) "Hot Jupiter" "Gas Giant"))
      ((eq? kind 'asteroid-belt) "Asteroid Belt")
      ((eq? kind 'minor-planet) (minor-planet-description body))
      (else (error 'orbit-notes "unknown body kind" kind)))))

;; Every orbit as a (orbit body-name notes) triple, Orbit 0 (the
;; primary star) first, then every other orbit in ascending order.
(define (system-rows hex bodies mainworld-type mainworld-profile mw-size mw-atmosphere mw-hydrographics moon-of)
  (map
    (lambda (entry)
      (let* ((orbit (car entry))
             (body (cdr entry))
             (notes (orbit-notes body mainworld-type mainworld-profile mw-size mw-atmosphere mw-hydrographics))
             (notes (if (and moon-of (= orbit moon-of))
                        (string-append notes " -- the mainworld orbits this gas giant as a moon")
                        notes)))
        (list orbit (orbit-body-name hex orbit) notes)))
    (cons (cons 0 (list 'primary-star))
          (sort bodies (lambda (a b) (< (car a) (car b)))))))

;; -------------------------------------------------------------------
;; Session data gathering. Every field here was already resolved (and
;; $session-set!) by an earlier page (including bodies/moon-of, stored
;; once by finish-system! the first time the system is generated, so
;; revisiting or exporting it later reproduces the same system rather
;; than rerolling it). Shared by the HTML result page and both
;; Markdown export pages so all three always agree.
(define (system-data)
  (let* ((mainworld-type ($session 'mainworld-type))
         (full-uwp? (mainworld-full-uwp? mainworld-type))
         (mw-size (and (not full-uwp?) ($session 'mw-size)))
         (mw-atmosphere (and (not full-uwp?) ($session 'mw-atmosphere)))
         (mw-hydrographics (and (not full-uwp?) ($session 'mw-hydrographics)))
         (mainworld-profile
          (and full-uwp?
               (sprintf "~A, ~A"
                 (wt-uwp-line ($session 'starport) ($session 'world-size) ($session 'atmosphere)
                              ($session 'hydrographics) ($session 'population) ($session 'government)
                              ($session 'law-level) ($session 'tech-level))
                 mainworld-type))))
    (list
      (cons 'system-name ($session 'system-name))
      (cons 'hex ($session 'hex))
      (cons 'num-bodies ($session 'num-bodies))
      (cons 'star-count-name ($session 'star-count-name))
      (cons 'star-orbits ($session 'star-orbits))
      (cons 'mainworld-orbit ($session 'mainworld-orbit))
      (cons 'mainworld-type mainworld-type)
      (cons 'mainworld-profile mainworld-profile)
      (cons 'mw-size mw-size)
      (cons 'mw-atmosphere mw-atmosphere)
      (cons 'mw-hydrographics mw-hydrographics)
      (cons 'bodies ($session 'bodies))
      (cons 'moon-of ($session 'moon-of)))))

(define (data-ref data key) (cdr (assq key data)))

;; -------------------------------------------------------------------
;; Registers all pages for this app. Called explicitly at the bottom
;; of this module for the interpreted `awful cu-systems.scm` dev
;; workflow, and again by the compiled awful-main entry point (from
;; inside awful-start) -- the second registration is harmless.
;;
;; Every page-specific helper (form fragments, the finished-system
;; generator/renderer) is defined here, before the define-session-page
;; calls that use them -- awful's define-session-page doesn't resolve
;; forward references the way plain internal defines do.
(define (run . args)

;; The Mainworld Orbit & Type form, shown at the end of whichever page
;; last resolved the star system (single-star systems skip straight
;; here from /orbits-result; binary/trinary systems reach it via
;; /companions-result once the companion(s) are placed).
(define (mainworld-orbit-type-form)
  `(div
    (h3 "Mainworld Orbit & Type (pp. 303-304)")
    (form (@ (action "/mainworld-result"))
          (ol
           (li (@ (value "1"))
               (p (b "Mainworld Orbit"))
               (ul
                (li (b "Mainworld Orbit")
                    (br)
                    (input (@ (type "radio") (id "mainworld-orbit-roll") (name "mainworld-orbit")
                              (value "Roll") (checked)))
                    (label (@ (for "mainworld-orbit-roll")) "Roll 1D3+2")
                    (br)
                    (input (@ (type "radio") (id "mainworld-orbit-choose") (name "mainworld-orbit")
                              (value "Choose")))
                    (label (@ (for "mainworld-orbit-choose")) "Choose 3-5")
                    " "
                    (label (@ (for "chosen-mainworld-orbit")) "Chosen Mainworld Orbit:")
                    (input (@ (type "number") (id "chosen-mainworld-orbit") (name "chosen-mainworld-orbit")
                              (min 3) (max 5)))))
               (br)
               ,(roll-field-li 'mainworld-type "Mainworld Type" 2 6 (mainworld-type-name))
               (br)
               (input (@ (type "submit") (value "Submit")))
               "    "
               (input (@ (type "reset") (value "Reset"))))))))

;; The Planetary Details form (p. 304) for a Rock, Hellhole or Desert
;; World mainworld -- Temperature is always Temperate for the
;; mainworld's own orbit, so there's no roll for it.
(define (mainworld-details-form mainworld-type)
  `(div
    (h3 "Mainworld Planetary Details (p. 304)")
    (form (@ (action "/mainworld-details-result"))
          (ol
           (li (@ (value "1")) (p (b "Size, Atmosphere & Hydrographics"))
               (ul
                (li (b "Size") (br)
                    (input (@ (type "radio") (id "mw-size-roll") (name "mw-size") (value "Roll") (checked)))
                    (label (@ (for "mw-size-roll"))
                           ,(if (string=? mainworld-type "Rock")
                                "Roll 1D6: 1-4 Size 0, 5-6 Size 1 or 2 (1D2)"
                                "Roll on the Creating Worlds World Size table (1D6; on a 6, 2D6+4; otherwise 2D6-2)"))
                    (br)
                    (input (@ (type "radio") (id "mw-size-choose") (name "mw-size") (value "Choose")))
                    (label (@ (for "mw-size-choose")) "Choose 0-16")
                    " " (label (@ (for "chosen-mw-size")) "Chosen Size:")
                    (input (@ (type "number") (id "chosen-mw-size") (name "chosen-mw-size") (min 0) (max 16))))
                (li (b "Atmosphere") (br)
                    (input (@ (type "radio") (id "mw-atmosphere-roll") (name "mw-atmosphere") (value "Roll") (checked)))
                    (label (@ (for "mw-atmosphere-roll"))
                           ,(cond ((string=? mainworld-type "Rock") "Roll 1D6 (+1 if Size 0): 1-4 Trace, 5-6 Very Thin")
                                  ((string=? mainworld-type "Hellhole") "Always Exotic, Corrosive or Insidious (A, B or C), chosen at random")
                                  (else "Roll 1D6: 1-2 Very Thin, 3 Thin, 4-5 Standard, 6 Dense")))
                    (br)
                    (input (@ (type "radio") (id "mw-atmosphere-choose") (name "mw-atmosphere") (value "Choose")))
                    (label (@ (for "mw-atmosphere-choose")) "Choose 0-12")
                    " " (label (@ (for "chosen-mw-atmosphere")) "Chosen Atmosphere:")
                    (input (@ (type "number") (id "chosen-mw-atmosphere") (name "chosen-mw-atmosphere") (min 0) (max 12))))
                (li (b "Hydrographics") (br)
                    (input (@ (type "radio") (id "mw-hydrographics-roll") (name "mw-hydrographics") (value "Roll") (checked)))
                    (label (@ (for "mw-hydrographics-roll"))
                           ,(cond ((string=? mainworld-type "Rock") "Roll 1D6 (+1 if Very Thin atmosphere): 1-6 None, 7 10%-20%")
                                  ((string=? mainworld-type "Hellhole") "Roll 1D6: 1-3 None, 4-5 10%-20%, 6 30%-80%")
                                  (else "Always None")))
                    (br)
                    (input (@ (type "radio") (id "mw-hydrographics-choose") (name "mw-hydrographics") (value "Choose")))
                    (label (@ (for "mw-hydrographics-choose")) "Choose (e.g. None, 10%-20%, 30%-80%)")
                    " " (label (@ (for "chosen-mw-hydrographics")) "Chosen Hydrographics:")
                    (input (@ (type "text") (id "chosen-mw-hydrographics") (name "chosen-mw-hydrographics")))))
               (br)
               (input (@ (type "submit") (value "Submit")))
               "    "
               (input (@ (type "reset") (value "Reset"))))))))

;; Generates the rest of the system (gas giants, asteroid belts, minor
;; planets) exactly once and stores it, so the result page and both
;; Markdown exports always show the same system rather than each
;; rerolling it independently.
(define (finish-system!)
  (let* ((num-bodies ($session 'num-bodies))
         (star-orbits ($session 'star-orbits))
         (mainworld-orbit ($session 'mainworld-orbit))
         (generated (generate-system num-bodies star-orbits mainworld-orbit)))
    ($session-set! 'bodies (cdr (assq 'bodies generated)))
    ($session-set! 'moon-of (cdr (assq 'moon-of generated)))))

(define (system-result-page)
  (let* ((data (system-data))
         (rows (system-rows (data-ref data 'hex) (data-ref data 'bodies)
                             (data-ref data 'mainworld-type) (data-ref data 'mainworld-profile)
                             (data-ref data 'mw-size) (data-ref data 'mw-atmosphere) (data-ref data 'mw-hydrographics)
                             (data-ref data 'moon-of)))
         (star-orbits (data-ref data 'star-orbits))
         (mainworld-profile (data-ref data 'mainworld-profile)))
    `((h3 "The story so far")
      ,(apply story-table
         (append
           (list
             (story-row "System Name" `(b ,(data-ref data 'system-name)))
             (story-row "Hex" `(b ,(data-ref data 'hex)))
             (story-row "Number of Planetary Bodies" `(b ,(data-ref data 'num-bodies)))
             (story-row "Star System" `(b ,(data-ref data 'star-count-name)))
             (story-row "Companion Orbit(s)" `(b ,(if (null? star-orbits) "None" (string-intersperse (map number->string star-orbits) ", "))))
             (story-row "Mainworld Orbit" `(b ,(data-ref data 'mainworld-orbit)))
             (story-row "Mainworld Type" `(b ,(data-ref data 'mainworld-type))))
           (if mainworld-profile
               (list (story-row "Mainworld Profile" `(b ,mainworld-profile)))
               (list
                 (story-row "Mainworld Size" `(b ,(uwp-char (data-ref data 'mw-size))) " (" (wt-size-name (data-ref data 'mw-size)) ")")
                 (story-row "Mainworld Atmosphere" `(b ,(uwp-char (data-ref data 'mw-atmosphere))) " (" (wt-atmosphere-name (data-ref data 'mw-atmosphere)) ")")
                 (story-row "Mainworld Hydrographics" `(b ,(data-ref data 'mw-hydrographics)))
                 (story-row "Mainworld Temperature" `(b "Temperate"))))))

      (h3 "The System (pp. 303-307)")
      (table (@ (style "border-collapse:collapse") (border "1") (cellpadding "4"))
             (tr (th "Orbit") (th "Body") (th "Notes"))
             ,@(map (lambda (row) `(tr (td ,(number->string (car row))) (td ,(cadr row)) (td ,(caddr row)))) rows))

      (form (@ (action "/system-markdown-table"))
            (input (@ (type "submit") (value "Show as Markdown (Table)"))))
      (form (@ (action "/system-markdown-list"))
            (input (@ (type "submit") (value "Show as Markdown (List)"))))
      (form (@ (action ,(main-page-path)))
            (input (@ (type "submit") (value "Start Over")))))))

;; Assembles the story-so-far fields plus one field per orbit, shared
;; by both Markdown export pages below.
(define (system-markdown-fields)
  (let* ((data (system-data))
         (rows (system-rows (data-ref data 'hex) (data-ref data 'bodies)
                             (data-ref data 'mainworld-type) (data-ref data 'mainworld-profile)
                             (data-ref data 'mw-size) (data-ref data 'mw-atmosphere) (data-ref data 'mw-hydrographics)
                             (data-ref data 'moon-of)))
         (star-orbits (data-ref data 'star-orbits))
         (mainworld-profile (data-ref data 'mainworld-profile)))
    (append
      (list
       (md-field "System Name" (data-ref data 'system-name))
       (md-field "Hex" (data-ref data 'hex))
       (md-field "Number of Planetary Bodies" (data-ref data 'num-bodies))
       (md-field "Star System" (data-ref data 'star-count-name))
       (md-field "Companion Orbit(s)" (if (null? star-orbits) "None" (string-intersperse (map number->string star-orbits) ", ")))
       (md-field "Mainworld Orbit" (data-ref data 'mainworld-orbit))
       (md-field "Mainworld Type" (data-ref data 'mainworld-type)))
      (if mainworld-profile
          (list (md-field "Mainworld Profile" mainworld-profile))
          (list
           (md-field "Mainworld Size" (uwp-char (data-ref data 'mw-size)) " (" (wt-size-name (data-ref data 'mw-size)) ")")
           (md-field "Mainworld Atmosphere" (uwp-char (data-ref data 'mw-atmosphere)) " (" (wt-atmosphere-name (data-ref data 'mw-atmosphere)) ")")
           (md-field "Mainworld Hydrographics" (data-ref data 'mw-hydrographics))
           (md-field "Mainworld Temperature" "Temperate")))
      (map (lambda (row) (md-field (sprintf "Orbit ~A: ~A" (car row) (cadr row)) (caddr row))) rows))))

(define-session-page (main-page-path)
  (lambda ()
    `((h3 "System Generation")
      (form (@ (action "/orbits-result"))
            (p "Populate the rest of a star system around a mainworld (Cepheus Universal, pp. 303-307).")
            (ol
             (li
              (p (b "System Name and Hex") " (optional, for flavour only)")
              (label (@ (for "system-name")) "System Name: ")
              (input (@ (type "text") (id "system-name") (name "system-name")))
              (br)
              (label (@ (for "hex")) "Subsector Hex: ")
              (input (@ (type "text") (id "hex") (name "hex")))
              (br)
              (input (@ (type "submit") (value "Submit")))
              "    "
              (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/orbits-result"
  (lambda ()
    (resolved-field! system-name (let ((v ($ "system-name"))) (if (string=? v "") "Unnamed System" v)))
    (resolved-field! hex ($ "hex"))

    `((h3 "The story so far")
      ,(story-table
        (story-row "System Name" `(b ,system-name))
        (story-row "Hex" `(b ,hex)))

      (h3 "Orbits & Other Stars (p. 303)")
      (form (@ (action "/star-system-result"))
            (ol
             (li (@ (value "1"))
                 (p (b "Number of Planetary Bodies"))
                 (ul
                  (li (b "Number of Planetary Bodies")
                      (br)
                      (input (@ (type "radio") (id "num-bodies-roll") (name "num-bodies")
                                (value "Roll") (checked)))
                      (label (@ (for "num-bodies-roll")) "Roll 2D6+2")
                      (br)
                      (input (@ (type "radio") (id "num-bodies-choose") (name "num-bodies")
                                (value "Choose")))
                      (label (@ (for "num-bodies-choose")) "Choose 4-14")
                      " "
                      (label (@ (for "chosen-num-bodies")) "Chosen Number of Planetary Bodies:")
                      (input (@ (type "number") (id "chosen-num-bodies") (name "chosen-num-bodies")
                                (min 4) (max 14)))))
                 (br)
                 ,(roll-field-li 'star-count "Star System" 2 6 (star-count-name))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/star-system-result"
  (lambda ()
    (resolved-field! num-bodies (resolve-value num-bodies (roll-num-bodies)))
    (define star-count-str (resolve-field star-count star-count-name (nD 2 6)))
    (resolved-field! star-count (star-count-number star-count-str))
    ($session-set! 'star-count-name star-count-str)
    (if (= star-count 1) ($session-set! 'star-orbits '()))

    `((h3 "The story so far")
      ,(story-table
        (story-row "System Name" `(b ,($session 'system-name)))
        (story-row "Hex" `(b ,($session 'hex)))
        (story-row "Number of Planetary Bodies" `(b ,num-bodies))
        (story-row "Star System" `(b ,star-count-str)))

      ,(if (> star-count 1)
           `(div
             (h3 "Companion Star Placement (p. 303)")
             (form (@ (action "/companions-result"))
                   (ol
                    (li (@ (value "1"))
                        (p (b "Companion Placement"))
                        (ul
                         (li (b "Companion Placement")
                             (br)
                             (input (@ (type "radio") (id "placement-roll") (name "placement")
                                       (value "Roll") (checked)))
                             (label (@ (for "placement-roll"))
                                    "Roll 1D6 -- odd: a companion takes Orbit 1; even: it sits beyond the furthest planetary body")
                             (br)
                             (input (@ (type "radio") (id "placement-choose") (name "placement")
                                       (value "Choose")))
                             (label (@ (for "placement-choose")) "Choose 1-6")
                             " "
                             (label (@ (for "chosen-placement")) "Chosen Placement Roll:")
                             (input (@ (type "number") (id "chosen-placement") (name "chosen-placement")
                                       (min 1) (max 6)))))
                        (br)
                        (input (@ (type "submit") (value "Submit")))
                        "    "
                        (input (@ (type "reset") (value "Reset")))))))
           (mainworld-orbit-type-form)))))

(define-session-page "/companions-result"
  (lambda ()
    (define num-bodies ($session 'num-bodies))
    (define star-count ($session 'star-count))
    (resolved-field! star-orbits
      (companion-orbits star-count num-bodies (resolve-value placement (D 6))))

    `((h3 "The story so far")
      ,(story-table
        (story-row "System Name" `(b ,($session 'system-name)))
        (story-row "Hex" `(b ,($session 'hex)))
        (story-row "Number of Planetary Bodies" `(b ,num-bodies))
        (story-row "Star System" `(b ,($session 'star-count-name)))
        (story-row "Companion Orbit(s)" `(b ,(string-intersperse (map number->string star-orbits) ", "))))

      ,(mainworld-orbit-type-form))))

(define-session-page "/mainworld-result"
  (lambda ()
    (define star-orbits ($session 'star-orbits))
    (resolved-field! mainworld-orbit
      (resolve-mainworld-orbit (resolve-value mainworld-orbit (roll-mainworld-orbit)) star-orbits))
    (resolved-field! mainworld-type (resolve-field mainworld-type mainworld-type-name (nD 2 6)))
    ;; 1D3+2 (mainworld orbit, 3-5) can occasionally exceed a minimum
    ;; 2D6+2 (number of planetary bodies, 4-14) roll -- the book doesn't
    ;; address this, so the total is widened to fit the mainworld
    ;; rather than leaving it without a valid orbit.
    (if (> mainworld-orbit ($session 'num-bodies))
        ($session-set! 'num-bodies mainworld-orbit))

    `((h3 "The story so far")
      ,(story-table
        (story-row "System Name" `(b ,($session 'system-name)))
        (story-row "Hex" `(b ,($session 'hex)))
        (story-row "Number of Planetary Bodies" `(b ,($session 'num-bodies)))
        (story-row "Star System" `(b ,($session 'star-count-name)))
        (story-row "Companion Orbit(s)" `(b ,(if (null? star-orbits) "None" (string-intersperse (map number->string star-orbits) ", "))))
        (story-row "Mainworld Orbit" `(b ,mainworld-orbit))
        (story-row "Mainworld Type" `(b ,mainworld-type)))

      ,(if (mainworld-full-uwp? mainworld-type)
           `(div
             (h3 "Mainworld Profile (Creating Worlds, pp. 281-302)")
             (form (@ (action "/mainworld-uwp-result"))
                   (ol
                    (li (@ (value "1")) (p (b "World Size"))
                        (ul (li (b "World Size") (br)
                                (input (@ (type "radio") (id "world-size-roll") (name "world-size") (value "Roll") (checked)))
                                (label (@ (for "world-size-roll")) "Roll 1D6; on a 6, it's a Super-Earth (roll 2D6+4); otherwise roll 2D6-2")
                                (br)
                                (input (@ (type "radio") (id "world-size-choose") (name "world-size") (value "Choose")))
                                (label (@ (for "world-size-choose")) "Choose 0-16")
                                " " (label (@ (for "chosen-world-size")) "Chosen World Size:")
                                (input (@ (type "number") (id "chosen-world-size") (name "chosen-world-size") (min 0) (max 16)))))
                        (br)
                        ,(roll-field-li 'atmosphere "Atmosphere" 2 6 (wt-atmosphere-name))
                        (br)
                        ,(roll-field-li 'hydrographics "Hydrographics" 2 6 (wt-hydrographics-name))
                        (br)
                        ,(roll-field-li 'population "Population" 2 6 (wt-population-name))
                        (br)
                        (li (b "Starport") (br)
                            (input (@ (type "radio") (id "starport-roll") (name "starport") (value "Roll") (checked)))
                            (label (@ (for "starport-roll")) "Roll 2D6, subtract 7, add Population, then look up the class")
                            (br)
                            (input (@ (type "radio") (id "starport-choose") (name "starport") (value "Choose")))
                            (label (@ (for "starport-choose")) "Choose the unmodified 2D6 roll, 2-12")
                            " " (label (@ (for "chosen-starport")) "Chosen Starport Roll:")
                            (input (@ (type "number") (id "chosen-starport") (name "chosen-starport") (min 2) (max 12))))
                        (br)
                        ,(roll-field-li 'government "Government" 2 6 (wt-government-name))
                        (br)
                        ,(roll-field-li 'law-level "Law Level" 2 6 (wt-law-level-name))
                        (br)
                        (li (b "Tech Level") (br)
                            (input (@ (type "radio") (id "tech-level-roll") (name "tech-level") (value "Roll") (checked)))
                            (label (@ (for "tech-level-roll")) "Roll 1D6, add DMs for Starport, Size, Atmosphere, Hydrographics, Population and Government")
                            (br)
                            (input (@ (type "radio") (id "tech-level-choose") (name "tech-level") (value "Choose")))
                            (label (@ (for "tech-level-choose")) "Choose the unmodified 1D6 roll, 1-6")
                            " " (label (@ (for "chosen-tech-level")) "Chosen Tech Level Roll:")
                            (input (@ (type "number") (id "chosen-tech-level") (name "chosen-tech-level") (min 1) (max 6))))
                        (br)
                        (input (@ (type "submit") (value "Submit")))
                        "    "
                        (input (@ (type "reset") (value "Reset")))))))
           (mainworld-details-form mainworld-type)))))

(define-session-page "/mainworld-uwp-result"
  (lambda ()
    (define mainworld-type ($session 'mainworld-type))
    (resolved-field! world-size (resolve-value world-size (wt-roll-world-size)))
    (resolved-field! atmosphere (resolve-value atmosphere (wt-roll-atmosphere world-size)))
    (resolved-field! hydrographics (resolve-value hydrographics (wt-roll-hydrographics world-size atmosphere)))
    (resolved-field! population (resolve-value population (wt-roll-population)))
    (resolved-field! starport
      (resolve-field starport (lambda (roll) (wt-starport-class-name (+ roll -7 population))) (nD 2 6)))
    (resolved-field! government (resolve-value government (wt-roll-government population)))
    (resolved-field! law-level (resolve-value law-level (wt-roll-law-level government)))
    (resolved-field! tech-level
      (resolve-field tech-level
        (lambda (roll)
          (max (wt-tech-level-minimum atmosphere)
               (+ roll (wt-starport-tl-dm starport) (wt-size-tl-dm world-size) (wt-atmosphere-tl-dm atmosphere)
                  (wt-hydrographics-tl-dm hydrographics) (wt-population-tl-dm population) (wt-government-tl-dm government))))
        (D 6)))
    (finish-system!)
    (system-result-page)))

(define-session-page "/mainworld-details-result"
  (lambda ()
    (define mainworld-type ($session 'mainworld-type))
    (define mw-size (resolve-value mw-size
                       (if (string=? mainworld-type "Rock") (rock-size) (wt-roll-world-size))))
    (define mw-atmosphere (resolve-value mw-atmosphere
                             (cond ((string=? mainworld-type "Rock") (rock-atmosphere mw-size))
                                   ((string=? mainworld-type "Hellhole") (hellhole-atmosphere))
                                   (else (desert-atmosphere)))))
    (define mw-hydrographics
      (if (string=? ($ "mw-hydrographics") "Roll")
          (cond ((string=? mainworld-type "Rock") (rock-hydrographics mw-atmosphere))
                ((string=? mainworld-type "Hellhole") (hellhole-hydrographics))
                (else "None"))
          ($ "chosen-mw-hydrographics")))
    ($session-set! 'mw-size mw-size)
    ($session-set! 'mw-atmosphere mw-atmosphere)
    ($session-set! 'mw-hydrographics mw-hydrographics)
    (finish-system!)
    (system-result-page)))

(define-session-page "/system-markdown-table"
  (lambda ()
    `((h3 "Markdown (Table)")
      (pre ,(md-table-rows (system-markdown-fields)))
      (form (@ (action ,(main-page-path)))
            (input (@ (type "submit") (value "Start Over")))))))

(define-session-page "/system-markdown-list"
  (lambda ()
    `((h3 "Markdown (List)")
      (pre ,(md-bullet-rows (system-markdown-fields)))
      (form (@ (action ,(main-page-path)))
            (input (@ (type "submit") (value "Start Over"))))))))

(run)

)
