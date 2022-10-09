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


-----

TODO:
anObject -- instance of --> aClass
aClass -- instance of --> Class
aClass -- superclass --> anotherClass

DONE:
Class -- instance of --> Object
Object -- instance of --> Class
Class -- superclass --> Class
Object -- superclass --> Object

"representation"

1. aClass is responsible for defining behaviour of anObject (which is an instance of aClass).
2. aClass must have a list of methods
3. aClass must have a list of known instance variable names.
4. anObject must have a list of "properties" - (list (list 'ptyname property-object) ...)
5. properties of an object are accessible within method definitions.
6. aClass is responsible for making anObject. Happens by sending a 'new message to aClass.

(block (a b c d)
  ....
  (x + 0.5)
  self
  )

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

(define (repr obj)
  (oops-send obj '$repr empty))

(define (oops-number n)
  (λ (self sel . args)
    (match sel
      ['$repr n] ; Only for implementation use.
      ['isa oops-Number]
      ['+ (oops-number (+ n (repr (first args))))]
      ['- (oops-number (- n (repr (first args))))]
      ['* (oops-number (* n (repr (first args))))]
      ['/ (oops-number (/ n (repr (first args))))]
      ['< (oops-bool (< n (repr (first args))))]
      ['<= (oops-bool (<= n (repr (first args))))]
      ['> (oops-bool (> n (repr (first args))))]
      ['>= (oops-bool (>= n (repr (first args))))]
      ['== (oops-bool (equal? n (repr (first args))))]
      ['description (oops-string (number->string n))]
      [_ (raise-argument-error 'oops-number "Valid selector for Number" sel)])))

(define (oops-string s)
  (λ (self sel . args)
    (match sel
      ['$repr s]
      ['isa oops-String]
      ['print (display s) self]
      ['++ (oops-string (string-append s (repr (first args))))]
      ['description self]
      [_ (raise-argument-error 'oops-string "Valid sel for String" sel)])))

(define (oops-bool b)
  (if b oops-true oops-false))

(define oops-true
  (λ (self sel . args)
    (match sel
      ['$repr $t]
      ['isa oops-True]
      ['if (oops-send (first args) 'invoke empty)]
      ['not oops-false]
      ['and (first args)]      
      ['or oops-true]
      ['description (oops-string "True")]
      [_ (raise-argument-error 'oops-true "Boolean selector" sel)])))

(define oops-false
  (λ (self sel . args)
    (match sel
      ['$repr #f]
      ['isa oops-False]
      ['if (oops-send (second args) 'invoke empty)]
      ['not oops-true]
      ['and oops-false]
      ['or (first args)]
      ['description (oops-string "False")]
      [_ (raise-argument-error 'oops-false "Boolean selector" sel)])))
      
(define (oops-block env formals body)
  (let ([r (vector env formals body)])
    (λ (self sel . args)
      (match sel
        ['$repr r]
        ['isa oops-Block]
        ['invoke (let ([env2 (extend-bindings formals args env)])
                   (oops-eval-body env2 body self))]
        ['description (oops-string "[Block]")]
        [_ (raise-argument-error 'oops-block "Valid block selector" sel)]))))


; TODO: When creating an object, make its representation
; a list of property-name to property-object mappings
(define (get-object-properties obj)
  (repr obj))

; TODO: What's needed to define a class?
; 1. Class name
; 2. List of instance variable names - ordinary Racket list of symbols
; 3. List of method definitions - ordinary Racket list of (list method-name-as-symbol method)
; (vector name instvarnames methods)
(define (class-prop-names class)
  (if (equals? class (superclass-of class))
      (vector-ref (repr class) 1)
      (append (vector-ref (repr class) 1)
              (class-prop-names (superclass-of class)))))

; (m invoke target arg1 arg2 ...)
(define (oops-method class block)
  (λ (self sel . args)
    (match sel
      ['isa oops-Method]
      ['invoke (let ([target (first args)]
                     [parameters (rest args)])
                 (match (repr block)
                   [(vector env formals body)
                    (let ([props (get-object-properties target)]
                          [prop-names (class-prop-names class)])
                      (let ([visible-props (filter (λ (pv) (member (first pv) prop-names)) props)])
                        (set! env (extend-bindings formals parameters env))
                        (set! env (append visible-props env))
                        (set! env (extend-env 'self target env))
                        (oops-eval-body env body target)))]))]
      [_ (raise-argument-error 'Method "Valid method selector" sel)])))

(define (oops-var val)
  (let ([r (box val)])
    (λ (self sel . args)
      (match sel
        ['$repr r]
        ['isa oops-Var]
        ; (x get)
        ['get (unbox (repr self))]
        ; (((x := 5) get) sqrt)
        [':= (set-box! (repr self) (first args))
             self]
        [_ (raise-argument-error 'var "Valid Var selector" sel)]))))

  
(define (oops-eval-body env body lastval)
  (if (empty? body)
      lastval
      (oops-eval-body env (rest body) (oops (first body) env))))


(define oops-Class
  (λ (self sel . args)
    (match sel
      ['isa oops-Object]
      ['superclass oops-Class]
      [_ self])))

(define oops-Object
  (λ (self sel . args)
    (match sel
      ['isa oops-Class]
      ['superclass oops-Object]
      [_ self])))

(define oops-Var
  (λ (self sel . args)
    (match sel
      ['isa oops-Class]
      ['superclass oops-Object]
      [_ self])))

(define oops-Block
  (λ (self sel . args)
    (match sel
      ['isa oops-Class]
      ['superclass oops-Object]
      [_ self])))

(define oops-Number
  (λ (self sel . args)
    (match sel
      ['isa oops-Class]
      ['superclass oops-Object]
      [_ self])))

(define oops-String
  (λ (self sel . args)
    (match sel
      ['isa oops-Class]
      ['superclass oops-Object]
      [_ self])))

(define oops-True
  (λ (self sel . args)
    (match sel
      ['isa oops-Class]
      ['superclass oops-Object]
      [_ self])))

(define oops-False
  (λ (self sel . args)
    (match sel
      ['isa oops-Class]
      ['superclass oops-Object]
      [_ self])))


  