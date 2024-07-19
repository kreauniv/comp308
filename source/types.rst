Types: Checking some program invariants statically
==================================================

.. note:: This section was written after the fact. We did types in class but
   these notes were written up later. It is also currently incomplete
   and to be considered a "work in progress".

In this section, we build on the notion of "goals" discussed in the
section on :ref:`alternative application semantics` and use the notions of
unification and goals to understand how we can express some invariants
of our programs that can be checked before we run them. We'll use
Prolog here because it simplifies the discussion. We'll also restrict
ourselves to talking about the "arithmetic expressions" language and
leave extensions to your own efforts.

Pure arithmetic expressions
---------------------------

First off, if we only talk about arithmetic expressions sans function
application, there is little for us to check, since every expression
we can compose using our :code:`add`, :code:`sub` and :code:`mul` operations
is guaranteed to produce a number as a result. So our type checker
for that restricted language would look like this -

.. code-block:: prolog

    :- module(typecheck, [exprtype/2]).

    % num(X) is a num as long as X is a number.
    exprtype(num(X), num) :-
        number(X).

    % add(A,B) is a num as long as both A and B are num.
    exprtype(add(A,B), num) :-
        exprtype(A, num),
        exprtype(B, num).

    exprtype(sub(A,B), num) :-
        exprtype(A, num),
        exprtype(B, num).

    exprtype(mul(A,B), num) :-
        exprtype(A, num),
        exprtype(B, num).

We use the Prolog built-in predicate :code:`number(X)` which succeeds if
the given :code:`X` happens to be a number and fails otherwise. So, we
can use the above type checker to validate any arithmetic expression
we can write for our simple arithmetic language.

A few observations are in order -

1. The type checker already looks like it is "interpreting" the
   expression but just stopping short of calculation. i.e. it has a
   structure that closely mimics our interpreter for the language.

2. The type-checking of :code:`add`, :code:`sub` and :code:`mul` are
   indistinguishable and can be replaced by a common predicate --

    .. code-block:: prolog

        binoptype(A, B, num) :-
            exprtype(A, num),
            exprtype(B, num).

   i.e. when we write :code:`add(A,B)`, we already know that the :code:`A`
   and :code:`B` terms must evaluate to numbers.

When we introduce functions
---------------------------

Things get interesting when we introduce functions and function
application in our language. As we know, this adds three new terms
to our language --

1. We need a term to hold a symbol or "identifier" -- :code:`id`. 

2. We need a term using which we can express a "function". This term
   won't evaluate to a number. It will evaluate to a "function value".

3. We need a term for applying a function value to an argument to
   produce a result.

With the above additions, our type checker now becomes --

.. code-block:: prolog

    :- module(typecheck, [exprtype/3]).

    exprtype(_, num(X), num) :-
        number(X).

    exprtype(Env, add(A,B), num) :-
        exprtype(Env, A, num),
        exprtype(Env, B, num).

    exprtype(Env, sub(A,B), num) :-
        exprtype(Env, A, num),
        exprtype(Env, B, num).

    exprtype(Env, mul(A,B), num) :-
        exprtype(Env, A, num),
        exprtype(Env, B, num).

    % id(X) is of type Ty if a binding X = Ty exists in the environment.
    exprtype(Env, id(X), Ty) :-
        atom(X),
        member(X : Ty, Env).

    % A fun(...) expression is of type fun(ArgTy, BodyTy)
    % if its argument is of type ArgTy and its body is of type
    % BodyTy given occurrences of the argument in the body
    % are consistent with the type of the argument being ArgTy.
    exprtype(Env, fun(ArgSym, ArgTy, Body, BodyTy), fun(ArgTy, BodyTy)) :-
        exprtype([ArgSym : ArgTy|Env], Body, BodyTy).

    % Applying a function Fun to an Arg produces a value of type ResultTy
    % if Arg's type is ArgTy and the body type of the function is ResultTy
    % given the argument type.
    exprtype(Env, apply(Fun, Arg), ResultTy) :-
        exprtype(Env, Arg, ArgTy),
        exprtype(Env, Fun, fun(ArgTy, ResultTy)).


.. note:: Notice how we exploit the ideas of unification and
   conjunctions to describe the type structure of programs in our mini
   language.

Functions introduce the notion of "identifiers" in our language
and therefore any sub term can be one of the following types --

1. A number, which we denote using the atom :code:`num`.

2. A function or "closure", whose type we denote using the term
   :code:`fun(ArgTy, BodyTy)`. So the full type description of a
   function includes the type of its argument and the type of its result.

3. Similar to our interpreter, we use an "environment" to keep track
   of the types of "identifier" sub-expressions. In this case, we bind
   our identifiers to **type** terms in contrast to using the
   environment to bind identifiers to values when we interpret the
   expression.

A subtlety
~~~~~~~~~~

We used :code:`member(X = Ty, Env)` to check if :code:`X = Ty` is present in
the type environment. This is permissible and valid only in a limited number of
cases -- where the identifier being checked for is unique in the whole program
being type checked. In the presence of shadowing of identifiers, this needs to
be modified to check against only the first occurrence of the identifier in the
environment, when the environment is treated as a list.

To accommodate that, we need to use Prolog's "cut" operator (notated :code:`!`)
to stop searching after the first time it finds the identifier in the
environment. While :code:`member` will permit other possibilities, the cut
operator forces Prolog to discard all possibilities after that point.

.. code-block:: prolog

    lookup(X : Ty, Env) :-
        member(X : Ty, Env), !.
        

Typing conditional expressions
------------------------------

When we introduce booleans, comparisons and conditionals into our
language, our type system needs to correspondingly grow.

.. code-block:: prolog

    exprtype(_, true, bool).
    exprtype(_, false, bool).
    exprtype(Env, equal(A,B), bool) :-
        exprtype(Env, A, num),
        exprtype(Env, B, num).
    exprtype(Env, less(A,B), bool) :-
        exprtype(Env, A, num),
        exprtype(Env, B, num).
    exprtype(Env, and(A,B), bool) :-
        exprtype(Env, A, bool),
        exprtype(Env, B, bool).
    exprtype(Env, or(A,B), bool) :-
        exprtype(Env, A, bool),
        exprtype(Env, B, bool).
    exprtype(Env, not(A), bool) :-
        exprtype(Env, A, bool).

In the above formulation, we had a choice of how to represent
booleans. We chose to be explicit about them and prevented numbers and
functions from being interpreted as boolean. Untyped Scheme/Racket,
for example, has the notion of "generalized booleans" where any value
that is not :code:`#f` is taken to be "true" when used in a boolean
context. 

... but how would we type a conditional expression :code:`if(Cond,Then,Else)` ?
What if the :code:`Then` part is of one type and the :code:`Else` part is of
another type? We have some choices to make here --

1. We can constrain the expression to be such that the :code:`Then` and
   :code:`Else` parts must be of the same type. This is a common strategy
   in many languages (especially functional statically checked ones)
   and very viable for most programs, given a rich type system.

2. We introduce the notion of "union types" in our type system
   and type the :code:`if` expression as the union of the types of the
   :code:`Then` part and the :code:`Else` part.

The second option is a substantial addition to our type system, so
we'll take the simpler route here initially until we understand more.

.. code-block:: prolog

    exprtype(Env, if(Cond,Then,Else), Ty) :-
        exprtype(Env, Cond, bool),
        exprtype(Env, Then, Ty),
        exprtype(Env, Else, Ty).


Recursive functions
-------------------

Consider the expression --

.. code-block:: prolog

    apply(fun(x, XTy1, apply(id(x), id(x)), BTy1), fun(x, XTy2, apply(id(x), id(x)), BTy2))

Before we ask the question of what type should this expression be,
what should we be passing in in place of the variables :code:`XTy1`,
:code:`XTy2`, :code:`BTy1` and :code:`BTy2`?

We know that the type of an expression of the form
:code:`fun(X,Xty,B,Bty)` is :code:`fun(XTy,BTy)`. We can therefore
consider -- :code:`XTy1 = fun(XTy2, BTy2)`. Since we're "applying"
:code:`X` to itself, we also have :code:`XTy2 = fun(XTy2, BTy2)`. So
we're justified in saying :code:`XTy1 = XTy2` and similarly
:code:`BTy1 = BTy2`. So let's use that to simplify our expression --

.. code-block:: prolog

    apply(fun(x, XTy, apply(id(x), id(x)), BTy), fun(x, XTy, apply(id(x), id(x)), BTy))

... and we have :code:`XTy = fun(XTy, BTy)`. Wait a sec now! What is the
:code:`XTy` on the right side supposed to be? If we expand using the equation,
we'll need to keep expanding forever, as --

.. code-block:: prolog

    fun(XTy, BTy)
    -> fun(fun(XTy, BTy), BTy)
    -> fun(fun(fun(XTy, BTy), BTy), BTy)
    ...

.. index:: Strong normalization

When we dealt with structural unification, we forbid such unifications by using
an :code:`occurs?` check that checks whether a variable being unified with a
structure does not itself occur within the structure for this reason. So We
cannot type such a program in our language at this point. An important result
to note here since we cannot type recursion in our system is that every
expression that has a type in our language is **guaranteed to terminate** after
a finite number of steps. This property is called *strong normalization*.

.. admonition:: **Exercise**

    This notion of "strong normalization" sounds like a very limited thing. Are
    languages with this property useful? For one thing they aren't Turing
    complete. Can you think of situations where it is very useful to know that
    a program will terminate before you actually run it?

However, we also have some experience dealing with this kind of an equation.
We're trying to solve the equation :code:`XTy = fun(XTy, BTy)` for :code:`XTy`,
given arbitrary :code:`BTy`.

.. code-block:: prolog

    solve(XTy, BTy) :-
        XTy = fun(XTy, BTy).

If we took our strict notion of unification, this would cause our type checker
to fail. Prolog, however, permits this unification by solving the equation for
us. You can imagine Prolog solving it for us like how we solved recursion for
functions using name binding, or using recursion combinators in lambda calculus.

One way we can avoid relying on this special property of Prolog, is to add
an explicit "recursive function" term in our language, where the body of
the recursive function may refer to the function itself by name.

.. code-block:: prolog

    exprtype(Env, rec(Fname, Arg, ArgTy, Body, BodyTy), fun(ArgTy, BodyTy)) :-
        exprtype([Arg : ArgTy, Fname : fun(ArgTy, BodyTy) | Env], Body, BodyTy).

This is certainly not a general notion of recursion, but is useful enough for
many cases such as looping and we're now not relying on Prolog's ability
to solve that recursive unification for us.

Types and mutation
------------------

Introducing sequenced computation in our language and a corresponding notion
of "mutation of variables" would introduce an additional complexity to
our type system.

What would be the type of the identifier :code:`x` in --

.. code-block:: prolog

    seq(set(id(x), 3), set(id(x), false))

Should the identifier :code:`x` be of type :code:`num` or :code:`bool`?
This gets more complicated if the two :code:`set` mutations happen in 
different branches of a conditional.

A simple way this is resolved in statically typed languages is to say that an
identifier has to have a fixed type in its scope and therefore cause the above
sequencing operation to fail the type check. This is the sensible thing to do
from a human reasoning perspective. Identifiers are, after all, a tool for
humans to make connections between different parts of the computational graph.
When we rethink identifiers as "storage locations", we're actually introducing
a whole new concept into the language -- mutation. Even then, a programmer
would expect an identifier to keep referring to the "same kind of thing" in its
scope and won't expect it to change like a chameleon. Therefore the constraint
of "a variable can have only one type" is often imposed in statically typed
languages with a concept of mutation. To change the type of thing an identifier
refers to, you'll have to introduce a new scope.


Type soundness
--------------

Our type checker predicate :code:`exprtype` is making a prediction about what
will happen when we run our program on actual values. How do we know this
function does not lie? -- i.e. how do we know that if our type checker tells us
that the type of an expression is :code:`T`, then when we evaluate the
expression using our interpreter we'll certainly get a value of type :code:`T`?

.. index:: Soundness

This property of a type system is called "soundness" -- i.e. a type system is 
said to be sound if the the type computed by the type checker is guaranteed
to be the type of an expression when it eventually gets evaluated.

.. index:: Progress

.. index:: Preservation

Proving that a type system is sound is done in a series of alternating
steps called *progress* and *preservation*. "Progress" is the statement
that when we know the type of an expression, we can execute one step
of computation. In the "preservation" step, we prove that the type computed
earlier is indeed the type produced. With a series of alternating progress
and preservation steps, we can therefore prove (or disprove) that a type
system is sound.

.. admonition:: **Question**
    
   Is there a use for unsound type systems? Do you know of programming
   languages that have a type system that is not sound?

Note that when dealing with a typed programming language, there is an implicit
assumption about a set of known exceptional conditions that can occur, such as
program non-termination, runtime check failures and such. Therefore soundness
goes along with consideration for such exceptional conditions that a programmer
needs to accept can occur.

In the Prolog formulation, the interpreter and the type checker cosely follow
each other in structure. So it becomes easier to show soundness through
progress/preservation steps and to check that the interpreter actually produces
values in accordance with what the type checker says it does.

A taste of type inference
-------------------------

So far, in our language, we've given the types of arguments and results of
our functions explicitly and checked these against usage. Specifying types
explicitly like this is good discipline, but we can let the computer do much
of this checking work for us.

In many circumstances, we can **infer**, for example, the argument type
of a function by looking at the context in which it is being used.

Let us say we introduce another kind of term in our language -- the
"function whose arg and body types are inferred from context".

.. code-block:: prolog

    exprtype(Env, funinf(Arg, Body), fun(ArgTy, BodyTy)) :-
        %....what goes here?

For one thing, we can perhaps infer :code:`ArgTy` from the body based on
usage.

.. code-block:: prolog

    exprtype(Env, funinf(Arg, Body), fun(ArgTy, BodyTy)) :-
        exprtype([Arg : ArgTy|Env], Body, BodyTy).
        %....anything else needed?

Supposing we have a function :code:`funinf(x, add(id(x), id(x)))`, 
querying :code:`exprtype(Env, funinf(x, add(id(x), id(x))), FunTy)`
will result in :code:`FunTy = fun(num, num)`, thanks to Prolog's
unification and goal search mechanisms.

In fact, much of what we've been writing so far can already do
some inference for us because we've embedded it in Prolog where
unification and goal search are built-in.

So, given that we have operations such as :code:`add`, :code:`or`
and :code:`equal` whose types are well known, we can completely
dispense with explicitly specifying types in our system and rely
on such inference. i.e. We can simply express our functions as
:code:`fun(ArgSym, Body)` and use the goal search mechanism --

.. code-block:: prolog

    exprtype(Env, fun(ArgSym, Body), fun(ArgTy, BodyTy)) :-
        exprtype([ArgSym : ArgTy|Env], Body, BodyTy).

The above goal is saying "Find some :code:`ArgTy` and :code:`BodyTy` such that
if you place :code:`ArgSym : ArgTy` in the environment, the body of the
function checks out to be of type :code:`BodyTy`. In fact, we needn't have made
any modification to our type checker to do such inference if we permitted the
use of Prolog variables when we constructed our function term. So instead of
saying :code:`fun(x, num, add(id(x), id(x)), num)`, all we needed to say was
:code:`fun(x, XTy, add(id(x), id(x)), RTy)` and our type checker would've told
us what :code:`XTy` and :code:`RTy` should be when we query
:code:`exprtype(Env, fun(x, XTy, add(id(x), id(x)), RTy), fun(XTy, RTy))`.

So even with just what we had earlier, you can do a query like --
:code:`exprtype([], fun(x, apply(id(x),num(4))), T)`, which will succeed with
:code:`T = fun(fun(num, _A), _A)`. Notice how SWI-Prolog gives a variable in
place of the result type of the function. If you try :code:`exprtype([], fun(x,
id(x)), T)`, you'll similarly get :code:`T = fun(_A, _A)`, which makes sense as
the identity function must have the same type for input and result. 

We therefore have some minimal polymorphism implemented in our type system (as
implemented in our checker) already, though our programs don't yet support
explicit polymorphism. For that, we need to enrich the type system with
types like "Listof A".

.. admonition:: **Exercise**

    Work out how the above implementation can compute the type of a function
    argument based on how the argument ends up being used in the function body.
    Where can such a type inference fail? Is it possible for more than one
    solution to the goal search to turn up? How and when? Would this goal
    search process terminate always?


Parametric polymorphism
-----------------------

Consider a function that always evaluates to the number :code:`42` in our language.
We could write such a function as :code:`fun(x, num, num(42), num)`. However,
since it is a "constant", we don't really care about the type of the argument.
How can we express the notion of "this function can work no matter what type
of argument you give it"? While we're using a trivial example here to introduce
the idea, this is a very common requirement when dealing with many functions.

For example, "addition" as a function can basically say "give me any two things
that can be added and I'll add them". This would work for integers, floating
point numbers, complex number and even equal length vectors of numbers.

While addition seems specific to "things that can be added", there are still
functions like :code:`map` which can apply arbitrary functions to elements of
a sequence without caring about what specific type they are, as long as some
structural constraints are met. For :code:`map`, for example, we say that
it has the type -

.. code-block:: haskell

    map :: (a -> b) -> Listof a -> Listof b

... where :code:`a` and :code:`b` are "type variables". Parametric polymorphism
combined with type inference can be a very powerful way to check correctness of
our programs and makes for a rich language.

First let's try to represent such a type. When we use such type variables without
saying anything more about them, what we're essentially saying is that the function
(if it is a function) ought to work for **all** instances of the type variable,
instantiated to be the same wherever it occurs. So let's capture that explicitly
for the :code:`map` function above, using the right-associativity of :code:`->`.

.. code-block:: prolog

    all([a,b], fun(fun(tvar(a),tvar(b)),fun(listof(tvar(a)), listof(tvar(b)))))

While we could've written the above as
:code:`all([a,b],fun(fun(a,b),fun(listof(a),listof(b))))`, that muddies up the
type expression language because we'll then be unable to distinguish between an
:code:`a` that is a concrete type (like :code:`num`) and a type variable. So it
is better to make that explicit.

So when we type check something against such a "polymorphic" type, we need to 
find bindings for the type variables, and also ensure that all occurrences of a
type variable meet required constraints when bound to the same type instance.

In yet more words, what we're saying is that :code:`map :: a -> b -> Listof a -> Listof b`
stands for the following collection of types --

.. code-block:: haskell

    Int -> String -> Listof Int -> Listof String
    Int -> Int -> Listof Int -> Listof Int
    Listof String -> Int -> Listof (Listof String) -> Listof Int
    Listof Int -> Listof String -> Listof (Listof Int) -> Listof (Listof String)
    -- ...and so on...

One thing to keep in mind is that when we write such an :code:`all` type,
the scope of the variables used within it is expected to be restricted to
the insides of the :code:`all(...)` form. In other words, we consider all
:code:`all(..)` forms obtained by replacing the type variables by arbitrary
symbols within the form to be equivalent. i.e. all of the below represent
the same type --

.. code-block:: prolog

    all([a,b],fun(fun(tvar(a),tvar(b)),fun(listof(tvar(a)),listof(tvar(b)))))
    all([b,a],fun(fun(tvar(a),tvar(b)),fun(listof(tvar(a)),listof(tvar(b)))))
    all([w],fun(fun(tvar(w),tvar(w)),fun(listof(tvar(w)),listof(tvar(w)))))
    all([x,y],fun(fun(tvar(x),tvar(y)),fun(listof(tvar(x)),listof(tvar(y)))))
    all([x42,b23],fun(fun(tvar(x42),tvar(b23)),fun(listof(tvar(x42)),listof(tvar(b23)))))
    ...and so on...

Observe that the ordering of the type variables listed in the first argument to
:code:`all` is irrelevant, and so that is really a "set of type variables".
Also, the third case where we give only one type variable instead of two,
captures the case where both :code:`a` and :code:`b` can be bound to the same
concrete type.

.. admonition:: **Question**

    Consider this -- are the two types :code:`all([a],fun(tvar(a),tvar(a)))`
    and :code:`fun(all([a],tvar(a)),all([a],tvar(a)))` equivalent? Try
    and describe these in words. Can you write example functions that fit
    these type descriptions?

In order to reduce all ambiguity about which type variables we're referring
to within such a polymorphic type, it would be useful to have a procedure that
makes the unique type variables within a scope, also globally unique. We
can do that using Prolog's :code:`gensym/2`.

.. code-block:: prolog

    unique_tvars(Env, tvar(V), tvar(U)) :-
        lookup(V = U, Env).

    unique_tvars(Env, fun(A,B), fun(UA, UB)) :-
        unique_tvars(Env, A, UA),
        unique_tvars(Env, B, UB).

    unique_tvars(Env, all(Tvars, PolyType), all(UTvars, UPolyType)) :-
        maplist(unique_tvarenv, Env, Tvars, UTvars, EnvR),
        unique_tvars(EnvR, PolyType, UPolyType).

    unique_tvarenv(Env, [], [], Env).
    unique_tvarenv(Env, [Tvar|Tvars], [UTvar|UTvars], EnvResult) :-
        gensym(Tvar, UTvar),
        unique_tvarenv([Tvar = UTvar | Env], Tvars, UTvars, EnvResult).


Now that we know how to make "local" type variables globally unique, we don't
need to worry about ambiguities in dealing with them. So we'll also assume
we'll use distinct variables to mean distinct types in our code for simplicity,
assuming that such a uniquification step has been done.

... to be continued ...


        







