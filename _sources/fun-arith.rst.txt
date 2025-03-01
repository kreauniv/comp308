Functions and scope (arithmetic track)
======================================

Thus far, we can construct basic arithmetic expressions in our language
and run them through our interpreter :rkt:`interp-v2` after desugaring
it using :rkt:`desugar-v2` as defined in the previous section.

Notice that instead of defining :rkt:`SubS` as a sugar term and expanding
it before we run it through our interpreter, we could've handled it within
our interpreter in terms, but in terms of our core terms like this -

.. code-block:: racket

    (define (interp-v3 aexpr)
        (match aexpr
            [(SubC e1 e2)
             (interp-v3 (AddC (interp-v3 e1) (MulC (NumC -1) (interp-v3 e2))))]
            ;...and so on for the others...
            ))

Here, we're defining a new construct that has a pattern into which we're substituting
the reductions of the corresponding "arguments" and reducing the result using our
other core expressions. In other words, we're defining a function "(sub a b)" as a 
"pattern" like this - :rkt:`(define (sub a b) (+ a (* -1 b)))`.

We'd obviously like to have this facility within our language as well! ... so
that the programmer can define their own functions in terms of core language
features and reuse them.

Defining functions
------------------

Towards this, we'll consider a function definition structure that captures
the essence of a general enough function within our language.

.. code-block:: racket

    (struct FunC (arg expr) #:transparent)

This structure captures what we need to specify a function. We'll identify a
function by its name, we'll identify its argument (a.k.a. ":index:`formal
parameter`") using a symbol and we'll give an expression as the
body of the function. In other words, we're interested in functions that
compute numeric results (via the interpreter). 

In our language so far, we can only call our functions with numbers as values.
However, we committed early on that all our "core expressions" will reduce to
values. Which means we'll need to define a value type for the values that
"function terms" reduce to.

.. code-block:: racket

    (struct FunV (argname expr) #:transparent)

This is no different from :rkt:`FunC`, but we'll keep the struct different
so we can keep track of all the possible return values of our interpreter
functions. Here, :rkt:`argname` is expected to be a symbol and :rkt:`expr`
is expected to be an expression.

Ok we have function expressions. Now we need to be able to apply them.
So we need to capture that as an expression as well.

.. code-block:: racket

    (struct ApplyC (fexpr vexpr) #:transparent)

"Application" is the process of taking a function value, associating its
"formal parameters" with a value computed from a given value expression
and evaluating the body of the function given this association.

Oh boy! We have a slew of notions at this point to capture. So let's
break that down.

First off, we need a way to reference the slots into which the actual
argument value should be used within the function body. We'll use the
following for that --

.. code-block:: racket

    (struct IdC (id) #:transparent)

... where the :rkt:`id` field is a symbol.

Let's try to write our interpreter based on these. We'll leave the desugaring as
an exercise since it is all recursive processing of the abstract syntax tree.

.. code-block:: racket

    (define (interp-v4 aexpr)
        (match aexpr
            [(FunC argname body)
             (FunV argname body)]
            [(ApplyC fexpr vexpr)
             (let ([fval (interp-v4 fexpr)]
                   [vval (interp-v4 vexpr)])
                ; some how associate vval with
                ; the argname in the fval and 
                ; call the interpreter on the body
                )]
            [(IdC id)
             ; Somehow lookup the current value of id
             ; and return the value that it is associated
             ; with
             ]
            ;...other terms...
            ))

So we see that we need a mechanism to associate ids with values
that can be extended and passed through our interpreter as it is
processing each term.

We call such an association an "environment" -- i.e. an "environment"
is (effectively) a set of associations between identifiers and
values. Since an environment maps ids to values, we can model it using
functions like this --

.. code-block:: racket

    ; The "empty environment" does not know about any identifier.
    (define empty-env (λ (id)
                         (error 'env "Unknown identifier ~s" id)))

    ; Given an environment, we can lookup the value corresponding
    ; to an identifier by just calling it like a function.
    (define (lookup env id) (env id))

    ; We an extend an environment to include an id by wrapping
    ; a given environment in an additional check for the new
    ; association.
    (define (extend env id val)
        (λ (id2)
           (if (equal? id2 id)
               val
               (lookup env id2))))

With such an environment at hand, we can now define our unfinished
interpreter like this -

.. code-block:: racket

    (define (interp-v4 env aexpr)
        (match aexpr
            [(FunC argname body)
             (FunV argname body)]
            [(ApplyC fexpr vexpr)
             (let ([fval (interp-v4 fexpr)]
                   [vval (interp-v4 vexpr)])
                (interp-v4 (extend env (FunV-argname fval) vval) 
                           (FunV-expr fval)))]
            [(IdC id)
             (lookup env id)]
            [(AddC e1 e2)
             (NumV (+ (NumV-n (interp-v4 env e1))
                      (NumV-n (interp-v4 env e2))))]
            ;...handle other terms...
            ))
   
Ok this is *some* language we've implemented certainly, but is it the one we
want? -- i.e. something that behaves like SMoL in this regard.

To understand what is lacking in this language, we need to understand
what defines a valid versus invalid expression that may include functions.
In order to produce a value as a result, the expression that we pass
to our interpreter must not have any "free variables". If it did, then
when we get to those variables in the evaluation process, we'll encounter
(or at least we expect to encounter) an error.

Consider the following Racket expression - 

.. code-block:: racket

    ((λ (f) (f (f 10)))
     ((λ (x) (λ (y) (+ y x)) 3)))

This expression has no free variables and is well formed according to 
lambda calculus. However, our interpreter will fail on it. Can you see why?

Lexical & dynamic environments
------------------------------

The :rkt:`env` argument in our :rkt:`interp-v4` function captures the
state of the environment at the point a term is being evaluated. To
evaluate some nested expressions, this environment may be extended,
such as when we're "applying" a function to a value. 

The value of the :rkt:`env` argument at the point of entry into the
:rkt:`interp` function is therefore called the "dynamic environment",
because it is in the process of computing the final result, while the
computation is still not finished yet.

In particular when our interpreter is evaluating a :rkt:`FunC` term to produce
a :rkt:`FunV` value, the meaning of the identifiers used in the body of the
:rkt:`FunC` term are to be considered in relation to the dynamic environment in
which this term is being evaluated -- i.e. at the point at which the
:rkt:`FunV` is being constructed. In this particular case, since the
**meaning** of the function is determined by the context in which it is being
**created** and not **applied**, this dynamic environment is also considered to
be the "lexical environment" of the function. Since the body of the function is
to be interpreted with only the additional fact of the binding for its
argument, we need to extend the lexical environment of a function when
computing an application, and not the dynamic environment at application time.

Without this "lexical environment", the function cannot be interpreted
correctly when applied. Therefore we need to keep this environment around.

The word "lexical" for this environment is used because this environment
can be gleaned off the local (i.e. "lexical") source code within which
the function expression exists by considering all the identifiers defined
in the enclosing expressions up to the top level ... which is often a short
way away from the point at which the function expression is given.

Since we need to capture this in our :rkt:`FunV`, we need to alter its
definition to be --

.. code-block:: racket

    (struct FunV (lexenv argname expr) #:transparent)

... and based on that our interpreter needs to be modified to --

.. code-block:: racket

    (define (interp-v5 env aexpr)
        (match aexpr
            [(FunC argname body)
             ; Note that we're storing away the dynamic environment
             ; at the point the function value is created, as its
             ; lexical environment.
             (FunV env argname body)]
            [(ApplyC fexpr vexpr)
             (let ([fval (interp-v5 fexpr)]
                   [vval (interp-v5 vexpr)])
                ; Here, we have to extend the "lexical environment"
                ; of the function with the new binding and evaluate it,
                ; instead of extending the dynamic environment at the
                ; call point.
                (match fval
                    [(FunV lexenv argname body)
                     (interp-v4 (extend lexenv argname vval) body)]
                    [_ (error "Not a function, so can't apply")]))]
            [(IdC id)
             (lookup env id)]
            [(AddC e1 e2)
             (NumV (+ (NumV-n (interp-v5 env e1))
                      (NumV-n (interp-v5 env e2))))]
            ;...handle other terms...
            ))

.. admonition:: **Exercise**

    Complete the interpreter and the corresponding :rkt:`desugar` function
    and test the various cases you think might be problematic, to see
    whether it performs correctly -- i.e. works where it should and errors
    out where it is faced with an invalid expression.

.. admonition:: **Exercise**

    Define a sugar expression :rkt:`(LetS id vexpr bodyexpr)` which binds the
    given identifier to the value of the given expression within the bodyexpr.
    You can define this in terms of :rkt:`FunC` and :rkt:`ApplyC`.

.. admonition:: **Exercise**

    Make the language more complete by adding support for boolean values,
    logical operations and branching. Define the following new terms and their
    behaviours in the :rkt:`interp` function and the :rkt:`desugar` function.

    .. code-block:: racket

        (struct BoolV (b) #:transparent) ; b = #t or #f

        (struct TrueC () #:transparent)
        (struct FalseC () #:transparent)
        (struct AndC (e1 e2) #:transparent)
        (struct OrC (e1 e2) #:transparent)
        (struct NotC (e1) #:transparent)
        (struct IfC (boolexpr thenexpr elseexpr) #:transparent)
        
    The slots named :rkt:`e1`, :rkt:`e2` etc are expected to be
    expressions (potential sugar terms as well), but which in this
    context are valid only if they evaluate to boolean values.


