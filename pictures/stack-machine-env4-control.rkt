#lang racket

(require racket/match)

; This is the "proper lexical scoping" version of the stack machine with environment.
; It also adds support for storage and "mutable boxes". It also adds "call" and "goto"
; primitives for full support for continuations in our stack language.

(define (top stack) (first stack))
(define (push val stack) (cons val stack))
(define (pop stack) (rest stack))

(struct State (stack bindings storage))
(struct Block (bindings code))
(struct Box (ref))

(define (stack-machine/ret program state return)
  (if (empty? program)
      (return state)
      (let ([instr (first program)])
        (process-instruction/ret instr state
                                 (λ (s)
                                   (stack-machine/ret (rest program) s return))))))



(define (print-state state)
  (match state
    [(State stack bindings storage)
     (display stack)
     (display "\n")
     (display bindings)
     (display "\n")
     (display storage)]))

(define (process-instruction/ret instr state return)
  (match state
    [(State stack bindings storage)
     (cond
       [(equal? instr 'call)
        (match (top stack)
          [(Block deftime-bindings program)
           (stack-machine/ret program
                              (State (push (λ (s) (return (State (State-stack s) bindings (State-storage s))))
                                           (pop stack))
                                     deftime-bindings
                                     storage)
                              return)]
          [_ (raise-argument-error 'call
                                   "Block on top of stack"
                                   (top stack))])]
       [(equal? instr 'goto)
        (if (procedure? (top stack))
            ((top stack) (State (pop stack) bindings storage))
            (raise-argument-error 'goto
                                  "Continuation on top of stack"
                                  (top stack)))]
       [(equal? instr 'box)
        (let ([r (newref storage)])
          (return (State (push (Box (first r)) stack) bindings (second r))))]
       [(equal? instr 'unbox)
        (if (Box? (top stack))
            (return (State (push (read-storage (Box-ref (top stack)) storage) stack)
                           bindings
                           storage))
            (raise-argument-error 'unbox
                                  "Box on top of stack"
                                  (top stack)))]
       [(equal? instr 'setbox)
        (if (Box? (top stack))
            (return (State (pop (pop stack))
                           bindings
                           (write-storage (Box-ref (top stack)) (top (pop stack)) storage)))
            (raise-argument-error 'setbox
                                  "Box on top of stack"
                                  (top stack)))]
       [(equal? instr 'do)
        (match (top stack)
          [(Block deftime-bindings program)
           (stack-machine/ret program (State (pop stack) deftime-bindings storage return))]
          [_ (raise-argument-error 'process-instruction
                                   "Block must be on top of stack for 'do instruction"
                                   stack)])]
       [(and (list? instr)
             (equal? (first instr) 'block))
        (return (State (push (Block bindings (rest instr)) stack) bindings storage))]       
       [(and (list? instr)
             (equal? (first instr) 'def))
        (if (symbol? (second instr))
            (return (State (pop stack) (cons (list (second instr) (top stack)) bindings storage)))
            (raise-argument-error 'process-instruction
                                  "(def <symbol>) instruction expects a symbol"
                                  instr))]
       [(equal? instr '+)
        (return (State (push (+ (top stack) (top (pop stack))) (pop (pop stack))) bindings storage))]
       [(equal? instr '-)
        (return (State (push (- (top stack) (top (pop stack))) (pop (pop stack))) bindings storage))]
       [(equal? instr '*)
        (return (State (push (* (top stack) (top (pop stack))) (pop (pop stack))) bindings storage))]
       [(equal? instr '/)
        (return (State (push (/ (top stack) (top (pop stack))) (pop (pop stack))) bindings storage))]
       [(equal? instr 'dup)
        (return (State (push (top stack) stack) bindings storage))]
       [(equal? instr 'rot2)
        (return (State (push (top (pop stack))
                             (push (top stack)
                                   (pop (pop stack))))
                       bindings storage))]
       [(equal? instr 'rot3)
        (return (State (push (top (pop stack))
                             (push (top (pop (pop stack)))
                                   (push (top stack) (pop (pop (pop stack))))))
                       bindings storage))]
       [(equal? instr 'rot4)
        (return (State (push (top (pop stack))
                             (push (top (pop (pop stack)))
                                   (push (top (pop (pop (pop stack))))
                                         (push (top stack)
                                               (pop (pop (pop (pop stack))))))))
                       bindings storage))]
       [(equal? instr 'drop)
        (return (State (pop stack) bindings storage))]
       [(equal? instr 'sqrt)
        (return (State (push (sqrt (top stack)) (pop stack)) bindings storage))]
       [(number? instr)
        (return (State (push instr stack) bindings storage))]
       ; We need to check this case at the end because
       ; predefined instructions like 'dup and 'drop are also symbols.
       [(symbol? instr)
        (let ([val (assoc instr bindings)])
          (if val
              (return (State (push (second val) stack) bindings  storage))
              (raise-argument-error 'process-instruction
                                    "Unbound symbol encountered"
                                    instr)))]
       [#t
        (raise-argument-error 'process-instruction "Valid instruction" instr)])]))


(define (make-storage) empty)

(define (newref s)
  (let ([r (+ 1 (length s))])
    (list r (cons (list r #f) s))))

(define (read-storage ref s)
  (match (assoc ref s)
    [(list ref val) val]
    [_ (raise-argument-error 'read-storage
                             "Valid reference"
                             ref)]))

(define (write-storage ref val s)
  (define (write-storage-helper s acc)
    (if (empty? s)
        acc
        (if (equal? ref (first (first s)))
            (write-storage-helper (rest s) (cons (list ref val) acc))
            (cons (list (first s) acc)))))

  (write-storage-helper s '()))


