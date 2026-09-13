;;; -*- geiser-scheme-implementation: chicken -*-
(module dice (make-d make-roll make-* make-+ highest lowest
                     ova-roll)

(import scheme)
(import loop)
(import format)
(import (chicken base))
(import (chicken port))
(import (chicken random))
(import (chicken sort))
(import (math base))
(import srfi-69)
(import sequences)
(import (prefix (only srfi-1 take drop) srfi-1-))

(define (make-d num-sides)
  (lambda () (+ 1 (pseudo-random-integer num-sides))))

(define (make-roll num-rolls d)
  (lambda () (loop repeat num-rolls collect (d))))

(define (make-* multiplier)
  (lambda (n) (* n multiplier)))

(define (make-+ addend)
  (lambda (n) (+ n addend)))

(define (sum-rolls numbers)
  ;; Display numbers in list as an infix expression of their sum.
  ;; (2 2 2) displays 2+2+2
  (loop for number in numbers
        for i from 1
        if (> i 1) do (format #t "+")
        do (format #t "~d" number)))

(define (hilo n rolls compare)
  (let* ((rolls (sort rolls compare))
         (taken (srfi-1-take rolls n))
         (dropped (srfi-1-drop rolls n))
         (result (sum taken)))
    (define (describe port)
      (format port "~d=" result)
      (parameterize ((current-output-port port))
        (sum-rolls taken))
      (format port ", dropped ")
      (loop for roll in dropped
            for i from 1
            if (> i 1) do (format port ", ")
            do (format port "~d" roll)))
    (values result (call-with-output-string describe))))

(define (highest n rolls)
  (hilo n rolls >))

(define (lowest n rolls)
  (hilo n rolls <))

(define (ova-section rolls)
  ;; Section the rolls into lists containing all the rolls of the same values:
  ;; (2 5 2 3 3 2 6 4 6 4) => ((6 6) (5) (4 4) (3 3) (2 2 2))
  (define (iter coll rolls)
    (if (null? rolls)
        coll
        (let* ((i (car rolls))
               (pred (lambda (n) (= n i)))
               (is (take pred rolls))
               (rolls (drop pred rolls)))
          (iter (cons is coll) rolls))))
  (iter '() (sort rolls <)))

(define (ova-label sections)
  ;; Label each list of numbers with their sum, and sort by their sum:
  ;; ((6 6) (5) (4 4) (3 3) (2 2 2)) =>
  ;; (((6 6) 12) ((4 4) 8) ((3 3) 6) ((2 2 2) 6) ((5) 5))
  (sort (loop for section in sections collect (list section (apply + section)))
        (lambda (section1 section2)
          ;;(format #t "section1: ~s section2: ~s~%" section1 section2)
          (> (cadr section1) (cadr section2)))))

(define (ova-positive n)
  (let* ((rolls ((make-roll n (make-d 6))))
         (sections (ova-section rolls))
         (labeled (ova-label sections))
         (result (cadar labeled)))
    (define (describe port)
      (parameterize ((current-output-port port)) 
        ;; Display all the numbers in a OVA roll, with each set of matches
        ;; summed up, in infix notation:
        ;; (((6 6) 12) ((4 4) 8) ((3 3) 6) ((2 2 2) 6) ((5) 5)) displays
        ;; 12=6+6, 8=4+4, 6=3+3, 6=2+2+2, 5=5
        (format #t "~d from " (cadar labeled))
        (loop for section in labeled
              for i from 1
              if (> i 1) do (format #t ", ")
              do (begin (format #t "~d=" (cadr section))
                        (sum-rolls (car section))))))
    (values result (call-with-output-string describe))))

(define (ova-negative n)
  (let* ((rolls (sort ((make-roll (abs n) (make-d 6))) <))
         (result (car rolls)))
    (define (describe port)
      (format port "~d from " result)
      (loop for number in rolls
            for i from 1
            if (> i 1) do (format port "<=")
            do (format port "~d" number))
      (format port "~%"))
    (values result (call-with-output-string describe))))

(define (ova-roll n)
  (assert (not (= n 0)) "Zero is an invalid number of dice to roll.")
  (if (< n 0)
      (ova-negative n)
      (ova-positive n)))

(define (make-ova n)
  (lambda ()
    (ova-roll n)))
      

;;(pp (loop repeat 100 do (ova-display (ova-label (ova-section (r10d6))))))

(define (main)
  #f)

(cond-expand
  (compiling
   (main))
  (else
   (define (test)
     (define d6 (make-d 6))
     (define r3d6 (make-roll 3 d6))
     (define r10d6 (make-roll 10 d6))
     (format #t "r10d6: ~a~%" (r10d6))
     )))  
)
