Alternative application semantics
=================================

.. note:: This section takes a different approach compared to the original
   `PLAI second edition <plaiappsem_>`_. Reasons -- `Lazy application`_ is
   dealt with well in PLAI already, so please refer to that. I don't think
   students gain much by working through the "reactive" application semantics
   from a PL perspective. Visual tools such as Excel, Max/MSP or PureData are
   better models of this mode than any textual programming language or sub
   language. If students are to learn it, it would probably be to learn that it
   isn't a great idea to pursue in a textual PL, despite possible conceptual
   elegance of the original Fran. I'm choosing to do searching a little
   differently due to doing type systems afterwards. I had not intended to do
   type systems due to time constraints but am trying to see if this change of
   approach can help with the constraint of a trimester system.

.. _plaiappsem: https://cs.brown.edu/courses/cs173/2012/book/Alternate_Application_Semantics.html

.. _Lazy application: https://cs.brown.edu/courses/cs173/2012/book/Alternate_Application_Semantics.html#%28part._.Lazy_.Application%29

Solving for goals
-----------------

One paradigm for program execution (function application) is to consider
"variables" to be first class entities you can pass to your functions.
Variables start off with low information content and as your function
progresses, more information is added to them. By "information" here, we're not
talking about adding bits of data, but in the sense that a variable may
initially be defined to take one of several values in a given set and as the
program progresses, the size of this set is progressively reduced, thereby
making the variable more precise about its values.

The simplest version of that process of adding information is to have variables
be initially in an "Unknown" state and later on as the program progresses, they
may transition to a "Known" state getting bound to some value, after which the
value cannot be changed.

The purpose of a program in this paradigm is to start off with a set of
variables (at least some of them) in an "unknown state" and when the program
finishes, at least some of them become known -- or "bound" to values.
Furthermore, we consider the program to produce one or more such possible set
of bindings of the program's variables. We'll look at how we can compute this.

Let's define a value type that represents this idea of a "variable". We'll further
give our variables some string name that we can recognize them by.

.. code-block:: racket

    (struct Var (name) #:transparent)
    ; That gives us Var, Var? and Var-name

We'll represent the idea of a set of bindings for our variables using our usual
"association list", with variables as keys and values which can be either variables
themselves or ordinary values.

.. admonition:: **Question**

    Our "bindings as an association list" representation permits the occurrence
    of mutiple bindings for a single variable. Reflect on whether that is
    desirable. What do you think?

We'll constrain our bindings list such that a particular variable can only
occur in the key position in one of the entries. i.e. We're not permitted to
indicate different bindings for a variable in the same bindings set. Given that
we're making variables using :rkt:`Var`, we can lookup our variables in the
bindings list using :rkt:`assv`. 

.. code-block:: racket

    (define v1 (Var "one"))
    (define v2 (Var "one"))
    (display (eqv? v1 v2)) ; Shows #f, which is what we want. We want each of our
                           ; Var values to be distinguishable irrespective of their
                           ; names.

Given that a set of bindings may indicate that a variable :rkt:`A` (we'll use
the convention of referring to variables using capitalized names) is is bound
to another variable :rkt:`B`, we need a procedure to determine the value at the
end of such a chain of "bindings". We'll call this procedure :rkt:`walk`.

.. code-block:: racket

    (define (walk var bindings)
        (let ([m (assv var bindings)])
            (if m
                (if (Var? (second m))
                    (walk (second m) bindings)
                    (second m))
                ; We let a var be itself if it isn't found in bindings.
                ; This also lets us deal with the case where A is bound
                ; to B but B does not appear as a key in the bindings.
                var)))

Now let's consider what kinds of assertions we can make about two "things" in
our system. A "thing" being a variable or a value. If we assert that
:rkt:`<thing1> = <thing2>`, what effect would we expect such an assertion to
have on our current set of bindings?

1. :rkt:`32 = 32` -- i.e. both things are values that are equal to each other.
   In this case, we're happy. No contradictions. And our bindings doesn't
   change one bit.

2. :rkt:`A = 32` -- i.e. first thing is a variable and the second thing is a value.
   In this case, we'd like to make note of this additional information in our
   bindings set. We'll therefore add an entry for it there.

3. :rkt:`32 = A` -- same as the previous case, we add a bindings for :rkt:`A` to
   our bindings set.

4. :rkt:`A = B` -- i.e. two *different* variables are declared to be equal to
   each other. We can add a binding to this effect to our set. **Question**: Should
   we add :rkt:`A` bound to :rkt:`B` or :rkt:`B` bound to :rkt:`A`?

5. :rkt:`A = A` -- i.e two variables are declared to be equal and they are the same.
   This also has no impact on our bindings set and we stay happy.

In any other case (such as :rkt:`2 = 3`), the assertion will fail. Let's capture all
of these in a function -- :rkt:`unify`. This process we described above, that
takes an assertion and augments a set of bindings with new information that reflects
the facts being asserted is called "unification" in the case where the assertion is
made via equality.

.. code-block:: racket

    ; unify tries to assert A = B in the context of the given
    ; bindings. It produces an augmented set of bindings if the
    ; assertion provided new information about variables involved.
    (define (unify A B bindings)
        (let ([av (walk A bindings)]
              [bv (walk B bindings)])
              ; By taking the walked end values for both LHS and RHS
              ; of the unification, we're guaranteed that both never
              ; appear as the key in our bindings set.
            (cond
                [(and (Var? av) (Var? bv) (equal? av bv))
                 av]         ; Handles 5
                [(Var? av)   ; Handles 2 & 4
                 (extend av bv bindings)]
                [(Var? bv)   ; Handles 3
                 (extend bv av bindings)]
                [(eq? av bv) ; Handles 1
                 bindings]
                ; Produce #f in all other cases.
                [#t #f])))


    (define empty-bindings empty)

    (define (extend key val bindings)
        (cons (list key val) bindings))

Goals
~~~~~

We earlier stated that our "program" in this model has the task of figuring out
which possible assignments to variables makes sense -- i.e. is consistent with
a set of declarations about their properties. Since we're talking about
"possible assignments to variables", we'll model the result of our program
as a list of bindings. i.e. if we call our set of bindings a :rkt:`BSet`,
our program is expected to produce a :rkt:`(listof BSet)`.

This is giving our program a uniform interface of :rkt:`BSet -> (listof BSet)`.
We'll call such a program a "goal", since it is faced with the goal of finding
one or more possible sets of assignments to variables that is consistent with
some logic. In this case, if our goal cannot be met, the result is expected to
be an empty list indicating that there is no possible set of bindings that is
consistent with the goal.

Let's now consider the simplest of such programs -- a declaration of equality
between two things ... which is :rkt:`unify` in a different clothing.

.. code-block:: racket

    (define (eq A B)
        (λ (bindings)
            (let ([b (unify A B bindings)])
                (if b
                    (list b) ; Singleton list of bindings.
                    empty))))


It is useful to look at possible ways to combine :rkt:`(listof BSet)` values.

If we concatenate two such lists, we're saying that the :rkt:`BSet` values
belonging to either of the two lists are permitted as outcomes. This is like an
"or" (a.k.a. "disjunction") and we can exploit that.

.. code-block:: racket

    (define (disj goalA goalB)
        (λ (bindings)
            (let ([b1 (goalA bindings)]
                  [b2 (goalB bindings)])
                (append b1 b2))))


So we have "or". How do we get an "and" (a.k.a. "conjunction") of two goals?
Calling the first goal on bindings can produce a list of possible bindings,
but we then need to use the second goal to examine whether it is consistent
with any of them at all. To do that, we can call the second goal on each
of the result bindings, each of which will produce a list of bindings, and
then concatenate all those lists to get the result. That way, if the second
goal fails on all of them, it will indicate that by returning an empty
list in each case and when we concatenate them all, we'll get an empty list
as the result. If even one of them succeeded, the we'll get a non-empty list
and can go home happy.

.. code-block:: racket

    (define (conj goalA goalB)
        (λ (bindings)
            (let ([bs (goalA bindings)])
                (let ([cs (map goalB bs)])
                    (apply append cs)))))

.. admonition:: **Exercise**

    Go off now and study how the above definition of :rkt:`conj` satisfies our
    descripion of "and" in the preceding paragraph.


Note that :rkt:`eq` produces a goal based on a statement about variables and
values, and :rkt:`disj` and :rkt:`conj` take goals as arguments and produce
a goal as their result. So we can call them "combinators".

We can now describe some simple interesting searches.

.. code-block:: racket

    (define a (Var "a"))
    (define b (Var "b"))
    (define goal (conj (eq a 1)
                       (disj (eq b 2)
                             (eq b 3))))
    (writeln (goal empty-bindings))

.. admonition:: **Exercise**

    Go off and run the above code to see what you get as the result.

This task of introducing new variables can perhaps be automated a bit.
We define a new primitive called :rkt:`fresh` which creates new variables
and makes a goal of them.

.. code-block:: racket

    (define (fresh varnames goal-proc)
        (if (equal? (procedure-arity goal-proc) (length varnames))
            (let ([vars (map Var varnames)])
                (apply goal-proc vars))
            (raise-argument-error 'fresh
                                  "varnames should provide a name for each argument of the goal procedure"
                                  (list varnames goal-proc))))

Now, we can code our simple example as --

.. code-block:: racket

    (defien goal (fresh '(a b) (λ (a b)
                                  (conj (eq a 1)
                                        (disj (eq b 2)
                                              (eq b 3))))))
    (writeln (goal empty-bindings))


Structural unification
~~~~~~~~~~~~~~~~~~~~~~

So far, our "unification" procedure only dealt with simple values and variables.
We can extend this mechanism to also consider matching, say two cons pairs.
In that case though, we'd expect the corresponding parts of the cons pairs
to unify and hence unify becomes a recursive procedure. 

.. note:: What are possible problems when we try to do this? Think through
   possible cases one might encounter when calling :rkt:`unify` with such
   cons pairs to be unified and what we're supposed to do to them. Below
   are spoilers, so do that now!

What is supposed to happen when we ask for a variable to be unified with a cons
pair which itself contains this variable? If we wish to be strict about it, we
can declare failure when we encounter such a case. If we decide on this, we
need to add an "occurs check" to our unify cases. Otherwise we need to consider
the possibility that the unification request is intended to produce an infinite
circular data structure as the variable's resultant binding and tip toe around
that possibility without catching ourselves doing an infinte loop.

We'll chicken out and do the simple "don't let that happen" approach. You can
try the other option as an exercise (heheh!).

.. code-block:: racket

    (define (occurs? var expr)
        (if (pair? expr)
            (or (occurs? var (car expr))
                (occurs? var (cdr expr)))
            ; Note that if expr itself is var, we don't treat
            ; that as "var occurs", since that is benign self equality.
            #f))

We now use this to modify our unification procedure to support pairs.

.. code-block:: racket

    (define (unify A B bindings)
        (let ([av (walk A bindings)]
              [bv (walk B bindings)])
              ; By taking the walked end values for both LHS and RHS
              ; of the unification, we're guaranteed that both never
              ; appear as the key in our bindings set.
            (cond
                [(and (Var? av) (Var? bv) (equal? av bv))
                 av]         ; Handles 5
                [(and (Var? av) (not (occurs? av bv)))   ; Handles 2 & 4
                 (extend av bv bindings)]
                [(and (Var? bv) (not (occurs? bv av)))   ; Handles 3
                 (extend bv av bindings)]
                [(and (pair? av) (pair? bv))
                 ; We have to use car and cdr here instead of first
                 ; and rest because the latter two require the 
                 ; pair to be a non-empty list ... which is not a
                 ; constraint we require to be met by the two pairs.
                 (let ([b2 (unify (car av) (car bv) bindings)])
                     (unify (cdr av) (cdr bv) b2))]
                [(eq? av bv) ; Handles 1
                 bindings]
                ; Produce #f in all other cases.
                [#t #f])))

Such a structural unification is way more powerful than the ordinary atomic
value unification we did earlier. Check out the simple example below and make
more of your own --

.. code-block:: racket

    (define goal 
        (fresh '(a b) 
               (λ (a b)
                   (eq (cons a b) (list 1 2 3 4 5)))))

    (writeln (goal empty-bindings))

.. admonition:: **Exercise**

    Thoroughly thrash out various possible usages of such structural unification.
    What sets of arguments will you try it with and what would you expect? How might
    you extend it even further?

.. admonition:: **Question**

    Why didn't we consider implementing a :rkt:`not` since we implemented "and"
    and "or" as :rkt:`conj` and :rkt:`disj` respectively?


**Reference**: The approach above specifies a small goal language called microKanren_.
You may also want to go through `A Gentle Introduction to microKanren`_.

.. _microKanren: https://github.com/jasonhemann/microKanren/blob/master/microKanren.scm
.. _A Gentle Introduction to microKanren: https://erik-j.de/microkanren/

Generalizing pair structure
~~~~~~~~~~~~~~~~~~~~~~~~~~~

In the latest version of :rkt:`unify` above, we supported unification of two
"pair" structures. What if we want to generalize that and support arbitrary
:rkt:`struct`-like ... structures?

To do that, see what is special about a :rkt:`struct` that we define ourselves.
The main component of the definition that identifies a structure is its name,
and the fields are a list of values. We could model the structure's name as a
constant symbol and the fields as ... a list of values! While Racket's
structures have fixed arity, there is no real need to restrict ourselves to
fixed arity structures for the purpose of unification because we've already
implemented unification between lists!

So, let's model such an arbitrary structure as a Racket :rkt:`struct`. We
borrow a term used in Prolog -- "functor" -- for this purpose. In Prolog, in an
expression of the form :rkt:`word(arg1,arg2,...)` the :rkt:`word` is referred
to as a "functor".

.. code-block:: racket

    (struct FExpr (functor args))
    ; functor is a symbol
    ; args is a list of values.

When our new :rkt:`unify` tries to match two functors, we're going to demand
that their :rkt:`name` parts match exactly and both be symbols (and,
in particular, not variables). For the fields themselves, we can bank on our
support for matching two lists.

.. admonition:: **Design question**

    Should we permit matching a variable against an entire sublist of fields of
    a particular functor? i.e. Should our unify support unification between
    :rkt:`(FExpr 'f (cons (Var "one") (Var "two")))` and :rkt:`(FExpr 'f
    (list 1 2 3 4))`? What are the consequences of permitting versus not permitting
    such a unification?

We're going to assume that we cannot do "partial list of fields" matching between
two functors. We want the fields to match in count. i.e. We're going to demand that
:rkt:`fields` actually be a **list** and not merely be a sequence of nested conses.

.. code-block:: racket

    (define (valid-fexpr? f)
        (and (FExpr? f)
             (symbol? (FExpr-functor f))
             (list? (FExpr-args f))))

    (define (occurs? var expr)
        (cond
            [(pair? expr)
             (or (occurs? var (car expr))
                 (occurs? var (cdr expr)))]
            [(valid-fexpr? expr)
             (ormap (λ (e) (occurs? var e)) (FExpr-args expr))]
            ; Note that if expr itself is var, we don't treat
            ; that as "var occurs", since that is benign self equality.
            [else #f]))

    (define (unify A B bindings)
        (let ([av (walk A bindings)]
              [bv (walk B bindings)])
              ; By taking the walked end values for both LHS and RHS
              ; of the unification, we're guaranteed that both never
              ; appear as the key in our bindings set.
            (cond
                [(and (Var? av) (Var? bv) (equal? av bv))
                 av]
                [(and (Var? av) (not (occurs? av bv)))
                 (extend av bv bindings)]
                [(and (Var? bv) (not (occurs? bv av)))
                 (extend bv av bindings)]
                [(and (pair? av) (pair? bv))
                 ; We have to use car and cdr here instead of first
                 ; and rest because the latter two require the 
                 ; pair to be a non-empty list ... which is not a
                 ; constraint we require to be met by the two pairs.
                 (let ([b2 (unify (car av) (car bv) bindings)])
                     (unify (cdr av) (cdr bv) b2))]
                [(and (valid-fexpr? av) 
                      (valid-fexpr? bv)
                      (equal? (FExpr-functor av) (FExpr-functor bv))
                      (equal? (length (FExpr-args av) (FExpr-args bv)))]
                 ; We already know how to unify lists!
                 ; Here we're relying on the previous cond case, which
                 ; works with general nested pairs and hence also works with lists
                 ; ... which is what we're limiting ourselves to in this case.
                 (unify (FExpr-args av) (FExpr-args bv) bindings)]
                [(eq? av bv)
                 bindings]
                ; Produce #f in all other cases.
                [#t #f])))


.. admonition:: **Questions**

    What can you imagine using the above extension for? After all, programming
    languages are there to wish our imaginations into existence. So what wizard
    powers did the above extensions to unify (relative to the first cut) give
    you? What kinds of goals would you try it on?

    **Hint**: For one thing, you can model :rkt:`pair` itself using
    :rkt:`(FExpr 'cons (list <head> <tail>))`.

More coming after the following lecture...




