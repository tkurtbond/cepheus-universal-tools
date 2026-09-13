;;; roll-tables.scm -- DSL for defining dice roll-range lookup tables, and
;;; the awful web-page scaffolding (form fragment + roll-or-choose
;;; resolution) that goes with them.
;;;
;;; Cepheus Universal (and most Traveller-derived systems) tables share the
;;; same shape: roll some dice, find which range the result falls in, read
;;; off a value. Hand-writing this three times over -- once as a `cond' to
;;; compute it, once as an HTML form fragment offering "Roll" or "Choose",
;;; and once as prose describing the ranges for the "Choose" case -- is
;;; repetitive and an easy place for the three copies to drift apart. Here
;;; the table is written once, the way the rulebook itself lays it out,
;;; and everything else is derived from it.
;;;
;;; Not a module: `(include "roll-tables.scm")' this file into whichever
;;; module needs it.

(import (chicken base))
(import (chicken format))
(import (chicken string))

;; A range is either (n) -- a single roll value -- or (lo . hi), inclusive
;; on both ends. This mirrors how ranges are written in the rulebook (and
;; in tables.scm): e.g. (8) for a lone "8", (3 . 5) for "3-5".
(define-syntax range-test
  (syntax-rules ()
    ((_ roll (n)) (= roll n))
    ((_ roll (lo . hi)) (<= lo roll hi))))

(define (range-lo range) (car range))
(define (range-hi range) (if (null? (cdr range)) (car range) (cdr range)))

(define (range-text range)
  (let ((lo (range-lo range)) (hi (range-hi range)))
    (if (= lo hi)
        (number->string lo)
        (string-append (number->string lo) "-" (number->string hi)))))

;; (define-roll-table (name roll) (range result) ...)
;;
;; Defines `name' as a procedure of 0 or 1 arguments:
;;   (name)      -> the table data, as a list of (range . result), for use
;;                  by roll-field-li et al, below.
;;   (name roll) -> the result whose range contains roll.
;;
;; e.g. the Biotype table (Cepheus Universal p. 329):
;;
;;   (define-roll-table (biotype-name roll)
;;     ((2 . 3) "Scavenger")
;;     ((4 . 5) "Herbivore")
;;     ((6 . 10) "Omnivore")
;;     ((11 . 12) "Carnivore"))
(define-syntax define-roll-table
  (syntax-rules ()
    ((_ (name roll) (range result) ...)
     (define name
       (case-lambda
         (() (list (cons 'range result) ...))
         ((roll) (cond ((range-test roll range) result)
                       ...
                       (else (error 'name "roll out of range" roll)))))))))

;; (define-keyed-roll-table (name key roll) (key-value (range result) ...) ...)
;;
;; For tables where the roll ranges (and their meanings) depend on a prior
;; result, such as the rulebook's Subtype table, whose ranges depend on
;; Biotype. Defines `name' as a procedure of 0, 1 or 2 arguments:
;;   (name)          -> alist of (key-value . table-data)
;;   (name key)      -> that key's table data (as above)
;;   (name key roll) -> the looked-up result
;;
;;   (define-keyed-roll-table (subtype-name biotype roll)
;;     ("Scavenger" ((2 . 3) "Reducer") ((4 . 7) "Hijacker") ...)
;;     ("Herbivore" ((2) "Filter") ((3 . 7) "Intermittent") ...)
;;     ...)
(define-syntax define-keyed-roll-table
  (syntax-rules ()
    ((_ (name key roll) (key-value (range result) ...) ...)
     (define name
       (case-lambda
         (() (list (cons key-value (list (cons 'range result) ...)) ...))
         ((key) (cond ((equal? key key-value) (list (cons 'range result) ...))
                      ...
                      (else (error 'name "unknown key" key))))
         ((key roll)
          (cond ((equal? key key-value)
                 (cond ((range-test roll range) result)
                       ...
                       (else (error 'name "roll out of range for" key-value roll))))
                ...
                (else (error 'name "unknown key" key)))))))))

;; -------------------------------------------------------------------
;; Deriving HTML form fragments and prose from table data.

(define (roll-table-min table) (apply min (map (lambda (e) (range-lo (car e))) table)))
(define (roll-table-max table) (apply max (map (lambda (e) (range-hi (car e))) table)))

(define (roll-table-description table)
  (string-intersperse
   (map (lambda (e) (sprintf "~a: ~a" (range-text (car e)) (cdr e))) table)
   ", "))

(define (keyed-roll-table-min keyed-table)
  (apply min (map (lambda (kv) (roll-table-min (cdr kv))) keyed-table)))
(define (keyed-roll-table-max keyed-table)
  (apply max (map (lambda (kv) (roll-table-max (cdr kv))) keyed-table)))

(define (keyed-roll-table-description keyed-table)
  (string-intersperse
   (map (lambda (kv) (sprintf "~a: ~a" (car kv) (roll-table-description (cdr kv))))
        keyed-table)
   ".  "))

;; (roll-field-li field-name label dice-count dice-sides table)
;;
;; Returns the sxml <li> for a form field backed by a define-roll-table
;; table: a Roll/Choose radio pair, and a number input for the "Choose"
;; case with min/max and a description of the table's ranges derived from
;; the table itself, so the prose can never drift out of sync with the
;; lookup code.
(define (roll-field-li field-name label dice-count dice-sides table)
  (let* ((fname (symbol->string field-name))
         (roll-id (string-append fname "-roll"))
         (choose-id (string-append fname "-choose"))
         (chosen-name (string-append "chosen-" fname)))
    `(li (b ,label)
         (br)
         (input (@ (type "radio") (id ,roll-id) (name ,fname)
                   (value "Roll") (checked)))
         (label (@ (for ,roll-id))
                ,(sprintf "Roll ~aD~a" dice-count dice-sides))
         (br)
         (input (@ (type "radio") (id ,choose-id) (name ,fname)
                   (value "Choose")))
         (label (@ (for ,choose-id))
                ,(sprintf "Choose ~a-~a" (roll-table-min table) (roll-table-max table)))
         " "
         (label (@ (for ,chosen-name))
                ,(sprintf "Chosen ~a: ~a" label (roll-table-description table)))
         (input (@ (type "number") (id ,chosen-name) (name ,chosen-name)
                   (min ,(roll-table-min table)) (max ,(roll-table-max table)))))))

;; (keyed-roll-field-li field-name label dice-count dice-sides key-label keyed-table)
;;
;; As roll-field-li, but for a define-keyed-roll-table table. Since this is
;; a plain HTML form with no scripting, the description covers every key's
;; ranges at once (there is no way to show only the ranges for whichever
;; key ends up chosen on a prior page).
(define (keyed-roll-field-li field-name label dice-count dice-sides key-label keyed-table)
  (let* ((fname (symbol->string field-name))
         (roll-id (string-append fname "-roll"))
         (choose-id (string-append fname "-choose"))
         (chosen-name (string-append "chosen-" fname)))
    `(li (b ,label)
         (br)
         (input (@ (type "radio") (id ,roll-id) (name ,fname)
                   (value "Roll") (checked)))
         (label (@ (for ,roll-id))
                ,(sprintf "Roll ~aD~a (meaning depends on ~a)" dice-count dice-sides key-label))
         (br)
         (input (@ (type "radio") (id ,choose-id) (name ,fname)
                   (value "Choose")))
         (label (@ (for ,choose-id))
                ,(sprintf "Choose ~a-~a" (keyed-roll-table-min keyed-table) (keyed-roll-table-max keyed-table)))
         " "
         (label (@ (for ,chosen-name))
                ,(sprintf "Chosen ~a: ~a" label (keyed-roll-table-description keyed-table)))
         (input (@ (type "number") (id ,chosen-name) (name ,chosen-name)
                   (min ,(keyed-roll-table-min keyed-table))
                   (max ,(keyed-roll-table-max keyed-table)))))))

;; -------------------------------------------------------------------
;; Resolving a field's submitted value inside a define-session-page.
;;
;; (resolve-field field lookup dice-expr)
;;
;; Reads the "Roll"/"Choose" radio for `field' (an unquoted symbol, e.g.
;; `biotype') via awful's `$', rolls dice-expr or parses "chosen-<field>",
;; and passes the result through `lookup' (a define-roll-table name).
;; Replaces, for a table-backed field, the repeated:
;;
;;   (define biotype-roll (if (string=? ($ "biotype") "Roll")
;;                             (nD 2 6)
;;                             (string->number ($ "chosen-biotype"))))
;;   (define biotype (biotype-name biotype-roll))
;;
;; with:
;;
;;   (define biotype (resolve-field biotype biotype-name (nD 2 6)))
(define-syntax resolve-field
  (syntax-rules ()
    ((_ field lookup dice-expr)
     (lookup (if (string=? ($ (symbol->string 'field)) "Roll")
                 dice-expr
                 (string->number ($ (string-append "chosen-" (symbol->string 'field)))))))))

;; (resolve-keyed-field field lookup key dice-expr)
;;
;; As resolve-field, for a define-keyed-roll-table `lookup', threading a
;; previously-resolved `key' (e.g. biotype) through to it:
;;
;;   (define subtype (resolve-keyed-field subtype subtype-name biotype (nD 2 6)))
(define-syntax resolve-keyed-field
  (syntax-rules ()
    ((_ field lookup key dice-expr)
     (lookup key (if (string=? ($ (symbol->string 'field)) "Roll")
                     dice-expr
                     (string->number ($ (string-append "chosen-" (symbol->string 'field)))))))))

;; -------------------------------------------------------------------
;; Formula tables: like roll tables, but a range selects a further dice
;; ROLL (e.g. "1D3+3") rather than a fixed value, such as the Government
;; and Tech Level tables (Cepheus Universal p. 326). A formula-spec is
;; the literal list (dice-count dice-sides modifier), meaning
;; dice-count D dice-sides + modifier; it must be literal numbers (not
;; expressions) so the table can be described in prose without actually
;; rolling any dice. Requires `nD' (num-dice, num-sides -> sum) to be
;; defined by the including file.

(define (formula-value spec)
  (+ (caddr spec) (nD (car spec) (cadr spec))))

(define (formula-min spec) (+ (caddr spec) (car spec)))
(define (formula-max spec) (+ (caddr spec) (* (car spec) (cadr spec))))

(define (formula-text spec)
  (let ((count (car spec)) (sides (cadr spec)) (modifier (caddr spec)))
    (string-append (number->string count) "D" (number->string sides)
                    (cond ((> modifier 0) (string-append "+" (number->string modifier)))
                          ((< modifier 0) (number->string modifier))
                          (else "")))))

;; (define-formula-table (name roll) (range formula-spec) ...)
;;
;; Defines `name' as a procedure of 0 or 1 arguments, as define-roll-table
;; does, except (name roll) rolls the selected formula and returns the
;; result, e.g. the Government table:
;;
;;   (define-formula-table (government-formula roll)
;;     ((1 . 3) (1 6 1))    ; 1-3: 1D6+1
;;     ((4 . 6) (1 6 7)))   ; 4-6: 1D6+7
(define-syntax define-formula-table
  (syntax-rules ()
    ((_ (name roll) (range (dice-count dice-sides modifier)) ...)
     (define name
       (case-lambda
         (() (list (cons 'range (list dice-count dice-sides modifier)) ...))
         ((roll) (cond ((range-test roll range)
                        (formula-value (list dice-count dice-sides modifier)))
                       ...
                       (else (error 'name "roll out of range" roll)))))))))

;; (define-keyed-formula-table (name key roll) (key-value (range formula-spec) ...) ...)
;;
;; As define-formula-table, keyed on a prior result. Tech Level ignores
;; the roll entirely for a Major Race (a flat 1D6+9) -- modeled, as with
;; Starport, as a single range covering every possible roll:
;;
;;   (define-keyed-formula-table (tech-level-formula major-or-minor roll)
;;     ('Major ((1 . 6) (1 6 9)))
;;     ('Minor ((1 . 3) (1 3 0))
;;             ((4 . 5) (1 3 3))
;;             ((6) (1 3 6))))
(define-syntax define-keyed-formula-table
  (syntax-rules ()
    ((_ (name key roll) (key-value (range (dice-count dice-sides modifier)) ...) ...)
     (define name
       (case-lambda
         (() (list (cons key-value (list (cons 'range (list dice-count dice-sides modifier)) ...)) ...))
         ((key) (cond ((equal? key key-value)
                       (list (cons 'range (list dice-count dice-sides modifier)) ...))
                      ...
                      (else (error 'name "unknown key" key))))
         ((key roll)
          (cond ((equal? key key-value)
                 (cond ((range-test roll range)
                        (formula-value (list dice-count dice-sides modifier)))
                       ...
                       (else (error 'name "roll out of range for" key-value roll))))
                ...
                (else (error 'name "unknown key" key)))))))))

(define (formula-table-min table) (apply min (map (lambda (e) (formula-min (cdr e))) table)))
(define (formula-table-max table) (apply max (map (lambda (e) (formula-max (cdr e))) table)))

(define (formula-table-description table)
  (string-intersperse
   (map (lambda (e) (sprintf "~a: ~a" (range-text (car e)) (formula-text (cdr e)))) table)
   ", "))

(define (keyed-formula-table-min keyed-table)
  (apply min (map (lambda (kv) (formula-table-min (cdr kv))) keyed-table)))
(define (keyed-formula-table-max keyed-table)
  (apply max (map (lambda (kv) (formula-table-max (cdr kv))) keyed-table)))

(define (keyed-formula-table-description keyed-table)
  (string-intersperse
   (map (lambda (kv) (sprintf "~a: ~a" (car kv) (formula-table-description (cdr kv))))
        keyed-table)
   ".  "))

;; (formula-field-li field-name label meta-dice-count meta-dice-sides table)
;;
;; As roll-field-li, for a define-formula-table table. Unlike a
;; name-lookup table, "Choose" enters the final value directly (there is
;; no roll surrogate to look up), so min/max come from the range of
;; values the formulas can actually produce, not from the meta-roll's
;; range.
(define (formula-field-li field-name label meta-dice-count meta-dice-sides table)
  (let* ((fname (symbol->string field-name))
         (roll-id (string-append fname "-roll"))
         (choose-id (string-append fname "-choose"))
         (chosen-name (string-append "chosen-" fname))
         (lo (formula-table-min table))
         (hi (formula-table-max table)))
    `(li (b ,label)
         (br)
         (input (@ (type "radio") (id ,roll-id) (name ,fname)
                   (value "Roll") (checked)))
         (label (@ (for ,roll-id))
                ,(sprintf "Roll ~aD~a, then: ~a" meta-dice-count meta-dice-sides
                          (formula-table-description table)))
         (br)
         (input (@ (type "radio") (id ,choose-id) (name ,fname)
                   (value "Choose")))
         (label (@ (for ,choose-id)) ,(sprintf "Choose ~a-~a" lo hi))
         " "
         (label (@ (for ,chosen-name)) ,(sprintf "Chosen ~a:" label))
         (input (@ (type "number") (id ,chosen-name) (name ,chosen-name)
                   (min ,lo) (max ,hi))))))

;; (keyed-formula-field-li field-name label meta-dice-count meta-dice-sides key-label keyed-table)
;;
;; As formula-field-li, for a define-keyed-formula-table table.
(define (keyed-formula-field-li field-name label meta-dice-count meta-dice-sides key-label keyed-table)
  (let* ((fname (symbol->string field-name))
         (roll-id (string-append fname "-roll"))
         (choose-id (string-append fname "-choose"))
         (chosen-name (string-append "chosen-" fname))
         (lo (keyed-formula-table-min keyed-table))
         (hi (keyed-formula-table-max keyed-table)))
    `(li (b ,label)
         (br)
         (input (@ (type "radio") (id ,roll-id) (name ,fname)
                   (value "Roll") (checked)))
         (label (@ (for ,roll-id))
                ,(sprintf "Roll ~aD~a (meaning depends on ~a), then: ~a"
                          meta-dice-count meta-dice-sides key-label
                          (keyed-formula-table-description keyed-table)))
         (br)
         (input (@ (type "radio") (id ,choose-id) (name ,fname)
                   (value "Choose")))
         (label (@ (for ,choose-id)) ,(sprintf "Choose ~a-~a" lo hi))
         " "
         (label (@ (for ,chosen-name)) ,(sprintf "Chosen ~a:" label))
         (input (@ (type "number") (id ,chosen-name) (name ,chosen-name)
                   (min ,lo) (max ,hi))))))

;; -------------------------------------------------------------------
;; Resolving a formula field's submitted value. Unlike resolve-field,
;; "Choose" is NOT passed through `lookup': for a formula table there is
;; no roll surrogate to look up, the user is choosing the final value.

(define-syntax resolve-formula-field
  (syntax-rules ()
    ((_ field lookup dice-expr)
     (if (string=? ($ (symbol->string 'field)) "Roll")
         (lookup dice-expr)
         (string->number ($ (string-append "chosen-" (symbol->string 'field))))))))

(define-syntax resolve-keyed-formula-field
  (syntax-rules ()
    ((_ field lookup key dice-expr)
     (if (string=? ($ (symbol->string 'field)) "Roll")
         (lookup key dice-expr)
         (string->number ($ (string-append "chosen-" (symbol->string 'field))))))))
