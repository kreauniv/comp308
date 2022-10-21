#lang racket

(struct Var (name) #:transparent)

(define (samevar? A B) (and (Var? A) (Var? B) (eq? A B)))

; A BSet or "binding set" is a set of bindings
; of variables to values. Each variable occurs
; only once as a key. We model a BSet using an
; association list as usual, with that extra constraint
; assumed.
(define empty-bset empty)
(define (extend A val bset)
  (cons (list A val) bset))


; walk is the act of looking up a variable in a given BSet.
; Since a variable could be bound to another variable, we
; keep repeating the lookup process until we find a value.
; If the value is itself a variable, then it should not
; appear as a key in the BSet.
(define (walk A bset)
  (let ([m (and (Var? A) (assv A bset))])
    (if m
        (walk (second m) bset)
        A)))

; Unification is a procedure that assets the equality of
; two entities. In this case, we may assert variables to
; be equal or values to be equal or variables to be
; equal to values. In the case where unification is expected
; to succeed, it may produce an augmented BSet with new
; associations under which the unification was proved to
; be feasible. Otherwise it returns #f, indicating that
; the terms cannot be unified.
(define (unify/basic A B bset)
  (let ([Av (walk A bset)]
        [Bv (walk B bset)])
    (cond
      [(samevar? Av Bv)
       bset]
      [(Var? Av)
       (extend Av Bv bset)]
      [(Var? Bv)
       (extend Bv Av bset)]
      [(equal? Av Bv)
       bset]
      [else #f])))


; We can generalize this notion of unification to lists also.
; Two lists are said to unify successfully if they are of the
; same length and all corresponding terms in the two lists unify
; succesfully. If any one such unification fails, the two lists
; are declared as not unifiable.
(define (unify/list-v1 A B bset)
  (let ([Av (walk A bset)]
        [Bv (walk B bset)])
    (cond
      [(samevar? Av Bv)
       bset]
      [(Var? Av)
       (extend Av Bv bset)]
      [(Var? Bv)
       (extend Bv Av bset)]
      ; Av and Bv are no longer variables.
      ; They're ordinary values.
      [(and (list? Av)
            (list? Bv)
            (equal? (length Av) (length Bv)))
       (if (empty? Av)
           (if (equal? Av Bv)
               bset
               #f)
           (let ([b2 (unify/list-v1 (first Av) (first Bv) bset)])
             (if b2
                 (unify/list-v1 (rest Av) (rest Bv) b2)
                 #f)))]
      [(equal? Av Bv)
       bset]
      [else #f])))

; unify/list-v1 has a bug.
; Try the following -
; (define b (unify/list-v1 A (list 1 A) empty-bset))
; (unify/list-v1 A (list B A) b)
; The second unification will result in an infinite loop.
; To resolve this, we can place the constraint that
; when we're defining A to some value, then A cannot occur
; in that value if the value happens to be a list.
; So we need an occurs? check.

; Assume A is a Var
(define (occurs-in-list? A B)
  (cond
    [(Var? B)
     (eq? A B)]
    [(list? B)
     (ormap (λ (item) (occurs-in-list? A item)) B)]
    [else #f]))

; We now define a bug-free version of unify that will
; always terminate.
(define (unify/list A B bset)
  (let ([Av (walk A bset)]
        [Bv (walk B bset)])
    (cond
      [(samevar? Av Bv)
       bset]
      [(and (Var? Av) (not (occurs-in-list? Av Bv)))
       (extend Av Bv bset)]
      [(and (Var? Bv) (not (occurs-in-list? Bv Av)))
       (extend Bv Av bset)]
      ; Av and Bv are no longer variables.
      ; They're ordinary values.
      [(and (list? Av)
            (list? Bv)
            (equal? (length Av) (length Bv)))
       (if (empty? Av)
           (if (equal? Av Bv)
               bset
               #f)
           (let ([b2 (unify/list (first Av) (first Bv) bset)])
             (if b2
                 (unify/list (rest Av) (rest Bv) b2)
                 #f)))]
      [(equal? Av Bv)
       bset]
      [else #f])))

; We can further generalize support for lists to
; "functor expressions" as in Prolog.
(struct FExpr (functor args) #:transparent)
(define (valid-fexpr? e)
  (and (FExpr? e)
       (symbol? (FExpr-functor e))
       (list? (FExpr-args e))))

; Two functor expressions are said to unify if their
; functors are the same and each of their args also unify.
; With that definition, we provide a (for the moment)
; complete unification.

(define (occurs? A B)
  (cond
    [(Var? B)
     (eq? A B)]
    [(list? B)
     (ormap (λ (item) (occurs? A item)) B)]
    [(valid-fexpr? B)
     (occurs? A (FExpr-args B))]
    [else #f]))

(define (unify A B bset)
  (let ([Av (walk A bset)]
        [Bv (walk B bset)])
    (cond
      [(samevar? Av Bv)
       bset]
      [(and (Var? Av) (not (occurs? Av Bv)))
       (extend Av Bv bset)]
      [(and (Var? Bv) (not (occurs? Bv Av)))
       (extend Bv Av bset)]
      ; Av and Bv are no longer variables.
      ; They're ordinary values.
      [(and (list? Av)
            (list? Bv)
            (equal? (length Av) (length Bv)))
       (if (empty? Av)
           (if (equal? Av Bv)
               bset
               #f)
           (let ([b2 (unify (first Av) (first Bv) bset)])
             (if b2
                 (unify (rest Av) (rest Bv) b2)
                 #f)))]
      [(and (valid-fexpr? Av)
            (valid-fexpr? Bv)
            (equal? (FExpr-functor Av) (FExpr-functor Bv)))
       (unify (FExpr-args Av) (FExpr-args Bv) bset)]
      [(equal? Av Bv)
       bset]
      [else #f])))

; Now, we're ready to define the simplest "goal".
; In principle, the functionality of eq is pretty
; much the same as unify. Except that it returns
; either a list of one bset or an empty list if
; the two things couldn't be equated.
(define (eq A B)
  (λ (bset)
    (let ([m (unify A B bset)])
      (if m
          (list m)
          empty))))

; Use list concatenation as "or" to define
; "disjunction" operation on goals.
(define (disj goalA goalB)
  (λ (bset)
    (append (goalA bset) (goalB bset))))

; Use sequential goal satisfaction to define "and"
; a.k.a. "conjunction".
(define (conj goalA goalB)
  (λ (bset)
    (apply append (map goalB (goalA bset)))))

; A simple predicate to create new variables that can
; be given to goals to work on.
; Example:
; (fresh '(a b)
;        (λ (A B)
;           (conj (eq A 1) (disj (eq B 2) (eq B 3)))))
; The return result of goalproc is expected to be a goal.
(define (fresh varnames goalproc)
  (let ([vars (map Var varnames)])
    (apply goalproc vars)))

  