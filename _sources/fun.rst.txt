Functions and scope
===================

Thus far, we can construct expressions (type :rkt:`PicExprC`) in our "PicLang"
and run them through our interpreter (we'll indulge a bit and also refer to it
as a "picture synthesizer") to produce a "picture" which we can "render" to a
P3 format PPM file for viewing.

When producing pictures using our synthesizer, as our compositions grow in
complexity, we're bound to come across repeated patterns that we will wish we
didn't have to repeat ourselves about. Functions are about that, and adding
functions to our language will vastly increase the breadth of what we can
accomplish within it. 

Defining functions
------------------

Towards this, we'll consider a function definition structure that captures
the essence of a general enough function within our language.

.. code-block:: racket

    (struct FunDefC ([name : Symbol]
                     [arg : Symbol]
                     [expr : PicExprC]))

This structure captures what we need to specify a function. We'll identify
a function by its name, we'll identify its argument (a.k.a. "formal parameter")
using a symbol and we'll give a :rkt:`PicExprC` expression as the body of
the function. In other words, we're interested in functions that compute
pictures (via the interpreter). 

When we call such a function, what kind of value should we pass for the
argument? We have a couple of choices given our picture language terms. We
could make functions of type :rkt:`Number -> Picture` or :rkt:`Picture ->
Picture`. [#nuance]_

.. [#nuance] We're thinking of our function as producing a "picture"
   here and not a :rkt:`PicExprC` for simplicity because the job of 
   taking a :rkt:`PicExprC` and computing a :rkt:`Picture` is known
   and is what is done by our interpreter.

In our language so far, only the picture parts of our expressions can be
other expressions. The numbers are all expected to be constants -- for
example: :rkt:`(RotateS 30.0 (TranslateS 3 4 (SquareS 15.0)))`. We don't
have the means to provide expressions in place of numbers so far. So we'll
limit our discussion to functions which take a :rkt:`Picture` as an argument
and produce a :rkt:`Picture` as a result.

Let's look at an example function definition for a function that encapsulates
the "translate and colourize" operation. To keep the discussion simple, we'll
assume that all terms are part of our core language. You should be able to
determine which ones are better expressed using a "surface syntax" versus
"core" split and apply :rkt:`desugar` in the appropriate places to complete the
picture.


.. code-block:: racket

    (FunDefC 'trans-and-colorize 'p (ColorizeC red (TranslateC 2.0 3.0 <a-reference-to-p>)))

We have a gap in our language here. We need to be able to express the idea of
"use whatever value this **identifier** called :rkt:`'p` stands for in this
slot" in order to be able to write function definitions in the first place.
Towards this, we'll add a new term to our :rkt:`PicExprC` type with the
following structure --

.. code-block:: racket

    (struct IdC ([id : Symbol]))

Now we can express the above function definition as --

.. code-block:: racket

    (FunDefC 'trans-and-colorize 'p (ColorizeC red (TranslateC 2.0 3.0 (IdC 'p))))

Whenever we're repeating ourselves, we need to be careful and examine what would
happen if we made some errors. For example, what if we'd written the above
function definition like this instead? --

.. code-block:: racket

    (FunDefC 'trans-and-colorize 'p (ColorizeC red (TranslateC 2.0 3.0 (IdC 'q))))

This definition has no meaning for us, since the identifier :rkt:`'q` has no definition
within any evaluation context. Such a variable that is not "declared" as a formal
parameter in the function definition and still finds mention in the function definition's
body is called a "free variable". In our language so far, we do not ascribe any meaning
to such "free variables" and therefore consider such an expression to be an error.

Applying functions: substitution a.k.a. β-reduction
---------------------------------------------------

Ok, we have a function definition now. How do we then use it to make pictures? We
need a way to "apply" the function to a concrete picture expression value to compute
the required result. We therefore need yet another addition to our language to
express this concept of "function application".

.. code-block:: racket

    (struct ApplyC ([fn : Symbol] [arg : PicExprC]))

Given that we're identifying functions by name, we can express an application
by giving the function name we wish to use and provide a value to be use as
argument. Note that there is a design choice we can make here since we're using
names to denote functions as well as placeholder slots in expressions that need
to be filled with values --

1. We can permit a "formal parameter" name to be the same that of another function 
   since we're not permitting :rkt:`IdC` references to be used for the :rkt:`fn`
   part of our :rkt:`ApplyC` structure. So here, we're keeping function names
   and value identifiers in separate "namespaces". Some languages like Common Lisp
   take this route.

2. If we permit :rkt:`FunDefC` itself to be a valid :rkt:`PicExprC` and which can
   be passed as an argument, we can extend our :rkt:`ApplyC` to accept such a function
   specification in its :rkt:`fn` slot. This way, we have "first class functions"
   in our language, which makes a language expressive.

We'll start with (1) to keep the discussion simple before we take a stab at (2).

So what should our interpreter do when it encounters an :rkt:`ApplyC` term?

.. code-block:: racket

    (define (interp picexprC fundefs)
        (match picexprC
            ; ...
            [(ApplyC fn arg)
             ; ... what should go here? ...
            ]
            ; ...))


First off, we need a function to lookup the named function in the supplied
list of function definitions.

.. code-block:: racket

    (define (lookup-fundef name fundefs)
        (if (empty? fundefs)
            (raise-argument-error 'lookup-fundef
                                  (string-append "Definition for function named " name)
                                  name)

            (if (equal? name (FunDefC-name (first fundefs)))
                (first fundefs)
                (lookup-fundef name (rest fundefs)))))


Given this, we need a procedure by which we can perform "β-reduction" on the function's
definition expression, using the :rkt:`arg` part of the :rkt:`ApplyC` term.

.. code-block:: racket

    (define (subst value for-identifier in-picexpr)
        (match in-picexpr
            ; examine each possible term and determine
            ; how to substitute the value for the 
            ; identifier slots used in the expression.))


For one thing, we :rkt:`subst` needs to deal with the new :rkt:`IdC` term. So
we need a :rkt:`match` arm like this - 

.. code-block:: racket

        [(IdC id) (if (equal? for-identifier id)
                      value
                      (error "Unknown identifier"))]

What about something like :rkt:`TranslateC`? For a term like :rkt:`TranslateC`,
the expectation is that :rkt:`subst` will produce the same :rkt:`TranslateC`
as the result but with any identifiers in the expression part of :rkt:`TranslateC`
substituted with the given value.

.. code-block:: racket

        [(TranslateC dx dy picexprC)
         (TranslateC dx dy (subst value for-identifier picexprC))]
        [(OverlayC pic1 pic2)
         (OverlayC (subst value for-identifier pic1)
                   (subst value for-identifier pic2))]
        ; .. and so on

Even :rkt:`ApplyC` follows the same structure within :rkt:`subst` --

.. code-block:: racket

        [(ApplyC fname picexprC)
         (ApplyC fname (subst value for-identifier picexprC))]


Within our :rkt:`interp` though, we will make use of :rkt:`subst` to
perform a "β-reduction".

.. code-block:: racket

    (define (interp picexprC fndefs)
        (match picexprC
            ;...
            [(ApplyC fname valexprC)
             (let ([def (lookup-fundef fname fundefs)])
                (subst valexprC (FunDefC-arg def) (FunDefC-expr def)))]
            ;...
            ))

... but that's actually of the **wrong** type since :rkt:`subst` produces a
:rkt:`PicExprC` as its result but :rkt:`interp` is of type :rkt:`PicExprC ->
Picture`. So we need to run the interpreter on the expression produced by
:rkt:`subst` like this --

.. code-block:: racket

    (define (interp picexprC fndefs)
        (match picexprC
            ;...
            [(ApplyC fname valexprC)
             (let ([def (lookup-fundef fname fundefs)])
                (interp (subst valexprC (FunDefC-arg def) (FunDefC-expr def))))]
            ;...
            ))

Two evaluation modes
--------------------

Consider the function definition below --

.. code-block:: racket

    (FunDefC 'ghost 'p (OverlayC (IdC 'p') (TranslateC 4.0 (OpacityC 0.5 (IdC 'p')))))

The identifier :rkt:`'p` appears twice in this. If we then apply this function to
:rkt:`(RotateC 30 (SquareC 5.0))`, we will get this as the result --

.. code-block:: racket

    (OverlayC (RotateC 30 (SquareC 5.0))
              (TranslateC 4.0 (Opacity 0.5 (RotateC 30 (SquareC 5.0)))))

Note the repeated occurrence of the :rkt:`(RotateC...)` sub-expression. So what we have
here in our interpreter is a way of calculating that puts off the actual evaluation of
the expression when it is actually required. Even there, it performs redundant calculation
of the same picture. This "putting off until required" strategy is what is called 
"lazy evaluation" -- though the expression if repeated in multiple slots is not repeatedly
evaluated in lazy languages. 

.. admonition:: **Exercise**

    Modify the interpreter so that it still performs lazy evaluation, but does
    not perform redundant calculations when the expression is substituted in
    multiple places inside the function body.

In contrast, we can choose to first evaluate the picture-expression given in the :rkt:`ApplyC`
term **before** we pass it on to :rkt:`subst` to perform substitution. i.e. we have --

.. code-block:: racket

    (define (interp picexprC fndefs)
        (match picexprC
            ;...
            [(ApplyC fname valexprC)
             (let ([def (lookup-fundef fname fundefs)])
                (interp (subst (interp valexprC) (FunDefC-arg def) (FunDefC-expr def))))]
            ;...
            ))

.. note:: There is a problem with this. Can you spot it before you read on?

The problem is that our language does not yet admit any way to specify an "already computed picture"
-- i.e. a "literal picture". You can see this by looking at the result type of :rkt:`(interp valexprC)`
which should be a :rkt:`Picture`, but :rkt:`subst` internally returns this :rkt:`Picture` value
in this case instead of a :rkt:`PicExprC` as we wanted.

The solution is to add a term to our :rkt:`PicExprC` type that wraps or "tags" such a value.

.. code-block:: racket

    (struct PictureC ([pic : Picture]))

Now, we can write the "eager interpreter" as --

.. code-block:: racket

    (define (interp picexprC fndefs)
        (match picexprC              
            ;...       
            [(PictureC pic) pic]
            [(ApplyC fname valexprC)
             (let ([def (lookup-fundef fname fundefs)])
                (interp (subst (PictureC (interp valexprC)) (FunDefC-arg def) (FunDefC-expr def))))]
            ;...
            ))

It is cheap for our interpreter to "evaluate" a :rkt:`PictureC` term since there is nothing
that it really needs to do beyond return the provided value, as seen above.

Scope
-----

So far, we've only seen only one condition that indicates we have a problematic
function definition at hand -- whenever we find a "free variable" in the
expression of a function definition, such an expression cannot be interpreted.

To see why it cannot be interpreted, look at what the :rkt:`IdC` arm of our interpreter's
:rkt:`match` expression should do --

.. code-block:: racket

    (define (interp picexprC fndefs)
        (match picexprC              
            ;...       
            [(IdC id) <what-to-do-here?>]
            ;...
            ))

Since the job of :rkt:`subst` is to get rid of all occurrences of :rkt:`IdC` terms
in its result, the interpreter should never see an :rkt:`IdC` term! So the only
response it can have to this is to raise an error -- using 
:rkt:`(raise-argument-error 'interp "No free variables" picexprC)`.

However, intuitively, we expect the interpreter to "lookup" the meaning of the
identifier somewhere to determine what it is and use what it finds. This is the
next notion we'll discuss - that of "environments and scope".

