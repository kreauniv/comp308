#lang racket

#|

oops - an Object Oriented Programming System
     - or Object Oriented Programming in Scheme

1. Everything is an object
2. All actions happen via message passing to objects

Use simple lists to represent expressions.

(<target> <selector> <arg1> <arg2> ...)

Object = Dispatcher

(λ (self selector . args)
    .....
    )

(block (a b c d)
  <mesage-send1>
  <mesage-send2>
  ...
  <message-sendN>)

((block ....) invoke 23)

2.3 42.76
"strings"
#t #f

(2.3 sqrt)
(2.3 + (34 * 2))

|#

(define (oops-expr? expr)
  (or (oops-literal? expr)
      (symbol? expr)
      (oops-message-send? expr)
      (oops-block? expr)))

(define (oops-literal? expr)
  (or (number? expr)
      (string? expr)
      (boolean? expr)))
  
(define (oops-message-send? expr)
  (and (list? expr)
       (>= (length expr) 2)
       (oops-expr? (first expr))
       (symbol? (second expr))
       (all-oops-exprs? (rest (rest expr)))))

(define (oops-block? expr)
  (and (list? expr)
       (>= (length expr) 2)
       (equal? (first expr) 'block)
       (list? (second expr))
       (all-symbols? (second expr))
       (all-oops-exprs? (rest (rest expr)))))

(define (all-satisfy? predicate list)
  (if (empty? list)
      #t
      (if (not (predicate (first list)))
          #f
          (all-satisfy? predicate (rest list)))))

(define all-oops-exprs? (λ (list) (all-satisfy? oops-expr? list)))
(define all-symbols? (λ (list) (all-satisfy? symbol? list)))

(define empty-env empty)
(define (extend-env sym val env)
  (cons (list sym val) env))
(define (lookup-env sym env)
  (match (assoc sym env)
    [(list sym val) val]
    [_ (raise-argument-error 'lookup-env "Defined symbol" sym)]))
(define (extend-bindings syms vals env)
  (if (empty? syms)
      env
      (extend-bindings (rest syms)
                       (rest vals)
                       (extend-env (first syms) (first vals) env))))

(define (oops expr env)
  (cond
    [(symbol? expr) (lookup-env expr env)]
    [(number? expr) (oops-number expr)]
    [(string? expr) (oops-string expr)]
    [(boolean? expr) (oops-bool expr)]
    [(oops-block? expr)
     (oops-block env (second expr) (rest (rest expr)))]
    [(oops-message-send? expr)
     (let ([target (oops (first expr) env)]
           [selector (second expr)]
           [args (map (λ (expr) (oops expr env)) (rest (rest expr)))])
       (oops-send target selector args))]
    [#t (raise-argument-error 'oops "Valid OOPS expression" expr)]))

; (target self selector args...)
(define (oops-send target selector args)
  (apply target (cons target (cons selector args))))

(define (oops-number n)
  (λ (self sel . args)
    (match sel
      ['$value n] ; Only for implementation use.
      ['+ (oops-number (+ n (oops-send (first args) '$value empty)))]
      ['- (oops-number (- n (oops-send (first args) '$value empty)))]
      ['* (oops-number (* n (oops-send (first args) '$value empty)))]
      ['/ (oops-number (/ n (oops-send (first args) '$value empty)))]
      ['< (oops-bool (< n (oops-send (first args) '$value empty)))]
      ['<= (oops-bool (<= n (oops-send (first args) '$value empty)))]
      ['> (oops-bool (> n (oops-send (first args) '$value empty)))]
      ['>= (oops-bool (>= n (oops-send (first args) '$value empty)))]
      ['== (oops-bool (equal? n (oops-send (first args) '$value empty)))]
      ['description (oops-string (number->string n))]
      [_ (raise-argument-error 'oops-number "Valid selector for Number" sel)])))

(define (oops-string s)
  (λ (self sel . args)
    (match sel
      ['$value s]
      ['print (display s) self]
      ['++ (oops-string (string-append s (oops-send (first args) '$value empty)))]
      ['description self]
      [_ (raise-argument-error 'oops-string "Valid sel for String" sel)])))

(define (oops-bool b)
  (if b oops-true oops-false))

(define oops-true
  (λ (self sel . args)
    (match sel
      ['if (oops-send (first args) 'invoke empty)]
      ['not oops-false]
      ['and (first args)]      
      ['or oops-true]
      ['description (oops-string "True")]
      [_ (raise-argument-error 'oops-true "Boolean selector" sel)])))

(define oops-false
  (λ (self sel . args)
    (match sel
      ['if (oops-send (second args) 'invoke empty)]
      ['not oops-true]
      ['and oops-false]
      ['or (first args)]
      ['description (oops-string "False")]
      [_ (raise-argument-error 'oops-false "Boolean selector" sel)])))
      
(define (oops-block env formals body)
  (λ (self sel . args)
    (match sel
      ['invoke (let ([env2 (extend-bindings formals args env)])
                 (oops-eval-body env2 body self))]
      ['description (oops-string "[Block]")]
      [_ (raise-argument-error 'oops-block "Valid block selector" sel)])))

(define (oops-eval-body env body lastval)
  (if (empty? body)
      lastval
      (oops-eval-body env (rest body) (oops (first body) env))))









  