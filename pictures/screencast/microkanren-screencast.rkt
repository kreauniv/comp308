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
    [(and (Var? Av) (not (occurs? Av Bv)))
     (extend Av Bv bset)]
    [(and (Var? Bv) (not (occurs? Bv Av)))
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

(define (occurs? A P)
  (cond
    [(eq? A P) #t]
    [(and (pair? P) (empty? P)) #f]
    [(and (pair? P) (not (empty? P)))
     (or (occurs? A (car P))
         (occurs? A (cdr P)))]
    [else #f]))
       

; (eq A B)
; A B BSet -> BSet | #f
; A = 3 or A = 4
; Goal :: BSet -> Listof BSet

(define (eq A B)
  (λ (bset)
    (let ([m (unify A B bset)])
      (if m
          (list m)
          empty))))

; bset1 :: (...)
; bset2 :: (...)
; bset3 :: (...)
;
; bset
; goalA -> (bset1 bset2)
; goalB -> (bset3)
; -> concat -> (bset1 bset2 bset3)
; "disjunction"
(define (disj goalA goalB)
  (λ (bset)
    (append (goalA bset) (goalB bset))))

; "and" = "conjunction"
(define (conj goalA goalB)
  (λ (bset)
    (apply append (map goalB (goalA bset)))))

; (disj goalA goalB) = (disj goalB goalA)
; (conj goalA goalB) = (conj goalB goalA)

; (apply append (map goalB (goalA bset)))
; =? (apply append (map goalA (goalB bset)))


; unify, conj, disj, variables, pairs
; Prolog
; A = B
; Alpha alpha
; [1,2,3]
; (cons x xs) = [x | xs]
; conj => ,
; disj => ;
; predicate(Arg1,Arg2,...)    "symbolic expressions"
; "functor"
; functor(Arg1, Arg2, ...)
; (struct AddC (x y))
; addC(x, y) === (AddC x y)
; mypredicate(A,B) :-
;     goalA(A, 23),
;     goalB(B, 45).
      


(define A (Var 'a))
(define B (Var 'b))

; (cons A 3) = (cons 4 B)
; A = 4 & 3 = B
; A = (cons 1 A)

  
       