Functions in PicLang
====================

Having seen how to implement proper lexical scoping in our :rkt:`stack-machine`
in the section :ref:`Stacks and scope`, we're now well placed to do that within
our expression interpreter for PicLang.

We're going to need corresponding notions of "blocks" in this language
and the notion of "do" as well. We'll also have to have our interpreter
keep track of bindings as wel go along, so we can eliminate the whole
substitution process and replace it with a single pass interpreter that
does effectively the same (and correctly) without having to run through a 
"substitution pass" before performing interpretation.

We'll call the equivalent of a "block" a :rkt:`FunC` in PicLang, defined
as below --

.. code-block:: racket

    (struct FunC (argname expr))

We'll call the equivalent of the :rkt:`do` instruction :rkt:`ApplyC` here.

.. code-block:: racket

    (struct (ApplyC (funexpr valexpr)))

An important thing to note is that we're now considering :rkt:`FunC` and
:rkt:`ApplyC` terms to be valid :rkt:`PicExprC` terms. While we can expect
:rkt:`ApplyC` to produce pictures, evaluating :rkt:`FunC` clearly does not
produce a picture. Just as the :rkt:`(block (def x) ...)` instruction produces a
:rkt:`Block` object on the stack in our :rkt:`stack-machine`, a :rkt:`FunC`
expression produces a ... "function value".

This means we need to expand the notion of what our PicLang :rkt`interpret`
function can return to include such function values. Incidentally, we've
now expanded the scope of what :rkt:`ApplyC` can produce to include
function values too. In other words, we've in two strokes admitted
first class functions into our language!

We'll now formalize the return type of :rkt:`interp` using a type
consisting of a set of "value terms" - denoted by the :rkt:`V` suffix.

.. code-block:: racket

    (struct PictureV (pic))
    (struct FunV (argname bindings expr))


Here is the modified interpreter ...

.. code-block:: racket

    ; bindings takes on the same list of two-element lists
    ; structure we used in stack-machine.
    (define (interp picexprC bindings)
        (match picexprC
            ; ...
            [(FunC argname expr)
             ; Store away the definition time bindings
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
             (lookup-bindings bindings id)]
            ; ...
            ))

We've chosen to keep the "bindings" structure abstract by referring to the two things
we need to do with it - "name lookup" and "extension" separate, so we can defer the
actual choice of structure.

.. admonition:: **Exercise**

    Write appropriate test expressions for this revised interpreter to check
    whether the scoping behaviour is indeed lexical.

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
actually want to produce. But we :ref:`kind of know how<Lambda - the everything>`
to deal with such self reference. Let's rewrite the above self referential
function.

.. code-block:: racket

    (define (make-standard-library definitions stdlib)
        (if (empty? definitions)
            (make-empty-bindings)
            (let ([def (first definitions)])
                (extend-bindings
                    (first def)
                    (interp (second def) stdlib)
                    (make-standard-library (rest definitions) stdlib)))))

We want to solve for the fixed point in the following "equation", given a list
of :rkt:`definitions` -

.. code-block:: racket

    stdlib = (make-standard-library definitions stdlib)

If we now rewrite the RHS --

.. code-block:: racket

    stdlib = ((λ (stdlib) (make-standard-library definitions stdlib)) stdlib)
    spec = (λ (stdlib) (make-standard-library definitions stdlib))

We can now apply our "function calls itself" trick to get -

.. code-block:: racket

    (define G (λ (f) (λ (spec) (spec (λ (g) (((f f) spec) g))))))
    (define F (G G))
    (define stdlib (F spec)) 

Note that we've modified the trick above so it would work with eager evaluation
strategy instead of the original "lazy" language. The expression :rkt:`(λ (g)
(((f f) spec) g))` is logically equivalent to :rkt:`((f f) spec)` by
"η-reduction", but helps delay the evaluation of the recursive parts by enough
so we don't get stuck in an infinite loop.

But this is still pending a specific representation for "bindings". Lets do a
simple one -

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


.. note:: An extension to the question in :ref:`Stacks and scope` -- we got an
   additional super power appart from ordinary functions with the approach to
   :rkt:`FunC` and :rkt:`ApplyC` and :rkt:`IdC` above. Can you recognize it?
   You're so familiar with it by now it probably slipped past you without your
   notice.

