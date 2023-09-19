#lang typed/racket

(define-type SimpleVal (U Boolean Integer Symbol))

(struct Var ([name : Symbol]) #:transparent)
(struct Val ([v : SimpleVal]) #:transparent)
;(struct Functor ([name : Symbol] [args : (Listof Term)]) #:transparent)
(define-type Term (U Var Val))

(struct Binding ([key : Var] [val : Term]) #:transparent)


(define-type BSet (Listof Binding))

(: extend (-> Var Term BSet BSet))
(define (extend var val bs)
  (cons (Binding var val) bs))

(: lookup (-> Var BSet (U False Term)))
(define (lookup var bs)
  (if (empty? bs)
      #f
      (if (eq? var (Binding-key (first bs)))
          (Binding-val (first bs))
          (lookup var (rest bs)))))

; For testing on the REPL
(define X (Var 'X))
(define Y (Var 'Y))
(define Z (Var 'Z))
(define K (Var 'K))
(define A (Var 'A))
(define B (Var 'B))

; In this BSet, Z ought to be equal to (Val 2)
(define bs (list (Binding X (Val 2))
                 (Binding Y (Val 'hello))
                 (Binding K X)
                 (Binding Z K)))

; walk will scan the BSet for mentions of the given
; variable on the "key" field and repeatedly walk
; the value part if the value for the key also turned out
; to be a variable. That way, walk does considerable logic
; work before unify gets to deal with other cases.
(: walk (-> Var BSet Term))
(define (walk var bs)
  (let ([b (lookup var bs)])
    (if b
        (if (Var? b)
            (walk b bs)
            b)
        var)))

; Produces a BSet if the two given terms could be unified.
; Produces #f if they couldn't be unified.
(: unify (-> Term Term BSet (U False BSet)))
(define (unify ta tb context)
  (let ([ta2 (if (Var? ta) (walk ta context) ta)]
        [tb2 (if (Var? tb) (walk tb context) tb)])
    (cond
      [(and (Val? ta2) (Val? tb2))
       (if (equal? ta2 tb2)
           context
           #f)]
      [(and (Var? ta2) (Val? tb2))
       (extend ta2 tb2 context)]
      [(and (Val? ta2) (Var? tb2))
       (extend tb2 ta2 context)]
      [(and (Var? ta2) (Var? tb2))
       (if (eq? ta2 tb2)
           ; Both variables are the same.
           ; So no need to add anything to the context.
           context
           ; We need to declare the two variables to be
           ; equal to each other in the context. Note that
           ; we don't (and shouldn't) add A->B and B->A to
           ; the context. If we did, then walk won't terminate.
           (extend ta2 tb2 context))]
      [else context])))

; For testing on the REPL
(define bs2
  (list (Binding X Y)))

; A Goal consumes a BSet as context and produces zero or more
; derived "universes" in which the goal holds true. Failure is
; indicated by returning an empty list of such "universes".
(define-type Goal (-> BSet (Listof BSet)))

; g-success is a primitive goal that always succeeds
; with the current context as the sole possible "universe".
(: g-success Goal)
(define g-success (λ (context) (list context)))

; g-failure is a primitive goal that always fails
; with an empty list of possible "universes".
(: g-failure Goal)
(define g-failure (λ (context) '()))

; A goal that succeeds with appropriate variable bindings
; if the two terms could be unified. unify is the real work
; horse behind g-equal.
(: g-equal (-> Term Term Goal))
(define (g-equal a b)
  (λ (context)
    (let ([r (unify a b context)])
      (if r
          (list r)
          '()))))

; Makes a goal that will give universes in which
; at least one of the two goals succeed.
(: g-or (-> Goal Goal Goal))
(define (g-or g1 g2)
  (λ (context)
    (let ([bs1 (g1 context)]
          [bs2 (g2 context)])
      (append bs1 bs2))))

; Makes a goal that will give universes in which
; both goals will succeed.
(: g-and (-> Goal Goal Goal))
(define (g-and g1 g2)
  (λ (context)
    (let ([bs1 (g1 context)])
      (apply append (map g2 bs1)))))

; A simple example that "searches" for a solution from
; two sets of possibilities for X and Y. Call this as
; (g-example (Var 'X) (Var 'Y))
(define g-example
  (λ ([X : Var] [Y : Var])
    (g-and (g-or (g-equal X (Val 2))
                 (g-equal X (Val 3)))
           (g-and (g-or (g-equal Y (Val 3))
                        (g-equal Y (Val 4)))
                  (g-equal X Y)))))

(define g-example-goal (g-example X Y))
(define g-example-result (g-example-goal '()))

  
