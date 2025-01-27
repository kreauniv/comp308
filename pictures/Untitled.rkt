#lang racket

(define (sum from-number to total)
  (if (>= from-number to)
      total
      (sum (+ 1 from-number) to (+ from-number total))))

(define-syntax while
  (syntax-rules ()
    ((while pred body ...)
     (let loop () (when pred body ... (loop))))))

(define-syntax push!
  (syntax-rules ()
    ((push! listvar expr)
     (set! listvar (append listvar (list expr))))))

(define (g n)
  (define a '())
  (define i 0)
  (while (< i n)
         (define j i)
         (push! a (lambda () (* j j)))
         (set! i (+ i 1)))
  a)

(define (print-fnarray a)
  (for-each (lambda (f) (displayln (f))) a))

identifier?