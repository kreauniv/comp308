Functions in PicLang
====================

Having seen how to implement proper lexical scoping in our :rkt:`stack-machine`
in the section :doc:`stacks-and-scope`, we're now well placed to do that within
our expression interpreter for PicLang.

We're going to need corresponding notions of "blocks" in this language
and the notion of "do" as well. We'll also have to have our interpreter
keep track of bindings as we go along, so we can eliminate the whole
substitution process and replace it with a single pass interpreter that
does effectively the same (and correctly).

We'll call the equivalent of a "block" a :rkt:`FunC` in PicLang, defined
as below --

.. index:: FunC, ApplyC

.. code-block:: racket

    (struct FunC (argname expr))

We'll call the equivalent of the :rkt:`do` instruction :rkt:`ApplyC` here.

.. code-block:: racket

    (struct (ApplyC (funexpr valexpr)))

An important thing to note is that we're now considering :rkt:`FunC` and
:rkt:`ApplyC` terms to be valid :rkt:`PicExprC` terms. While we can expect
:rkt:`ApplyC` to produce pictures, evaluating :rkt:`FunC` clearly does not
produce a picture. Just as the :rkt:`(block (def x) ...)` instruction produces
a :rkt:`Block` object on the stack in our :rkt:`stack-machine`, we'll take a
:rkt:`FunC` expression to produce a ... "function value".

This means we need to expand the notion of what our PicLang :rkt:`interpret`
function can return to include such function values. Incidentally, we've now
expanded the scope of what :rkt:`ApplyC` can produce to include function values
too. In other words, we've in two strokes admitted first class functions into
our language!

We'll now formalize the return type of :rkt:`interp` using a type
consisting of a set of "value terms" - denoted by the :rkt:`V` suffix.

.. code-block:: racket

    (struct PicV (pic))
    (struct FunV (argname bindings expr))

No more subst
-------------

.. index:: Abstract Syntax Tree, AST 

Next comes a very important change to the interpreter. The substitution process
walks the expression tree once and then our interpreter does it again. These
two are also tied by the fact that they both use the same expression tree
structure (i.e. the "abstract syntax tree"). 

The only job of the :rkt:`subst` function was to replace the :rkt:`IdC` terms
with their corresponding values. So if we're keeping track of "current
bindings" as we're evaluating a (sub) expression, then we no longer need a
separate :rkt:`subst` function. Our interpreter can do that job on its own,
since it can lookup the value that is expected to go in the :rkt:`(IdC sym)`
term's place and treat that as the result of "interpreting" that term. This
would effectively perform a "substitution".


Interpreter with bindings
-------------------------

What we've been loosely calling a "set of bindings" where "binding" refers to a
name-value pair association has a name -- the "environment". We need some
practice to translate "environment" in our minds to a data structure that
associates some meaning (i.e. value) with a set of symbols. So we'll continue
to use both until that settles. 

.. note:: Personally, I find "environment" a little too broad though it is
   a standard term used in this context within interpreters.

Here is the modified interpreter ...

.. code-block:: racket

    ; bindings takes on the same list of two-element lists
    ; structure we used in stack-machine.
    (define (interp picexprC bindings)
        (match picexprC
            ; ...
            [(FunC argname expr)
             ; Store away the definition time bindings
             ; along with the FunV value structure.
             ;             v------ One more field compared to FunC
             (FunV argname bindings expr)]
            [(ApplyC funexpr valexpr)
             (let ([fun (interp funexpr bindings)]
                   [val (interp valexpr bindings)]) 
                (match fun
                    [(FunV argname definition-time-bindings expr)
                     ; Now to apply the function, we add a new
                     ; binding for its argument name and evaluate
                     ; the body.
                     (interp expr (extend-bindings argname val definition-time-bindings))]
                    [_ (raise-argument-error 'interp
                                             "Function value for application"
                                             funexpr)]))]
            [(IdC id)
             (lookup-binding bindings id)]
            ; ...
            ))

We've chosen to keep the "bindings" structure abstract by referring to the two things
we need to do with it - "name lookup" and "extension" separate, so we can defer the
actual choice of structure.

.. admonition:: **Exercise**

    Write appropriate test expressions for this revised interpreter to check
    whether the scoping behaviour is indeed lexical. Use any simple representation
    you want to for the "bindings" parameter by implementing the :rkt:`extend-bindings`,
    :rkt:`lookup-binding` and :rkt:`make-empty-bindings` functions.

.. admonition:: **Question**

    Consider the way we're evaluating :rkt:`FunC` terms in the interpreter. We
    store the current state of the :rkt:`bindings` argument in the resulting
    :rkt:`FunV` structure .. which is one of the possible result values of our
    interpreter. Do we need to store *all* the bindings in the :rkt:`FunV`
    structure? What are the consequences of storing all the bindings? Can we
    trim it down? If we can, how should we determine the set of bindings to
    trim down to?

A standard library
------------------

Notice that we've gotten rid of the :rkt:`fundefs` argument which was a list of
:rkt:`FunDefC` terms. Technically, we do not need it any more, as we can pass
any functions as arguments to an :rkt:`ApplyC` term and refer to it within the
value expression of the function term via the argument name. However, doing this
for even 20 functions is cumbersome. 

.. note:: What exactly is cumbersome about it? Is it simply that we have to
   nest many :rkt:`ApplyC` terms?

From a user interface perspective, all we need to do is to provide a starter
set of bindings to the interpreter that expressions can use. These bindings
must be mappings from symbols to :rkt:`FunV` terms. However, note that
our :rkt:`FunV` terms also have their own list of bindings. The question
then is "what should these bindings lists be?".

We're calling this initial set of bindings a "standard library" of functions
that may be useful when writing PicLang expressions. This also means that
this standard library is also available to the standard library functions
themselves. So one way to resolve this conundrum is to make these :rkt:`FunV`
values given the standard library! The snake must eat its own tail!

.. code-block:: racket

    ; definitions is a list of bindings where a "binding" is given
    ; as a list of two values - the first being the symbol to be bound
    ; and the second being the :rkt:`FunC` expression to bind to it.
    (define (make-standard-library definitions)
        (if (empty? definitions)
            (make-empty-bindings)
            (let ([def (first definitions)])
                (extend-bindings
                    (first def)
                    (interp (second def) (make-standard-library definitions))
                    (make-standard-library (rest definitions))))))
            
There, in all its naïvette, is a fully self referential expression of what we
actually want to produce. But we :doc:`kind of know how<lambda>` to deal with
such self reference. Let's rewrite the above self referential function.

.. code-block:: racket

    (define (make-standard-library definitions stdlib)
        (if (empty? definitions)
            (make-empty-bindings)
            (let ([def (first definitions)])
                (extend-bindings
                    (first def)
                    (interp (second def) stdlib)
                    (make-standard-library (rest definitions) stdlib)))))

Here we're assuming that our function will be passed the result :rkt:`stdlib`
we're constructing and it makes use of this to construct its result!! That's
something we did earlier as well in :doc:`Lambda - the everything<lambda>`. We
want to solve for the fixed point in the following "equation", given a list of
:rkt:`definitions` -

.. index:: Fixed point

.. code-block:: racket

    stdlib = (make-standard-library definitions stdlib)

If we now rewrite the RHS --

.. code-block:: racket

    spec = (λ (stdlib) (make-standard-library definitions stdlib))
    stdlib = (spec stdlib)

    ; Using the Turing combinator approach ...
    (define (Θ spec) (spec (Θ spec)))
    stdlib = (Θ spec)

We can now apply our "function is called with itself to enable the function to
call itself" trick to get -

.. index:: Turing combinator

.. code-block:: racket

    (define G (λ (f) (λ (spec) (spec (λ (g) (((f f) spec) g))))))
    (define Θ (G G))
    (define stdlib (Θ spec)) 

We've used the :index:`Turing combinator` here to capture the process of
computing such a "fixed point". Note that we've modified the trick above so it
would work with eager evaluation strategy instead of the original :rkt:`#lang
lazy` choice. The expression :rkt:`(λ (g) (((f f) spec) g))` is logically
equivalent to :rkt:`((f f) spec)` by ":index:`η-reduction`", but helps delay
the evaluation of the recursive parts by enough so we don't get stuck in an
infinite loop.

But this is still pending a specific representation for "bindings". Lets do a
simple one -- where the idea is that we capture the meaning of "an environment
can be used to lookup a value given a name" as a lambda function --

.. code-block:: racket

    (define (make-empty-bindings)
        (λ (name)
           (raise-argument-error 'lookup-binding
                                 "Valid name"
                                 name)))

    (define (lookup-binding name bindings)
        (bindings name))

    (define (extend-bindings name value bindings)
        (λ (n)
            (if (equal? n name)
                value
                (lookup-binding n bindings))))


.. admonition:: **Exercise**

    Check that the above way of defining the standard library works. Add
    functions to print out the various intermediate structures to see how this
    actually works.

.. admonition:: **Exercise**

    Reflect on the efficiency of this approach to making the "standard library"
    of definitions. Can we do something simpler if we allow ourselves some new
    feature of the language (Racket, not PicLang) that we haven't used so far?


.. admonition:: **Question**

    An extension to the question in :doc:`stacks-and-scope` -- we got an
    additional super power apart from ordinary functions with the approach to
    :rkt:`FunC` and :rkt:`ApplyC` and :rkt:`IdC` above. Can you recognize it?
    You're so familiar with it by now it probably slipped past you without your
    notice.


A superpower
------------

.. index:: Closure

When we interpret a :rkt:`(FunC argname fexpr)` term within the interpreter and
produce a :rkt:`(FunV argname bindings fexpr)` value, we've also captured the
current set of bindings that can give meaning to :rkt:`IdC` references within
the :rkt:`fexpr` part of the :rkt:`FunC` term and stored it away for future
reference -- for use when we're applying the function to a value in an
:rkt:`ApplyC` term.

This :rkt:`FunV` structure is called a "closure". In the Scheme/LiSP family, we
usually don't make it a point to distinguish between "functions" and "closures"
and freely interchange the two terms. There is no meaningful distinction in
programs since where functions are acceptable, closures can be passed and vice
versa. However, while this is true in the LiSP family languages, many languages
like Objective-C and C++ do differentiate between the two, with the idea that
the programmer can choose what they want according to the performance criteria
they need to meet.

For example, you already understand what the following Racket code is expected
to do .. and what we've done is to model how we do it so our understanding of 
the scope implications of making closures is now complete.

.. code-block:: racket

    (define adder (lambda (y)
                        (lambda (x) (+ x y))))
    (define three-more-than (adder 3))
    (define ten-more-than (adder 10))
    (display (three-more-than 8))      ; Prints 11
    (display (ten-more-than 8))        ; Prints 18


Closures are a powerful feature in any language that provides them. We've
already seen this in the work we did with Church's lambda calculus -- that
anything computable can be expressed using λ. Looking back, it is both a
surprise and not a surprise that "mainstream" languages put off adopting
closures for a long time under the perception that they're inefficient to
implement, when the lisp family has had them from (pretty much) day one. There
is some truth to the "inefficiency" myth in the early days, but on today's
machines and with the heavy use of interpreted languages like Python and PHP,
the inefficiency argument no longer holds ground. In particular, compilers for
Common LiSP and Scheme have long implemented proper lexical closures resulting
in programs more efficient than the interpreted ones.

Where does this myth of inefficiency come from?

A part of it you can see in the way we made the :rkt:`FunV` object. We just
stored away the **entire** definition environment in the object, without any
consideration for whether the function expression actually uses any values from
it. One "optimization" here is to scan the function expression, collect the set
of references that are bound in the definition environment, and make a new
:rkt:`bindings` field that only keeps the used ones. Here, we're trading off
the computational cost of constructing a closure against the memory cost of
storing unnecessary bindings. Such optimizations are not essential for us to
consider in this course as they don't (and indeed must not) change the meanings
of our programs.

