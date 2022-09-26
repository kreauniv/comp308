#lang racket

(require racket/match)

; This is the "proper lexical scoping" version of the stack machine with environment.

(define (top stack) (first stack))
(define (push val stack) (cons val stack))
(define (pop stack) (rest stack))

(struct State (stack bindings))
(struct Block (bindings code))

(define (stack-machine program state)
  (if (empty? program)
      state
      (let ([instr (first program)])
        (stack-machine
         (rest program)
         (process-instruction instr state)))))


(define (print-state state)
  (match state
    [(State stack bindings)
     (display stack)
     (display "\n")
     (display bindings)]))

(define (process-instruction instr state)
  (match state
    [(State stack bindings)
     (cond
       [(equal? instr 'do)
        (match (top stack)
          [(Block deftime-bindings program)
           (stack-machine program (State (pop stack) deftime-bindings))]
          [_ (raise-argument-error 'process-instruction
                                   "Block must be on top of stack for 'do instruction"
                                   stack)])]
       [(and (list? instr)
             (equal? (first instr) 'block))
        (State (push (Block bindings (rest instr)) stack) bindings)]       
       [(and (list? instr)
             (equal? (first instr) 'def))
        (if (symbol? (second instr))
            (State (pop stack) (cons (list (second instr) (top stack)) bindings))
            (raise-argument-error 'process-instruction
                                  "(def <symbol>) instruction expects a symbol"
                                  instr))]
       [(equal? instr '+)
        (State (push (+ (top stack) (top (pop stack))) (pop (pop stack))) bindings)]
       [(equal? instr '-)
        (State (push (- (top stack) (top (pop stack))) (pop (pop stack))) bindings)]
       [(equal? instr '*)
        (State (push (* (top stack) (top (pop stack))) (pop (pop stack))) bindings)]
       [(equal? instr '/)
        (State (push (/ (top stack) (top (pop stack))) (pop (pop stack))) bindings)]
       [(equal? instr 'dup)
        (State (push (top stack) stack) bindings)]
       [(equal? instr 'rot2)
        (State (push (top (pop stack))
                     (push (top stack)
                           (pop (pop stack))))
               bindings)]
       [(equal? instr 'rot3)
        (State (push (top (pop stack))
                     (push (top (pop (pop stack)))
                           (push (top stack) (pop (pop (pop stack))))))
               bindings)]
       [(equal? instr 'rot4)
        (State (push (top (pop stack))
                     (push (top (pop (pop stack)))
                           (push (top (pop (pop (pop stack))))
                                 (push (top stack)
                                       (pop (pop (pop (pop stack))))))))
               bindings)]
       [(equal? instr 'drop)
        (State (pop stack) bindings)]
       [(equal? instr 'sqrt)
        (State (push (sqrt (top stack)) (pop stack)) bindings)]
       [(number? instr)
        (State (push instr stack) bindings)]
       ; We need to check this case at the end because
       ; predefined instructions like 'dup and 'drop are also symbols.
       [(symbol? instr)
        (let ([val (assoc instr bindings)])
          (if val
              (State (push (second val) stack) bindings)
              (raise-argument-error 'process-instruction
                                    "Unbound symbol encountered"
                                    instr)))]
       [#t
        (raise-argument-error 'process-instruction "Valid instruction" instr)])]))

