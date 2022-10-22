#lang racket

#|

set of variables in some state (set ...values..)
program progresses
set of variables in a narrower state (smaller (set ...values...))

variables : Unknown -> Known
"goals"

Set of bindings for variables.
BSet - association list
((A 3)
 (B C)
 (C D))

|#

(struct Var (name) #:transparent)
; Var Var? Var-name
; Distinct according to eq? eqv?

(define empty-bset empty)
(define (extend var value bset)
  (cons (list var value) bset))
(define (valid-bset? bset)
  (and (list? bset)
       (andmap (λ (item)
                 (and (list? item)
                      (equal? (length item) 2)
                      (Var? (first item))))
               bset)
       ; Each variable occurs only once in the key position,
       ; or does not occur at all
       ))

(define (walk var bset)
  (let ([m (and (Var? var) (assv var bset))])
    ; m is either
    (if m
        ; (list var value)
        (if (Var? (second m))
            (walk (second m) bset)
            (second m))
        ; #f
        var)))

; A = B [bset]
; (walk A bset) = (walk B bset)
; 2 = 3
; 3 = A      ; ((A 3) . bset)
; "unification" :: A -> B -> BSet -> BSet
(define (unify A B bset)
  (let ([Av (walk A bset)]
        [Bv (walk B bset)])
  (cond
    [(and (Var? Av) (Var? Bv) (eq? Av Bv))
     bset]
    [(Var? Av)
     (extend Av Bv bset)]
    [(Var? Bv)
     (extend Bv Av bset)]
    [(and (pair? Av)
          (pair? Bv))
     (if (empty? Av)
         (if (eq? Av Bv)
             bset
             #f)
         (if (empty? Bv)
             #f
             (let ([b2 (unify (car Av) (car Bv) bset)])
               (unify (cdr Av) (cdr Bv) b2))))]
    [(eq? Av Bv)
     bset]
    [else #f])))

(define A (Var 'a))
(define B (Var 'b))

; (cons A 3) = (cons 4 B)
; A = 4 & 3 = B
; 

  
       