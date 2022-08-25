Lambda - the everything
=======================

If Alonzo Church were asked "how far does the computational rabbit hole go?",
he might have answered "It's :rkt:`lambda` all the way through.".

Alonzo Church, in the 1930s (yes, that's getting to be a century ago!), and his
students formulated what could be called the essence of anything computable.
The insight they had was that given functions and function applications,
anything that can be computed is expressible. Note that we aren't talking about
functions of numbers or strings or booleans or anything else. The only entities
in Church's world are functions, and the only thing you can do with them is to
apply them to other things (which are ... functions) ... and he claimed that
all of what's computable is expressible using these! What's known as the
`Church-Turing thesis`_ is the proof that Church's "lambda calculus" is
equivalent in its universality to Alan Turing's "Turing machine".

.. _Church-Turing thesis: https://en.wikipedia.org/wiki/Church%E2%80%93Turing_thesis

Take a moment to digest that large claim, for the :rkt:`lambda` construct in
Scheme is directly based on that foundational insight. In studying programming
languages, we repeatedly encounter this idea of "we can express X in terms of
Y" and where we make larger sets of these "X"s for our convenience where a much
smaller set of "Y"s will suffice for the job. This "extra", we call "syntactic
sugar", which draws from Alan Perlis' joke - "Syntactic sugar causes cancer of
the semicolon." -- made in reference to unessential syntactic cruft often added
on to programming languages by their creators without a taste for minimalism.

The process of taking an expression that's rich in "syntactic sugar" and
producing an equivalent expression using fewer "primitives" is something we'll
refer to as "desugaring". Such a reduction is useful because it is usually
easier to reason about properties of a program if we have to deal with fewer
basic entities in it, than if we complicate it with ... well, "syntactic
sugar". Since desugaring is a kind of translation, it could also be taken as a
kind of "compilation", but in case that scares you, don't worry and just stick
to "desugaring".

The point of lambdas is that lambdas are at the end of the entire stack of
sugarings. The buck stops with them.

So what's :rkt:`lambda`
-----------------------

In Scheme, a "lambda expression" is an expression of the general form
shown below --

.. code-block:: racket

    (lambda (..<list-of-var-names>..) <expr-using-vars-in-the-list>)

It represents a packaged computation that can be performed when given concrete
values for the variables listed after :rkt:`lambda` in the above expression.

For example, :rkt:`` is the function that squares numbers.
When given a number :rkt:`2`, by substituting :rkt:`x` with :rkt:`2`, you can compute
the result of what the lambda expression denotes -- which is :rkt:`(* 2 2) = 4`.

There are two main rules you need to know when working with :rkt:`lambda`
expressions (the abstract ones).

**α-renaming**
    If :rkt:`(lambda (x) E[x])` is a lambda expression in one argument where :rkt:`E[x]`
    denotes some expression involving the variable :rkt:`x`, then you can change
    the name of :rkt:`x` to anything else and what the expression denotes is
    considered to be the same. i.e. You can rewrite it to :rkt:`(lambda (y) E[y])`
    (where we use the same :rkt:`E`) and it means the same thing.

**β-reduction**
    If you have an expression of the form :rkt:`((lambda (x) E1[x]) E2)` where :rkt:`E1[x]`
    is an expression that (optionally) uses the variable :rkt:`x` and :rkt:`E2` is some other
    expression, then it is equivalent to :rkt:`E1[E2]`. i.e.

        :rkt:`((lambda (x) E1[x]) E2) => E1[E2]`

    It is important to note that when we say "is equivalent to", it means you
    can rewrite a sub-expression that looks like one side to the other form
    **anywhere**. We refer to the above left-to-right rewrite as "β-reduction"
    and the corresponding right-to-left rewrite as "β-abstraction".

    Just as lambdas are the conceptual basis of all of computation, all
    abstraction in computing boils down to β-abstraction.

.. note:: "**β-reduction**" can be considered a fancy term for "substitution",
   for that's what it is. We don't have a corresponding simple term for the
   opposite transformation though. So we'll continue to call it
   "**β-abstraction**". We'll refer to the transformation :rkt:`E1[E2] =>
   ((lambda (x) E1[x]) E2)` as "β-abstracting over :rkt:`E2`". In most cases,
   when we're performing such a transformation, we're no longer really
   interested in the :rkt:`E2` and will usually focus on the preceding
   :rkt:`(lambda (x) E1[x])` and loosely talk about that as the β-abstracted
   expression.

.. warning:: When performing a β-reduction step in Scheme, you need to be careful
   not to substitute symbols within a :rkt:`quote` sub-expression. For example,
   :rkt:`((lambda (x) (quote (+ x x))) 3)` reduces to the list :rkt:`'(+ x x)`
   whereas :rkt:`((lambda (x) (+ x x)) 3)` reduces to :rkt:`(+ 3 3) = 6`.

Take the expression :rkt:`((lambda (x) (* x ((lambda (x) (- x 1)) x))) 10)` and
try to apply the reduction rules. If you took the "β-reduction" rule in the
naive way, you might end up with :rkt:`(* 10 ((lambda (10) (- 10 1)) 10))` and
then scratch your head about what you have at hand and what to do with it next!
To do this correctly, you must see that the original expression is the same as
:rkt:`((lambda (x) (* x ((lambda (y) (- y 1)) x))) 10)` .. where we've "α-renamed"
the inner lambda's :rkt:`x` variable to :rkt:`y`, because, well they're supposed to
be equivalent right? If you now do β-reduction on this equivalent expression,
you won't be left with the confused expression.

So the two rules are taken to be **always** applicable in evaluating an
expression and all correct applications of the rules must evaluate to 
the same result no matter the sequence in which they're applied.

Tall claims need taller evidence
--------------------------------

Back to Church, what he made was a tall claim -- that all computable functions
are expressible in terms of lambdas. When we make such a claim, we have to back
it up though. To recap, he's saying that you don't need :rkt:`cons`, :rkt:`car`,
:rkt:`cdr`, :rkt:`if`, :rkt:`let`, :rkt:`cond`, booleans or numbers or strings or whatever
we're used to in normal programming. He claimed that all of these are
representable using lambdas **alone** .. and showed how to do it.

We'll now work through how to represent basic things in terms of which we
can build a whole computational edifice.

Pairs
~~~~~

Pairs are the simplest of data structures. Once you can make a pair of two
things like :rkt:`(pair a b)` or the equivalent in a programming language, you can
get lists using --

.. code-block:: racket

    (pair a (pair b (pair c ... (pair x sentinel))) ...)

where we use a :rkt:`sentinel` to indicate end of the list. You can also make
trees using nested structures like --

.. code-block:: racket

    (pair (pair a b) (pair (pair c d) (pair e f)))

Or tables as a list of lists. Or even graphs. So if we can show we can
represent pairs using just :rkt:`lambda`, we're good with the other structures.

.. code-block:: racket

    (define pair (lambda (x y) ...))

What should we put within the :rkt:`...`? In fact, what **can** we put in there
when all we have are functions (i.e. lambda expressions)? So we're now
looking at --

.. code-block:: racket

    (define pair (lambda (x y) (lambda (p) ...)))

Again, what can we put in there? We have a :rkt:`p` and some two arbitrary values
:rkt:`x` and :rkt:`y` that we're expected to "store" in the pair. About the only
thing we can do (apart from nesting lambda once more, which would seem
pointless) is to apply :rkt:`p` to the :rkt:`x` and :rkt:`y`.

.. code-block:: racket

    (define pair (lambda (x y) (lambda (p) (p x y))))

We can now make "pairs" like below --

.. code-block:: racket

    (define p1 (pair 12 100))

(taking the liberty to use numbers just to illustrate). Since :rkt:`p1` is a function
that takes one argument, the only thing we can do with it is call it. Since its
argument is also a function that's applied to 2 arguments, let's consider
some simple 2-argument functions shown below --


.. code-block:: racket

    (define .first (lambda (x y) x))

and

.. code-block:: racket

    (define .second (lambda (x y) y))

The functions ignore one of their arguments and just evaluate to the other.
Now what happens when you apply :rkt:`p1` to these two functions.

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

    Work it out similarly and show that :rkt:`(p1 .second)` results in :rkt:`100`.

So we have a function now named :rkt:`pair` that can make so-called "pair objects"
and we can get the individual values out of the pair object using the 
"accessor" functions :rkt:`.first` and :rkt:`.second`.

Many of you are familiar with "object oriented languages" like Python and will
see the reasoning behind naming the accessor functions that way .. since the
expression :rkt:`(p1 .first)` looks very similar to :rkt:`p1.first` typical of such
languages.

.. note:: The ones with a careful eye might've noticed that while we claimed to
   only use lambdas, we ended up using :rkt:`define` in the above definitions. We
   use it here only as a substitute for writing the mathematical definitional
   equality :math:`pair = (λ\ (x\ y)\ (λ\ (p)\ (p\ x\ y)))` and because it
   actually permits you to type it into Racket and check things out for
   yourself. We therefore lose no generality by using :rkt:`define` in the above
   code. Also, lambda calculus deals only with one-argument functions and we've
   used two here. However, :math:`(λ\ (x\ y)\ E[x,y])` can be mechanically
   rewritten to :math:`(λ\ (x)\ (λ\ (y)\ E[x,y]))` with corresponding changes
   to substitution steps without loss of logical correctness. So we'll take
   that additional liberty here too.


Booleans
~~~~~~~~

From this section on, it will be valuable for us to use the :rkt:`#lang lazy`
language instead since we're going to be doing equational reasoning which will
work only in a lazy scheme and not when using eager evaluation. The syntax and
meaning are generally the same, except that the values of expressions will be
computed only when they are needed and not before.

.. admonition:: **Exercise**

    The only place we use boolean values is to do a branch within an :rkt:`if`
    condition. So if we can implement :rkt:`if` purely using :rkt:`lambda`, we're
    good. For this exercise, you'll need to consider "lazy evaluation" instead
    of "eager evaluation" to keep things simple. In fact, for the rest of this
    demonstration, we'll use lazy evaluation with :rkt:`#lang lazy`. The earlier
    ones will also work with :rkt:`#lang lazy`. So complete the definition below --

    .. code-block:: racket

        (define IF (lambda (bool then-expr else-expr) ....))

    Remember the trick we used with :rkt:`pair`. You have all you need in that
    code.


``let``
~~~~~~~

It is quite easy to see that we can rewrite :rkt:`let` expressions using :rkt:`lambda`.

.. code-block:: racket

    (let ([var1 expr1]
          [var2 expr2]
          ...
          [varn exprn])
      <body-using-var1..n>)

Can be rewritten as --

.. code-block:: racket

    ((lambda (var1 var2 ... varn)
        <body-using-var1..n>)
     expr1 expr2 ... exprn)

So :rkt:`let` is just "syntactic sugar" on top of lambda - i.e. is for our
convenience without offering additional "expressive power". These notions will
become clearer (and more formal) as we go along. For now, if you have a sense
of what they are, that's sufficient.

Numbers
~~~~~~~

Numbers are a big one to claim to be representable using :rkt:`lambda` alone!
Numbers (i.e. basic arithmetic with whole numbers) hold a "threshold" place in
mathematical logic too -- that every "formal system" [#fs]_ is representable
using numbers.

.. [#fs] A "formal system" is a collection of postulates -- i.e. "theorems" that
   are assumed to be true -- that serve as a starting point, and a collection
   of rules that tell us how to combine theorems to produce more theorems.

In lambda calculus, all we have are functions and function application. What can
we apply functions to? The answer to that question is also "functions"! So how
can we capture the idea of natural numbers using functions alone?

Given a function, what can we do with it? We can apply it to some value. What
kind of a value can we apply it to (at least within lambda calculus)? We can
apply it to another function. So Alonzo Church came up with a representation
for numbers as the idea of applying a function a certain number of times.

If we consider applying a function :rkt:`f` to a value :rkt:`x` a number
of times, we could write that sequence as --

.. code-block:: racket

    x                     ; 0
    (f x)                 ; 1
    (f (f x))             ; 2
    (f (f (f x)))         ; 3
    ;... and so on

But we don't know what these :rkt:`f` and :rkt:`x` are. The nice thing here
is that you can "β-abstraction" on the two in order to postpone the problem
of what values we want them to take on. So instead of the above, we can
consider the sequence below as a representation of numbers --


.. code-block:: racket

    (λ (f) (λ (x) x))               ; 0
    (λ (f) (λ (x) (f x)))           ; 1
    (λ (f) (λ (x) (f (f x))))       ; 2
    (λ (f) (λ (x) (f (f (f x)))))   ; 3
    ;... and so on

Observe by reading the lambda expression for each "number" that a Church
numeral :rkt:`n` stands for the idea of "n applications of f on x" given some
:rkt:`f` and :rkt:`x`.

We can't exhaustively list all such numbers. Even if we could, that wouldn't
capture the structure inherent in the numbers that's laid out in Peano's
axioms -

1. "Zero" is a number
2. Every number has a "successor".

Let's now try to apply Peano's axioms to capture the idea of successorship
for Church numerals.

.. code-block:: racket

    (define ch-zero (λ (f) (λ (x) x))

    (define ch-succ (λ (n) ...))

How should we now define :rkt:`ch-succ`? Before we get there, let's pull in
some preparatory functions that we encountered before --

.. code-block:: racket

    (define pair (λ (x y) (λ (p) (p x y))))
    (define .first (λ (x y) x))
    (define .second (λ (x y) y))
    (define swap (λ (p) (pair (p .second) (p .first))))

    ; The function composition operation .. as a function
    (define comp (λ (f g) (λ (x) (f (g x)))))

.. note:: Try to define :rkt:`ch-succ` yourself before reading on, for you have spoilers below.

Let's write out in words what the expression :rkt:`(ch-succ n)` for some specific
Church numeral :rkt:`n` is supposed to mean -- "n+1 applications of some function f on an x".
In other words, if we have "n applications of some function f on an x", we need to apply
f once more on that to get "n+1 applications of some function f on an x".

To make things concrete, let's look at the definition for "3" and see if we can
express it in terms of our definition for "2".

.. code-block:: racket

    (define ch-two (λ (f) (λ (x) (f (f x)))))
    (define ch-three (λ (f) (λ (x) (f (f (f x))))))

    ; See that the expression (f (f x)) is ((ch-two f) x)
    ; Replacing the inner most (f (f x)) in ch-three with ((ch-two f) x)
    (define ch-three (λ (f) (λ (x) (f ((ch-two f) x)))))

It's not hard to see now that we could do that for any pair of :math:`(n,n+1)`.

.. code-block:: racket

    (define ch-nplus1 (λ (f) (λ (x) (f ((ch-n f) x)))))

What we want for our :rkt:`ch-succ` function is for the relation ":rkt:`(ch-succ ch-n) == ch-nplus1`
to hold. So if we β-abstract over :rkt:`ch-n`, we get --

.. code-block:: racket

    (define ch-nplus1 ((λ (n) (λ (f) (λ (x) (f ((n f) x))))) ch-n))

    ; Then due to the equality which we just stated above, we have
    (define ch-succ (λ (n) (λ (f) (λ (x) (f ((n f) x))))))

    ; We can simplify it further though. Notice that
    ; (λ (x) (f ((n f) x)))
    ; is just the function composition of f and (n f).
    ; i.e. (λ (f) (comp f (n f))) == (λ (f) (λ (x) (f ((n f) x)))) 
    ; Therefore we can also write -
    (define ch-succ (λ (n) (comp f (n f))))

I hope it is much easier to read the last definition as "n applications of f
followed by one more" (reading the function composition from right-to-left).

Ok how about adding two Church numerals?

.. code-block:: racket
    
    (define ch-add (λ (m n) ...))

Given an :rkt:`n` (a Church numeral), we can express the idea of "m+n" as
"m applications of :rkt:`ch-succ` on n". This translates easily enough to
a lambda expression like below --

.. code-block:: racket

    (define ch-add (λ (m n) ((m ch-succ) n)))

Let's up the game now. How do we implement multiplication of Church numerals? i.e. 
a two argument function :rkt:`ch-mul` used as :rkt:`(ch-mul m n)`.

If :rkt:`(n f)` (for a given :rkt:`f`) yields :rkt:`n` applications of :rkt:`f`,
then we need to do this :rkt:`m` times. That's an easy enough expression too.

.. code-block:: racket

    (define ch-mul (λ (m n) (λ (f) (m (n f)))))

However, the inner part of that :rkt:`(λ (f) (m (n f)))` looks very familiar
doesn't it? It is simple :rkt:`(comp m n)`. So we have.

.. code-block:: racket

    (define ch-mul (λ (m n) (comp m n)))

Or to put it even more simply, :rkt:`(define ch-mul comp)`!! i.e. the multiplication
operation for Church numerals is simply the function composition operation!

I've been avoiding a problem so far though -- how would we do subtraction? To
do that, we'll need to implement :rkt:`(ch-pred n)` which behaves such that
:rkt:`(ch-succ (ch-pred n)) == n`. Since we don't have the capability to check
for equality yet, we cannot search the natural numbers starting from
:rkt:`ch-zero` and work our way upwards until we find a value :rkt:`k` such
that :rkt:`(ch-succ k) == n`.

This problem apparently stumped Church too. However, his student Stephen Kleene
came up with a solution to it. His solution was to use pairs of Church numerals
in a particular sequence - the first number in the sequence is :math:`(0,0)`
and if an entry is :math:`(m,n)`, the next entry in the sequence is :math:`(n,n+1)`.
This gives us the following sequence --

.. code-block::

    (0,0)   ; 0
    (0,1)   ; 1
    (1,2)   ; 2
    (2,3)   ; 3
    (3,4)   ; 4
    ...

In the above sequence, the first value of the pair gives the predecessor of
the second value which is the same as the row number. The only irksome bit
in this that we have to put up with is that we have to assume that "the
predecessor of 0 is 0".

So if we define :rkt:`k-zero` as :rkt:`(define k-zero (pair ch-zero ch-zero))`
and :rkt:`(define k-succ (λ (kp) (pair (kp .second) (ch-succ (kp .second)))))`,
we can produce the sequence through repeated applications of :rkt:`k-succ`
on :rkt:`k-zero`. That's a concept we already understand. So to produce
the row corresponding to number :rkt:`n`, we need to do :rkt:`((n k-succ) k-zero)`.
Thereafter, all that remains is to pick the first value of the pair to get the
predecessor of :rkt:`n`. So ...

.. code-block:: racket

    (define k-zero (pair ch-zero ch-zero))
    (define k-succ (λ (kp) (pair (kp .second) (ch-succ (kp .second)))))
    (define ch-pred (λ (n) (((n k-succ) k-zero) .first)))

.. admonition:: **Exercise:**

    Define :rkt:`(ch-sub m n)` for :math:`m >= n` using :rkt:`ch-pred`.


.. admonition:: **Exercise:**

    Can you come up with a representation for integers? -- i.e. numbers
    that can be positive or negative or zero. You'll also have to implement
    the corresponding addition, subtraction, multiplication and division
    operators. You can throw in a "negation" too.

Interlude on β-abstraction
--------------------------

You've seen above how useful β-abstraction turns out to be when exploring
representations that we do not initially fully understand. We were able to
postpone specific choices of functions until we understood things better, we
could transform expressions to extract common patterns, etc. As mentioned
earlier, all abstractions boil down to β-abstractions at the end. This means
you can use β-abstraction to great effect when when working with domains that
you're just about beginning to understand. That's useful even if you are not
using a functional programming language, because once you construct those
abstractions, it is usually a mechanical matter to translate them into other
languages that may not be functional. How can we be sure of that? That's what
this whole section is about -- that :rkt:`lambda` is enough to represent all of
computation, so any general purpose language (i.e. "Turing complete language")
can be understood in terms of it.

The key to exploiting β-abstraction is practice.

Recursion
---------

Akan datang!



    

