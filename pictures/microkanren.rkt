#lang racket

(struct Var (name) #:transparent)
(struct FExpr (functor args) #:transparent)

; When 'walk' is done, the result is guaranteed
; to not be found as a key in bindings.
(define (walk var bindings)
  (let ([m (assv var bindings)])
    (if m
        (walk (second m) bindings)
        var)))

; A valid functor expression has a symbol as the "functor" field
; and a true blue list as the "args" field.
(define (valid-fexpr? f)
  (and (FExpr? f)
       (symbol? (FExpr-functor f))
       (list? (FExpr-args f))))

(define (occurs? var expr)
  (cond
    [(pair? expr)
     (or (occurs? var (car expr))
         (occurs? var (cdr expr)))]
    [(valid-fexpr? expr)
     (ormap (λ (e) (occurs? var e)) (FExpr-args expr))]
    [else #f]))

(define (unify A B bindings)
  (let ([av (walk A bindings)]
        [bv (walk B bindings)])
    (cond
      [(and (Var? av) (Var? bv) (eq? av bv))
       bindings]
      [(and (Var? av) (not (occurs? av bv)))
       (extend av bv bindings)]
      [(and (Var? bv) (not (occurs? bv av)))
       (extend bv av bindings)]
      [(and (pair? av) (pair? bv))
       (let ([b2 (unify (car av) (car bv) bindings)])
         (unify (cdr av) (cdr bv) b2))]
      [(and (valid-fexpr? av)
            (valid-fexpr? bv)
            (equal? (FExpr-functor av) (FExpr-functor bv))
            (equal? (length (FExpr-args av)) (length (FExpr-args bv))))
       ; We already know how to unify lists because we know how
       ; to unify nested cons pairs!
       (unify (FExpr-args av) (FExpr-args bv) bindings)]
      [(eq? av bv)
       bindings]
      [#t #f])))
      
(define empty-bindings empty)
(define (extend var val bindings)
  (cons (list var val) bindings))

(define (eq a b)
  (λ (bindings)
    (let ([m (unify a b bindings)])
      (if m
          (list m)
          empty))))

(define (conj goalA goalB)
  (λ (bindings)
    (let ([bs (goalA bindings)])
      (apply append (map goalB bs)))))

(define (disj goalA goalB)
  (λ (bindings)
    (let ([as (goalA bindings)]
          [bs (goalB bindings)])
      (append as bs))))

(define (fresh varnames goal-proc)
  (if (equal? (procedure-arity goal-proc) (length varnames))
      (let ([vars (map Var varnames)])
        (apply goal-proc vars))
      (raise-argument-error 'fresh
                            "Expecting same number of varnames as arity of goal proc"
                            (list varnames goal-proc))))

(define a (Var "a"))
(define b (Var "b"))

(define sample-goal
  (fresh '(a b)
         (λ (a b)
           (eq (cons a b) (list 1 2 3 4 5)))))