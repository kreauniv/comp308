#lang typed/racket

(struct Zero ())
(struct TaylorZPair
  ([x : Float]
   [dx : TaylorZ]))
(define-type TaylorZ (U Zero TaylorZPair))

(require racket/match)

(: print-taylor (-> TaylorZ))
(define (print-taylor t)
  (cond
    [(Zero? t)
     (display "Zero")]
    [(TaylorZPair? t)
     (display "Taylor(")
     (display (TaylorZPair-x t))
     (display ",")
     (print-taylor (TaylorZPair-dx t))
     (display ")")]))


