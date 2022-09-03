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

For example, :rkt:`(lambda (x) (* x x))` is the function that squares numbers.
When given a number :rkt:`2`, by substituting :rkt:`x` with :rkt:`2`, you can
compute the result of what the lambda expression denotes -- which is :rkt:`(* 2
2) = 4`.

There are two main rules you need to know when working with :rkt:`lambda`
expressions (the abstract ones).

**α-renaming**
    If :rkt:`(lambda (x) E[x])` is a lambda expression in one argument where :rkt:`E[x]`
    denotes some expression involving the variable :rkt:`x`, then you can change
    the name of :rkt:`x` to anything else and what the expression denotes is
    considered to be the same. i.e. You can rewrite it to :rkt:`(lambda (y) E[y])`
    (where we use the same :rkt:`E`) and it means the same thing ... as long as
    E doesn't already use :rkt:`y` as a free variable.

**β-reduction**
    If you have an expression of the form :rkt:`((lambda (x) E1[x]) E2)` where :rkt:`E1[x]`
    is an expression that (optionally) uses the variable :rkt:`x` and :rkt:`E2` is some other
    expression, then it is equivalent to :rkt:`E1[E2]`. i.e.

        :rkt:`((lambda (x) E1[x]) E2) => E1[E2]`

    It is important to note that when we say "is equivalent to", it means you
    can rewrite a sub-expression that looks like one side to the other form
    **anywhere**. We refer to the above left-to-right rewrite as "β-reduction"
    and the corresponding right-to-left rewrite as "β-abstraction".

    Just as lambdas offer a conceptual basis of all of computation, all
    abstraction in computing can be seen through β-abstraction.

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
   of rules that tell us how to derive new theorems from other known theorems.

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

But we don't know what these :rkt:`f` and :rkt:`x` are. The only thing we know
about them is that the function :rkt:`f` must have the property that its domain
and co-domain are the same. The nice thing here is that you can "β-abstraction"
on the two in order to postpone the problem of what values we want them to take
on. So instead of the above, we can consider the sequence below as a
representation of numbers --


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

What we want for our :rkt:`ch-succ` function is for the relation ":rkt:`(ch-succ ch-n) = ch-nplus1`
to hold. So if we β-abstract over :rkt:`ch-n`, we get --

.. code-block:: racket

    (define ch-nplus1 ((λ (n) (λ (f) (λ (x) (f ((n f) x))))) ch-n))

    ; Then due to the equality which we just stated above, we have
    (define ch-succ (λ (n) (λ (f) (λ (x) (f ((n f) x))))))

    ; We can simplify it further though. Notice that
    ; (λ (x) (f ((n f) x)))
    ; is just the function composition of f and (n f).
    ; i.e. (λ (f) (comp f (n f))) = (λ (f) (λ (x) (f ((n f) x)))) 
    ; Therefore we can also write -
    (define ch-succ (λ (n) (λ (f) (comp f (n f)))))

I hope it is much easier to read the last definition as "n applications of f
followed by one more" (reading the function composition from right-to-left).

We'll take a break here and define two utility functions outside of
Church's lambda calculus that will help us make Church numerals and display
them in notation we understand - i.e. as decimal numbers.

.. code-block:: racket

    (define (i->ch i)
       (if (equal? i 0)
           ch-zero
           (ch-succ (i->ch (sub1 i)))))

    (define (ch->i n)
        ((n add1) 0))

We can now use :rkt:`i->ch` to make Church numerals given Scheme numbers and
:rkt:`ch->i` to make Scheme numbers given Church numerals.

Ok how about adding two Church numerals? Again, try to figure it out yourself
before reading on.

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
:rkt:`(ch-succ (ch-pred n)) = n`. Since we don't have the capability to check
for equality yet, we cannot search the natural numbers starting from
:rkt:`ch-zero` and work our way upwards until we find a value :rkt:`k` such
that :rkt:`(ch-succ k) = n`. We also don't know how to compute the "inverse of
a given function :rkt:`f`" in the general case, so we can apply the inverse
after :rkt:`n` applications.

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

Recursion underlies all repetition in Scheme -- in the sense that you can
express any looping construct using recursion. However, we have a problem
at this point. We typically define a recursive function such as :rkt:`sqrt/rec`
using :rkt:`define` like this --

.. code-block:: racket

    (define sqrt/rec
       (λ (n xk eps)
          (if (< (abs (- (* xk xk) n)) eps)
              xk
              (sqrt/rec n (* 0.5 (+ xk (/ n xk))) eps))))

.. note:: We'll use the :rkt:`sqrt/rec` function to illustrate, but whatever
   we're doing with that we can also do to any other recursive function
   definition you may want to solve. I picked this 'cos I gave this function
   to you to practice recursion.

Scheme works with this definition just fine, but that's because it already provides
a mechanism for you to assume the existence of the inner :rkt:`sqrt/rec` function
when typing to evaluate a particular call. Somehow, the repeated unfolding of the
code is avoided by using names to tie the function's structure to itself. We **don't**
have that concept in lambda calculus and so will need to show that we can do this
without such a naming+delayed-binding trick.

So, for our purposes, we do not know what function to use to effect the recursive
call within the body of the above :rkt:`sqrt/rec` definition. 

By now, you should've already guessed what we're going to do when we're faced
with an unknown like this. Yup - we'll β-abstract over :rkt:`sqrt/rec`!

.. code-block:: racket

    (define cheat
       (λ (f)
          (λ (n xk eps)
             (if (< (abs (- (* xk xk) n)) eps)
                 xk
                 (f n (* 0.5 (+ xk (/ n xk))) eps)))))

Now, we can see how :math:`\text{sqrt/rec} = (\text{cheat}\ \text{sqrt/rec})`,
provided we know :rkt:`sqrt/rec` already (hence the name "cheat"). To find
out :rkt:`sqrt/rec` given :rkt:`cheat`, we need to "solve" the above equation.
Because applying :rkt:`cheat` to :rkt:`sqrt/rec` produces the same function,
:rkt:`sqrt/rec` is called the "fixed point" of :rkt:`cheat`. In mathematics,
a fixed point of a function :math:`f(x)` is a value :math:`x` such that
:math:`x = f(x)`. 

However, our :rkt:`cheat` function is not of much use though it captures the
essentials of the algorithm. We called it "cheat" because to get the
:rkt:`sqrt/rec` function from it, you have to pass it to it in the first place,
which seems to defeat the point. What we really want is for the whole machinery
of the :rkt:`(λ (n xk eps) ...)` part of :rkt:`cheat` to be available in place
of :rkt:`f` when we're calling it. Since :rkt:`cheat` is fully defined (we do
not refer to it recursively), what if we could just pass it to itself as an
argument (bound to :rkt:`f`)?

Another way to ask that question is "what if we just had an extra argument to
:rkt:`sqrt` function and we just passed :rkt:`sqrt` itself in its place -- like
this --

.. code-block:: racket
    
    (define sqrt/norec
        (λ (f n xk eps)
           (if (< (abs (- (* xk xk) n)) eps)
               xk
               (f f n xk eps))))

So you can calculate square-roots using :rkt:`(sqrt/norec sqrt/norec 64 64
0.1)`. This actually lets us do recursive function calls without using a
recursive definition! However, it is somewhat awkward to pass this additional
argument all the time. Let's see how we can improve it. First, we can
lift that :rkt:`f` argument out so we can "Curry" it like this --

.. code-block:: racket

    (define good
        (λ (f)
           (λ (n xk eps)
              (if (< (abs (- (* xk xk) n)) eps)
                  xk
                  ((f f) n xk eps)))))

... and we can now do our square-root algorithm using :rkt:`good`
like this --

.. code-block:: racket

   ((good good) 64 64 0.1)
   ; Prints out 8.005147977880979
   ; which is an approximate square root indeed.

Now, you see that :rkt:`sqrt/rec = (good good)` .. which is ... good as we have
an explicit function that behaves exactly as our original recursive definition
... without any extra arguments.

To summarize, we've now figured out a trick by which we can turn a recursively
defined function into one that isn't recursive but can effectively accomplish
the same result.

.. code-block:: racket

    (define some-function/rec (λ (a) ... (some-function/rec next-arg) ...))
    ; can be transformed into
    (define some-function/norec (λ (f) (λ (a) ... ((f f) next-arg) ...)))
    ; .. so that some-function/rec can now be defined in terms of 
    ; some-function/norec as --
    (define some-function/rec (some-function/norec some-function/norec))

    ; Note that the number of sites at which the recursive call happens
    ; does not matter. We replace all of them with (f f).

The journey isn't finished yet
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We've now shown that you can express recursive calls using :rkt:`lambda` alone.
Mission accomplished! However, don't forget our larger claim that anything
computable can be expressed using :rkt:`lambda`. In this case, what we just saw
is how we can start with a recursively defined function (given as a spec
similar to :rkt:`cheat`) and **mechanically** transform it into the true
recursive function. If we've truly "mechanized" it, then we should be able to
express that transformation as a function, right?

Though we called our original funciton "cheat", we're being a bit unfair to it,
because it serves as a specification for how the recursion is to proceed. It
captures all the details of the algorithm we intended to write down, except for
exactly which function to use to recurse. Furthermore, our desired
:rkt:`sqrt/rec` is a fixed point of this function, which is simple enough to
write. So we can now ask -- "If I give you such a :rkt:`cheat` function, can
you **calculate** :rkt:`sqrt/rec` mechanically?"

We can also see that :rkt:`(good f) = (cheat (f f))` through simple β-reduction.
In fact, we got :rkt:`(good good) = (cheat (good good))` from that in the
first place.

We can now rewrite that way of stating :rkt:`good` as --

.. code-block:: racket

    (define good (λ (f) (cheat (f f))))

And we can now express our desired :rkt:`sqrt/rec` function as just --

.. code-block:: racket

    (define sqrt/rec (good good))

If we then β-abstract on :rkt:`good`, we get --

.. code-block:: racket

    (define sqrt/rec ((λ (f) (f f)) good))
    ; =>
    (define sqrt/rec ((λ (f) (f f)) (λ (g) (cheat (g g)))))
    ; => β-abstract on "cheat" =>
    (define sqrt/rec ((λ (s) ((λ (f) (f f)) (λ (g) (s (g g))))) cheat))

So, we actually now have a function that we can apply to our easy-to-define
"spec" function in order to get our recursive result! This function that we've
figured out above is called the "Y combinator".

.. code-block:: racket

    (define Y (λ (s) ((λ (f) (f f)) (λ (g) (s (g g))))))

(We're using :rkt:`s` as the variable name to suggest "spec function" for
:rkt:`cheat`.)

A way the Y combinator is usually presented is with one β-reduction applied 
which gives us a nice symmetric form --

.. code-block:: racket

    (define Y (λ (s) ((λ (g) (s (g g))) (λ (g) (s (g g))))))

And we have :rkt:`(Y cheat) = (cheat (Y cheat))`. This is why the Y combinator
is said to be a "fixed point combinator" because it calculates the fixed point
of the given function. So all you have to do now is to express your recursive
function using an "unknown :rkt:`f`" and then have the Y-combinator figure out
what :rkt:`f` to pass to it.

Can we just solve for the combinator?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

While we originally tried to solve for :rkt:`sqrt/rec` given the equation
:rkt:`sqrt/rec = (cheat sqrt/rec)`, we turned the problem into finding a
function of :rkt:`cheat` that can produce :rkt:`sqrt/rec`. i.e. we were
actually looking for a function :rkt:`F` such that -

.. code-block:: racket

    (F cheat) = (cheat (F cheat))
    ; i.e.
    (define F (λ (cheat) (cheat (F cheat))))

Now we have a recursive "solution" for :rkt:`F`. If we now apply the same
technique/trick that we used to turn :rkt:`cheat` into a non-recursive function
:rkt:`good`, we have --

.. code-block:: racket

    (define G (λ (f) (λ (cheat) (cheat ((f f) cheat)))))
    ; and
    (define F (G G))

Now, let's look at the full expression for :rkt:`(G G)` with less judgemental
variable names --

.. code-block:: racket

    (define F ((λ (f) (λ (s) (s ((f f) s)))) (λ (f) (λ (s) (s ((f f) s))))))

(We're again using the variable named :rkt:`s` to denote the "spec function"
:rkt:`cheat`.)

This looks like a different function compared to :rkt:`Y` we figured out
earlier that also has the property :rkt:`(F s) = (s (F s))` just like :rkt:`(Y
s) = s (Y s)`. The difference between the two is this -- since we only used
β-abstraction to come up with :rkt:`F`, we can see how evaluating :rkt:`(F s)`
simply β-reduces to :rkt:`(s (F s))`, whereas with the :rkt:`Y` combinator,
:rkt:`(Y s)` and :rkt:`(s (Y s))` give us the same expression. :rkt:`F` is
therefore a valid combinator in its own right and is called the "Turing
combinator", usually denoted by :math:`\Theta`.

Can we not be lazy please?
~~~~~~~~~~~~~~~~~~~~~~~~~~

We've so far been using the :rkt:`#lang lazy` for all the above work on
recursion. If you want to, you can try to see if the Y combinator as defined
above will work with eager evaluation by switching the language to :rkt:`#lang
racket`. You'll find that you'll get a stack overflow as :rkt:`Y` tries to
repeatedly expand itself without stopping. The benefit of laziness for the
definition of :rkt:`Y` is that the expansion only happens when it is needed,
i.e. in the part of the spec function that actually makes a recursive call.
When the termination condition is hit, no further expansion of :rkt:`Y`
is needed and the recursion stops.

We can achieve the same effect in the eager evaluation mode by wrapping the
expansion in another :rkt:`λ`. To do this, we need to see that :rkt:`(λ (x) (f
x)) = f` for a function :rkt:`f` whose expression does not make use of the
outer variable :rkt:`x` -- i.e. it does not contain :rkt:`x` as a "free
variable", with "free" meaning "unbound". 

.. note:: The transformation :rkt:`(λ (x) (f x)) => f` when :rkt:`f` does not
   contain :rkt:`x` as a free variable is called η-reduction ("eta-reduction").
   This transformation can be done both ways. I haven't traced the history of
   λ-calculus to figure out why Church chose to call it η-reduction and not
   γ-reduction as one might expect to follow β-reduction. I'd like to think he
   tried many intermediate rules to complete the λ-calculus until he finally
   settled on the one he named η-reduction. At least, that fictitious
   explanation would capture the labour necessary for mathematical insight.

We apply this transformation to the inner :rkt:`(g g)` call, turning it into
:rkt:`(λ (v) ((g g) v))`. We can now rewrite the Y combinator as --

.. code-block:: racket

    (define Y (λ (s) ((λ (f) (f f)) (λ (g) (s (λ (v) ((g g) v)))))))

.. admonition:: **Exercise:**

    Check out whether this way of specifying the Y combinator works
    in eager mode. Do you understand why?


    

