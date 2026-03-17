Continuations in our language
=============================

In the :doc:`generators` section, we saw how Racket's ``let/cc``
construct can enable us to express the idea of generators,
a concept found in other languages like Python and Javascript.

Our language so far does not have an equivalent construct.
How can we add such a construct to our language without this
construct being present in the "host" language? i.e. if
Racket didn't have ``let/cc``, can we still add this as a
capability to our language? If so, how and how would it change
our language?

.. dropdown:: Why shouldn't we use Racket's ``let/cc``?

    Because we don't learn anything about its nature if
    we simply borrow the underlying Racket construct into our
    language. Also, we'll not know how to implement it in a
    language that does not provide the construct. This is the
    same reason we didn't use Racket's ``box`` construct to
    implement :doc:`mutations` in our language.

So far, all our functions (values of type ``FnV``) take a ``Val``
and produce a ``Val``. Reproducing these types below for convenience
of reference.

.. code:: racket

   (struct (e) fn ([arg : Symbol] [body : e])
       #:transparent)
   (struct id ([sym : Symbol])
       #:transparent)
   (struct (e) app ([fexpr : e] [valexpr : e])
       #:transparent)

   (struct FnV ([env : Env] [arg : Symbol] [body : ExprCore])
       #:transparent)
   (struct Val (U GenV FnV Real))

   (define-type Env (-> Symbol Val))

   (: interp (-> Env ExprCore Val))
   (define (interp env expr)
     (match expr
       ...
       [(id sym)
        (lookup env sym)]
       [(fn arg body)
        (FnV env arg body)]
       [(app fexpr valexpr)
        (match-let ([(FnV denv arg body) (fnv (interp env fexpr))]
                    [v (interp env valexpr)])
            (interp 
               (extend denv arg v)
               body))]
       ...))

We may model the continuations made available by ``let/cc`` as
functions that do not have a return value in Racket, for simplicity -- i.e.
as the type ``(-> Val Void)``. To get access to these continuations
without having to use ``let/cc``, we'll have to transform our interpreter
into its CPS-style or "/ret" form.

.. code:: racket

    (: interp/ret (-> Env ExprCore (-> Val Void) Void))
    (define (interp/ret env expr return)
      (match expr
        [(konst v)
         (return (GenV (a:konst v)))]
        ...
        [(id sym)
         (return (lookup env sym))]
        [(fn arg body)
         (return (FnV env arg body))]
        [(app fexpr valexpr)
         (interp/ret env fexpr
           (λ (fv)
             (match-let ([(FnV denv arg body) (fnv fv)])
               (interp/ret env valexpr
                 (λ (v)
                   (interp/ret
                     (extend denv arg v)
                     body
                     return))))))]
        ...))

Adding ``letcc``
----------------

Now we're ready to add a ``letcc`` construct to our language
analogous to Racket's because we have the continuations at
any point available via the ``return`` argument of the 
``interp/ret`` procedure.

.. code:: racket

    (struct (e) letcc ([cont : Symbol]
                       [body : ExprCore])
        #:transparent)

    (struct ContV ([fn : (-> Val Void)]))

    (define-type Val (U GenV FnV Real ContV))

We need to interpret the ``letcc`` term, as well as be ready to
apply a ``ContV`` type procedure to a value in addition to a
``FnV`` type procedure.

.. code:: racket

    (define (interp/ret env expr return)
      (match expr
        ...
        [(letcc cont body)
         (interp/ret 
           (extend env cont (ContV return))
           body
           return)]
        [(app fexpr valexpr)
         (interp/ret env fexpr
           (λ (fv)
             (match fv
               [(FnV denv arg body)
                (interp/ret env valexpr
                  (λ (v)
                    (interp/ret
                      (extend denv arg v)
                      body
                      return)))]
               [(ContV k)
                (k v)]
               [_ (error "Invalid function")])))]
        ...))

Note that the continuation call occurs in the tail position - i.e. as the
final step of the interpreter and the ``return`` argument does not get used
in that case - i.e. the whole "stack" gets thrown away and replaced by 
what the continuation represents instead. This is why such a call is often
referred to as a "continuation jump" -- you "jump" to another point in the
history of evaluation that you'd saved away as the continuation.

.. index:: Reified continuation

.. dropdown:: **Term**: "Reified continuation"

   A "continuation" is not a thing, but a concept that applies to all
   programming languages -- since they all have to deal with sequencing
   computations and therefore there is always a notion of "what remains to be
   done right now?" that is applicable at every step. When such a continuation
   concept is made available as a **value** in a programming language, it is
   considered to have been "reified" -- "to reify" meaning "to make real",
   because now we can manipulate it like any other value which lends it a
   notion of "a real thing" for us in this context.

   So what we've done here is to add "reified continuations" to our language.

Reflection
----------

We're now exposing a raw Racket lambda function to our interpreter. Is that a
good thing?

We aren't exposing *general* lambda procedures from Racket into our language.
We're only introducing the continuation procedures that our interpreter
constructs into the language as a ``ContV`` value. We could do this
equivalently by representing the pending computations as a stack (perhaps using
an accumulating list) and that would have the same scope.

Isn't Racket's ``call/cc`` more fundamental than ``let/cc``? Why didn't we
implement ``letcc`` in terms of a ``callcc``?

We could've also gone the route of defining ``callcc`` analogous to Racket's
``call/cc`` and then defined ``letcc`` as syntactic sugar in terms of
``callcc``. That would offer slightly more generality since the procedure
receiving the continuation can be reused in multiple contexts, unlike the raw
body of ``letcc``. However, the principle is the same and the above code serves
to illustrate how to bring such a concept to life in our language. With
``call/cc``, there is an additional layer of ``lambda`` to parse and keep in
mind which is avoided when using ``let/cc``. This is helpful when learning
about continuations (I think). Once you learn that, it is easy to switch to
``call/cc`` when you need that extra bit of flexibility.

