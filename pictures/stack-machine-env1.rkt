#lang racket

(require racket/match)

; This is the "stack-machine" interpreter given in the quiz
; that we built on in class, adding support for "variables"
; and "blocks". See the bottom of this file for notes on
; the "lexical" versus "dynamical" scoping problem.

(define (top stack) (first stack))
(define (push val stack) (cons val stack))
(define (pop stack) (rest stack))

(struct State (stack bindings))
(struct Block (code))

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
          [(Block program)
           (stack-machine program (State (pop (State-stack state))
                                         (State-bindings state)))]
          [_ (raise-argument-error 'process-instruction
                                   "Block must be on top of stack for 'do instruction"
                                   stack)])]
       [(and (list? instr)
             (equal? (first instr) 'block))
        (State (push (Block (rest instr)) stack) bindings)]       
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

#|
Our stack-machine defined so far succeeds on this program when it shouldn't -

'((block (def x) x y +)
  (def b)
  42
  100 (def y)
  b do)

We looked at reasons why it shouldn't in class.

This happens currently for the simple reason that all our variables are
effectively "global" in this mini stack language as we've implemented it.
The "globalness" is also evident because the (def x) that's done inside the
block is also visible outside after we execute the block.

So, with a correct implementation of separation between "lexical scope"
and "dynamic scope", the above program should be considered an error
by our stack-machine.

A trivial consequence of that is that the following program should
also error out -

'((block (def x) x x +)
  (def b)
  42
  b do
  x)

This can also be seen as the "free variable" problem (i.e. the same scoping problem
as above), because the final occurrence of "x" is in a lexical environment where it
has no binding and so this last "x" is a free variable. However, the "x" within the
block that occurs after the (def x) is not a free variable.

i.e. The (def x) that happens within the block should not be visible outside
the block. As a first step, you can try to modify the stack-machine to error
out for this case. In other words, may the stack-machine obey "what happens within
the block stays within the block". This is an easy first step.

After implementing that, you can take a stab at keeping "lexical scope" and "dynamic
scope" separate. Of course, you don't have to do it in two stages and can directly
tackle the scope separation problem.

For those of you who want to challenge yourself, stop reading further as you'll
find some hints below which would be spoilers!

;;;;;;; POTENTIAL SPOILERS ;;;;;;;;;

Hint (1): (for global variables problem) Notice that the state returned when we're
evaluating a block includes all the new bindings that it might've introduced
when its instructions are executed.

Hint (2): (for lexical/dynamic scope separation problem) When the stack-machine sees
the (block ...) instruction, it constructs a "Block" structure. This is where the
"definition environment" a.k.a. "lexical environment" or "lexical scope" is in
effect. The meaning of the contents of the block when it is run should depend only
on this environment and not when "do" invokes the block .. which is the "invocation
environment" a.k.a. "dynamic scope".

|#
