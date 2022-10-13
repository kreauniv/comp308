Generators
==========

In :doc:`control`, we implemented a rudimentary way to define and work with
generators in our small stack-based language. In this section, we'll see how
Racket provides us with full continuations that can be used for this purpose.

:rkt:`call/cc` and :rkt:`let/cc`
--------------------------------

When working with our now-familiar "distance" function, :rkt:`(sqrt (+ (* dx dx) (* dy dy)))`,
we saw how we can get "the rest of the computation that's supposed to happen after :rkt:`(* dx dx)`"
by β-abstracting over :rkt:`(* dx dx)` to get :rkt:`(λ (dx2) (sqrt (+ dx2 (* dy dy))))`. Racket/Scheme
provide access to this function for us. We just have to ask!

.. admonition:: **Terminology**

    The function that represents "the rest of the computation" at any given evaluation point
    (i.e. sub-expression) is called the **current continuation** at that point. This function
    will differ depending on which sub-expression is under consideration, since what remains
    to be done will differ.

In the "distance" expression, to get access to the current continuation at the
time we're evaluating the :rkt:`(* dx dx)` (note that the language talks about
the **dynamic** state of the program, not its lexical structure) can be obtained
using :rkt:`call/cc` (read as "call with current continuation") like this --

.. code-block:: racket

    (sqrt (+ (call/cc (λ (k) (k (* dx dx)))) (* dy dy)))

The entire :rkt:`(call/cc (λ (k) (k (* dx dx))))` is simply equivalent to :rkt:`(* dx dx)`.

One way to understand this is to think of the :rkt:`k` continuation as labeling
the dynamic return point of the :rkt:`call/cc` invocation that is providing it.
So call :rkt:`k` with some value will result in the entire :rkt:`call/cc`
expression that provided that :rkt:`k` completing its computation with the
value as its result. In the above code, we're supplying :rkt:`(* dx dx)` to
:rkt:`k`, and so the whole :rkt:`call/cc` expression is equivalent to :rkt:`(*
dx dx)`. So you could think of it as :rkt:`(call/cc (λ (return) (return (* dx
dx))))` and that would be correct.

It can get quite cumbersome to write lambdas every time we use :rkt:`call/cc`, so
Racket/Scheme provides some syntactic sugar for it -- :rkt:`let/cc` that is convenient.

.. code-block:: racket

    (let/cc k ...some-expression-using-k...) 
    ; desugars into 
    (call/cc (λ (k) ..some-expression-using-k...))

i.e., :rkt:`let/cc` introduces the local variable :rkt:`k` into the expression
much like :rkt:`let`.

You could ask "so what?". Having access to the current continuation as a value
gives us many super powers -- we can implement many different types of control
flow within our program with this as a primitive. For example, since the
continuation is available as a value, we can store it away to be called later
on. This is what we need to implement generators.

Python generators
-----------------

In python, you can return from a function in two ways --

1. Using the ``return <value>`` statement.

2. Using the ``yield <value>`` statement.

While :rkt:`return` finishes the calculations that the function was doing, :rkt:`yield`
merely suspends it at that state. It means you can resume from that dynamic point
and continue on to the next :rkt:`yield`. While all code that follows :rkt:`return`
is dead code, you can have multiple :rkt:`yield` statements in the code and the function
will suspend every time it encounters such a :rkt:`yield`.

A function that uses :rkt:`yield` is called a "generator" in python. Similar
constructs in other languages may be called "co-routines" or "asynchronous
functions" when combined with event loops. Though some subtle differences exist
between these various presentations exist, they're all basically the same idea
underneath -- the idea of "reified continuations". The word "reified" in CS is
used to mean "made real" -- i.e. made into a value that can be used like a
value.

Consider the following code sequence.

.. code-block:: python


    def silly_gen():
        print("Generating 'one'");
        yield "one"
        print("Generating 'two'");
        yield "two"
        print("Generating 3");
        yield 3;
        print("Generating 4");
        yield 4;

    g = silly_gen(); # Prints nothing
    next(g)
    #> Generating 'one'
    #> 'one'
    next(g)
    #> Generating 'two'
    #> 'two'
    next(g)
    #> Generating 3
    #> 3
    next(g)
    #> Generating 4
    #> 4
    next(g)
    #> Traceback (most recent call last):
    #> File "<stdin>", line 1, in <module>
    #> StopIteration
    #
    # (This last bit could differ depending on where you run this code)


What's happening there?

1. With the first call to :rkt:`silly_gen()`, we create a "generator object" that
   can suspend and resume computations. No computation has actually started just yet though,
   as noted by "Generating 'one'" not being printed at that point.

2. Every time we cann :rkt:`next(g)`, we resume the generator and cause it to
   run until the next :rkt:`yield`. The return value of the :rkt:`next(g)` call
   is what was given as the value in :rkt:`yield <value>`.

3. Once we run out of yields, python arranges to terminate the code by raising
   an exception named :rkt:`StopIteration`.


We'll now see how to implement that in Racket. The idea is that in any language
that gives us the equivalent of :rkt:`call/cc` (like our stack language to which
we gave that power in :doc:`control`), we can follow the same thinking. What we
won't do here is to develop generator **syntax** in Racket. We'll merely show how
to mechanically produce generator-like behaviour. Once you learn how to define
your own syntax in Racket, it then becomes a simple matter to mechanically translate
generator code to produce the necessary constructs.

Generators in Racket
--------------------

We want to be able to write something like this --

.. code-block:: racket

    (generator (a b c)
        (yield "one")
        (yield "two")
        (yield 3)
        (yield 4))

... as a parallel to the python code. 

Let's start with treating the generator as an ordinary lambda --

.. code-block:: racket

    (define (gen)
        (let/cc return
           ;...
           ))

The :rkt:`return` captures the dynamic continuation point at the point of call
of :rkt:`(gen)`. We will need to return something to that point to help
control the progress of the generator. What could the "yield" point look like?

.. code-block:: racket

    (define (gen)
        (let/cc return
            ;...
            (let/cc resume (yield (list "one" resume)))
            ))

The "list of two values" is a placeholder mechanism to pass on the resume point to the
point at which :rkt:`next` call is happening. We're yet to determine the :rkt:`yield` though.
What should :rkt:`yield` be? If we treat it as a function that doesn't return to the point
(unless resumed), we can see that it is essentially a continuation. What continuation is it
though?

.. note:: Think about it for a bit and see if you can answer it.

The yield continuation is expected to come from the caller's dynamic call
point. So we need a mechanism for the caller to pass their continuation into
the generator so it can yield contro back to that call point when it wants to
pause.

We therefore see that there are two bits of shared state information we need to
have for each generator instance -- one channel passes a resume continuation
from the generator to the caller and another channel passes a yield
continuation from the caller into the generator. Let's use a box for each of these.

.. code-block:: racket

    (define (gen)
        (let/cc return
            (define yield-box (box #f))
            (define resume-box (box #f))
            (define (yield val) ((unbox yield-box) val))
            ;...
            ))

... but we want "yield" to also enable resumption. For that we can roll the
:rkt:`let/cc resume` into the yield and put that continuation into the
:rkt:`resume-box`.

.. code-block:: racket

    (define (gen)
        (let/cc return
            (define yield-box (box return))
            (define resume-box (box #f))
            (define (yield val) 
                ; Mark the point where we want the code that calls "next"
                ; to resume from.
                (let/cc resume
                    ; Store this resume point in the resume-box accessible to
                    ; the generator user.
                    (set-box! resume-box resume)
                    ; Return to the caller at the marked yield point provided by
                    ; the caller. In the very first instance, this will return to
                    ; the point where the generator is being created by calling
                    ; (gen). In that case alone, we pass the caller both the
                    ; yield-box and resume-box.
                    ((unbox yield-box) val)))
            (yield (list yield-box resume-box)) ; Pass the channels to the caller at 
                                                 ; the generator creation point.

            ; Ordinary generator code using yield like a function.
            ; ...
            (yield "one")
            ; ...
            ))

    (define g (gen))
    ; g is now a list of yield-box and resume-box

    (define (next g val)
        (let/cc yield
            (let ([yield-box (first g)]
                  [resume-box (second g)])
                (set-box! yield-box yield)
                ((unbox resume-box) val))))


    (next g #f) ; The value is currently unused, but could be used if needed.
                ; As much as the generator is capable of passing a value back
                ; to the caller, the caller can also pass values back into the
                ; generator which will become the result of the (yield ..)
                ; expression.


Notice how the beginning part of the generator is completely independent of what the
generator actually does -- i.e. it is "boiler plate code" that can be auto generated.


.. admonition:: **Exercise**

    Try out the above version of the generator on your own. Explore what's
    possible with this. In particular explore the idea of the yield function
    itself being a first class value in our scheme of things. This is **more**
    powerful than Python generators where :rkt:`yield` is a keyword and not
    a value that can be passed out. In our case, for example, you can pass this
    yield funciton down as arguments to other functions as well.

Let's see if we can absorb the boiler plate code into a reusable function.
Given we're representing the generator state as a pair of boxes that contain
continuations, we can start there and model our generator as a lambda that
takes an extra parameter as its first argument, called :rkt:`yield`.

i.e. we want to write our generator as --

.. code-block:: racket

    (lambda (yield arg1 arg2 ...)
        ;...
        (yield val)
        ;...
        (yield val)
        ;...
        )

.. code-block:: racket

    (define (generator genfn . args)
        (let/cc return
            (define yield-box (box return))
            (define resume-box (box #f))
            (define (yield val)
                (let/cc resume
                    (set-box! resume-box resume)
                    ((unbox yield-box) val)))
            ; Pass the generator state to the caller for use by "next".
            (yield (list yield-box resume-box))
            ; Call the generator function with our newly minted "yield" function
            ; as the first argument.
            (apply genfn (cons yield args))))

Now, we can easily write the above python code like this --

.. code-block:: racket

    (define g (generator (λ (yield) (map yield '("one" "two" 3 4)))))
    ; Note that we can't map the yield function like this in Python
    ; because in Python yield is not a function or a value that works
    ; as one.
    (next g #f)
    (next g #f)
    (next g #f)
    (next g #f)

You can also make :rkt:`generator` a bit more convenient to use by
uncurrying the :rkt:`args`.

.. code-block:: racket

    (define (generator genfn)
        (lambda args
            (let/cc return
                (define yield-box (box return))
                (define resume-box (box #f))
                (define (yield val)
                    (let/cc resume
                        (set-box! resume-box resume)
                        ((unbox yield-box) val)))
                ; Pass the generator state to the caller for use by "next".
                (yield (list yield-box resume-box))
                ; Call the generator function with our newly minted "yield" function
                ; as the first argument.
                (apply genfn (cons yield args)))))

    (define gen (generator (λ (yield . args) (for-each yield '("one" "two" 3 4)))))
    ; With this form, the function `generator` works like a word that
    ; declares the given lambda function to be a generator. You can then call
    ; the produced functions to make make independently evolving generator instances.

    (define g (gen))
    (next g #f)
    ;...

    
Enjoy ... and the journey always continues on!

.. admonition:: **Exercise**

    Notice that if you call :rkt:`next` one too many a time, you get an error.
    How can you arrange for the generator to finish its calculations
    gracefully?

    **Hint**: Attend to where the result expression of the genfn is returning
    its value to. Where should it return to? .. and what can it possibly return
    to signal the end?


Search as a language feature
----------------------------

Many popular languages today have a language feature usually going by the name
"set comprehension", "list comprehension", "array comprehension" or "dictionary
comprehension". The essence of these constructs is nested for-loop iteration
where values are produced based on the for loop iterations which meet some
criteria expressed as a boolean constraint on the values being enumerated.

Generators are closely linked with comprehensions and languages like Julia even
make generators use the same syntax as comprehensions. So it is not unreasonable
to expect that the ideas we developed above can serve to explore a space of
variable values that need to meet some constraints. For example, let's consider
a toy problem of finding pythagorean triplets.

.. code-block:: python

    def pytriplets(m, n):
        for x in range(m, n):
            for y in range(m, n):
                for z in range(m, n):
                    if x*x+y*y == z*z:
                        yield (x,y,z)

How can we model this kind of searching using our scheme of things. First off,
we need to realize that the inner-most for loop gets to run fully for each of
the outer for loops -- i.e. the search is **depth first**. This kind of a
search can be modeled using a stack, where the top state of the stack captures
the state of the inner loop. Similar to what we did above, we will need
:rkt:`yield` to be modeled as "try to find one more case".  One other point to
note here is that there is a role played by the "else" part of the if -- it
tries the next possible set of values for x,y,z. We'll model that instead of
yield directly, because with search, we're interested in finding one solution
(at least for starters).

And what we'll use here is a stack of continuations!

.. code-block:: racket

    (define stack (box empty))
    (define (push val)
        (set-box! stack (cons val (unbox stack))))
    (define (pop)
        (let ([top (first (unbox stack))])
            (set-box! stack (rest (unbox stack)))
            top))

    (define (try-again)
        ((pop)))

    (define (ensure bool)
        (when (not bool)
            (try-again)))

    ; range produces one value at a time. If you don't
    ; like it, you can call (try-again) to get another.
    (define (range m n)
        (let/cc return
            (let/cc trynext
                (push trynext)
                (return m))
            (if (< m n)
                (range (+ m 1) n)
                (try-again))))

    (define (pytriplets m n)
        (let ([x (range m n)]
              [y (range m n)]
              [z (range m n)])
            (ensure (equal? (* z z) (+ (* x x) (* y y))))
            (list x y z)))


Now, if you call, say, :rkt:`(pytriplets 10 50)`, it will return a list
of three numbers that form a triplet. If you're not happy and want another,
you can invoke :rkt:`(try-again)` to get the next one.

.. code-block::

    > (pytriplets 10 50)
    '(10 24 26)
    > (try-again)
    '(12 16 20)
    > (try-again)
    '(12 35 37)
    > (try-again)
    '(14 48 50)
    > (try-again)
    '(15 20 25)
    > (try-again)
    '(15 36 39)
    > 

That was fun, wasn't it?

.. admonition:: **Question**

    Notice that the next result isn't being returned from the :rkt:`(try-again)`.
    Why is that? Do you want to change that behaviour? If so, how would you?
    Also, why is the result being printed out even though we aren't writing it
    out explicitly and are simply returning a list from :rkt:`pytriplets`?

.. admonition:: **Terminology**

    This kind of behaviour is referred to as "non-determinism" in a language.
    We know that the program is quite deterministic alright, but the reason the
    term is used is that at the point where the :rkt:`(range m n)` function
    call returns, the result could be any value in the range that meets
    criteria that's going to be specified **later** in the program. So at that
    point, we don't truly know what value it is going to produce.

.. admonition:: **Exercise**

    Write an :rkt:`options` function similar to :rkt:`range` that behaves like
    this -- It takes any number of arguments and, just as range runs over integers
    from the first arg to the second arg, steps through the arguments one by one.
    In other words, :rkt:`options` can return any one of its arguments, and the
    value it returns can be decided by any constraints on the value that may appear
    in the code after the :rkt:`options` call.

    .. code-block:: racket

        (define (pytriplets)
            (let ([x (options 2 3 4 5 6 7 8 9)]
                  [y (options 2 3 4 5 6 7 8 9)]
                  [z (options 2 3 4 5 6 7 8 9)])
                (ensure (equal? (* z z) (+ (* x x) (* y y))))
                (list x y z)))

    The above code should behave the same way as though :rkt:`(range 2 9)` was
    used instead of :rkt:`(options 2 3 4 5 6 7 8 9)`. Except that in the case
    of :rkt:`options`, the values can be of any type.
