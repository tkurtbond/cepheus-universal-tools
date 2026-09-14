;;; cu-unified.scm -- Unified Cepheus Universal Tools web app.
;;;
;;; Combines cu-arcs.scm, cu-worlds.scm and cu-systems.scm into a
;;; single running site. Each app keeps its own entry page at its own
;;; path ("/arcs", "/worlds", "/systems" respectively -- see the note
;;; at the top of each of those files); this module additionally
;;; registers a hub page at "/" with a button to each one.
;;;
;;; awful --port=8100 cu-unified.scm
(include "cu-arcs.scm")
(include "cu-worlds.scm")
(include "cu-systems.scm")

(module cu-unified (run)

(import scheme)
(import (chicken base))
(import awful)
(import (prefix cu-arcs arcs-))
(import (prefix cu-worlds worlds-))
(import (prefix cu-systems systems-))

;; Registers this module's own hub page, then each sub-app's pages in
;; turn. Called explicitly at the bottom of this module for the
;; interpreted `awful cu-unified.scm` dev workflow, and again by the
;; compiled awful-main entry point (from inside awful-start) -- the
;; second registration is harmless, same as in each sub-app.
(define (run . args)

(define-session-page (main-page-path)
  (lambda ()
    `((h3 "Cepheus Universal Tools")
      (p "Choose a generator:")
      (form (@ (action "/arcs"))
            (input (@ (type "submit") (value "Alien Race Creation"))))
      (form (@ (action "/worlds"))
            (input (@ (type "submit") (value "Creating Worlds"))))
      (form (@ (action "/systems"))
            (input (@ (type "submit") (value "System Generation")))))))

(arcs-run)
(worlds-run)
(systems-run))

(run)

)
