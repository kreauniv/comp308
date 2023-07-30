Lambda - via β-abstraction
==========================
:author: Srikumar K. S.
:date: 29 July 2023

.. note:: This section is a repeat of the previous one but presents a slightly
   different take on the topic via extensive use of β-abstraction. **You can
   skip this if you're comfortable with the topic**.

As we saw, Alonzo Church established that a "calculus" of functions is adequate
to express anything computable. He further shows how to start from "just
functions" and produce representations for what we normally need in expressing
various algorithms. A key part of this demonstration is a representation for
numbers that's come to be known as "Church numerals". We also saw how the idea
of recursion can also be expressed in terms of various "fixed point
combinators".

Of course, nobody really programs with Church numerals, not to mention that
they are woefully in adequate for the absolute basics such as subtraction and
representing full integers. And we don't really use fixed point combinators
very often in "real world programming". [#fpc]_ So what purpose does learning
these serve us?

.. [#fpc] We'll see some places where they are useful tools, even though these
   largely arise when building up programming languages and not usually when
   using a language to build programs.

When we program, we're repeatedly dealing with abstraction and encapsulation.
We've seen that functions and function composition perform the job of
encapsulating computations and making them reusable. Working through Church
numerals and the fixed point combinators serves as a great exercise to practice
β-abstraction, which offers a systematic and explorative way to work our way up
from "we know how to do this" to "what is this exactly as a concept?".

So this writeup focuses on a re-presentation of these ideas through the lens of
β-abstraction. I'm going to try and be explicit about the use of β-abstraction
throughout and at times that might feel trivial or laborious, but I hope you
gain enough fluency with the idea by the end that you don't need to think hard
to leverage it in the future.

λ-calculus
----------

So the basics first -- expressed in Racket notation using s-expressions.

Its "stuff"
~~~~~~~~~~~

We call an expression of the notion of a "function" a "λ-term".

Its "structure"
~~~~~~~~~~~~~~~

1. An identifier like ``x``, ``y``, called "variables" due to the mathematical origin
   of λ-calculus, is a "λ-term".

2. If ``x`` and ``y`` are λ-terms, then ``(x y)`` is also a λ-term. This is 
   how function application is expressed.

3. If ``x`` is an identifier and ``E[x]`` is a λ-term that uses ``x`` in some
   way (including not using it at all), then ``(λ (x) E[x])`` is a λ-term.

Its "properties"
~~~~~~~~~~~~~~~~

**α-renaming**

    Two λ-terms that differ only in a change of variable are equivalent.
    ``(λ (x) E[x])`` is equivalent to and may be exchanged anywhere for
    ``(λ (y) E[y])``. Here ``x`` and ``y`` are identifiers.

**β-reduction**

    A λ-term of the form ``((λ (x) E[x]) y)`` may be "reduced" to ``E[y]``.
    Here ``y`` is a λ-term. Note that if ``y`` features any "free variables"
    (variables not bound to identifiers introduced by a ``(λ (id) ...)`` term
    that contains ``y``), you'll have to consider that the ``(λ (x) E[x])`` is
    first α-renamed using unique identifiers before performing the
    substitution.

**β-abstraction**

    You can go the other way too. A λ-term of the form ``E[y]`` can be
    "abstracted" to ``((λ (x) E[x]) y)``, provided ``y`` (a λ-term) does not
    feature variables bound to other enclosing ``(λ (id) ...)`` terms.

**η-reduction**
    
    A λ-term ``y`` is considered equivalent to ``(λ (x) (y x))`` provided the
    identifier ``x`` does not occur as a free variable in ``y``. Note that all
    terms in λ-calculus are what we'd call "functions", so this equivalence can
    be understood as one kind of equivalence of functions.

Allowances
----------

Strictly speaking, λ-calculus only talks about functions of one variable.
We can extend the idea to functions of multiple variables because this
case can be reduced to functions of one variable like this --

.. code:: racket

    (λ (x y) E[x,y]) => (λ (x) (λ (y) E[x,y]))

We'll also "define" identifiers to λ-terms using the usual Racket ``(define
...)`` construct.

Making pairs
------------

Our starting point for building the edifice of useful computational objects
is the absolute basic data structure -- the humble "pair" that associates
two objects. We need to be able to make pairs of objects, which are,
in our case, functions (we have nothing else to speak of).

.. code:: racket

   (define .first (λ (x y) x))
   (define .second (λ (x y) y))


Now we can pick one of two arguments using ``(.first x y)`` and
``(.second x y)``. If we β-abstract on the first term in these two
expressions, we get --

.. code:: racket

    ; 1
    ((λ (z) (z x y)) .first)

    ; and 2
    ((λ (z) (z x y)) .second)

We see that the head λ-terms are both identical up to α-renaming,
but still specific to ``x`` and ``y``. So β-abstracting that term
on both ``x`` and ``y`` gives us the ``pair`` function.

.. code:: racket

    (λ (z) (z x y)) 
    ; =>
    ((λ (x y) (λ (z) (z x y))) x y)

    (define pair (λ (x y) (λ (z) (z x y))))
    (define swap (λ (p) (pair (p .second) (p .first))))


We can now make pairs using ``pair`` and get its contents out using ``.first``
and ``.second``. The value of having the ability to make pairs is that we
can build pretty much any other data structure out of it. But we'll first
need some basics like numbers to store in these data structures.

Church numerals
---------------

The word "numeral" refers to a way of expressing or representing a number.
So 123, 01111011, CXXIII, १२३ are all representations of the same *number*.
Church numerals are such a representation of numbers (whole numbers to be
precise) in λ-calculus.

The key idea behind Church numerals is to represent a whole number ``n``
as "n applications of a function to a value". Let's write that down first.

.. code:: racket

    (f   (f    (f   ...   (f x)...)))
    ; --- n occurrences of f ----
    
So if ``n`` is a Church numeral representing the concept "n applications of f",
we write ``(n f)`` when we're considering it being applied to ``f``. But we're
talking of "n applications of f to x", so we take the "n applications of f"
and apply it to ``x``, to get ``((n f) x)``. Therefore ``n`` will have the form
``(λ (f) (λ (x) ...))``. Remember this, since we need to stick to this form for
all Church numerals and operators that combine them to produce other numerals.

Let's look at "one application of f on x" first.

.. code:: racket

    (f x)

But what are these ``f`` and ``x``. The answer in λ-calculus is "some two
functions". Since these are "some two functions", we can consider the 
β-abstracted form of them that abstracts over both.

.. code:: racket

    (((λ (f) (λ (x) (f x)) f) x))

The λ term ``(λ (f) (λ (x) (f x)))`` now captures the idea of "one 
application of a function to an argument". We use this λ-term to
represent the number "one". Zero offers a simple case by extension.

.. code:: racket

    (define ch-one (λ (f) (λ (x) (f x))))
    (define ch-zero (λ (f) (λ (x) x)))

Successor
~~~~~~~~~

To define representations for other numbers, we need a way to define
the idea of a "successor" function ``ch-succ``, that can take us
from ``zero`` to ``one`` --

.. code:: racket

    (ch-succ ch-zero) = ch-one

So how do we define ``ch-succ``? We want ``(ch-succ n)`` to stand for "n+1
applications of f to x" or rather "one more application of f to x after n
applications". We can therefore express this as ``(f ((n f) x))``. Beta
abstracting over ``f`` and ``x`` first gives us the representation of "n+1" for
a specific n. This is ``(λ (f) (λ (x) (f ((n f) x))))``. To generalize over
``n``, we β-abstract over it to get ``ch-succ``.

.. code:: racket

    (define ch-succ (λ (n) (λ (f) (λ (x) (f ((n f) x))))))

Converting between Racket and Church numerals
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To play with these concretely in Racket, you can use the following functions to
convert from Racket's number representation to Church numerals.

.. code:: racket

    ; Here n is a Racket numeral
    (define (i->ch n)
      (if (= n 0)
          ch-zero
          (ch-succ (i->ch (- n 1)))))

    ; Here n is a Church numeral
    (define (ch->i n)
      ((n (λ (x) (+ x 1))) 0))

Addition
~~~~~~~~

Now how do you add two Church numerals? Given ``m`` and ``n`` represent
their respective number of applications of a function ``f`` to an ``x``,
we seek to calculate ``((m f) ((n f) x))``. As before, we β-abstract
over ``f`` and ``x`` to get the standard "Church numeral protocol".

.. code:: racket

    (λ (f) (λ (x) ((m f) ((n f) x))))

The above is specific to some given ``m`` and ``n``. To generalize
to addition of arbitrary ``m`` and ``n``, we need to, once more,
β-abstract over them to get ``ch-add``. This time though, we'll
take the comfort of multi-argument functions since it is easier
to think of addition as a binary operator.

.. code:: racket

    (define ch-add (λ (m n) (λ (f) (λ (x) ((m f) ((n f) x))))))

    ; Try this out
    (ch->i (ch-add (i->ch 5) (i->ch 3)))

Taking advantage of the ``compose`` function defined as --

.. code:: racket

    (define compose (λ (f g) (λ (x) (f (g x)))))

, we see that the above ``ch-add`` definition can be re-expressed in slightly
more abstracted form as --

.. code:: racket

    (define ch-add (λ (m n) (λ (f) (compose (m f) (n f)))))

This form brings out some of the symmetry between ``m`` and ``n`` in the
operation, even though ``compose`` is a non-commutative operation in general.

Now, we can't claim to have understood something if we can only explain it in
one way. Our representation for numbers is pretty abstract now -- in that it is
talking about applications of an **arbitrary** function to an **arbitrary**
value. So we can also re-imagine the idea of :math:`m+n` as "m'th successor of
n" or in other words, "m applications of ``ch-succ`` to n". So :math:`m+n` can
simply be expressed as ``((m ch-succ) n)``. So indeed, we have, after
abstracting on ``m`` and ``n`` --

.. code:: racket

    (define ch-add (λ (m n) ((m ch-succ) n)))

... which is an equally valid (and clearer) definition of ``ch-add``. 

Multiplication
~~~~~~~~~~~~~~

Now how do we multiply two numbers? If ``m`` and ``n`` are two Church numerals
standing for "m applications of f" and "n applications of f", we seek to capture
the idea of "m applications of n applications of f". This is easily expressed
as ``(m (n f))`` with the ``x`` already abstracted out. Therefore multiplication
is simply β-abstracting over ``f`` first, followed by a two-argument abstraction
over ``m`` and ``n`` --

.. code:: racket

    (define ch-mul (λ (m n) (λ (f) (m (n f)))))
    ; ... or equivalently simply
    (define ch-mul compose)

    ; Try this
    (ch->i (ch-mul (i->ch 5) (i->ch 3)))

We also note that this is ordinary function composition of ``m`` and ``n``.
    

Subtraction
~~~~~~~~~~~

How do you then get subtraction? Can we do a "predecessor" operator?

.. code:: racket

    (ch->i (ch-pred (i->ch 5)))
    ; Should print 4

Let's write a naïve version --

.. code:: racket

    (define ch-pred (λ (n) (λ (f) (λ (x) ((b-inverse f) ((n f) x))))))

i.e. if only we had access to :math:`f^{-1}` as a function, we can just
use that and apply it once after applying :math:`f` ``n`` times.

Supposing we change our representation of the function that we're applying
``n`` times, to include information about the inverse. Supposing our
functions always come in pairs and we can take the first part to get
the original function and the second part to get its inverse. So our 
"protocol" now changes slightly and the ``f`` argument is now to be
treated as a ``pair`` of :math:`(f,f^{-1})`. Then we have the following
concept representations --

1. "successor" is one more application of the **first** part of the joint function
   and can be written as ``((f .first) ((n f) x))``. (Think about what if ``n``
   stood for a negative number.)

2. "predecessor" is one more application of the **second** part of the joint function
   and can be written as ``((f .second) ((n f) x))``.

3. :math:`m+n` can be thought of in the same way as for Church numerals, so we
   can write ``((m f) ((n f) x))``. Here, the ``f`` is expected to be an
   :math:`(f,f^{-1})` pair.

4. :math:`-n` (i.e. "negation") is represented by swapping the pair of functions,
   so we get ``(n (swap f))`` as the representation of :math:`-n`.

5. :math:`m*n` is again thought of as "m applications of n applications f", but
   this time, the "m applications" part needs to receive a "pair"
   representation, and ``(n f)`` does not produce a pair value. Furthermore, if
   ``m`` is positive, we ned to use ``(n f)`` and if it is negative, we need to
   use :math:`-n` which we know is ``(n (swap f))``. These two are inverses of
   each other, so the idea of :math:`m*n` is captured by ``(m (pair (n f) (n
   (swap f))))``. Think a bit more about how that'd play out for various
   combinations of signs for ``m`` and ``n``.

.. admonition:: **Exercise**

    Apply β-abstraction to those terms to define ``b-zero``, ``b-succ``,
    ``b-pred``, ``b-add``, ``b-sub`` and ``b-mul``.

We also need to define new converters between Racket and these "b"
representations ("b" chosen for "Brahmagupta" - see `Church-Brahmagupta
numerals`_).

.. _Church-Brahmagupta numerals: https://sriku.org/posts/church-brahmagupta-numerals/

.. code:: Racket

    (define (b->i n)
      (n (pair add1 sub1) 0))

    (define (i->b n)
      (if (= n 0)
          b-zero
          (n (pair b-succ b-pred) b-zero)))


    ; Try this
    (b->i (i->b -10))
    (b->i (b-add (i->b 5) (i->b 3)))
    (b->i (b-sub (i->b 3) (i->b 5)))
    (b->i (b-mul (i->b -5) (i->b 3)))
    (b->i (b-mul (i->b -5) (i->b -3)))

Understanding recursion
-----------------------

We have the whole of integers done now. However, we haven't solved the case of
repetition -- a.k.a. "iteration" -- which in functional terms we express using
the concept of "recursion". In fact, even in the previous section, in our
definitions of the conversion functions, we assumed the ability to define and
use recursive functions ... and that's not in our λ-calculus formalism.

So we need to be able to express recursion using ordinary λ-terms.

Let's take an example -- the Newton-Raphson solver for the root of a function
near a given guess point.

.. code:: racket

    (define d (λ (f x eps)
                 (/ (- (f (+ x eps)) (f (- x eps))) (* 2 eps))))

    (define solve 
      (λ (f xn zero-eps d-eps)
         (if (< (abs (f xn)) zero-eps)
             xn
             (solve f (- xn (/ (f xn) (d f xn d-eps))) zero-eps d-eps))))

At the point at which we're "define"-ing ``solve``, we're already assuming
its availability in the body of the definition. This is not a facility we
included in λ-calculus. So we'd either have to cave in and include this
new possibility, thereby extending the "language" or show how the concept
can be captured with the currently available facilities.

First, we recognize that we don't know what the value of ``solve`` in the
inner definition part should be. So how do we account for it? Yes, we
β-abstract it out and make it an argument like this --

.. code:: racket

    (define solve/cheat
      (λ (solve)
         (λ (f xn zero-eps d-eps)
            (if (< (abs (f xn)) zero-eps)
                xn
                (solve f (- xn (/ (f xn) (d f xn d-eps))) zero-eps d-eps)))))

Now, when we actually have the ``solve`` function available, we can pass it to
``solve/cheat`` like ``(solve/cheat solve)`` to get ... the ``solve`` function!
i.e. we have the equation ``solve = (solve/cheat solve)``. The gap here is that
while ``solve/cheat`` is a well formed λ-term and captures the calculation we
intend to do, we still don't know how to get ``solve`` out of it.

In mathematical terminology, a value :math:`x` that satisfies :math:`f(x) = x`
for some given function :math:`f` is said to be a "fixed point" of :math:`f`.
The "fixed" comes from trying to apply :math:`f` repeatedly to a value. If you
choose an :math:`x` such that :math:`x = f(x)`, then no matter how many times
you apply it, the value doesn't change -- i.e. stays "fixed". So we're in
essence seeking the "fixed point" of ``solve/cheat``.

One other trick we can do is to rewrite ``solve`` using an extra argument,
in which slot we intend to pass itself.

.. code:: racket

    (define solve2
      (λ (g f xn zero-eps d-eps)
         (if (< (abs (f xn)) zero-eps)
             xn
             (g g f (- xn (/ (f xn) (d f xn d-eps))) zero-eps d-eps))))

Now instead of ``solve``, we can call the well-formed ``solve2`` like
``(solve2 solve2 f xn zero-eps d-eps)``. This is "almost usable" and
it looks like we have a mechanical way to deal with recursive functions.
If it is truly mechanical, we need to be able to express the transformation
from ``solve/cheat`` to a form that can be used exactly like ``solve``
using an appropriate λ-term definintion.

First, we rewrite ``solve2`` by pulling out the first argument.

.. code:: racket

    (define solve/good
      (λ (g)
         (λ (f xn zero-eps d-eps)
            (if (< (abs (f xn)) zero-eps)
                xn
                ((g g) f (- xn (/ (f xn) (d f xn d-eps))) zero-eps d-eps)))))

Now, we see that ``solve = (solve/good solve/good)``.

We can also therefore see that --

.. code:: racket

    (solve/good solve/good) = (solve/cheat (solve/good solve/good))

For brevity, we'll drop the "solve/" prefixes for now and just write --

.. code:: racket

    solve = (good good)
    (good good) = (cheat (good good))

We also see ``(good f) = (cheat (f f))`` by simple β-reduction of ``cheat``.

So we have ``good = (λ (f) (cheat (f f)))``.

This gets us --

.. code:: racket

    solve = (good good) = ((λ (g) (g g)) good) 
          = ((λ (g) (g g)) (λ (f) (cheat (f f))))

β-abstracting over cheat gets us --

.. code:: racket
    
    solve = ((λ (c) ((λ (g) (g g)) (λ (f) (c (f f))))) cheat)

The λ-term being applied to ``cheat`` is now producing a solution of
the equation ``solve = (cheat solve)`` and captures the entire process of
the transformation! This "fixed point combinator" is called the "Y combinator".

.. code:: racket

    (define Y (λ (c) ((λ (g) (g g)) (λ (f) (c (f f))))))

**Take a moment** to savour that! We now have a function that can take a
**specification** of a recursive/iterative/repetitive evaluation and actually
produce a function that does the repetition. We've completed the "mechanical
transformation" demand we set out to meet!

Now, given a "cheat" function, we can get the actual recursive function
using ``(Y solve/cheat)``.

Taking a step back, we're actually trying to find a function ``F`` such that

.. code:: racket

    (F cheat) = (cheat (F cheat))

This ``F`` seems to be itself recursively defined and we seem to be back at
square one. However, we can apply our "good" trick to ``F``. 

.. code:: racket

    (define F (λ (cheat) (cheat (F cheat))))
    ; =>
    (define G (λ (h) (λ (cheat) (cheat ((h h) cheat)))))
    ; => F = (G G)
    ; => F = ((λ (g) (g g)) G)
    ; =>
    (define F ((λ (g) (g g)) (λ (h) (λ (cheat) (cheat ((h h) cheat)))))
    
This gets us **another** fixed point combinator called the "Turing combinator"
also written as the :math:`\Theta`-combinator.

Note that neither ``Y`` nor ``Θ`` in the above forms work in normal Racket.
They require the ``#lang lazy`` language because we've been doing equational
reasoning that's only valid as long as we're not eagerly performing
β-reductions everywhere.

One way to make, say, ``Θ`` work in ordinary "eager" Racket is to realize that
the the problematic eager expansion is the ``((h h) cheat)`` part. Since this
whole expression is a function, we can use η-transformation on this to delay
its computation to the point when it is needed within the body of ``cheat``, by
writing it as ``(λ (x) (((h h) cheat) x))``. With this, the ``((h h) cheat)``
won't get evaluated until ``cheat`` needs it, at which point it will invoke it
with an appropriate argument.
        
So the "eager" version of the Turing combinator is written as --

.. code:: racket

    (define Θ ((λ (g) (g g)) 
               (λ (h) (λ (cheat) (cheat (λ (x) (((h h) cheat) x)))))))

If you have the careful eye, you'd notice that ``x`` is the argument we'd want to
pass to our original recursive function and we had many arguments to pass. So
it would've been more appropriate to write that as --

.. code:: racket

    (define Θ ((λ (g) (g g)) 
               (λ (h) (λ (cheat) (cheat (λ x (apply ((h h) cheat) x)))))))

Here, if an identifier is given without parentheses, Racket will bind it to
the entire list of arguments that will be given to the λ, and ``apply``
applies a function to a given **list** of arguments.

Similarly, we can also make the Y combinator eager like this --

.. code:: racket

    (define Y (λ (c) ((λ (g) (g g)) (λ (f) (c (λ x (apply (f f) x)))))))

Moral of the story
------------------

We started with low level ideas and have systematically moved to work with
higher level concepts using β-abstraction. In particular, arriving at the
general "fixed point combinators" starting from concrete specifications of
recursive/iterative/repetitive computations was done through β-abstraction
steps too. Now we're in a position where we can study these resultant artifacts
to understand the essence of recursive computations, whereas originally we were
forced to pick concrete examples to think about. In that sense, we can **now**
claim that we "understand" the idea of recursion because we know how to
mechanize it. Even if Racket didn't give us a way to express recursive
computations by letting us use a name before it being fully defined, we now
know how to deal with that **mechanically** and can give ourselves recursion.

This pattern crops up in many situations where we start off with a cursory and
weak understanding of concrete aspects and through systematic and judicial
application of β-abstraction, we can arrive at the key concepts important to
the domain. This is therefore a powerful process of "theory building" for a
domain that we can do as programmers.


