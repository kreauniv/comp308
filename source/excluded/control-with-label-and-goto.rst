Control
-------

In programs, the word "control" is used to denote a number of things related to
jumping from one part of the program to another. While in many languages, forms
such as "if" and "while" are referred to as "control structures", we'll focus
on transfer of control that is dynamic and non-local. A familiar example of
such a dynamic and non-local control transfer is exceptions -- where you may
"throw" or "raise" an exception in one part of your program and "catch" it in
another part which dynamically encloses the part of the program raising the
exception. Another kind of non-local control transfer that you may be familiar
with is the idea of "generators" or "co-routines" in programming languages
like Python, Julia and Kotlin.

.. admonition:: **Question**

   What kind of non-local control transfer have we been relying on for the
   meaning of our programs thus far in the course?

Think through the above question based on the following simple code snippet -

.. code-block:: racket

    (define (distance dx dy)
        (sqrt (+ (square dx) (square dy))))

    (define (square dx)
        (* dx dx))

    (distance 3 4)

Think of how when we're interpreting the code of :rkt:`(square dx)`, we're
inside the function and examining :rkt:`(* dx dx)` with :rkt:`dx` bound to
:rkt:`3`. Once we calculate :rkt:`(* 3 3)`, we somehow assume that the interpreter
knows to go "I'm done, aha, I now have to resume with :rkt:`(square dy)` and
moves control to that point. Then it descends into :rkt:`square` again. It then
caculates :rkt:`(* 4 4)` and then goes "I'm done, aha, now I have to resume with
:rkt:`+`." .. and so on.

In the above program therefore, control of the process of interpretation keeps
jumping between the inner square and outer distance functions, finally jumping
back to the original :rkt:`(distance 3 4)` expression and finishing off by
printing the result.

Consider our :rkt:`stack-machine` program --

.. code-block:: racket

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
           [(equal? instr ...)
            ...])]))

This is a more complicated program than our distance calculator, but
let's make the "return control to where we left off" operation explicit
in these two functions.

.. code-block:: racket

    (define (stack-machine program state)
      (if (empty? program)
          (return state)
          (let ([instr (first program)])
            (return (stack-machine
                        (rest program)
                        (process-instruction instr state))))))

    (define (process-instruction instr state)
      (match state
        [(State stack bindings)
         (cond
           [(equal? instr ...)
            (return ...)])]))

Notice the introduction of the explicit :rkt:`(return state)` and such
expressions at points where we're done with the calculation and want to jump
back and continue from wherever we entered the function.

If we treat this :rkt:`return` as an actual function, it looks like it has a
lot of magic behind it. If you imagine that this return function is itself
defined somewhere as in :rkt:`(define return (lambda (val) ...))`, it is
somehow supposed to know where to "return" to when used in a particular
function's source code ... no matter what that function is! Such a return
cannot therefore be implemented inside our language. It must be provided by the
maker of the language ... and as you all know by now, we don't like that
power difference!

Characteristics of such a "return" if we treat it as a function.

1. We *can* treat it as a function - though not necessarily a pure one.

2. :rkt:`return` itself doesn't return to do the next instruction that appears
   in the source code following the return form. For example :rkt:`(begin
   (return x) (+ x y))` is not expected to calculate :rkt:`(+ x y)`.

3. In an expression like :rkt:`(sqrt (+ (square x) (square y)))`, return for
   the first :rkt:`square` is different from the return for the second square,
   since the pending computations are different in both cases.

Since we see that return is doing different things inside different functions
depending on the usage context, one way to make it clear is to ... believe it
or not .. β-abstract over :rkt:`return` so that we faithfully capture our
lack of knowledge about what exactly the :rkt:`return` function should do
in any given dynamic situation.

So let's rewrite the :rkt:`stack-machine` and :rkt:`process-instruction`
functions by β-abstracting over :rkt:`return`. We'll name these rewritten
functions with a :rkt:`/ret` at the end which we read as "with return".

.. code-block:: racket

    (define (stack-machine/ret program state return)
      (if (empty? program)
          (return state)
          (let ([instr (first program)])
            (process-instruction/ret instr state 
                (λ (state2)
                    (stack-machine/ret (rest program) state2 return))))))

.. note:: We've been conservative in choosing which functions we consider such
   an explicit return argument. At this point, you may want to pause and think
   about what it would mean to do this for **every** function called in our
   code above. In particular, what would it mean to implement :rkt:`if` this
   way?

Examine the λ that we're passing as a :rkt:`return` argument to
:rkt:`process-instruction`. The idea it captures -- which in this case reads
well too -- is "run the rest of the program".

.. note:: Really. Go back and read the program and see if you can convince
   yourself that the λ we pass to :rkt:`process-instruction/ret` is indeed
   "perform the remaining computations".

.. code-block:: racket

    (define (process-instruction/ret instr state return)
      (match state
        [(State stack bindings)
         (cond
           [(equal? instr 'do)
            (match (top stack)
              [(Block program)
               (stack-machine/ret program 
                                  (State (pop stack) bindings)
                                  return)]
              [_ (raise-argument-error 'process-instruction
                                       "Block must be on top of stack for 'do instruction"
                                       stack)])]
           [(equal? instr '+)
            ; Here we're relying on Scheme's implementation of "+".
            (return (State (push (+ (top stack) (top (pop stack))) (pop (pop stack)))
                           bindings))]
           ; ...
           )]))


Let's take the distance function again.

.. code-block:: racket

    (define distance (λ (dx dy) (sqrt (+ (square dx) (square dy)))))
    (define square (λ (x) (* x x)))

Rewrite these two functions in the "with explicit return" form.

.. code-block:: racket

    (define (*/ret x y return) (return (* x y))) ; Primitive / atomic
    (define (+/ret x y return) (return (+ x y))) ; Primitive / atomic
    (define square/ret (λ (x return) (*/ret x x return)))
    (define distance/ret 
        (λ (dx dy return)
            (square/ret dx 
                (λ (dx2)
                    (square/ret dy 
                        (λ (dy2)
                            (+/ret dx2 dy2 
                                (λ (pv)
                                    (sqrt/ret pv 
                                        (λ (s)
                                            (return s)))))))))))
                                                                                    

Ok this is a convoluted way of saying the same thing, but it does tell us
something about the sequence of operations by which the whole computation is
effected -- we first calculate :rkt:`(square dx)`, then we calculate
:rkt:`(square dy)` taking care to remember the result of :rkt:`(square dx)`,
then we calculate :rkt:`(+ dx1 dy2)` taking care to remember both the previous
results, then we calculate :rkt:`sqrt` on the final value. This should look
pretty darn familiar - the stack program :rkt:`dx dx * dy dy * + sqrt`.

If you read it a bit more closely, it tells us something more interesting too.
The penultimate nested λ term :rkt:`(λ (pv) (sqrt/ret pv (λ (s) (return s))))`
makes no reference to :rkt:`dx2` and :rkt:`dy2`. This means that while we need
to remember them to calculate :rkt:`(+ dx2 dy2)`, we don't need them
afterwards. The way our stack progresses also reflects that same insight.

Let's now look at it another way using our favourite tool - β-abstraction.
Take the core expression below -

.. code-block:: racket

    (return (sqrt (+ (square dx) (square dy)))))

β-abstract on the first calculation (square dx). We get

.. code-block:: racket

    ((λ (dx2) (return (sqrt (+ dx2 (square dy))))) (square dx))

Now β-abstract the inside of the lambda on the next calculation (square dy)

.. code-block:: racket

    ((λ (dx2) ((λ (dy2) (return (sqrt (+ dx2 dy2)))) (square dy))) (square dx))

Now we β-abstract again on (+ dx2 dy2)

.. code-block:: racket

    ((λ (dx2) ((λ (dy2) ((λ (p) (return (sqrt p))) (+ dx2 dy2))) (square dy))) (square dx))

Then we β-abstract on (sqrt p) -

.. code-block:: racket

    ((λ (dx2) ((λ (dy2) ((λ (p) ((λ (s) (return s)) (sqrt p))) (+ dx2 dy2))) (square dy))) (square dx))

If we read this final expression right to left, it also captures the sequence
in which we wanted to evaluate the expression - (square dx), (square dy), +,
sqrt. In this case, it is not a surprise because that's the sequence in which
we performed the β-abstraction in the first place. However, if we constrain this
process of successive β-abstraction to only pull out single operations, the
sequence in which we performed this is unique.

.. admonition:: **Question**

    Is the sequence **really** unique? We could've done :rkt:`(square dy)`
    first and then :rkt:`(square dx)`. Does that change our understanding?

But what are all these lambdas to the left of each calculation? What do they
represent? .. i.e. what do each of these lambda's stand for?

.. note:: Try to answer that on your own before proceeding.

Let's take the innermost lambda, for example -- :rkt:`(lambda (s) (return s))`.
Do you see it in the large "/ret" form we wrote? Likewise, take the next
innermost lambda -- :rkt:`(lambda (p) ((lambda (s) (return s)) (sqrt p)))`. Do
you see something similar in the second-last lambda in the /ret form?

.. index:: Continuation, CPS, Continuation Passing Style

The various lambdas we wrote that we then applied to a small part of the whole
composite computation all represent "what remains to be done" at each point we
evaluate using beta-reduction. There is a word for this "what remains to be
done" -- it is called a "continuation" and is simply a function that takes the
result of some prior step and calculates whatever remains to be done.

The way we rewrote the expression calculation using /ret variants of the
corresponding functions is called "continuation passing style" or CPS for
short. If you find it hard to recall that, you can also think of "CPS" as
expanding to "callback passing style", for in each of the /ret variants,
the last argument is a non-returning callback that is intended to be called
with the result.

.. note:: At some level within our interpreter, we need to assume the existence
   of "primitive" operations which compute their results atomically and won't
   have to go off and do something complicated on, say, some other machine. For
   instance, we can assume that Racket/Scheme won't go off to a server to
   calculate :rkt:`(+ 3 4)` and therefore we don't need to rewrite that in CPS
   form.

.. index:: reified continuations

These "continuations" could also be thought of as the state of the stack at any
point, made real as a value in our program. A word often used in CS for "made
real" which means "made into a value" is "reified". So what we have here are
"reified continuations". While continuations exist as an idea in every program
language whether you use them or not, very few languages expose this idea as a
function value to the programs written in these languages. Scheme is one of the
exceptions that provides "reified continuations".

But what are they good for?

(Optional) Yet another perspective
----------------------------------

Consider the very first β-abstraction step we did above, ignoring the
:rkt:`return` for this section's purpose.

.. code-block:: racket

    ((λ (dx2) (sqrt (+ dx2 (square dy)))) (square dx))

If we have an expression of the form :rkt:`(f x)`, we can always
rewrite it to :rkt:`((λ (g) (g x)) f)`. In doing so, we've
reversed the order of the two terms. Let's see what we get if
we do that to our expression above.

.. code-block:: racket

   ((λ (k) (k (square dx))) (λ (dx2) (sqrt (+ dx2 (square dy)))))

While previously we were writing down the lambdas only to have
them be applied immediately, the lambda we wrote down in this
case is now visible as a value to the inside of the first term
:rkt:`(λ (k) (k (square dx)))` as the variable :rkt:`k`. If
our language gave us the :rkt:`k` to use as we please, we can
see that we can now call it multiple times to calculate the
"rest of the computation" within this **limited** context. [#noret]_

.. [#noret] This is why we considered it without the :rkt:`return`.

.. index:: delimited continuations

The :rkt:`racket/control` module provides constructs that can give us these
reusable "delimited continuations" via the :rkt:`prompt` and :rkt:`control`
constructs (a.k.a. :rkt:`reset` and :rkt:`shift` respectively). We could've
written our expression as --

.. code-block:: racket

    (prompt (sqrt (+ (control k (k (square dx))) (square dy))))
    ; also written as
    (reset (sqrt (+ (shift k (k (square dx))) (square dy))))

-- to get access to the :rkt:`k` inside. Of course, in this case, we're not
doing anything interesting with the :rkt:`k` function we got. If time permits,
we'll visit this later as this is a pretty general control structure.

Note that we can express :rkt:`prompt` and :rkt:`control` as "desugaring"
operations in our expression language ... with the constraint that the
:rkt:`control` construct can only occur inside a :rkt:`prompt` construct.

.. note:: Try to see if you can implement prompt/control in PicLang.

Adding continuations to the stack language
------------------------------------------

.. note:: **WARNING** Iffy section!

When we rewrote our :rkt:`stack-machine` in the previous section as
:rkt:`stack-machine/ret`, we got explicit access to the "rest of the
computations" as a function value. What powers do we gain if we make
this function available to the stack language itself?

First off, *how* do we make it available? We'll need to add an
instruction condition to handle this.

.. code-block:: racket

    (define (process-instruction/ret instr state return)
        (match state
            [(State stack bindings)
             (cond instr
                [(equal? instr 'call)
                 (let ([b (top stack)])
                    (if (not (Block? b))
                        (raise-argument-error 'process-instruction/ret
                                              "Block on stack"
                                              (top stack))
                        (stack-machine (Block-program b) 
                                       (State (push (λ (s) (return (State (State-stack s) bindings)))
                                                    (pop stack))
                                              (Block-bindings b)))))]
                [(equal? instr 'goto)
                 (if (procedure? (top stack))
                     ((top stack) (State (pop stack) bindings))
                     (raise-argument-error 'process-instruction/ret
                                           "Continuation on the stack"
                                           (top stack)))]
                ;...
                )]
            [_ (raise-argument-error ...)]))

    (define (process-instruction/ret instr state return)
        (match state
            [(State stack bindings)
             (cond instr
                [(and (list? instr)
                      (not (empty? instr))
                      (equal? (first instr) 'label)
                      (symbol? (second instr)))
                 (letrec ([newbindings (extend-bindings (second instr)
                                            (λ (s) ; <-- NOTE THIS BINDING 
                                               (return (State (State-stack s) newbindings)))
                                            bindings)])
                    (return (State stack newbindings)))]
                [(equal? instr 'goto)
                 (if (procedure? (top stack))
                     ((top stack) (State (pop stack) bindings))
                     (raise-argument-error 'process-instruction/ret
                                           "Continuation must be present on the stack"
                                           (top stack)))]
                ;...
                )]
            [_ (raise-argument-error ...)]))

What we've done here is that if we encounter the instruction :rkt:`(label k)`,
we add a binding to the identifier :rkt:`k` that will then hold the **current**
:rkt:`return` procedure. The program is then free to push it on to the stack 
and call it using :rkt:`k goto`. It is not a coincidence that we gave these names
to these two new operations -- :rkt:`label` and :rkt:`goto`. 

.. admonition:: **Achtung!**

    We've done something here that needs more careful attention. We've vastly
    increased the scope of what kinds of values can be placed on the stack of
    our language to include pretty much everything that Scheme has to offer.
    This is not to be done lightly when you're playing language designer
    because you will want to work carefully between "too little power" and "too
    much power" in the core language. Since our purpose here is to understand
    programming language features, we'll take this liberty.

.. admonition:: **Question**

    While we've named these two new instructions as :rkt:`label` and
    :rkt:`goto`, what do they exactly stand for? Do they only stand for "jump
    to this other instruction and continue executing the program from there"?
    To answer this, consider how this new "feature" of our stack language
    interacts with the concept of "blocks".

.. admonition:: **Question(s)**

    When handling :rkt:`(label k)`, we bound the identifier :rkt:`k` to the
    :rkt:`return` procedure directly. That's where you see "NOTE THIS BINDING"
    in the code above. When this function is resumed later on with a :rkt:`k
    goto`, it will receive a new state. What are the language consequences of
    this decision? What if we instead bound it to just :rkt:`return`? 

    Also, given that we've done mutations using a store, we should really be
    considering the :rkt:`storage` as part of our :rkt:`State` structure too.
    So now there are more choices on what we can close over. What are the
    language consequences of these various choices? Start off by listing the
    choices we have. **Hint:** This is similar to our earlier discussion on
    "dynamic scoping" where we made a distinction between "definition
    environment" and "application environment" to resolve the problem.

    Which of the available choices would you prefer and why? How would you
    modify what we bind the "label" identifier to?

.. admonition:: **Exercise**

    Now go back and read the CPS code we wrote earlier to see if you can
    understand that in terms of :rkt:`label` and :rkt:`goto`.

.. admonition:: **Exercise**

    Consider the following program for our :rkt:`stack-machine` --

    .. code-block:: racket
        
        (block (def somewhere n) n 1 + dup print somewhere goto)
        (def inc-loop)
        1
        (label square-one)
        "Loopity loop" print
        square-one inc-loop do

    Implement enough of the machine to enable this program to run
    and study what it does by running it step by step.

