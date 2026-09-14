;;; cu-worlds.scm -- Cepheus Universal Creating Worlds system.
;;; Generates a Universal World Profile for a single mainworld.
;;;
;;; awful --port=2021 cu-worlds.scm
(include "worlds-tables.scm")

(module cu-worlds (run)

(import scheme)
(import (chicken base))
(import (chicken random))
(import (math base))
(import loop)
(import srfi-1)
(import srfi-13)
(import (only (chicken format) sprintf))
(import (only (chicken string) string-translate*))
(import awful)
(import worlds-tables)

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

;; A Markdown pipe-table row, mirroring story-row's label/content shape
;; so the Markdown export tracks the HTML story table field-for-field.
;; Pairs with md-table-header, whose alignment markers (---:/: ---)
;; right-align the Field column and left-align the Value column, the
;; same layout story-row gives the HTML table.
(define (md-row label . content)
  (sprintf "| **~A** | ~A |\n" (md-escape label)
    (md-escape (apply string-append (map (lambda (x) (sprintf "~A" x)) content)))))

;; Header + alignment-marker rows for a story-so-far Markdown table;
;; precedes a run of md-row calls.
(define (md-table-header)
  "| Field | Value |\n|---:|:---|\n")

;; Registers all pages for this app. Called explicitly at the bottom
;; of this module for the interpreted `awful cu-worlds.scm` dev
;; workflow, and again by the compiled awful-main entry point (from
;; inside awful-start) -- the second registration is harmless.
(define (run . args)

(define-session-page (main-page-path)
  (lambda ()
    `((h3 "Creating Worlds")
      (form (@ (action "/world-size-result"))
            (p "Create a world (Cepheus Universal, pp. 281-302).")
            (ol
             (li
              (p (b "World Name and Hex") " (optional, for flavour only)")
              (label (@ (for "world-name")) "World Name: ")
              (input (@ (type "text") (id "world-name") (name "world-name")))
              (br)
              (label (@ (for "hex")) "Subsector Hex: ")
              (input (@ (type "text") (id "hex") (name "hex")))
              (br)
              (input (@ (type "submit") (value "Submit")))
              "    "
              (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/world-size-result"
  (lambda ()
    (resolved-field! world-name (let ((v ($ "world-name"))) (if (string=? v "") "Unnamed World" v)))
    (resolved-field! hex ($ "hex"))
    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex)))

      (h3 "World Size (p. 281)")
      (form (@ (action "/atmosphere-result"))
            (ol
             (li (@ (value "1"))
                 (p (b "World Size"))
                 (ul
                  (li (b "World Size")
                      (br)
                      (input (@ (type "radio") (id "world-size-roll") (name "world-size")
                                (value "Roll") (checked)))
                      (label (@ (for "world-size-roll"))
                             "Roll 1D6; on a 6, it's a Super-Earth (roll 2D6+4); otherwise roll 2D6-2")
                      (br)
                      (input (@ (type "radio") (id "world-size-choose") (name "world-size")
                                (value "Choose")))
                      (label (@ (for "world-size-choose")) "Choose 0-16")
                      " "
                      (label (@ (for "chosen-world-size")) "Chosen World Size:")
                      (input (@ (type "number") (id "chosen-world-size") (name "chosen-world-size")
                                (min 0) (max 16)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/atmosphere-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (resolved-field! world-size (resolve-value world-size (roll-world-size)))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size)))

      (h3 "Atmosphere (p. 285)")
      (form (@ (action "/hydrographics-result"))
            (ol
             (li (@ (value "2"))
                 (p (b "Atmosphere"))
                 (ul
                  (li (b "Atmosphere")
                      (br)
                      (input (@ (type "radio") (id "atmosphere-roll") (name "atmosphere")
                                (value "Roll") (checked)))
                      (label (@ (for "atmosphere-roll"))
                             "Roll 2D6, modified by World Size (Size 0-2: none, always 0; Size 3-4: -5; Size 5-7: none; Size 8+: +2)")
                      (br)
                      (input (@ (type "radio") (id "atmosphere-choose") (name "atmosphere")
                                (value "Choose")))
                      (label (@ (for "atmosphere-choose")) "Choose 0-12")
                      " "
                      (label (@ (for "chosen-atmosphere")) "Chosen Atmosphere:")
                      (input (@ (type "number") (id "chosen-atmosphere") (name "chosen-atmosphere")
                                (min 0) (max 12)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/hydrographics-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (resolved-field! atmosphere (resolve-value atmosphere (roll-atmosphere world-size)))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere)))

      (h3 "Hydrographics (p. 290)")
      (form (@ (action "/population-result"))
            (ol
             (li (@ (value "3"))
                 (p (b "Hydrographics"))
                 (ul
                  (li (b "Hydrographics")
                      (br)
                      (input (@ (type "radio") (id "hydrographics-roll") (name "hydrographics")
                                (value "Roll") (checked)))
                      (label (@ (for "hydrographics-roll"))
                             "Roll 2D6, modified by World Size and Atmosphere (Size 0-2: none, always 0; Atmosphere 2, 3, B or C: -6; otherwise none)")
                      (br)
                      (input (@ (type "radio") (id "hydrographics-choose") (name "hydrographics")
                                (value "Choose")))
                      (label (@ (for "hydrographics-choose")) "Choose 0-10")
                      " "
                      (label (@ (for "chosen-hydrographics")) "Chosen Hydrographics:")
                      (input (@ (type "number") (id "chosen-hydrographics") (name "chosen-hydrographics")
                                (min 0) (max 10)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/population-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (resolved-field! hydrographics (resolve-value hydrographics (roll-hydrographics world-size atmosphere)))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
        (story-row "Hydrographics" `(b ,hydrographics) " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics)))

      (h3 "Population (p. 293)")
      (form (@ (action "/starport-result"))
            (ol
             (li (@ (value "4"))
                 (p (b "Population"))
                 (ul
                  (li (b "Population")
                      (br)
                      (input (@ (type "radio") (id "population-roll") (name "population")
                                (value "Roll") (checked)))
                      (label (@ (for "population-roll")) "Roll 2D6-2")
                      (br)
                      (input (@ (type "radio") (id "population-choose") (name "population")
                                (value "Choose")))
                      (label (@ (for "population-choose")) "Choose 0-10")
                      " "
                      (label (@ (for "chosen-population")) "Chosen Population:")
                      (input (@ (type "number") (id "chosen-population") (name "chosen-population")
                                (min 0) (max 10)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/starport-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (define hydrographics ($session 'hydrographics))
    (resolved-field! population (resolve-value population (roll-population)))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
        (story-row "Hydrographics" `(b ,hydrographics) " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics))
        (story-row "Population" `(b ,population) " (" (uwp-char population) "): " (population-name population)))

      (h3 "Starport (p. 293)")
      (form (@ (action "/government-result"))
            (ol
             (li (@ (value "5"))
                 (p (b "Starport"))
                 (ul
                  (li (b "Starport")
                      (br)
                      (input (@ (type "radio") (id "starport-roll") (name "starport")
                                (value "Roll") (checked)))
                      (label (@ (for "starport-roll"))
                             "Roll 2D6, subtract 7, add Population, then look up the class")
                      (br)
                      (input (@ (type "radio") (id "starport-choose") (name "starport")
                                (value "Choose")))
                      (label (@ (for "starport-choose")) "Choose the unmodified 2D6 roll, 2-12")
                      " "
                      (label (@ (for "chosen-starport")) "Chosen Starport Roll:")
                      (input (@ (type "number") (id "chosen-starport") (name "chosen-starport")
                                (min 2) (max 12)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/government-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (define hydrographics ($session 'hydrographics))
    (define population ($session 'population))
    (resolved-field! starport
      (resolve-field starport (lambda (roll) (starport-class-name (+ roll -7 population))) (nD 2 6)))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
        (story-row "Hydrographics" `(b ,hydrographics) " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics))
        (story-row "Population" `(b ,population) " (" (uwp-char population) "): " (population-name population))
        (story-row "Starport" `(b ,starport) ": " (starport-description starport)))

      (h3 "Government (p. 294)")
      (form (@ (action "/law-level-result"))
            (ol
             (li (@ (value "6"))
                 (p (b "Government"))
                 (ul
                  (li (b "Government")
                      (br)
                      (input (@ (type "radio") (id "government-roll") (name "government")
                                (value "Roll") (checked)))
                      (label (@ (for "government-roll"))
                             "Roll 2D6, subtract 7, add Population")
                      (br)
                      (input (@ (type "radio") (id "government-choose") (name "government")
                                (value "Choose")))
                      (label (@ (for "government-choose")) "Choose the unmodified 2D6 roll, 2-12")
                      " "
                      (label (@ (for "chosen-government")) "Chosen Government Roll:")
                      (input (@ (type "number") (id "chosen-government") (name "chosen-government")
                                (min 2) (max 12)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/law-level-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (define hydrographics ($session 'hydrographics))
    (define population ($session 'population))
    (define starport ($session 'starport))
    (resolved-field! government
      (resolve-field government (lambda (roll) (clamp (+ roll -7 population) 0 15)) (nD 2 6)))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
        (story-row "Hydrographics" `(b ,hydrographics) " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics))
        (story-row "Population" `(b ,population) " (" (uwp-char population) "): " (population-name population))
        (story-row "Starport" `(b ,starport) ": " (starport-description starport))
        (story-row "Government" `(b ,government) " (" (uwp-char government) "): " (government-name government)))

      (h3 "Law Level (p. 294)")
      (form (@ (action "/tech-level-result"))
            (ol
             (li (@ (value "7"))
                 (p (b "Law Level"))
                 (ul
                  (li (b "Law Level")
                      (br)
                      (input (@ (type "radio") (id "law-level-roll") (name "law-level")
                                (value "Roll") (checked)))
                      (label (@ (for "law-level-roll"))
                             "Roll 2D6, subtract 7, add Government")
                      (br)
                      (input (@ (type "radio") (id "law-level-choose") (name "law-level")
                                (value "Choose")))
                      (label (@ (for "law-level-choose")) "Choose the unmodified 2D6 roll, 2-12")
                      " "
                      (label (@ (for "chosen-law-level")) "Chosen Law Level Roll:")
                      (input (@ (type "number") (id "chosen-law-level") (name "chosen-law-level")
                                (min 2) (max 12)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/tech-level-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (define hydrographics ($session 'hydrographics))
    (define population ($session 'population))
    (define starport ($session 'starport))
    (define government ($session 'government))
    (resolved-field! law-level
      (resolve-field law-level (lambda (roll) (clamp (+ roll -7 government) 0 999)) (nD 2 6)))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
        (story-row "Hydrographics" `(b ,hydrographics) " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics))
        (story-row "Population" `(b ,population) " (" (uwp-char population) "): " (population-name population))
        (story-row "Starport" `(b ,starport) ": " (starport-description starport))
        (story-row "Government" `(b ,government) " (" (uwp-char government) "): " (government-name government))
        (story-row "Law Level" `(b ,law-level) " (" (uwp-char law-level) "): " (law-level-name law-level)))

      (h3 "Technology Level (p. 295)")
      (p "Minimum Tech Level for this Atmosphere: " ,(tech-level-minimum atmosphere))
      (form (@ (action "/bases-result"))
            (ol
             (li (@ (value "8"))
                 (p (b "Technology Level"))
                 (ul
                  (li (b "Technology Level")
                      (br)
                      (input (@ (type "radio") (id "tech-level-roll") (name "tech-level")
                                (value "Roll") (checked)))
                      (label (@ (for "tech-level-roll"))
                             "Roll 1D6, add DMs for Starport, Size, Atmosphere, Hydrographics, Population and Government, then apply the Atmosphere minimum")
                      (br)
                      (input (@ (type "radio") (id "tech-level-choose") (name "tech-level")
                                (value "Choose")))
                      (label (@ (for "tech-level-choose")) "Choose the unmodified 1D6 roll, 1-6")
                      " "
                      (label (@ (for "chosen-tech-level")) "Chosen Tech Level Roll:")
                      (input (@ (type "number") (id "chosen-tech-level") (name "chosen-tech-level")
                                (min 1) (max 6)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/bases-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (define hydrographics ($session 'hydrographics))
    (define population ($session 'population))
    (define starport ($session 'starport))
    (define government ($session 'government))
    (define law-level ($session 'law-level))
    (resolved-field! tech-level
      (resolve-field tech-level
        (lambda (roll)
          (max (tech-level-minimum atmosphere)
               (+ roll (starport-tl-dm starport) (size-tl-dm world-size) (atmosphere-tl-dm atmosphere)
                  (hydrographics-tl-dm hydrographics) (population-tl-dm population) (government-tl-dm government))))
        (D 6)))
    (define codes (trade-codes world-size atmosphere hydrographics population))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
        (story-row "Hydrographics" `(b ,hydrographics) " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics))
        (story-row "Population" `(b ,population) " (" (uwp-char population) "): " (population-name population))
        (story-row "Starport" `(b ,starport) ": " (starport-description starport))
        (story-row "Government" `(b ,government) " (" (uwp-char government) "): " (government-name government))
        (story-row "Law Level" `(b ,law-level) " (" (uwp-char law-level) "): " (law-level-name law-level))
        (story-row "Tech Level" `(b ,tech-level) ": " (tech-level-name tech-level))
        (story-row "Trade Codes" `(b ,(if (null? codes) "None" (string-intersperse codes ", ")))))

      (h3 "Bases and Gas Giants (pp. 294, 297)")
      (form (@ (action "/world-result"))
            (ol
             (li (@ (value "9"))
                 (p (b "Bases and Gas Giants"))
                 (ul
                  (li (b "Naval Base")
                      (br)
                      (input (@ (type "radio") (id "naval-base-roll") (name "naval-base")
                                (value "Roll") (checked)))
                      (label (@ (for "naval-base-roll"))
                             "If Starport is A or B, roll 2D6; 8+ means a Naval Base is present")
                      (br)
                      (input (@ (type "radio") (id "naval-base-choose") (name "naval-base")
                                (value "Choose")))
                      (label (@ (for "naval-base-choose")) "Choose the unmodified 2D6 roll, 2-12")
                      " "
                      (label (@ (for "chosen-naval-base")) "Chosen Naval Base Roll:")
                      (input (@ (type "number") (id "chosen-naval-base") (name "chosen-naval-base")
                                (min 2) (max 12))))
                  (li (b "Scout Base")
                      (br)
                      (input (@ (type "radio") (id "scout-base-roll") (name "scout-base")
                                (value "Roll") (checked)))
                      (label (@ (for "scout-base-roll"))
                             "Unless Starport is E or X, roll 2D6 (DM -1 for C, -2 for B, -3 for A); 7+ means a Scout Base is present")
                      (br)
                      (input (@ (type "radio") (id "scout-base-choose") (name "scout-base")
                                (value "Choose")))
                      (label (@ (for "scout-base-choose")) "Choose the unmodified 2D6 roll, 2-12")
                      " "
                      (label (@ (for "chosen-scout-base")) "Chosen Scout Base Roll:")
                      (input (@ (type "number") (id "chosen-scout-base") (name "chosen-scout-base")
                                (min 2) (max 12))))
                  (li (b "Gas Giant")
                      (br)
                      (input (@ (type "radio") (id "gas-giant-roll") (name "gas-giant")
                                (value "Roll") (checked)))
                      (label (@ (for "gas-giant-roll"))
                             "Roll 2D6 once per star system; 5+ means at least one gas giant is present")
                      (br)
                      (input (@ (type "radio") (id "gas-giant-choose") (name "gas-giant")
                                (value "Choose")))
                      (label (@ (for "gas-giant-choose")) "Choose 2-12")
                      " "
                      (label (@ (for "chosen-gas-giant")) "Chosen Gas Giant Roll:")
                      (input (@ (type "number") (id "chosen-gas-giant") (name "chosen-gas-giant")
                                (min 2) (max 12)))))
                 (br)
                 (input (@ (type "submit") (value "Submit")))
                 "    "
                 (input (@ (type "reset") (value "Reset")))))))))

(define-session-page "/world-result"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (define hydrographics ($session 'hydrographics))
    (define population ($session 'population))
    (define starport ($session 'starport))
    (define government ($session 'government))
    (define law-level ($session 'law-level))
    (define tech-level ($session 'tech-level))
    (resolved-field! naval-base
      (resolve-field naval-base (lambda (roll) (>= roll 8)) (nD 2 6)))
    (resolved-field! scout-base
      (resolve-field scout-base (lambda (roll) (>= (+ roll (scout-base-dm starport)) 7)) (nD 2 6)))
    (resolved-field! gas-giant
      (resolve-field gas-giant (lambda (roll) (>= roll 5)) (nD 2 6)))

    ;; Naval and Scout Bases only ever apply for the right Starport
    ;; classes (p. 297); a "Roll" of 8+/7+ on an ineligible Starport is
    ;; simply ignored, matching naval-base-present?/scout-base-present?.
    (define naval-base* (and (member starport '("A" "B")) naval-base))
    (define scout-base* (and (not (member starport '("E" "X"))) scout-base))
    (define codes (trade-codes world-size atmosphere hydrographics population))
    (define uwp (uwp-line starport world-size atmosphere hydrographics population government law-level tech-level))
    (define bases (bases-code naval-base* scout-base*))

    `((h3 "The story so far")
      ,(story-table
        (story-row "World Name" `(b ,world-name))
        (story-row "Hex" `(b ,hex))
        (story-row "World Size" `(b ,world-size) " (" (uwp-char world-size) "): " (size-name world-size))
        (story-row "Atmosphere" `(b ,atmosphere) " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
        (story-row "Hydrographics" `(b ,hydrographics) " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics))
        (story-row "Population" `(b ,population) " (" (uwp-char population) "): " (population-name population))
        (story-row "Starport" `(b ,starport) ": " (starport-description starport))
        (story-row "Government" `(b ,government) " (" (uwp-char government) "): " (government-name government))
        (story-row "Law Level" `(b ,law-level) " (" (uwp-char law-level) "): " (law-level-name law-level))
        (story-row "Tech Level" `(b ,tech-level) ": " (tech-level-name tech-level))
        (story-row "Trade Codes" `(b ,(if (null? codes) "None" (string-intersperse codes ", "))))
        (story-row "Naval Base" `(b ,(if naval-base* "Yes" "No")))
        (story-row "Scout Base" `(b ,(if scout-base* "Yes" "No")))
        (story-row "Gas Giant Present" `(b ,(if gas-giant "Yes" "No"))))

      (h3 "Universal World Profile")
      (p (tt ,(string-intersperse
               (filter (lambda (s) (not (string=? s "")))
                       (list world-name hex uwp bases
                             (if (null? codes) "" (string-intersperse codes ", "))
                             (if gas-giant "G" "")))
               " ")))

      (h3 "Travel Zones, Climate and a Hook (pp. 298-299)")
      (p "These are Game Master judgment calls, not rolled: Travel Zones (Amber for a dangerous or unstable world,
Red for one interdicted entirely), a Climate label for the predominant temperature band (Frozen, Cold, Cool,
Temperate, Warm, Hot, Inferno, or Locked/Eccentric for a tidally-locked or highly eccentric orbit), and a single
memorable 'hook' -- a signature physical or social detail that makes this world distinctive.")

      (h3 "Interpretation")
      (p "Write up a summary of the world: what do these results say about its environment, economy and society, and what makes it worth visiting (or avoiding)?")

      (form (@ (action "/world-markdown"))
            (input (@ (type "submit") (value "Show as Markdown"))))
      (form (@ (action ,(main-page-path)))
            (input (@ (type "submit") (value "Start Over")))))))

;; Renders the same results as /world-result, as a block of Markdown
;; text the GM can copy into their own notes. Reads everything back
;; out of the session rather than re-deriving it, since every field
;; here was already resolved (and $session-set!) by /world-result.
(define-session-page "/world-markdown"
  (lambda ()
    (define world-name ($session 'world-name))
    (define hex ($session 'hex))
    (define world-size ($session 'world-size))
    (define atmosphere ($session 'atmosphere))
    (define hydrographics ($session 'hydrographics))
    (define population ($session 'population))
    (define starport ($session 'starport))
    (define government ($session 'government))
    (define law-level ($session 'law-level))
    (define tech-level ($session 'tech-level))
    (define naval-base ($session 'naval-base))
    (define scout-base ($session 'scout-base))
    (define gas-giant ($session 'gas-giant))
    (define naval-base* (and (member starport '("A" "B")) naval-base))
    (define scout-base* (and (not (member starport '("E" "X"))) scout-base))
    (define codes (trade-codes world-size atmosphere hydrographics population))
    (define uwp (uwp-line starport world-size atmosphere hydrographics population government law-level tech-level))
    (define bases (bases-code naval-base* scout-base*))

    `((h3 "Markdown")
      (pre ,(string-append
             "### The story so far\n\n"
             (md-table-header)
             (md-row "World Name" world-name)
             (md-row "Hex" hex)
             (md-row "World Size" world-size " (" (uwp-char world-size) "): " (size-name world-size))
             (md-row "Atmosphere" atmosphere " (" (uwp-char atmosphere) "): " (atmosphere-name atmosphere))
             (md-row "Hydrographics" hydrographics " (" (uwp-char hydrographics) "): " (hydrographics-name hydrographics))
             (md-row "Population" population " (" (uwp-char population) "): " (population-name population))
             (md-row "Starport" starport ": " (starport-description starport))
             (md-row "Government" government " (" (uwp-char government) "): " (government-name government))
             (md-row "Law Level" law-level " (" (uwp-char law-level) "): " (law-level-name law-level))
             (md-row "Tech Level" tech-level ": " (tech-level-name tech-level))
             (md-row "Trade Codes" (if (null? codes) "None" (string-intersperse codes ", ")))
             (md-row "Naval Base" (if naval-base* "Yes" "No"))
             (md-row "Scout Base" (if scout-base* "Yes" "No"))
             (md-row "Gas Giant Present" (if gas-giant "Yes" "No"))
             "\n### Universal World Profile\n\n"
             "`" (string-intersperse
                  (filter (lambda (s) (not (string=? s "")))
                          (list world-name hex uwp bases
                                (if (null? codes) "" (string-intersperse codes ", "))
                                (if gas-giant "G" "")))
                  " ")
             "`\n"
             "\n### Travel Zones, Climate and a Hook (pp. 298-299)\n\n"
             "These are Game Master judgment calls, not rolled: Travel Zones (Amber for a dangerous or unstable "
             "world, Red for one interdicted entirely), a Climate label for the predominant temperature band "
             "(Frozen, Cold, Cool, Temperate, Warm, Hot, Inferno, or Locked/Eccentric for a tidally-locked or "
             "highly eccentric orbit), and a single memorable 'hook' -- a signature physical or social detail "
             "that makes this world distinctive.\n"
             "\n### Interpretation\n\n"
             "Write up a summary of the world: what do these results say about its environment, economy and "
             "society, and what makes it worth visiting (or avoiding)?\n"))
      (form (@ (action ,(main-page-path)))
            (input (@ (type "submit") (value "Start Over"))))))))

(run)

)
