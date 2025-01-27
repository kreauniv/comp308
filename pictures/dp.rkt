#lang typed/racket

(require racket/match)
(require racket/control)

(define-type Dims (Vectorof Positive-Integer))
(struct Zero ([dims : Dims]) #:transparent)

(struct (t) TensorS ([dims : Dims]
                     [x : (Vectorof t)]
                     [dx : (Tensor t)]) #:transparent)

(define-type (Tensor t) (U Zero (TensorS t)))

(define dims #(3 2))
(define z (Zero dims))
(define t (TensorS dims #(2.0 3.0 4.0 5.0 6.0 7.0) z))

(: dims-match? (-> Dims Dims Boolean))
(define (dims-match? d1 d2)
  (and (equal? (vector-length d1) (vector-length d2))
       (let loop ([i 0] [n (vector-length d1)])
         (if (< i n)
             (if (equal? (vector-ref d1 i) (vector-ref d2 i))
                 (loop (+ i 1) n)
                 #f)
             #t))))

(: tdims (All (t) (-> (Tensor t) Dims)))
(define (tdims t)
  (if (Zero? t)
      (Zero-dims t)
      (TensorS-dims t)))

(: tsize (All (t) (-> (Tensor t) Positive-Integer)))
(define (tsize t)
  (let ([d (tdims t)])
    (let loop ([i 0] [p : Positive-Integer 1] [n (vector-length d)])
      (if (< i n)
          (loop (+ i 1) (* p (vector-ref d i)) n)
          p))))
#|
(define (broadcast op argixs argv)
  (if (let loop ([i 1] [N (vector-length argixs)] [NA (vector-length argv)])
        (if (< i N)
            (if (and (dims-match? (vector-ref argv (vector-ref argixs i))
                             (vector-ref argv (vector-ref argixs 0)))
                (loop (+ i 1) N NA)
                #f)))
      
            

(: tadd (All (t) (-> (Tensor t) (Tensor t) (Tensor t))))
(define (tadd t1 t2)
  (if (dims-match? (TensorS-dims t1) (TensorS-dims t2))
      (if (Zero? t1)
          t2
          (if (Zero? t2)
              t1
              (TensorS (TensorS-dims t1)
                       (let ([v (make-vector 
          



|#