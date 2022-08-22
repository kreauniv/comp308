Lambda - the everything
=======================

If Alonzo Church were asked "how far does the computational rabbit hole go?",
he might have answered "It's ``lambda`` all the way through.".

Alonzo Church, in the 1930s (yes, that's getting to be a century ago!), and his
students formulated what could be the called the essence of anything
computable. The insight they had was that given functions and function
applications, anything that can be computed is expressible. Note that we aren't
talking about functions of numbers or strings or booleans or anything else. The
only entities in Church's world are functions, and the only thing you can do
with them is to apply them to other things (which are ... functions) ... and he
claimed that all of what's computable is expressible using these! What's known
as the `Church-Turing thesis`_ is the proof that Church's "lambda calculus"
is equivalent in its universality to Alan Turing's "Turing machine".

.. _Church-Turing thesis: https://en.wikipedia.org/wiki/Church%E2%80%93Turing_thesis

Take a moment to digest that large claim, for the ``lambda`` construct in
Scheme is directly based on that foundational insight. In studying programming
languages, we repeatedly encounter this idea of "we can express X in terms of
Y" and where we make larger sets of these "X"s for our convenience where a much
smaller set of "Y"s will suffice for the job. This "extra", we call "syntactic
sugar", which draws from Alan Perlis' joke - "Syntactic sugar causes cancer of
the semicolon." -- made in reference to unessential syntactic cruft often added
on to programming languages by their creators without a taste for minimalism.

The process of taking an expression that's rich in "syntactic sugar" and
producing an equivalent expression using fewer "primitives" is something we'll
refer to as "desugaring". Since it is a kind of translation, it could also be
taken as a kind of "compilation", but in case that scares you, don't worry
and just stick to "desugaring".

The point of lambdas is that lambdas are at the end of the entire stack of
sugarings. The buck stops with them.

So what's ``lambda``
--------------------

In Scheme, a "lambda expression" is an expression of the general form
shown below --

.. code-block:: racket

    (lambda (..<list-of-var-names>..) <expr-using-vars-in-the-list>)

It represents a packaged computation that can be performed when given concrete
values for the variables listed after ``lambda`` in the above expression.

For example, ``(lambda (x) (* x x))`` is the function that squares numbers.
When given a number ``2``, by substituting ``x`` with ``2``, you can compute
the result of what the lambda expression denotes -- which is ``(* 2 2) = 4``.

There are two main rules you need to know when working with ``lambda``
expressions (the abstract ones).

**α-renaming**
    If ``(lambda (x) E[x])`` is a lambda expression in one argument where ``E[x]``
    denotes some expression involving the variable ``x``, then you can change
    the name of ``x`` to anything else and what the expression denotes is
    considered to be the same. i.e. You can rewrite it to ``(lambda (y) E[y])``
    (where we use the same ``E``) and it means the same thing.

**β-reduction**
    If you have an expression of the form ``((lambda (x) E1[x]) E2)`` where ``E1[x]``
    is an expression that (optionally) uses the variable ``x`` and ``E2`` is some other
    expression, then it is equivalent to ``E1[E2]``. i.e.

        ``((lambda (x) E1[x]) E2) => E1[E2]``

    It is important to note that when we say "is equivalent to", it means you
    can rewrite a sub-expression that looks like one side to the other form
    **anywhere**. We refer to the above left-to-right rewrite as "β-reduction"
    and the corresponding right-to-left rewrite as "β-abstraction".

    Just as lambdas are the conceptual basis of all of computation, all
    abstraction in computing boils down to β-abstraction.

.. note:: "β-reduction" can be considered a fancy term for "substitution",
   for that's what it is. We don't have a corresponding simple term for the
   opposite transformation though. So we'll continue to call it "β-abstraction".
   We'll refer to the transformation ``E1[E2] => ((lambda (x) E1[x]) E2)``
   as "β-abstracting over ``E2``".

.. warning:: When performing a β-reduction step in Scheme, you need to be careful
   not to substitute symbols within a ``quote`` sub-expression. For example,
   ``((lambda (x) (quote (+ x x))) 3)`` reduces to the list ``'(+ x x)``
   whereas ``((lambda (x) (+ x x)) 3)`` reduces to ``(+ 3 3) = 6``.

Take the expression ``((lambda (x) (* x ((lambda (x) (- x 1)) x))) 10)`` and
try to apply the reduction rules. If you took the "β-reduction" rule in the
naive way, you might end up with ``(* 10 ((lambda (10) (- 10 1)) 10))`` and
then scratch your head about what you have at hand and what to do with it next!
To do this correctly, you must see that the original expression is the same as
``((lambda (x) (* x ((lambda (y) (- y 1)) x))) 10)`` .. where we've "α-renamed"
the inner lambda's ``x`` variable to ``y``, because, well they're supposed to
be equivalent right? If you now do β-reduction on this equivalent expression,
you won't be left with the confused expression.

So the two rules are taken to be **always** applicable in evaluating an
expression and all correct applications of the rules must evaluate to 
the same result no matter the sequence in which they're applied.

Tall claims need taller evidence
--------------------------------

Back to Church, what he made was a tall claim -- that all computable functions
are expressible in terms of lambdas. When we make such a claim, we have to back
it up though. To recap, he's saying that you don't need ``cons``, ``car``,
``cdr``, ``if``, ``let``, ``cond``, booleans or numbers or strings or whatever
we're used to in normal programming. He claimed that all of these are
representable using lambdas **alone** .. and showed how to do it.

We'll now work through how to represent basic things in terms of which we
can build a whole computational edifice.

Pairs
~~~~~

Pairs are the simplest of data structures. Once you can make a pair of two
things like ``(pair a b)`` or the equivalent in a programming language, you can
get lists using ``(pair a (pair b (pair c ... (pair x sentinel)))..))`` where
we use a ``sentinel`` to indicate end of the list. You can also make trees
using nested structures like ``(pair (pair a b) (pair (pair c d) (pair e f)))``.
Or tables as a list of lists. Or even graphs. So if we can show we can
represent pairs using just ``lambda``, we're good with the other structures.

``(define pair (lambda (x y) ...))``

What should we put within the ``...``? In fact, what **can** we put in there
when all we have are functions (i.e. lambda expressions)? So we're now
looking at --

``(define pair (lambda (x y) (lambda (p) ...)))``

Again, what can we put in there? We have a ``p`` and some two arbitrary values
``x`` and ``y`` that we're expected to "store" in the pair. About the only
thing we can do (apart from nesting lambda once more, which would seem
pointless) is to apply ``p`` to the ``x`` and ``y``.

``(define pair (lambda (x y) (lambda (p) (p x y))))``

We can now make "pairs" like below --

``(define p1 (pair 12 100))``

(taking the liberty to use numbers just to illustrate). Since ``p1`` is a function
that takes one argument, the only thing we can do with it is call it. Since its
argument is also a function that's applied to 2 arguments, let's consider
some simple 2-argument functions shown below --

``(define .first (lambda (x y) x))``

and

``(define .second (lambda (x y) y))``

The functions ignore one of their arguments and just evaluate to the other.
Now what happens when you apply ``p1`` to these two functions.

.. code-block:: racket

    (p1 .first)
    => ((pair 12 100) (lambda (x y) x)) ; substitute their definitions
    => (((lambda (x y) (lambda (p) (p x y))) 12 100) (lambda (x y) x))
    ; β-reduce the first term
    => ((lambda (p) (p 12 100)) (lambda (x y) x))
    ; β-reduce the expression again
    => ((lambda (x y) x) 12 100)
    ; β-reduce the expression again
    => 12

.. admonition:: **Exercise**

    Work it out similarly and show that ``(p1 .second)`` results in ``100``.

So we have a function now named ``pair`` that can make so-called "pair objects"
and we can get the individual values out of the pair object using the 
"accessor" functions ``.first`` and ``.second``.

Many of you are familiar with "object oriented languages" like Python and will
see the reasoning behind naming the accessor functions that way .. since the
expression ``(p1 .first)`` looks very similar to ``p1.first`` typical of such
languages.

.. note:: The ones with a careful eye might've noticed that while we claimed to
   only use lambdas, we ended up using ``define`` in the above definitions. We
   use it here only as a substitute for writing the mathematical definitional
   equality :math:`pair = (λ\ (x\ y)\ (λ\ (p)\ (p\ x\ y)))` and because it
   actually permits you to type it into Racket and check things out for
   yourself. We therefore lose no generality by using ``define`` in the above
   code. Also, lambda calculus deals only with one-argument functions and we've
   used two here. However, :math:`(λ\ (x\ y)\ E[x,y])` can be mechanically
   rewritten to :math:`(λ\ (x)\ (λ\ (y)\ E[x,y]))` with corresponding changes
   to substitution steps without loss of logical correctness. So we'll take
   that additional liberty here too.


Booleans
~~~~~~~~

.. admonition:: **Exercise**

    The only place we use boolean values is to do a branch within an ``if``
    condition. So if we can implement ``if`` purely using ``lambda``, we're
    good. For this exercise, you'll need to consider "lazy evaluation" instead
    of "eager evaluation" to keep things simple. In fact, for the rest of this
    demonstration, we'll use lazy evaluation with ``#lang lazy``. The earlier
    ones will also work with ``#lang lazy``. So complete the definition below --

    ``(define IF (lambda (bool then-expr else-expr) ....))``

    Remember the trick we used with ``pair``. You have all you need in that
    code.

Numbers
~~~~~~~

Recursion
---------





    

