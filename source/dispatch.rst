Polymorphism via dispatch
=========================

When writing our procedures/functions in a programming language, we deal with different
data structures and entities such as files, network sockets and processes. For any given
system, a number of such entities serves as its "API" or "Application Programming Interface".
If each of these entities were to be transacted with using its own vocabulary, it will
become very hard for programmers to retain the vocabularies necessary to work with a
practical subset of these entity types in working memory so they act of programming is
both efficient and reliable. 

Thankfully, many of these entities can be worked with using a much smaller set of "verbs"
using which programmers typically chunk their thinking about them. For example, both hash-tables
and vectors in Racket offer the notion of associating a value with a key. Only, in the case
of hash-tables, the key can be anything "hashable" whereas in the case of a vector, the key
must be in the range :math:`[0,N)`. However, the act of getting a value associated with a
particular key can simply be thought of across all such data structures using the verb "get"
and similarly the setting of a value against a particular key can be thought of using the
verb "set".

For an analogy, consider the Harry Potter world and Hermione Granger's timely use of
the spell "Alohamora" to open a lock. Suppose that in the wizarding world, each kind of
lock required a different spell to be learnt to open it -- "Alohamora Big One", "Alohamora 42",
"Alohamora Locksmith & Sons Tiny 2021 edition" and so on -- wizards might give up pretty soon.
But we have a hint here -- that the word "Alohamora" suggests that the lock needs to be opened,
and the ones programming these locks can determine what to do when the lock hears the spell
"Alohamora", instead of making custom spells for it. This would then obviously be preferrable
for wizards (and students!) since they would then need to remember far fewer spells overall
to be effective in their world. 

Racket library functions kind of work as though they were in that complicated world of
spells. In Racket, though you'll find procedures named according to such common vocabulary,
each data structure carries its own set of procedures to work with it. So vectors come
with ``vector-get`` and ``vector-set!`` and ``vector-length``, and similarly hash-tables have
``hashtable-get``, ``hashtable-set!`` and ``hashtable-length``. If we were to invent another
data structure, say, ``tree-map``, then we'll have to expose yet more procedures named
``tree-map-get``, ``tree-map-set!`` and ``tree-map-length`` that will do analogous things with
tree-maps. If we choose completely different vocabularies -- say, ``tree-map-search-and_retrieve``,
``tree-map-find-and-replace`` and ``tree-map-count-entries`` -- we'd place a huge cognitive
burden on programmers who'd want to adopt our new data structure since they cannot reuse
their vocabulary in the new context.

What if we could simply say ``get``, ``set!`` and ``length`` and when we introduce a new data
structure, be able to declare how these verbs should work with it at that point? That way,
if we have a vector ``v``, we get get its ``k``-th element using ``(get v k)`` and if we have a
hashtable ``h`` and a key ``k``, we can get its associated value using ``(get h k)`` as well,
instead of ``(hashtable-get h k)``. It is quite evident that the cognitive burden is lower
for such a unified concept of "``get``-ting" a value. While doing this makes for concise code
while writing, we also notice that when reading code, ``(get h k)`` tells us very little about
``h`` than "something we can call ``get`` on", whereas ``(hashtable-get h k)`` is amply clear.
This is part of the reason for that design choice in the Scheme language.

Such a multi-purpose definition of a verb like ``get`` and ``set!`` is referred to in programming languages as
"polymorphism" and the verb is said to be "polymorphic" over a collection of types.

.. admonition:: **Polymorphism**
    
    The language facility by which a verb can result in different actions depending on
    which entity/entities it is addressed to.

Generic procedures
------------------

So far we've defined procedures in Scheme/Racket using the ``define`` operator, like this --

.. code:: racket

    (define (f x y) ...)

Once defined, the procedure ``f`` will remain bound to that body of code forever .. until
redefined entirely. What if, however, we wish to enable it to be extensible with different
code paths depending on what arguments are passed to it. For simplicity, we'll assume that the
arity of the function cannot be changed, initially.

.. code:: racket

    (define (extend proc predicate extension)
        (lambda args
            (if (apply predicate args)
                (apply extension args)
                (apply proc args)))
    
    ; Example of extending ordinary artihmetic to symbolic arithmetic.
    (set! + (extend +
                (lambda (x y)
                    (or (symbol? x) (symbol? y))
                (lambda (x y)
                    (list '+ x y)))))

    ; (plus 2 3) => 5
    ; (plus 2 'y) => '(+ 2 y)
    ; (plus 'x 3) => '(+ x 3)

The predicate-extension pairs form the various branches of a ``cond`` expression
that decides which of the extension procedures to call based on properties met by
the arguments --

.. code:: racket

    (cond
        [(apply predicate1 args) (apply extension1 args)]
        [(apply predicate2 args) (apply extension2 args)]
        ...)

Since the cond expression serves as a "post office" that "dispatches" the arguments
to the appropriate extension procedure, we refer to this approach in the general sense
as "dispatch mechanisms" and will study variants in this chapter.

There are some incidental aspects of the above implementation of the extension of a function
that we won't concern ourselves about. For example, When we extend with a new predicate
and extension, the latest extension takes precedence over the earlier installed ones.
This raises a question -- "what if we want it to be the other way around?" -- but
there is little there of interest to us at this point.

.. admonition:: **Restriction**

    For our purposes, we'll restrict our cases to where the predicates are all disjoint
    on any given list of arguments -- i.e. only one of the predicates evaluates to ``#t``
    on a given list of arguments. This means we don't have to bother about the order in which
    we check the predicates.

So, the key idea behind organizing code using **dispatch** mechanisms is to have a set of 
special case procedures associated with predicates on the generic procedure's arguments
which determine which special case is to be used.

One argument dispatch
---------------------

Let's take the simple case where all the predicates make their decisions based
only on the first argument. A classic example is "string representation". We'd like
to be able to view our values in some way and that calls for a textual presentation
of the value. 

.. code:: racket

    (define (as-string value)
        (if (string? value)
            value
            (error "Don't know how to treat value as a string")))

Now supposing we wish to extend this facility to integers. We will need a special procedure
for that --

.. code:: racket

    (define (int-as-string i)
        (cond
            [(= i 0) "0"]
            [(< i 0) (string-concat "-" (int-as-string (- i)))]
            [(> i 0) (positive-int-as-string i)]))
    (define (positive-int-as-string i)
        (if (= i 0)
            ""
            (string-concat (positive-int-as-string (div i 10)) (digit-as-string (remainder i 10)))))
    (define (digit-as-string d)
        (char->string (string-char-at "0123456789" d)))

Now we can augment our "as-string" generic procedure with this special case for integers.

.. code:: racket

    (set! as-string (extend as-string
                            integer?
                            int-as-string))

Whenever we create a new data type in our program, we can augment our ``as-string``
generic procedure with a facility that works for our new type when passed to it.

Note that we've now started associating the predicate for dispatch with a "type"
of value we're passing. Given data types ``A``, ``B``, ``C``, etc. in our program,
we'll then end up with specialization functions named ``A-as-string``, ``B-as-string``,
``C-as-string`` and so on which handle ``as-string`` cases for each of our types.

This is a little curious because we now associate the "ability to be expressed as a string"
with each of our data types for which we need that in our program. So there are perhaps
two equivalent ways of organizing our code here --

1. Maintain ``as-string`` in a module and add a new implementation to that module for
   every type we introduce within our program. This means every such type's definition will have
   to be imported into the module that builds up ``as-string``. If we continue along the
   lines of what we've been doing so far, we'll end up with this kind of an organization.

2. We can declare the ability to be presented as a string as a "property" of our data
   type, and declare the specialization wherever we declare our type. This then keeps
   all such behaviours together, which makes for ease of maintenance. However then, 
   we need some background facility that will collect all such specifications for our
   various types and build up a single ``as-string`` that will dispatch over our data types.

The second way of looking at this approach makes us think of our data types as
"things" to which these kinds of special behaviour procedures are "attached" as
properties. When we need to "invoke" these procedures, we simply call the procedure
on the value and it knows which special case to use.

Since we're assuming that all our predicates are disjoint, it would be a far more
efficient way to dispatch if we store right within our value, which of the various
dispatch predicates will return ``#t`` for it. So we treat each value as having a
hashtable of properties keyed by the various "generic" behaviours it needs to support
and whose values are the special implementation. To call on this behaviour, then
we can implement a common ``invoke`` procedure like this --

.. code:: racket

    (invoke value 'as-string)

Instead of ``(as-string value)``. 

Of course, it is also possible to make the generic procedure ``as-string`` efficiently
do its dispatch using a similar hashtable within it.

Dispatch over a single argument is therefore the crux of "objects" in programmning
lanugages. We will come back to some of the design aspects of object systems after
going through the other possible dispatch mechanisms.


Multiple argument dispatch
--------------------------



Dispatching with tagged values
------------------------------

One argument case
~~~~~~~~~~~~~~~~~

Multiple argument case
~~~~~~~~~~~~~~~~~~~~~~

