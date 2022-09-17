Stacks and scope
================

We considered a minimally useful :index:`stack machine` in the preceding quiz,
which is reproduced below for reference -

.. code-block:: racket

    #lang racket

    (define (top stack) (first stack))
    (define (push val stack) (cons val stack))
    (define (pop stack) (rest stack))

    (define (stack-machine program stack)
      (if (empty? program)
          stack
          (let ([instr (first program)])
            (stack-machine
             (rest program)
             (process-instruction instr stack)))))

    (define (process-instruction instr stack)
      (cond
        [(equal? instr '+)
         (push (+ (top stack) (top (pop stack))) (pop (pop stack)))]
        [(equal? instr '-)
         (push (- (top stack) (top (pop stack))) (pop (pop stack)))]
        [(equal? instr '*)
         (push (* (top stack) (top (pop stack))) (pop (pop stack)))]
        [(equal? instr '/)
         (push (/ (top stack) (top (pop stack))) (pop (pop stack)))]
        [(equal? instr 'dup)
         (push (top stack) stack)]
        [(equal? instr 'rot2)
         (push (top (pop stack))
               (push (top stack)
                     (pop (pop stack))))]
        [(equal? instr 'rot3)
         (push (top (pop stack))
               (push (top (pop (pop stack)))
                     (push (top stack) (pop (pop (pop stack))))))]
        [(equal? instr 'rot4)
         (push (top (pop stack))
               (push (top (pop (pop stack)))
                     (push (top (pop (pop (pop stack))))
                           (push (top stack)
                                 (pop (pop (pop (pop stack))))))))]
        [(equal? instr 'drop)
         (pop stack)]
        [(equal? instr 'sqrt)
         (push (sqrt (top stack)) (pop stack))]
        [(number? instr)
         (push instr stack)]
        [#t
         (raise-argument-error 'do-instruction "Valid instruction" instr)]))

This machine lets us perform simple arithmetic calculations. For example,
:rkt:`'(dup * rot2 dup * + sqrt)` is a program that can be used to compute the
distance from the origin to a point :rkt:`(x y)` where the coordinates are
given on the stack. For example,

.. code-block:: racket

    (stack-machine '(dup * rot2 dup * + sqrt) '(3 4))
    ; Produces '(5) as the result stack

While this program is understandable without much effort, it is not obvious
that the program :rkt:`'(dup dup * rot3 rot2 dup dup * rot3 * dup + + +)`
computes the algebraic expression :math:`(a^2 + 2ab + b^2)`, so that we can
transform it into the equivalent program :rkt:`'(+ dup *)` -- i.e.
:math:`(a+b)^2`. Maybe if we work with such expressions enough, we'll build
sufficient algebraic prowess to see how the longer expression can be reduced to
the shorter one. 

Given that the mechanisms we don't have prior familiarity with are the
:rkt:`dup` and :rkt:`rotN` family which juggle elements on the stack in
preparation for future operations, it is easy to see that if we can simply
name the elements on top of the stack, the program can become more comprehensible.
For example, if :rkt:`a` and :rkt:`b` stood for the top two elements of the stack,
the longer program above could be written as :rkt:`'(a a * 2 a b * * b b * + +)`,
which is much better for the human reader. Similarly, the distance formula
also can be written as :rkt:`'(a a * b b * + sqrt)`.

This version of the distance formula should look familiar!

Consider the expression we would've written in Racket --

.. code-block:: racket

    (define (distance a b)
        (sqrt (+ (* a a) (* b b))))

    ; Focus on the "sqrt" expression
    (sqrt (+ (* a a) (* b b)))

    ; Remove all the parentheses
    sqrt + * a a * b b

This is just the :index:`stack machine` program written from right to left
order! For this reason, programs like the ones we wrote for the
:rkt:`stack-machine` are said to be "postfix notation" while LiSP's notation is
also called "prefix notation". LiSP's notation admits variadic functions
(functions which can take any number of arguments such as :rkt:`+`) whereas
with the postfix notation the "arity" of an operator, or "words" as operators
are called in such languages, is in general fixed. "Arity" refers to the number
of arguments to a function or procedure.

.. admonition:: **Aside**

    Apart from Forth_ being the canonical "postfix notation language", you
    perhaps pretty much use a postfix language on a daily basis without knowing
    it -- PostScript_ and PDF files! Adobe's PostScript_ ("Post" is there in
    the name for a reason) is actually a programming language for drawing. PDF
    , while advertised as a "portable document format", is a compressed version
    of the drawing commands produced by a PostScript_ program. Apple (well,
    NeXT) also adapted Postscript for use in the NeXT OS for controlling the
    display, called `Display PostScript`_ , which enabled the OS to capture
    scalable on-screen vector graphics as PostScript_ or PDF files easily for
    print. As we saw, Postfix languages are very easy to write interpeters for
    and these turn out to be low resource processors that can be used in
    devices like printers.


.. _Forth: https://en.wikipedia.org/wiki/Forth_(programming_language)
.. _PostScript: https://en.wikipedia.org/wiki/PostScript
.. _Display PostScript: https://en.wikipedia.org/wiki/Display_PostScript

Adding names to the stack-machine
---------------------------------

So we'd like to be able to ":index:`bind`" symbols to values picked from the
stack so we can recall them whenever we need their values. For this, we need a
kind of "dictionary" in which we can lookup values associated with symbols.
There is a Scheme function :rkt:`assoc` that'll do this for us -

.. index:: Scheme assoc

.. code-block:: racket

    (define alist (list (list 'one "ek")
                        (list 'two "do")
                        (list 'three "teen")
                        (list 'three "theen")))
    (display (assoc 'three alist))
    ; Prints out (three "teen")
    ; Notice that only the first occurrence is returned.
    (display (assoc 'four alist)
    ; Prints out #f to indicate "not found".


So let's augment our stack machine with such a ":index:`dictionary`" and
interpret "symbols" we find in the instruction stream to mean "lookup this
symbol in the dictionary and push the value you find on the top of the stack".
We'll call this dictionary "bindings" because it is a list of symbols bound to
values. We'll also add a new "compound instruction" for popping off a value
from the stack and binding it to a symbol - as :rkt:`(def <symbol>)`.

.. code-block:: racket

    ; Since our stack-machine now has to consume a stack
    ; and a bindings list and produce new versions of those
    ; as a result, we'll group them into a simple struct
    ; we'll call "State".
    (struct State (stack bindings))

    (define (stack-machine program state)
      (if (empty? program)
          state
          (let ([instr (first program)])
            (stack-machine
             (rest program)
             (process-instruction instr state)))))

    (define (process-instruction instr state)
      (match state
         [(State stack bindings)
          (cond
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
            ; Handle (def <symbol>) instruction
            [(and (list? instr)
                  (not (empty? instr))
                  (equal? (first instr) 'def)
                  (symbol? (second instr)))
             (State (pop stack) (cons (list (second instr) (top stack)) bindings))]
            ; Handle symbols that occur that we don't already know about
            ; as a "lookup operation"
            [(symbol? instr)
             (match (assoc instr bindings)
                 [(list sym value) 
                  (State (push value stack) bindings)]
                 [#f (raise-argument-error 'process-instruction
                                           "Defined symbol expected"
                                           instr)])]
            [#t
             (raise-argument-error 'process-instruction "Valid instruction" instr)])]))


With these two additions, we can now express our "Euclidean distance" function
as :rkt:`((def x) (def y) x x * y y * + sqrt)`. Note how this closely
resembles :rkt:`(lambda (x) (lambda (y) (sqrt (+ (* x x) (* y y)))))`.

.. admonition:: **Exercise**

    To make the resemblance to :rkt:`lambda` even closer, modify the
    implementation of the :rkt:`(def <symbol>)` instruction to support multiple
    symbols. The idea is to pull one value off the stack for each symbol and
    bind it to the corresponding symbol. So encountering a :rkt:`(def x y)`
    instruction will cause our machine to pull the top two values from the
    stack and bind them to :rkt:`x` and :rkt:`y`.

Blocks
------

Though we've been able to bind symbols to values and use them, our
stack-machine programming language does not have the ability to reuse such
calculations. For example, we'll have to repeat the whole distance calculation
code whenever we need to do it. 

We can invent another type of value -- the ":index:`block`" -- which contains a
list of instructions (a "program") that we can store bound to a symbol and
"invoke" whenever we need. Surprisingly, this requires only a small change to
our stack-machine. We'll also have to add a :rkt:`do` instruction that will pop
a block off the top of the stack and run its program on the stack.

.. code-block:: racket

    (struct Block (program))

    (define (process-instruction instr state)
      (match state
         [(State stack bindings)
          (cond
            ; <common-operators>
            ; ...
            ; </common-operators>

            ; A "block" compound instruction is given like (block dup + sqrt)
            [(and (list? instr)
                  (not (empty? instr))
                  (equal? (first instr) 'block))
             (State (push (Block (rest instr)) stack) bindings)]

            ; A "do" instruction will pop a Block value off the top of the
            ; stack and "run" it.
            [(equal? instr 'do)
             (match (top stack)
                 [(Block program)
                  (stack-machine program (State (pop stack) bindings))]
                 [_ (raise-argument-error 'process-instruction
                                          "Block value on stack"
                                          stack)])]

            ; Handle (def <symbol>) instruction
            [(and (list? instr)
                  (not (empty? instr))
                  (equal? (first instr) 'def)
                  (symbol? (second instr)))
             (State (pop stack) (cons (list (second instr) (top stack)) bindings))]

            ; Handle symbols that occur that we don't already know about
            ; as a "lookup operation"
            [(symbol? instr)
             (match (assoc instr bindings)
                 [(list sym value) 
                  (State (push value stack) bindings)]
                 [#f (raise-argument-error 'process-instruction
                                           "Defined symbol expected"
                                           instr)])]

            [#t
             (raise-argument-error 'process-instruction "Valid instruction" instr)])]))


Now, we're actually equipped to define a "euclidean distance" function in our
stack-machine language!

.. code-block:: racket

    (define program '( (block (def x) (def y) x x * y y * + sqrt)
                       (def distance)
                       3 4 distance ) )
    (display-state (stack-machine program (State '() '())))
    ; Prints out (5) as the result stack.

Which programs are valid blocks?
--------------------------------

The way we've implemented block execution, the final value of a block's
bindings will be available after block execution. So the following
program will actually produce a value with our stack-machine.

.. code-block:: racket

    (stack-machine '((block (def x) (def y) x x * y y * + sqrt)
                     (def distance)
                     3 4 distance do
                     x y +)
                    (State '() '()))
    ; will produce (7 5) as the result stack.

What does this program really mean? Why should the :rkt:`x y +` part
of the program care what variable names the block implementing the
:rkt:`distance` calculation uses **internally**?

Our "block" defines a "region of code" that we wish to be self contained. In
other words, we want "what happens within the block, stays within the block" to
hold, except for the effect it has on the stack. In yet more words, we want to
throw away all symbol bindings done within the block once the block is done.
We don't want all our variables to be "global" and interfere with each other.

.. note:: Why is this required?  Think about it before reading on.

Let's first fix the problem we noted above, assuming :index:`global variables`
are "a bad idea".

.. code-block:: racket

    (define (process-instruction instr state)
      (match state
         [(State stack bindings)
          (cond
            ; <common-operators>
            ; ...
            ; </common-operators>

            ; A "block" compound instruction is given like (block dup + sqrt)
            [(and (list? instr)
                  (not (empty? instr))
                  (equal? (first instr) 'block))
             (State (push (Block (rest instr)) stack) bindings)]

            ; A "do" instruction will pop a Block value off the top of the
            ; stack and "run" it.
            [(equal? instr 'do)
             (match (top stack)
                 [(Block program)
                  ; <<<---->>>>
                  ; We've modified this expression to consider only the stack
                  ; as part of the result state of executing a block. We discard
                  ; the bindings it produces and retain the original bindings list.
                  (State (State-stack (stack-machine program (State (pop stack) bindings)))
                         bindings)]
                 [_ (raise-argument-error 'process-instruction
                                          "Block value on stack"
                                          stack)])]

            ; Handle (def <symbol>) instruction
            [(and (list? instr)
                  (not (empty? instr))
                  (equal? (first instr) 'def)
                  (symbol? (second instr)))
             (State (pop stack) (cons (list (second instr) (top stack)) bindings))]

            ; Handle symbols that occur that we don't already know about
            ; as a "lookup operation"
            [(symbol? instr)
             (match (assoc instr bindings)
                 [(list sym value) 
                  (State (push value stack) bindings)]
                 [#f (raise-argument-error 'process-instruction
                                           "Defined symbol expected"
                                           instr)])]

            [#t
             (raise-argument-error 'process-instruction "Valid instruction" instr)])]))


This version of the :rkt:`stack-machine` rightly rejects the program we considered to
be erroneous. However we have not solved the problem completely. While we've
eliminated the "global variables only" meaning in our program, our blocks can still
reference variables that are meaningless in certain ways.

Dynamic scoping
---------------

.. index:: Dynamic scoping

Consider the program below --

.. code-block:: racket

    (stack-machine '((block (def x) x x * y y * + sqrt)
                     (def distance)
                     (block 4 (def y) 3 distance do)
                     do)
                    (State '() '()))

Note that in this program, we've removed the :rkt:`(def y)` within the block,
so the :rkt:`distance` definition will only pop one value off the stack and
name it as :rkt:`x`. Our use of :rkt:`y` within the block is meaningless at the
point at which the block is being defined, because there is no guarantee that
it will become defined later on, and that could happen within another block
which accidentally uses a "local variable" :rkt:`y`, which would interfere with
the reference to :rkt:`y` within our :rkt:`distance` block.

So, we want this program to also be treated as erroneous and fail rather than
be given a spurious meaning. 

Programming languages which give meaning to such programs are said to have
":index:`dynamic scoping`". The word "dynamic" here refers to the fact that as
the program is running, the symbol :rkt:`y` takes on different values and the
meaning being attributed by the interpreter to the :rkt:`y` within the first
block is "whatever value :rkt:`y` happens to have **right now**".

That global variables are a bad idea is quite easily argued -- two different
parts of a large program accidentally using the same symbol to refer to
different kinds of values should not cause the whole program to become invalid.
The reason dynamic scoping is also "a bad idea" is less obvious.

.. note:: Think about why, before you read on.

In general, when we encapsulate some computation as a function for purposes of
reuse, we want to be able to reason about the behaviour of the function without
having to consider anything apart from the arguments supplied to it. If we're
able to do that, the task of ensuring the correctness of a large program is
tractable -- since we only have to validate each function based on the
constraints of the functions that it relies on. We **do not** want to have to
check how a function behaves in every context it is being invoked.

Fixing dynamic scoping
----------------------

.. index:: Lexical scoping

To fix the "dynamic scoping bug", we need to clarify what exactly is the problem
in the first place.

.. note:: Think about it before reading on. Why is the stray variable :rkt:`y`
   in our last example taking on an actual value when we're invoking the block?

The set of bindings in effect when evaluating a particular instruction is
called its "environment". For a block, we therefore need to distinguish between
two such "environments". 

.. index:: Definition Environment, Environment/Definition
The bindings in effect at the point we're creating the "block value" (or "block
object" if you want) is its "**definition environment**". This "block value"
refers to the :rkt:`Block` type value we're placing on the stack and therefore
the "definition environment" is the environment in effect when we're creating
this :rkt:`Block` type value.

.. index:: Evaluation environment, Environment/Evaluation

The bindings in effect at the point we're invoking the block is called its
"**evaluation environment**". This is the environment in effect when we
evaluate :rkt:`distance do`. The problem we currently have is that we're not
distinguishing between these two environments. More specifically, we're letting
the evaluation environment affect the inside of the block where the definition
environment is the one that's supposed to be in effect. This is because the
definition environment is what lends meaning to the value of the symbols used
within the block and we don't want the evaluation environment to be responsible
for that.

.. note:: Think about why it is the definition environment that lends meaning
   to the inside of a block. What consequences does it have when building
   large programs as a collection of small pieces of functionality?

As with many problems, identifying the problem is the major part of fixing it.
In this case, because we only have one notion of environment, we need to store
away the definition environment along with the block when we're creating it, so
that we can refer to it later at evaluation time.

.. code-block:: racket

    (struct Block (program definition-time-bindings))

    (define (process-instruction instr state)
      (match state
         [(State stack bindings)
          (cond
            ; <common-operators>
            ; ...
            ; </common-operators>

            ; A "block" compound instruction is given like (block dup + sqrt)
            [(and (list? instr)
                  (not (empty? instr))
                  (equal? (first instr) 'block))
             (State (push (Block (rest instr) bindings) stack) bindings)]
             ;                                ^---- Note that we added this
             ;                                to store the definition time
             ;                                bindings when we're making the block.

            ; A "do" instruction will pop a Block value off the top of the
            ; stack and "run" it.
            [(equal? instr 'do)
             (match (top stack)
                 [(Block program definition-time-bindings)
                  ;              ^---- Now we pick up what we stored away
                  ;                    at definition time.
                  ; <<<---->>>>
                  ; We've modified this expression to consider only the stack
                  ; as part of the result state of executing a block. We discard
                  ; the bindings it produces and retain the original
                  ; definition-time-bindings that were captured when the block
                  ; was created.
                  (State (State-stack (stack-machine program 
                                                     (State (pop stack) definition-time-bindings)))
                                                     ;                  ^---- Note this.
                         bindings)]
                  ;      ^------------ These bindings are unaffected by what happens
                  ;                    when running the block.

                 [_ (raise-argument-error 'process-instruction
                                          "Block value on stack"
                                          stack)])]

            ; ...
            ; THE REST OF (def <symbol>) and (symbol? x) etc.
            ; ...
            [#t
             (raise-argument-error 'process-instruction "Valid instruction" instr)])]))




With this, we've dealt the final blow to dynamic scoping in our interpreter.
Our interpreter now properly implements ":index:`lexical scoping`" -- i.e. the
meaning of a particular symbol used is taken to be available in the region of
program text where it's used. That's an informal way of saying it though. We
usually imply that there is some region of code (usually delimited by some form
of brackets or pair of keywords like :rkt:`begin` and :rkt:`end`) which is the
intended "region of program text".

.. admonition:: **Exercise**

    While we've "fixed" dynamic scoping, think about whether we've lost any
    useful ability along the way.

.. admonition:: **Exercise**

    Btw we've also gained another ability when we implemented proper lexical
    scoping in :rkt:`stack-machine`. Can you spot it? What possible ways to use
    blocks would you try to exhaust some of these possibilities?

