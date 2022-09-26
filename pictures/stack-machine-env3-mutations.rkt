#lang racket

(require racket/match)

; This is the "proper lexical scoping" version of the stack machine with environment.
; It also adds support for storage and "mutable boxes".

(define (top stack) (first stack))
(define (push val stack) (cons val stack))
(define (pop stack) (rest stack))

(struct State (stack bindings storage))
(struct Block (bindings code))
(struct Box (ref))

(define (stack-machine program state)
  (if (empty? program)
      state
      (let ([instr (first program)])
        (stack-machine
         (rest program)
         (process-instruction instr state)))))


(define (print-state state)
  (match state
    [(State stack bindings storage)
     (display stack)
     (display "\n")
     (display bindings)
     (display "\n")
     (display storage)]))

(define (process-instruction instr state)
  (match state
    [(State stack bindings storage)
     (cond
       [(equal? instr 'box)
        (let ([r (newref storage)])
          (State (push (Box (first r)) stack) bindings (second r)))]
       [(equal? instr 'unbox)
        (if (Box? (top stack))
            (State (push (read-storage (Box-ref (top stack)) storage) stack)
                   bindings
                   storage)
            (raise-argument-error 'unbox
                                  "Box on top of stack"
                                  (top stack)))]
       [(equal? instr 'setbox)
        (if (Box? (top stack))
            (State (pop (pop stack)) bindings (write-storage (Box-ref (top stack)) (top (pop stack)) storage))
            (raise-argument-error 'setbox
                                  "Box on top of stack"
                                  (top stack)))]
       [(equal? instr 'do)
        (match (top stack)
          [(Block deftime-bindings program)
           (stack-machine program (State (pop stack) deftime-bindings storage))]
          [_ (raise-argument-error 'process-instruction
                                   "Block must be on top of stack for 'do instruction"
                                   stack)])]
       [(and (list? instr)
             (equal? (first instr) 'block))
        (State (push (Block bindings (rest instr)) stack) bindings storage)]       
       [(and (list? instr)
             (equal? (first instr) 'def))
        (if (symbol? (second instr))
            (State (pop stack) (cons (list (second instr) (top stack)) bindings storage))
            (raise-argument-error 'process-instruction
                                  "(def <symbol>) instruction expects a symbol"
                                  instr))]
       [(equal? instr '+)
        (State (push (+ (top stack) (top (pop stack))) (pop (pop stack))) bindings storage)]
       [(equal? instr '-)
        (State (push (- (top stack) (top (pop stack))) (pop (pop stack))) bindings storage)]
       [(equal? instr '*)
        (State (push (* (top stack) (top (pop stack))) (pop (pop stack))) bindings storage)]
       [(equal? instr '/)
        (State (push (/ (top stack) (top (pop stack))) (pop (pop stack))) bindings storage)]
       [(equal? instr 'dup)
        (State (push (top stack) stack) bindings storage)]
       [(equal? instr 'rot2)
        (State (push (top (pop stack))
                     (push (top stack)
                           (pop (pop stack))))
               bindings storage)]
       [(equal? instr 'rot3)
        (State (push (top (pop stack))
                     (push (top (pop (pop stack)))
                           (push (top stack) (pop (pop (pop stack))))))
               bindings storage)]
       [(equal? instr 'rot4)
        (State (push (top (pop stack))
                     (push (top (pop (pop stack)))
                           (push (top (pop (pop (pop stack))))
                                 (push (top stack)
                                       (pop (pop (pop (pop stack))))))))
               bindings storage)]
       [(equal? instr 'drop)
        (State (pop stack) bindings storage)]
       [(equal? instr 'sqrt)
        (State (push (sqrt (top stack)) (pop stack)) bindings storage)]
       [(number? instr)
        (State (push instr stack) bindings storage)]
       ; We need to check this case at the end because
       ; predefined instructions like 'dup and 'drop are also symbols.
       [(symbol? instr)
        (let ([val (assoc instr bindings)])
          (if val
              (State (push (second val) stack) bindings  storage)
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
            