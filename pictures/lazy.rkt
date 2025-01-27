#lang lazy

(define (step2 n) (+ n 2))

(define (map f ls)
  (if (empty? ls)
      empty
      (cons (f (car ls)) (map f (cdr ls)))))

(define odds (cons 1 (map step2 odds)))

void