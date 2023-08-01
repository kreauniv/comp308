#lang typed/racket

(provide color (struct-out color))
(provide byte-color? unit-color?)
(provide premultiply-color
         quantize-color-component
         quantize-color)
(provide white red green blue black background)

(struct (t) color ([a : t]
                   [r : t]
                   [g : t]
                   [b : t])
  #:transparent)

(define white : (color Float) (color 1.0 1.0 1.0 1.0))
(define red : (color Float) (color 1.0 1.0 0.0 0.0))
(define green : (color Float) (color 1.0 0.0 1.0 0.0))
(define blue : (color Float) (color 1.0 0.0 0.0 1.0))
(define black : (color Float) (color 1.0 0.0 0.0 0.0))
(define background : (color Float) (color 0.0 0.0 0.0 0.0))



(: byte-color? (-> Any Boolean : (color Byte)))
(define (byte-color? c)
  (and (color? c)
       (byte? (color-a c))
       (byte? (color-r c))
       (byte? (color-g c))
       (byte? (color-b c))
       #t))

(: unit-color? (-> Any Boolean : (color Float)))
(define (unit-color? c)
  (and (color? c)
       (flonum? (color-a c))
       (flonum? (color-r c))
       (flonum? (color-g c))
       (flonum? (color-b c))
       #t))

(: premultiply-color (-> (color Float) (color Float)))
(define (premultiply-color c)
  (let ([a (color-a c)])
    (color a
           (* a (color-r c))
           (* a (color-g c))
           (* a (color-b c)))))

(: quantize-color-component (-> Float Byte))
(define (quantize-color-component c)
  (assert (exact-floor (* 255.99 c)) byte?))



(: quantize-color (-> (color Number) (color Byte)))
(define (quantize-color c)
  (cond
    ([byte-color? c] c)
    ([unit-color? c]
     (let ([pc (premultiply-color c)])
       (color 255
              (quantize-color-component (color-r c))
              (quantize-color-component (color-g c))
              (quantize-color-component (color-b c)))))
    (else (raise-argument-error 'unknown-color
                                "Either (color Byte) or (color Float)"
                                c))))