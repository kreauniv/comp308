#lang racket

(struct Var (name) #:transparent)
(struct Val (v) #:transparent)
;(struct Functor ([name : Symbol] [args : (Listof Term)]) #:transparent)

(struct Binding (key val) #:transparent)


(define (extend var val bs)
  (cons (Binding var val) bs))

(define (lookup var bs)
  (if (empty? bs)
      #f
      (if (eq? var (Binding-key (first bs)))
          (Binding-val (first bs))
          (lookup var (rest bs)))))

(define X (Var 'X))
(define Y (Var 'Y))
(define Z (Var 'Z))
(define K (Var 'K))
(define A (Var 'A))
(define B (Var 'B))

(define bs (list (Binding X (Val 2))
                 (Binding Y (Val 'hello))
                 (Binding K X)
                 (Binding Z K)))

(define (walk var bs)
  (let ([b (lookup var bs)])
    (if b
        (if (Var? b)
            (walk b bs)
            b)
        var)))

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
           context
           (extend ta2 tb2 context))]
      [else context])))
     
(define bs2
  (list (Binding X Y)))

; g-succ is a primitive goal that always succeeds
; with the current context as the sole possible "universe".
(define g-succ (λ (context) (make-generator (λ (yield)
                                              (yield context)))))

; g-fail is a primitive goal that always fails
; with an empty list of possible "universes".
(define g-fail (λ (context) (make-generator (λ (yield)
                                              #f))))

; A goal that succeeds with appropriate variable bindings
; if the two terms could be unified.
(define (g-equal a b)
  (λ (context)
    (make-generator (λ (yield)
                      (let ([r (unify a b context)])
                        (when r (yield r))
                        #f)))))

(define (g-or g1 g2)
  (λ (context)
    (make-generator (λ (yield)
                      (let ([bsg1 (g1 context)])
                        (let loop1 ([bs1 (bsg1)])
                          (if bs1
                              (begin (yield bs1)
                                     (loop1 (bsg1)))
                              (let ([bsg2 (g2 context)])
                                (let loop2 ([bs2 (bsg2)])
                                  (if bs2
                                      (begin (yield bs2)
                                             (loop2 (bsg2)))
                                      #f))))))))))


(define (g-and g1 g2)
  (λ (context)
    (make-generator (λ (yield)
                      (let ([bsg1 (g1 context)])
                        (let loop1 ([bs1 (bsg1)])
                          (if bs1
                              (let ([bsg2 (g2 bs1)])
                                (let loop2 ([bs2 (bsg2)])
                                  (if bs2
                                      (begin (yield bs2)
                                             (loop2 (bsg2)))
                                      (loop1 (bsg1)))))
                              #f)))))))

(define g-success (λ (context)
                    (make-generator (λ (yield)
                                      (yield context)
                                      #f))))
(define g-failure (λ (context)
                    (make-generator (λ (yield)
                                      #f))))

; A simple example that "searches" for a solution from
; two sets of possibilities for X and Y. Call this as
; (g-example (Var 'X) (Var 'Y))
(define g-example
  (λ (X Y)
    (g-and (g-or (g-equal X (Val 2))
                 (g-equal X (Val 3)))
           (g-and (g-or (g-equal Y (Val 3))
                        (g-equal Y (Val 4)))
                  (g-equal X Y)))))

(define (make-generator proc)
  (define yielder #f)
  (define resumer #f)
  (λ ()
    (if resumer
        (resumer #t)
        (let/cc y
          (set! yielder y)
          (proc (λ (v)
                  (let/cc r
                    (set! resumer r)
                    (yielder v))))))))

(define gfn (λ (X)
              (g-or (g-equal X (Val 2))
                    (g-equal X (Val 3)))))
(define gg (gfn (Var 'X)))
(define g1 (gg '()))

(define (g-any X vals)
  (if (empty? vals)
      g-failure
      (g-or (g-equal X (Val (first vals)))
            (g-any X (rest vals)))))

(define (g-all goals)
  (if (empty? goals)
      g-success
      (g-and (first goals) (g-all (rest goals)))))

(define g-example2
  (g-all (list (g-any X (list 10 20 30 40))
               (g-any Y (list 11 22 30 44))
               (g-equal X Y))))
