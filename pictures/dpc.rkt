#lang racket

(require racket/match)
(require racket/control)

(define (iter items)
  (if (empty? items)
      (shift k k)
      (cons (first items) (iter (rest items)))))

