Generators
==========

In :doc:`control`, we implemented a rudimentary way to define and work with
generators in our small stack-based language. In this section, we'll see how
Racket provides us with full continuations that can be used for this purpose.

Seeing continuations through β-abstraction
------------------------------------------

In an eager evaluation language, the order in which computations happen
to produce the value of a given expression is known from the structure of
the expression -- i.e. "statically". It is possible to make this order
explicit, as it is done in compilers, by transforming them to a form
known as "static single assignment form" or "SSA form" for short. [#ssa]_

.. [#ssa] We won't be dealing with all cases of SSA. Just enough to give
   an idea of what "the rest of the computation" means.

Consider our now familiar expression - the distance calculator between
two points on a plane --

.. code-block:: racket

    (sqrt (+ (square (- x1 x2)) (square (- y1 y2))))
    ; we consider x1, x2, y1 and y2 to be bound variables,
    ; perhaps by an enclosing λ

We can expression the sequence of calculations that happen here by rewriting
it in such a way that each calculation's result gets assigned to a variable.

.. code-block:: racket

    (let ()
        (define v1 (- x1 x2))
        (define v2 (square v1))
        (define v3 (- y1 y2))
        ;------------ the "rest of the computation"
        ;------------ after (- y1 y2) is computed
        ;------------ follows below.
        (define v4 (square v3))
        (define v5 (+ v2 v4))
        (define v6 (sqrt v5))
        v6)

An important aspects of SSA form is that variables introduced are assigned only
once ("single assignment") based on the "static" analysis of the code.
Compilers do this transformation because it helps optimizers figure out
dependencies easier than if multiple assignments we permitted. For instance,
exchanging the definition order of ``v2`` and ``v3`` won't affect the result.
However, consider the following expression -

.. code-block:: racket

    (let ([x 3] [y 4])
        (set! x (+ x y)) ; line1
        (set! y (/ x 2)) ; line2
        (set! x (* x 5)) ; line3
        (set! x (- x y)) ; line4
        x)

Notice that exchanging ``line2`` and ``line3``  changes the
meaning of the program. However, when we rewrite it in SSA form as --

.. code-block:: racket

    (let ([x 3] [y 4])
        (define v1 (+ x y))   ; ssa-line1
        (define v2 (/ v1 2))  ; ssa-line2
        (define v3 (* v1 5))  ; ssa-line3
        (define v4 (- v3 v2)) ; ssa-line4
        v4)

... ``ssa-line2`` and ``ssa-line3`` can be exchanged without changing the
meaning of the program. This analysis is much easier to do in SSA form for
compiler writers.

Since at any point we know the "next expression that can be evaluated",
we can use that knowledge to transform the original distance calculation
expression through β-abstraction to make clear the execution order like
below --

.. code-block:: racket

    (sqrt (+ (square (- x2 x1)) (square (- y2 y1))))
    ; β-abstract over (- x2 x1)
    ((λ (v1) (sqrt (+ (square v1) (square (- y2 y1))))) (- x2 x1))
    ; Now β-abstract over the first λ term
    ((λ (f1) (f1 (- x2 x1)))
     (λ (v1) (sqrt (+ (square v1) (square (- y2 y1))))))

Here, ``f1`` is a real function that captures "the rest of the computation"
up to the ``sqrt`` calculation (it is said to be "delimited" at that point)
and the ``v1`` identifier is analogous to our first SSA form line.

We can continue this process with the insides of the second λ term to
produce the complete form through this sequence of transformations --

.. code-block:: racket

    ((λ (f1) (f1 (- x2 x1)))
     (λ (v1) (sqrt (+ (square v1) (square (- y2 y1))))))
    ; =>
    ((λ (f1) (f1 (- x2 x1)))
     (λ (v1) ((λ (f2) (f2 (square v1)))
              (λ (v2) (sqrt (+ v2 (square (- y2 y1))))))))
    ; =>
    ((λ (f1) (f1 (- x2 x1)))
     (λ (v1) ((λ (f2) (f2 (square v1)))
              (λ (v2) ((λ (f3) (f3 (- y2 y1)))
                       (λ (v3) (sqrt (+ v2 (square v3)))))))))
    ; =>
    ((λ (f1) (f1 (- x2 x1)))
     (λ (v1) ((λ (f2) (f2 (square v1)))
              (λ (v2) ((λ (f3) (f3 (- y2 y1)))
                       (λ (v3) ((λ (f4) (f4 (square v3)))
                                (λ (v4) (sqrt (+ v2 v4))))))))))
    ; =>
    ((λ (f1) (f1 (- x2 x1)))
     (λ (v1) ((λ (f2) (f2 (square v1)))
              (λ (v2) ((λ (f3) (f3 (- y2 y1)))
                       (λ (v3) ((λ (f4) (f4 (square v3)))
                                (λ (v4) ((λ (f5) (f5 (+ v2 v4)))
                                         (λ (v5) (sqrt v5)))))))))))

The functions ``f1``, ``f2``, .. all represent the remaining computations
to be done at each point and ``v1``, ``v2`` all get the results of each
computation step as it happens.

Delimited continuations
-----------------------

We now make a small step that's a giant leap of sorts.

Within the λ where we use the ``f1``, ``f2`` etc., we have
expressions of the form ``(f1 (- x2 x1))`` and so on. We now
ask "what if we had a magic operator ``magic`` that made this 
``f1`` available for us at the point we're calculating ``(- x2 x1)``?"

.. code-block:: racket

    (START (sqrt (+ (square (magic f1 (f1 (- x2 x1))))
                    (square (- y2 y1)))))

... where we've also marked the outer most expression up to which
we consider "the rest of the computation" to happen.

Thing is, this "``magic`` operator" exists in racket via the ``control``
module. ``START`` is called ``reset`` and ``magic`` is called ``shift``.
The function made available by ``shift`` is called a "delimited continuation"
since its range is delimited by the surrounding ``reset``.

.. code-block:: racket

    (require racket/control)
    (reset (sqrt (+ (square (shift f1 (f1 (- x2 x1))))
                    (square (- y2 y1)))))

Ok so what? Now we ask ourselves "what kind of super powers having 
the ``f1`` at that point gets us?" To see what happens in the
forms below, remember that, for the cases we're looking at,

.. code-block:: racket

    (reset ...A... (shift f1 ...B...) ...C...)
    ; is equivalent to
    ((λ (f1) ...B...) (λ (v1) ...A... v1 ...C...))

Consider what would be the result of the following expression --

.. code-block:: racket

    (reset (sqrt (+ (square (shift f1 0))
                    (square (- y2 y1)))))

Here, we are not using ``f1`` at all. The equivalent form therefore 
looks like --

.. code-block:: racket

    ((λ (f1) 0) (λ (v1) (sqrt (+ (square v1) (square (- y2 y1))))))

Clearly, the entire computation that the second λ stands for has
been completely discarded. In other words, we've gained the power
to choose to abort the computation based on the local decisions
up to a given outer term identified by ``reset``. For example,
we could've made it conditional like so --


.. code-block:: racket

    (reset (sqrt (+ (square (shift f1 (if (> x2 x1)
                                          (f1 (- x2 x1))
                                          0)))
                    (square (- y2 y1)))))

When ``x2 <= x1``, the entire expression will evaluate to 0.
We could've chosen to produce an error term or anything else
that we please as well.

For another simple example, consider --

.. code-block:: racket

    (reset (+ 5 (shift f (f (f 10)))))

To find out what this means, we can rewrite it to --

.. code-block:: racket

    ((λ (f) (f (f 10))) (λ (v) (+ 5 v)))

Reducing that, we see that the expression computes to ``20``
by adding ``5`` twice.

Within the ``shift`` block, we can do anything else that Racket
permits us to do with functions since these delimited continuation
functions are effectively ordinary functions -- like ...

1. Storing it away in a variable or data structure for later use.
2. Applying it twice.
3. Mapping it over a list of values.
4. .... and so on

:rkt:`call/cc` and :rkt:`let/cc`
--------------------------------

Racket also provides un-delimited continuations via the ``let/cc`` construct
which desugars to ``call/cc`` as shown below --

.. code-block:: racket

    (let/cc <identifier>
        <body>...)
    ; => desugar =>
    (call/cc (λ (<identifier>)
        <body>...))

The ``<identifier>`` given is bound to the continuation at the point
and thus made available to the ``..body..`` code. The ``let/cc`` is
visually easier to relate to and so we'll use that, but understand 
that it desugars to ``call/cc`` like above and therefore ``call/cc``
is the more fundamental operator here.

.. admonition:: **Terminology**

    ``call/cc`` stands for the much longer name ``call-with-current-continuation``.

There are some differences from the ``reset`` / ``shift`` pair though.

1. The continuation function provided by ``let/cc`` does not itself return to
   the call point. We saw that with the delimited continuation provided by
   ``shift``, we can call it as many times as we want, even doing compositions
   like ``(f1 (f1 10))``. Since the continuation provided by ``let/cc`` does
   not itself "return" to its call point, if ``f1`` were such a ``let/cc``
   contination, the double call would just be equivalent to ``(f1 10)``. In
   other words, a call to a ``let/cc`` provided continuation function is
   **always** a tail call whether it occurs in a tail position or not.

2. The value of the body of code in ``let/cc`` becomes the value of the
   ``let/cc`` block, as though there was an implicit call to the continuation
   at the end. This is different from the case of ``shift`` where the body of
   ``shift`` aborts the entire calculation if it does not use the continuation
   function. It is easy to see why ``let/cc`` has this implicit call at the end
   because such an abort will essentially be an exit from the program (in
   single threaded cases) which is not what we usually want. So the
   continuation function provided by ``let/cc`` can be seen as a "jump out of
   the ``let/cc`` block with this value" procedure.

.. code-block:: racket

    (+ 5 (let/cc f
            (displayln "one")
            (f 10)
            (displayln "two")))

The above will print ``one`` and then evaluate to the result ``15``. The
``(displayln "two")`` never gets a chance to run because the call to the
continuation ``f`` aborts everything that follows ``(f 10)``. The ``10``
essentially becomes the value of the entire ``let/cc`` expression, leaving us
with ``(+ 5 10)`` as the result.

``let/cc`` (i.e. ``call/cc``) gives us an operator using which we can implement
any of our familiar imperative control constructs like while/repeat/break/continue,
and also those considered more "modern" such as "async/await" and generators. We'll
look at generators next. For this reason, ``call/cc`` is often referred to as
"the ultimate ``goto``".

Super power time - generators
-----------------------------

Python generators generalize the notion of ``return`` from a function to
"temporarily return" using ``yield``, by saving away the computational state
so that it can be resumed later. See the sample below --

.. code-block:: python

    def three(msg):
        print(msg + " 1")
        yield 1
        print(msg + " 2")
        yield 2
        print(msg + " 3")
        yield 3
        return None

    > g = three("step")
    > next(g)
    step 1
    1
    > next(g)
    step 2
    2
    > next(g)
    step 3
    3
    > next(g)
    Traceback (most recent call last):
    File "<stdin>", line 1, in <module>
    StopIteration

You can see how the function uses "yield" to temporarily pause its computation
which is subsequently resumed by ``next(g)``. In the line ``g = three("step")``,
the function has actually not started any computations at all, as evidenced
by "step 1" not being printed out at that point. Only upon calling ``next(g)``
is the computation started.

Generators, due to their ability to suspend and resume computations, find
many uses in python code, including a form of lazy generation of infinite
sequences like this squares generator --

.. code-block:: python
    
    def squaresFrom(n):
        while True:
            yield (n * n)
            n = n + 1

Try it out on your own to see that it doesn't complete and yields
one square number at a time.

We can construct this facility given ``let/cc``/``call/cc`` as shown
below --

What we're looking for is a procedure ``generator`` that takes a ``λ``
function standing for the body of the generator code and uses ``yield``
to pause and resume computation just like the python version.
In our case, we'll provide this ``yield`` as an argument to the λ function
given to the ``generator`` procedure. We want to be able to do the equivalent
of ``next(g)`` with the result. In our case, we can simplify that by having
``generator`` return a function that can be called like ``(g val)`` where the
passed value will be returned from the ``yield`` call to resume the 
computation.

.. code-block:: racket

    (define g (generator (λ (yield)
                  (displayln "step 1")
                  (yield 1)
                  (displayln "step 2")
                  (yield 2)
                  (displayln "step 3")
                  (yield 3)
                  #f)))
    > (g "one")
    step 1
    1
    > (g "two")
    step 2
    2
    > (g "three")
    step 3
    3
    > (g "four")
    #f

In python, the ``StopIteration`` exception is merely a convention used to
temrinate sequences produced by generators. We can choose any such convention
ourselves.

From the above example with ``generator``, a few observations can be made --

1. ``generator`` returns a λ function.
2. ``(yield 1)`` is "returning" to the exit point of ``(g "one")``.
3. ``(g "two")`` is "returning" to the exit point of ``(yield 1)`` within the
   generator λ.

Based on those, the implementation would look something like this --

.. code-block:: racket

    (define (generator fn)
        (define (return val)
            ; Handles the final return from the generator
            ; procedure
            <return-body-code>
            )
        (define (yield val)
            ; Handles yielding back to the generator's
            ; call point.
            <yield-body-code>
            )
        (define cont #f) ; Var to remember exit point of yield
        (define ret #f)  ; Var to remember exit point of call to g.
        (λ (val) ; Because ``g`` takes a single argument
          (let/cc c ; Because we need to remember the exit point
                    ; of each call to ``g``.
            (set! ret c)    ; Remember where the next yield should return to.
            <resume-code>
                ; Either continue by supplying the val to the exit
                ; point of the last yield, or call the given function
                ; to start the computation.
                )

We remembered the return point of a generator function (``g``)
in the variable named ``ret``. So it is clear that ``yield`` must return
to that point. Furthermore, yield must remember where the generator
function must continue to when it is called, putting those two together,
we see that the implementation of ``yield`` must be like this --

.. code-block:: racket

    (define (yield val)
        (let/cc c
            (set! cont c) ; Remember where to continue.
            (ret val)))

Within the generator function, we need to first find out whether the 
``fn`` function was called at all (and hit a ``yield`` point) in order
to decide what to do. If ``cont`` is ``#f``, it means the function 
wasn't called, since it would've hit a ``yield`` call which would've
modified ``cont`` to be a procedure. So we see that the ``<resume-code>``
part needs to be --

.. code-block:: racket
    
    (if cont
        (cont val)
        (return (fn yield))) ; Starts the function going.

The ``return`` function is similar to ``yield``, but must set things
up so that it would be an error to continue to call the generator function
after its completion.

.. code-block:: racket

    (define (return val)
        ; By setting cont to be an error generating procedure,
        ; we prevent any further jumps into the function ``fn``.
        (set! cont (λ (v)
                      (raise 'stop-generation)))
        (ret val))

Putting it all together, we have --

.. code-block:: racket

    (define (generator fn)
        (define (yield val)
            (let/cc exit-point-of-yield-call
                (set! cont exit-point-of-yield-call)
                (ret val)))
        (define (return val)
            (set! cont (λ (v) (raise 'stop-generation)))
            (ret val))
        (define cont #f)
        (define ret #f)
        (λ (val)
            (let/cc exit-point-of-g-call
                (set! ret exit-point-of-g-call)
                (if cont
                    (cont val)
                    (return (fn yield))))))

.. admonition:: **Exercise**

    Test out ``generator`` using the example above.

Differences from Python's generators
------------------------------------

1. ``yield`` is a reserved word in Python whereas the ``yield`` argument
   in our generator implementation is an ordinary first class function.
   Therefore ``(map yield (list 1 2 3))`` is value whereas that is
   not possible with Python's ``yield`` keyword.

2. ``(yield x)`` looks and behaves like a normal function call.
   Python's yield is a statement when written like ``yield val``
   and an expression that can be resumed with a value when written
   as ``(yield val)`` (here the parentheses stand for grouping, so
   it is the same as ``((yield val))``).

3. When the generator function in Python completes with a return, it
   can no longer be jumped into and it will indicate that with a ``StopIteration``
   exception. In our case, we can choose our own protocol on how to
   finish it .. either by using a known sentinel value or by raising
   an error like Python does.

4. Python embeds its generator capabilities into constructs like
   list comprehension and for loops. We haven't done anything like
   that with our generators ... yet, but we can of course use the
   same protocol to implement similar behaviours.

Uses for generators
-------------------

The ability to pause and resume computation that lexically looks like a single
sequence of operations is a valuable design tool in organizing many kinds of
systems.

Async/Await
~~~~~~~~~~~

In particular, this is useful when considering event loops that service browser
interfaces or server-side programs. Of late, this mechanism is usually
presented in languages using the keywords ``async`` and ``await``, where
``async`` marks a function for such asynchronous processing (analogous to
``generator`` in our case) and ``await`` performs the equivalent of ``yield``,
but returns control to the event loop instead.

In Javascript, for example, an object called a ``Promise`` plays the role
of capturing a computation that "promises" to produce a value in the future.
Such a promise is constructed like this --

.. code-block:: js

    new Promise(function (resolve, reject) {
        .... code ...
        resolve(value); // When the computation completed successfully.
        ...
        reject(value); // When it completes with an error.
    })

.. admonition:: **Notice**

    Do you notice the similarity between the way ``Promise`` is structured
    and our ``generator`` function? While somewhat similar, they're also
    different in that ``yield`` can be used multiple times whereas ``resolve``
    and ``reject`` can only be called once.

The form ``await <expr>`` then expects ``<expr>`` to provide a ``Promise``
object and waits for it to complete, returning the value passed to ``resolve``,
or raising as error the value passed to ``reject``.

Thus, ``async``/``await`` in javascript desugars to generators that coordinate
using ``Promise`` objects. The situation is similar in other language which may
use slightly different terminology -- for example ``Future`` may be used
instead of ``Promise``.

Search
~~~~~~

Generators are useful to structure computations where values need to be
produced "lazily", for example, to explore search spaces. A variable
that is permitted to take on a number of values according to some known
constraints can be treated as a generator for those values, permitting
the exploration of a search space across a number of such variables.

One way to see this is to think of generators as sequences in the same footing
as lists. "List of X" can for many such search/explore applications be
re-presented as "Generator of X" without incurring the storage costs of lists.
Common operations on lists such as ``map`` and ``filter`` translate well
to generators as well. Much as mapping over a list produces another list,
mapping over a generator produces another generator. And so is the case
with filtering.

.. code-block:: racket

    (define (g-map fn g)
        (generator (λ (yield)
            (let loop ([v (g #f)])
                (when v
                    (begin (yield (fn v))
                           (loop (g #f))))
                #f))))

    (define (g-filter fn g)
        (generator (λ (yield)
            (let loop ([v (g #f)])
                (when v
                    (when (fn v)
                        (yield v))
                    (loop (g #f)))
                #f))))

In the above code, we've used the simple protocol that when a 
generator produces ``#f``, it means it's completed and no further
calls are possible.


