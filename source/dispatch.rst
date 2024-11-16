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

A value as a "thing"
----------------------

If we articulate our extension approach as an ``as-string`` facility that's attached to
every value we create that's specialized to its purpose, we're starting to think of
our values as "things" ... more commonly known as "objects" in programming.

So far, we've been thinking of ``as-string`` as the primary entity that we seek to
extend. If we flip our perspective to focus on the value, it is the value that we
then seek to augment with a procedure named ``as-string``. So, the value-specific
behaviour of ``as-string`` becomes more of an attribute of the value.

So instead of ``(as-string value)``, we think of a mechanism ``invoke`` that can 
invoke such behavioral attributes of our "objects" by name like 
``(invoke value 'as-string)`` instead.

We can extend this notion to take in more arguments also, which is compatible with
our "dispatch based on a predicate set over the first argument of a generic procedure".
``(invoke value 'method arg1 arg2 ...)``.

.. admonition:: **Terminology**:

	We call such procedural attributes "methods". 

"Methods" are general enough to model "properties" of such "objects". To model a 
property, we need to be able to **get** a property value, and **set** it to change
its value. So if we have a method that optionally takes a single argument --
i.e. either ``(invoke value 'prop-name)`` or ``(invoke value 'prop-name prop-val)``, where
the first way of calling will return the current value of the property and if you
supply an argument, it sets the property to the given value and (optionally) returns
``value`` as the result, we can pretend that the method ``'prop-name`` corresponds
not to a procedure, but to a property of an object.

.. admonition:: **Terminology**:

	The notion of an object's **property** is equivalent to having a named
	behaviour that can be invoked to set or get a particular value identified
	by the behaviour's name.

Duplication of dispatch
-----------------------

When we associate a set of behaviours (and properties, by extension, which we'll
stop calling out from now on) with values, we may imagine a table tagging
along with each value in the system -- where the table maps behaviour names to
special procedures. If we are to do this for, say, all the numbers in our program,
this starts to look like an awful waste of memory for what is essentially repeated
information. After all, we usually don't want to do different things to 2, 3, 4,
42, etc. However, we may want to do one thing for all integers, and another thing
for all floating point numbers, and yet another for fractions.

In essence, our ``as-string`` generic procedure therefore dispatches on predicates
of the form ``integer?``, ``float?`` or ``rational?``, rather than specific
values.

To put this differently, we have a table of such behaviours we wish integers
to satisfy and give special procedures for named behaviours in this table. Then
we merely need to identify this table by pointing to it when we have an integer
value ... or any other more complex and potentially compound data item.

In OOP languages, such a table of behaviours is called a "class". Our ``invoke``
procedure then starts to look like this --

.. code:: racket

	(define (invoke value method-name . args)
		(let* [(class (get-class value))
			   (behaviour (lookup-behaviour-proc class method-name))]
			(apply behaviour (cons value args))))

The above specification of what ``invoke`` does has a gap. What happens when
``lookup-behaviour-proc`` determines that the identified ``class`` has no such
method?

.. code:: racket

	(define (invoke value method-name . args)
		(let* [(class (get-class value))
			   (behaviour (lookup-behaviour-proc class method-name))]
			(if (procedure? behaviour)
				(apply behaviour (cons value args))
				(error "No such method"))))

In the above version which calls out this case, we actually have a design
choice.

1. Perhaps we could call a default generic procedure that we can specialize
   for different types of values.

2. We can check another class's behaviour table for a procedure. If we take
   this route, we see that our value then automatically would get all the
   behaviours associated with this other class -- or it will "inherit" 
   these behaviours. For this reason, such a class to which the "no such method"
   case is delegated to is called the "parent class" or "super class".
			
.. code:: racket

	(define (invoke value method-name . args)
		(let* [(class (get-class value))
			   (behaviour (lookup-behaviour-proc class method-name))]
			(if (procedure? behaviour)
				(apply behaviour (cons value args))
				(let* [(super-class (get-parent class))
				       (behaviour (lookup-behaviour-proc super-class method-name))]
					(if (procedure? behaviour)
						...)))))

Ah! So this procedure of looking up the parent class seems to go on for ever?
Let's simplify this by defining invoke in a different way.

.. code:: racket

	(define (c-invoke class value method-name . args)
		(let [(behaviour (lookup-behaviour-proc class method-name))]
			(if (procedure? behaviour)
				(apply behaviour (cons value args))
				(apply c-invoke (list (get-parent class) value method-name . args)))))

How deep would this ``get-parent`` lookup go then?

Most object oriented languages solve this problem by having a "root" class,
perhaps named ``Object`` whose parent is itself.

Objects objects everywhere
--------------------------

We can then ask -- "Can we treat all values in our language as objects?"
... and the answer would be "yes!". Languages like Smalltalk, Ruby
and Self take a "everything is an object" perspective. This means
all values have associated "classes" and even a "class" is itself
an object and also has a class. In the case of Smalltalk, a class'
class is called a "meta class" and meta classes also form a hierarchy 
that parallels the class heirarchy.

Take a moment to think about this. We're comfortable representing
some values such as numbers directly in our programs because we have
common character based representations for them. Once they become
values within the program, they gain behaviours we can invoke
by name. This has the same power as having a slew of procedures
we can invoke on these numbers and such values. However, the only
way to **do** anything in such a language is to invoke a method
or an object! If the invocation returned another object and you
want to see it, you need to invoke another method on **that** object.
Obviously, this recursion has to stop somewhere, and programming
languages provide some built-in objects with behaviour implementations
that don't return any further values, and entire programs are then
constructed using these built-in values and the class-mechanism
of the language.

.. admonition:: **Terminology**:

	When something in a programming language can be represented and
    manipulated as a value, we say it is "first class". True OOP
	languages like Smalltalk feature classes as first-class entities,
	whereas semi-OOP languages like C++ treat classes and values 
	as separate worlds within the language.


The methods of a class
----------------------

Since we're looking at a class as an object as well, it is instructive
to think about what kinds of behaviours may be attributable to
a class.

We already know one such -- the ``'parent-class`` property that
all classes must possess for the behaviour lookup mechanism to
work in the language. 

We may also wish to be able to see a representation of all values
in our system and therefore might wish to define procedures
that will, say, print them to a terminal, or display them in 
some environment. A common generic way to handle this is to
permit a string representation of all values. Such a behaviour
that can be used to get such a string representation is often
named ``'description`` in such languages.

.. code:: racket

	(invoke value 'description)
	; Gets a "string" that is repurposable across multiple
	; presentation modes.

We'd previously used a ``lookup-behaviour-proc``. This looks like a 
perfect candidate for a property of a class, so to get a behaviour
proc object associated with a class by name, we'd do --

.. code:: racket

	(invoke class 'behaviour-named name)
	
At this point, you may begin to appreciate how the snake starts
to eat its own tail, since a "behaviour procedure" itself ought
to be an object.

Since invocation is the only thing you can do in a strict OOP 
language, these languages give built-in syntax to keep invocations
short. Many C-based languages such as Python and Javascript and C++
use the "dot notation" to denote both properties and methods --
like ``value.property`` and ``value.method(arg1, arg2)``. 

Languages like Smalltalk make it even simpler by making method
invocation invisible in the text -- like ``value method`` or 
``value methodKey1: val1 key2: val2 ...``.


Classes versus types
--------------------

Object oriented languages also tend to refer to such "classes" as "types".
This comes from an identification of "what kind of thing is this thing?"
with "what set of behaviours does this thing permit?".

Since method invocation is the only action available in such systems,
if you know the set of behaviours supported by a particular value,
you know all there is to know about what kind of a thing it is,
within this programming context. 


Multiple argument dispatch
--------------------------



Dispatching with tagged values
------------------------------

One argument case
~~~~~~~~~~~~~~~~~

Multiple argument case
~~~~~~~~~~~~~~~~~~~~~~

