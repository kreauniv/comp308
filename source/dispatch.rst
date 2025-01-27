Polymorphism via dispatch
=========================

Note: This section is expected to supercede the discussion on :doc:`objects`.

When writing our procedures/functions in a programming language, we deal with
different data structures and entities such as files, network sockets and
processes. For any given system, a number of such entities serves as its "API"
or "Application Programming Interface". If each of these entities were to be
transacted with using its own vocabulary, it will become very hard for
programmers to retain the vocabularies necessary to work with a practical
subset of these entity types in working memory so they act of programming is
both efficient and reliable. 

Thankfully, many of these entities can be worked with using a much smaller set
of "verbs" using which programmers typically chunk their thinking about them.
For example, both hash-tables and vectors in Racket offer the notion of
associating a value with a key. Only, in the case of hash-tables, the key can
be anything "hashable" whereas in the case of a vector, the key must be in the
range :math:`[0,N)`. However, the act of getting a value associated with a
particular key can simply be thought of across all such data structures using
the verb "get" and similarly the setting of a value against a particular key
can be thought of using the verb "set".

For an analogy, consider the Harry Potter world and Hermione Granger's timely
use of the spell "Alohamora" to open a lock. Suppose that in the wizarding
world, each kind of lock required a different spell to be learnt to open it --
"Alohamora Big One", "Alohamora 42", "Alohamora Locksmith & Sons Tiny 2021
edition" and so on -- wizards might give up pretty soon. But we have a hint
here -- that the word "Alohamora" suggests that the lock needs to be opened,
and the ones programming these locks can determine what to do when the lock
hears the spell "Alohamora", instead of making custom spells for it. This would
then obviously be preferrable for wizards (and students!) since they would then
need to remember far fewer spells overall to be effective in their world. 

Racket library functions kind of work as though they were in that complicated
world of spells. In Racket, though you'll find procedures named according to
such common vocabulary, each data structure carries its own set of procedures
to work with it. So vectors come with ``vector-ref`` and ``vector-set!`` and
``vector-length``, and similarly hash-tables have ``hash-ref``,
``hash-set!`` and ``hash-count``. If we were to invent another data
structure, say, ``treemap``, then we'll have to expose yet more procedures
named ``treemap-ref``, ``treemap-set!`` and ``treemap-length`` that will do
analogous things with tree maps. If we choose completely different vocabularies
-- say, ``treemap-search-and-retrieve``, ``treemap-find-and-replace`` and
``treemap-count-entries`` -- we'd place a huge cognitive burden on programmers
who'd want to adopt our new data structure since they cannot reuse their
vocabulary in the new context.

What if we could simply say ``ref``, ``set!`` and ``length`` and when we
introduce a new data structure, be able to declare how these verbs should work
with it at that point? That way, if we have a vector ``v``, we reference its ``k``-th
element using ``(ref v k)`` and if we have a hashtable ``h`` and a key ``k``,
we can get its associated value using ``(ref h k)`` as well, instead of
``(hash-ref h k)``. It is quite evident that the cognitive burden is lower
for such a unified concept of "``ref``-ing" a value.

While doing this makes for concise code while writing, we also notice that when
reading code, ``(ref h k)`` tells us very little about ``h`` than "something we
can call ``ref`` on", whereas ``(hash-ref h k)`` is amply clear. This is part
of the reason for that design choice to be explicit in the Scheme/Racket
languages. The goal of a program is only partly to instruct machines (such as
"locks") but equally to communicate "how to" knowledge to other humans.

.. admonition:: **Terminology**

    Such a multi-purpose definition of a verb like ``ref`` and ``set!`` is
    referred to in programming languages as "polymorphism" and the verb is said
    to be "polymorphic" over a collection of types.

Generic procedures
------------------

So far we've defined procedures in Scheme/Racket using the ``define`` operator,
like this --

.. code:: racket

    (define (f x y) ...)

Once defined, the procedure ``f`` will remain bound to that body of code
forever .. until redefined entirely. What if, however, we wish to enable it to
be extensible with different code paths depending on what arguments are passed
to it. For simplicity, we'll assume that the arity of the function cannot be
changed, initially.

.. code:: racket

    (define (extend proc predicate extension)
        (lambda args
            (if (apply predicate args)
                (apply extension args)
                (apply proc args)))
    
    ; Example of extending ordinary artihmetic to symbolic arithmetic.
    (define sym+ 
        (extend +
                (lambda (x y)
                    (or (symbol? x) (symbol? y))
                (lambda (x y)
                    (list '+ x y)))))

    ; (plus 2 3) => 5
    ; (plus 2 'y) => '(+ 2 y)
    ; (plus 'x 3) => '(+ x 3)

However, instead of introducing a new symbol ``sym+`` for our extended
notion of addition, we can replace the earlier definition of ``+`` to 
mean what the new ``sym+`` means because ``sym+`` also deals with the
case of adding up ordinary numbers.

.. code:: racket

    (set! + sym+)

.. admonition:: **Exercise**

    When defining ``sym+``, we used the existing definition of ``+``. Now
    that we've changed what ``+`` means, do we now have a circular program?
    Explain whether you think "yes" or "no" is the answer to that question
    using your understanding of scoping rules of SMoL.

The predicate-extension pairs form the various branches of a ``cond``
expression that decides which of the extension procedures to call based on
properties met by the arguments --

.. code:: racket

    (cond
        [(apply predicate1 args) (apply extension1 args)]
        [(apply predicate2 args) (apply extension2 args)]
        ...)

Since the cond expression serves as a "post office" that "dispatches" the
arguments to the appropriate extension procedure, we refer to this approach in
the general sense as "dispatch mechanisms" and will study variants in this
chapter.

There are some incidental aspects of the above implementation of the extension
of a function that we won't concern ourselves about. For example, When we
extend with a new predicate and extension, the latest extension takes
precedence over the earlier installed ones. This raises a question -- "what if
we want it to be the other way around?" -- but there is little there of
interest to us at this point.

.. admonition:: **Restriction**

    For our purposes, we'll restrict our cases to where the predicates are all
    disjoint on any given list of arguments -- i.e. only one of the predicates
    evaluates to ``#t`` on a given list of arguments. This means we don't have
    to bother about the order in which we check the predicates.

So, the key idea behind organizing code using **dispatch** mechanisms is to
have a set of special case procedures associated with predicates on the generic
procedure's arguments which determine which special case is to be used.

One argument dispatch
---------------------

Let's take the simple case where all the predicates make their decisions based
only on the first argument. A classic example is "string representation". We'd
like to be able to view our values in some way and that calls for a textual
presentation of the value. 

.. code:: racket

    (define (as-string value)
        (if (string? value)
            value
            (error "Don't know how to treat value as a string")))

Now supposing we wish to extend this facility to integers. We will need a
special procedure for that --

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

Now we can augment our "as-string" generic procedure with this special case for
integers.

.. code:: racket

    (set! as-string (extend as-string
                            integer?
                            int-as-string))

Whenever we create a new data type in our program, we can augment our
``as-string`` generic procedure with a facility that works for our new type
when passed to it.

Note that we've now started associating the predicate for dispatch with a
"type" of value we're passing. Given data types ``A``, ``B``, ``C``, etc. in
our program, we'll then end up with specialization functions named
``A-as-string``, ``B-as-string``, ``C-as-string`` and so on which handle
``as-string`` cases for each of our types.

This is a little curious because we now associate the "ability to be expressed
as a string" with each of our data types for which we need that in our program.
So there are perhaps two equivalent ways of organizing our code here --

1. Maintain ``as-string`` in a module and add a new implementation to that
   module for every type we introduce within our program. This means every such
   type's definition will have to be imported into the module that builds up
   ``as-string``. If we continue along the lines of what we've been doing so
   far, we'll end up with this kind of an organization.

2. We can declare the ability to be presented as a string as a "property" of
   our data type, and declare the specialization wherever we declare our type.
   This then keeps all such behaviours together, which makes for ease of
   maintenance. However then, we need some background facility that will
   collect all such specifications for our various types and build up a single
   ``as-string`` that will dispatch over our data types.

A value as a "thing"
----------------------

If we articulate our extension approach as an ``as-string`` facility that's
attached to every value we create that's specialized to its purpose, we're
starting to think of our values as "things" ... more commonly known as
"objects" in programming.

So far, we've been thinking of ``as-string`` as the primary entity that we seek
to extend. If we flip our perspective to focus on the value, it is the value
that we then seek to augment with a procedure named ``as-string``. So, the
value-specific behaviour of ``as-string`` becomes more of an attribute of the
value.

So instead of ``(as-string value)``, we think of a mechanism ``invoke`` that
can invoke such behavioral attributes of our "objects" by name like ``(invoke
value 'as-string)`` instead.

We can extend this notion to take in more arguments also, which is compatible
with our "dispatch based on a predicate set over the first argument of a
generic procedure". ``(invoke value 'method arg1 arg2 ...)``.

.. admonition:: **Terminology**

    We call such procedural attributes "methods". 

"Methods" are general enough to model "properties" of such "objects". To model
a property, we need to be able to **get** a property value, and **set** it to
change its value. So if we have a method that optionally takes a single
argument -- i.e. either ``(invoke value 'prop-name)`` or ``(invoke value
'prop-name prop-val)``, where the first way of calling will return the current
value of the property and if you supply an argument, it sets the property to
the given value and (optionally) returns ``value`` as the result, we can
pretend that the method ``'prop-name`` corresponds not to a procedure, but to a
property of an object.

.. admonition:: **Terminology**

    The notion of an object's **property** is equivalent to having a named
    behaviour that can be invoked to set or get a particular value identified
    by the behaviour's name.

Dispatch (in)efficiencies
-------------------------

When we associate a set of behaviours (and properties, by extension, which
we'll stop calling out from now on) with values, we may imagine a table tagging
along with each value in the system -- where the table maps behaviour names to
special procedures. If we are to do this for, say, all the numbers in our
program, this starts to look like an awful waste of memory for what is
essentially repeated information. After all, we usually don't want to do
different things to 2, 3, 4, 42, etc. However, we may want to do one thing for
all integers, and another thing for all floating point numbers, and yet another
for fractions.

In essence, our ``as-string`` generic procedure therefore dispatches on
predicates of the form ``integer?``, ``float?`` or ``rational?``, rather than
specific values.

To put this differently, we have a table of such behaviours we wish integers to
satisfy and give special procedures for named behaviours in this table. Then we
merely need to identify this table by pointing to it when we have an integer
value ... or any other more complex and potentially compound data item.

In OOP languages, such a table of behaviour procedures is called a "class". Our
``invoke`` procedure then starts to look like this --

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

1. Perhaps we could call a default generic procedure that we can specialize for
   different types of values.

2. We can check another class's behaviour table for a procedure. If we take
   this route, we see that our value then automatically would get all the
   behaviours associated with this other class -- or it will "inherit" these
   behaviours. For this reason, such a class to which the "no such method" case
   is delegated to is called the "parent class" or "super class".
            
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

    (define (invoke value method-name . args)
        (apply c-invoke (append (list (get-class value) value method-name) args)))

How deep would this ``get-parent`` lookup go then?

Most object oriented languages solve this problem by having a "root" class,
perhaps named ``Object`` whose parent is itself.

.. admonition:: **Ponder this**
    
    We casually wrote function calls ``(get-class value)`` and ``(get-parent class)``.
    Won't these two functions also have to work across all values and return different
    classes for different values and different parents for different classes? .. thereby
    assuming the very mechanism we're trying to implement with ``invoke``? i.e. Aren't
    these ``(invoke value 'class)`` and ``(invoke class 'parent-class)``?


Objects, objects, everywhere
----------------------------

We can then ask -- "Can we treat all values in our language as objects?" ...
and the answer would be "yes!". Languages like Smalltalk, Ruby and Self take a
"everything is an object" perspective. This means all values have associated
"classes" and even a "class" is itself an object and also has a class. In the
case of Smalltalk, a class' class is called a "meta class" and meta classes
also form a hierarchy that parallels the class heirarchy.

Take a moment to think about this. We're comfortable representing some values
such as numbers directly in our programs because we have common character based
representations for them. Once they become values within the program, they gain
behaviours we can invoke by name. This has the same power as having a slew of
procedures we can invoke on these numbers and such values. However, the only
way to **do** anything in such a language is to invoke a method or an object!
If the invocation returned another object and you want to see it, you need to
invoke another method on **that** object. Obviously, this recursion has to stop
somewhere, and programming languages provide some built-in objects with
behaviour implementations that don't return any further values, and entire
programs are then constructed using these built-in values and the
class-mechanism of the language.

.. admonition:: **Terminology**

    When something in a programming language can be represented and manipulated
    as a value, we say it is "first class". True OOP languages like Smalltalk
    feature classes as first-class entities, whereas semi-OOP languages like
    C++ treat classes and values as separate worlds within the language.


The methods of a class
----------------------

Since we're looking at a class as an object as well, it is instructive to think
about what kinds of behaviours may be attributable to a class.

We already know one such -- the ``'parent-class`` property that all classes
must possess for the behaviour lookup mechanism to work in the language. 

We may also wish to be able to see a representation of all values in our system
and therefore might wish to define procedures that will, say, print them to a
terminal, or display them in some environment. A common generic way to handle
this is to permit a string representation of all values. Such a behaviour that
can be used to get such a string representation is often named ``'description``
in such languages.

.. code:: racket

    (invoke value 'description)
    ; Gets a "string" that is repurposable across multiple
    ; presentation modes.

We'd previously used a ``lookup-behaviour-proc``. This looks like a perfect
candidate for a property of a class, so to get a behaviour proc object
associated with a class by name, we'd do --

.. code:: racket

    (invoke class 'behaviour-named name)
    
At this point, you may begin to appreciate how the snake starts to eat its own
tail, since a "behaviour procedure" itself ought to be an object.

Since invocation is the only thing you can do in a strict OOP language, these
languages give built-in syntax to keep invocations short. Many C-based
languages such as Python and Javascript and C++ use the "dot notation" to
denote both properties and methods -- like ``value.property`` and
``value.method(arg1, arg2)``. 

Languages like Smalltalk make it even simpler by making method invocation
invisible in the text -- like ``value method`` or ``value methodKey1: val1
key2: val2 ...``.

Since "invoking a method on an object" can be split into "look up a
function-valued property of the object" and then "calling it, passing the
object as one of the arguments", we can generalize the mechanism for such
"lookup a property of a thing" so we can reuse it in different way. For that,
we introduce two functions -- ``getprop`` and ``setprop`` -- with the following
behaviours --

1. ``getprop`` when given a thing and a property name, produces a value.
2. ``setprop!`` stores a value against a property name associated with a thing,
   so that a subsequent call to ``getprop`` will retrieve that value.

.. code:: scheme

    (define (make-proplist)
        ; A "property list" is a list of triples of thing-property-value
        (define **proplist** (box '()))

        ; The default-value is returned if the thing or its property
        ; are not found.
        (define (getprop thing property default-value)
            (let loop [(tail (unbox **proplist**))]
                (if (null? tail)
                    default-value
                    (let [(triple (first tail))]
                        (if (and (eq? (first triple) thing)
                                 (equal? (second triple) property))
                            (third triple)
                            (loop (rest tail)))))))

        (define (setprop! thing property value)
            ; We're being a bit lazy here (in the human sense) and
            ; simply adding the new association at the head without
            ; checking whether it is already there and modifying that
            ; entry instead. The meanings of getprop and setprop!
            ; are preserved by this approach though lacking in
            ; efficiency. We will have to modify our approach to
            ; use a "mutable cons" if we are to change this strategy.
            (set-box! **proplist**
                      (cons (list thing property value)
                            (unbox **proplist**))))

        (values getprop setprop!))

    (define-values (getprop setprop!) (make-proplist))
                    
.. admonition:: **Question**

    When checking the "thing" position in the property list, we used ``eq?``
    but for the property position, we used ``equal?``. What are the
    consequences of using one versus the other for these fields?

These ``getprop`` and ``setprop!`` are intended for use in our interpreter for
us to understand the ideas behind various types of dispatch. So we can now
express the basic notion of ``invoke`` like this --

.. code:: scheme

    (define (invoke thing method-name . args)
        (let [(method (getprop thing method-name #f))]
            (if method
                (apply method (cons thing args))
                (error "Unresolved method"))))


Classes versus types
--------------------

Object oriented languages also tend to refer to such "classes" as "types". This
comes from an identification of "what kind of thing is this thing?" with "what
set of behaviours does this thing permit?". For problems that lend themselves
to modelling as objects (example graphical user interfaces), this is a
reasonable identification. In other cases, this may not be reasonable and we'll
see some examples later. 

.. admonition:: **Terminology**

    This "identification" of "the kind of a thing" with "set of a thing's
    behaviours" is also known as **Duck Typing**. It comes from "if it looks
    like a duck and quacks like a duck, it is a duck." Strongly OOP languages
    such as Ruby, Smalltalk and Javascript embrace and exploit this idea.

Since method invocation is the only action available in such systems, if you
know the set of behaviours supported by a particular value, you know all there
is to know about what kind of a thing it is, within this programming context. 

With a "class system", our notion of invoke changes to this --

.. code:: scheme

    (define (invoke thing method-name . args)
        (let [(tclass (getprop thing 'class #f))]
            (if tclass
                (c-invoke tclass thing method-name args)
                (error "Unknown class for thing"))))

    (define (c-invoke tclass thing method-name args)
        (let [(method (getprop tclass method-name #f))]
            (if method
                ; [REF1] Calling method on thing
                (apply method (cons tclass (cons thing args)))
                (let [(parent (getprop tclass 'parent #f))]
                    (if parent
                        (c-invoke parent thing method-name args)
                        (error "No such method"))))))

The way we call the method in this case at "[REF1]" in the code is slightly
different from the non-class approach where the only additional argument
it received was the thing itself. In this case, we're also passing the class
as well to the method. This is to meet a common need in such systems to extend
methods by calling on a "super class"'s behaviour under some conditions. So,
a method may decide that the parent class of the given ``tclass`` may know
better and delegate the task to it. So without knowing ``tclass`` (the
class of ``thing``), it cannot make that call.

When using such ``getprop`` and ``setprop!``, the step of creating a value also
means associating the value with its class at creation time using ``setprop!``
so that method invocations can happen.

.. admonition:: **Reflect**

    We need to ``(setprop! val 'class class-of-val)`` even for simple values
    like integers. So obviously this approach is not very efficient if we have
    to do that. However, we can specialize ``getprop`` and ``setprop!``
    themselves to make this more efficient and so we don't store one entry for
    2, one for 3, another for 42, and so on, if we are guaranteed that property
    and method lookups are common for all the numbers. 

Message passing "paradigm"
--------------------------

Consider our polymorphic invocation ``(invoke value 'as-string)``. If we
abstract out the value from this expression, we get ``(lambda (x) (invoke x
'as-string))``. The concept embodied by this lambda can also be thought of
as "sending the message ``'as-string`` to ``x``". Note that in this case
we also expect a result to be returned from that invocation.

If we relax the requirement that a result must be returned, this lambda then
becomes a pure "send-message" procedure. Something happens with the object
that's a consequence of the message having been sent, but no value is provided
as a response. Since this is also, conceptually, "message passing", we can see
how method invocation is one implementation of the notion of message passing.
Even in languages where method invocation is the implementation, "message
passing" serves as a mental model and Smalltalk, for example, provides the
ability to abstractly represent, store and send entire messages independent of
objects. This is not quite true of languages like C++, although you can bend
the language to this mode through some gymnastics.

.. note:: Method invocation is one implementation of the notion of message passing.

Asynchronous message passing is yet another implementation of the idea, where
the object to which the message is being sent may not act on the message by the
time the message sending completes. Now, are there languages where this
approach is applied? Indeed, the Erlang (and its syntactic variant "Elixir")
language has the notion of "process" which behaves like our objects, which can
receive and respond to messages asynchronously. Processes in Erlang are very
lightweight -- you can create hundreds of thousands or even millions of
processes on modern computers without overwhelming the system -- and in some
sense are more hard core objects than other languages. Is Erlang an esoteric
language that nobody uses? I'll leave you with the thought that when you send a
message though Whatsapp, it is forwarded to your recipient by an Erlang
program. Yup Whatsapp was for a long time just one big machine running a highly
concurrent Erlang program to handle all the message sending.


Multiple argument dispatch
--------------------------

There are domains where the previously discussed "single argument dispatch"
or "OOP" way of thinking does not quite map naturally. Mathematics is one such.
We'll look at some characteristics of mathematical domains that makes it hard
to use OOP ideas and what we coudl replace it with.

Consider the notion of "addition" of two things. If the two happened to be real
numbers, then we we need to use the ``real+`` procedure to add them. If they're
both complex numbers, say, then we should use ``complex+`` to add them. What if
we have one real number and one complex number? In this case, we know that we
should "promote" the real number to a complex number and then use ``complex+``.
This is because real numbers are a sub-space of complex numbers -- i.e. a complex
number consists of two real numbers, along with some special rules of arithmetic.

Let's explore this situation a bit more -

If I have a value bound to an identifier ``x``, I can check if it is a real
number or a complex number using the corresponding predicate like ``(real? x)``
and ``(complex? x)``. In the mathematical sense, since a real number is also a
complex number, ``complex?`` may answer ``true`` even if ``x`` was originally
created as a pure real number in computer memory. Now let's consider the notion
of a "vector" -- which is an ordered collection of numbers. We might expect to
be able to test whether an ``x`` is a vector using ``(vector? x)`` (we're still
talking about the mathematical domain). However, our concept space has
surreptitiously multiplied. We now have to deal with the notions of
``real-vector?`` and ``complex-vector?``. If we then think of adding symbolic
arithmetic capabilities to our system, then an ``x`` may be bound to a symbol
value, which we may then test using ``(symbol? x)``. However, again, our
concept space has surreptitiously multiplied yet again to -- 

.. list-table:: Type combinations
   :header-rows: 1

   * - Types as predicates
     - Description
   * - ``real?``
     - A real number value
   * - ``complex?``
     - A complex number value
   * - ``real-symbol?``
     - A symbol whose value is expected to be a real number
   * - ``complex-symbol?``
     - A symbol whose value is expected to be a complex number
   * - ``real-vector?``
     - A vector of real numbers
   * - ``complex-vector?``
     - A vector of complex numbers
   * - ``real-vector-symbol?``
     - A symbol standing for a vector of real numbers
   * - ``complex-vector-symbol?``
     - A symbol standing for a vector of complex numbers
   * - ``real-symbol-vector?``
     - A vector of symbols that stand for real numbers
   * - ``complex-symbol-vector?``
     - A vector of symbols that stand for complex numbers

In the above table, we haven't considered the possibilities with vectors where
you may have, say, a mixture of real and complex numbers.

Note that the way the concepts multiply is dependent on the domain and there is
no generic rule that applies to all cases. Here, we make use of
:math:`\mathbb{R} \in \mathbb{C}` and that a symbol can stand for any concrete
thing such as a real number, or a complex number or a vector of reals, and a
vector may be a collection of things, including symbols that stand for complex
numbers. Also, there are operations on integers that may not be applicable to
reals, like reversing digits in some base.

Now when adding two things, we need to consider the :math:`n \times n` possibile
combinations of operations to decide what to do in each case. In this domain therefore,
when we introduce a new concept, it helps to introduce it in its most general form
rather than a specific case. For example, the notion of a vector can be introduced
as a "tensor" which would come with a specific rank and we can then deal with vectors
as "rank 1 tensors". 

Now, this isn't quite unique to Mathematics. We see it with data structures too.
For example, once we go beyond the basic "primitive" types like ``integer?``,
``real?``, ``complex?``, ``char?`` and ``string?``. When we consider, say, lists,
we need to ask "list of what?". So we now have ``real-list?``, ``complex-list?``,
``char-list?`` and ``string-list?`` to start with, but in truth this compounds
even more, like "list of lists of complex numbers" and so on. As with vectors
above, we haven't even considered the case of lists of mixed type entities.

Parametric types
----------------

Clearly we need a systematic way to tame this complexity blow up we saw in the
previous section. To start with, we'll at least need a notation to express
these types. As a first step, we can actually "lift" our type predicates over
the types of their contained values. For example, the type ``complex-vector?``
can be written as ``(vector? complex?)``, with the result of the expression
being the predicate that is equivalent to ``complex-vector?`` predicate.
Similarly, "a symbol that refers to a real number" would be ``(symbol? real?)``
and "a vector of symbols that refer to real numbers" can be expressed as
``(vector? (symbol? real?))``. So these concepts are compositional in nature.
This would perhaps work for collection types like lists too, with ``(list?
string?)``, ``(list? real?)``, ``(list? (list? string?))`` and so on.

With this approach, our types table now reads --

.. list-table:: Type combinations
   :header-rows: 1

   * - Types as predicates
     - Description
   * - ``real?``
     - A real number value
   * - ``complex?``
     - A complex number value
   * - ``(symbol? real?)``
     - A symbol whose value is expected to be a real number
   * - ``(symbol? complex?)``
     - A symbol whose value is expected to be a complex number
   * - ``(vector? real?)``
     - A vector of real numbers
   * - ``(vector? complex?)``
     - A vector of complex numbers
   * - ``(symbol? (vector? real?))``
     - A symbol standing for a vector of real numbers
   * - ``(symbol? (vector? complex?))``
     - A symbol standing for a vector of complex numbers
   * - ``(vector? (symbol? real?))``
     - A vector of symbols that stand for real numbers
   * - ``(vector? (symbol? complex?))``
     - A vector of symbols that stand for complex numbers

Note that from a domain perspective, not all of these may make sense. For
example, what would a ``(symbol? (symbol? real?))`` mean mathematically? Again,
in some mathematical contexts it might, but if you're doing ordinary algebra,
this concept would be out of place.

Such a ``list?`` predicate can be implemented perhaps as shown below --

.. code:: racket

    (define (list? argtype?)
        (lambda (arg)
            (if (cons? arg)
                (let loop [(ls arg)]
                    (if (empty? ls)
                        #t ; An empty list belongs to all list types.
                        (if (argtype? (first ls))
                            ; Every element of the list must satisfy the argtype? predicate.
                            (loop (rest ls))
                            #f)))
                #f)))

.. admonition:: **Exercise**

    How would you implement a ``symbol?`` type predicate as used above.

If we now consider an operation like addition and what it must do when given
two symbols to add, we expect it to produce an expression with two symbols
connected by a ``+`` operation -- like perhaps ``(+ x y)``. One way we can
simplify our calculation system is to say "we don't care what the symbols ``x``
and ``y`` are supposed to refer to, but this is how their sum is expressed.
Now, this may work in some contexts and not in others. For example, if you know
all symbols are going to be referring to scalars, this would be ok, but if
``x`` may be a symbol referring to a vector of reals and ``y`` a real number,
the result of their sum is something that needs explicit specification in the
mathematical context as there is no singular natural extension.

Here are some ways programming languages deal with these possibilities --

Untyped collections
    Languages like Scheme, Python, Javascript and Smalltalk take the route
    where a collection type such as a ``list?`` or ``vector?`` doesn't care
    what types of values it stores. It may be a mix of different types as well.
    It is up to the programmer to be cognizant of the domain and place appropriately
    typed values into these collections to be manipulated by their programs.
    In such languages, constraints on such data types are checked using
    **contracts** at procedure or module boundaries.

Uniformly typed collections
    Languages such as Haskell in which a type must be assignable to every
    identifier, it is not possible to have an idea such as "list of
    reals and strings" without having it be expressible as type in its
    system. For this reason, Haskell enforces that collection types such
    as lists and arrays must have uniform types -- i.e. we can have a list of
    all reals, a list of all complex numbers, but a list of reals and complex
    numbers needs a new type "real or complex" to be created before it can be
    expressed. 

    In the case of lists, it is easy to see how this uniformity leads to
    manageable complexity of operations such as "concatenation", where
    two lists can be concatenated only if they have the same value types,
    and produce another list of the same value type as well. 

Automatic type promotion
    This is rarely used except perhaps in a context where a programming language
    that was originally "dynamically typed" gains type declaration features
    that can be used partially -- referred to as "gradual typing".

    In such languages, concatenating a list of strings with a list of reals may 
    yield a computed type like "list of (union of real and string)".

The above illustrate the design space available when considering operations
that may be specialized over multiple types, but these approaches are also
relevant when considering single-argument dispatch as well.

Dispatching with tagged values
------------------------------

When we considered the design of procedure dispatch over a single argument
value, we considered a set of predicates that we test against the value to
determine which course of action to take. This was our starting point. Now, we
further restricted ourselves to think that we'll consider the set of predicates
to be mutually exclusive or "disjoint" -- meaning we're guaranteed that a value
will satisfy exactly one of the predicates in our set.

If that is the case, what if we kept a piece of extra information along with
each value that indicated which of these set of predicates it satisfies?
Arguably, this can be a tiny piece of information that doesn't add much in
terms of storage, provided our set of predicates does not have a large size.

With this approach, the dispatch branches become tests for equality with 
a value's tags. Even better, if each tag is associated with a set of procedures
by name, the lookup can be in near-constant time (complexity wise) as well".
Such tags reify what we called "classes" earlier when discussing OOP, but
are more closely related to the notion of "types".

If we now generalize the notion of attaching a tag to attaching a list of tags
(or perhaps a set of tags) to a value, then the behaviours that we can get from
that value become additively expandable. In the single argument dispatch
universe of design, this is referred to as "multiple inheritance".

Multiple inheritance
~~~~~~~~~~~~~~~~~~~~

"Multiple inheritance" refers to a value (or a new type) inheriting the
functionality of a number of other types by declaring them as "parents".
Multiple inheritance can lead to certain kinds of problems. For example, if two
of the "inherited" types prescribe different behaviours for the same
method/message, it is unclear which behaviour the type or value must inherit.

Programming languages try to "solve" this problem through some predictable
mechanism that, despite the ambiguity continuing to exist in principle, makes
it easy to determine which behaviour manifests by inspecting the code. For
example, C++ solves it by mandating that the declaration order of the classes
featuring in the inheritance list determines the priority for selection of a
method implementation -- i.e. if A and B are both parent classes declared in
that order and both specify implementations for method M, then if the
declaration order is ``A, B``, then A's implementation takes precedence over
B's and if the order is ``B, A``, then B's implementation takes precedence over
A's. 

While such a resolution mechanism appears to address the issue, it is still not
clear from the program design perspective what actually should happen in some
cases. For example, if ``A`` is a class that ``B`` and ``C`` inherit from and
both override behaviour of method ``M``, and subsequently ``D`` inherits from
both ``B, C``, both the behaviours of ``B`` and ``C`` for method ``M`` seem
appropriate as the implementation for ``D``. So which one to choose? Again,
even if this is resolved by the "declaration sequence = priority" approach, the
burden has merely shifted to the programmer to decide which of the two orders
to choose. Due to the nature of the inheritance pattern, this is referred to
as "the diamond problem" in OOP literature.

.. figure:: images/diamond.png
   :align: center
   :alt: The "diamond problem" of class inheritance.

   When two "base classes" a.k.a. "parent classes" of a class themselves
   share the same base class, we have a "diamond problem" at hand.


.. d2::
   :caption: Testing d2
   :format: svg
   :width: 50%

   direction: up
   A <- B <- D
   A <- C <- D


Traits: classes as types
~~~~~~~~~~~~~~~~~~~~~~~~

One approach to program design that truly resolves the multiple inheritance
problem described in the previous subsection treats classes as equivalent to
types only if a class consists exclusively of specifications of abstract 
methods that its child-class must implement in order to be made concrete.
Such an abstract class cannot be tagged to a value since a value doesn't provide
method implementations, and is therefore often called an "abstract class" or
an sometimes (like in Julia) an "abstract type". Furthermore, the inheritance
mechanism is only used to specify the set of methods available in a "concrete class"
and no further inheritance is permitted in the design. 

Interestingly enough, though this looks like a severe restriction, it is not
really a restriction and in practice and leads to a well organized code base.
The "abstract base class" serves as the "interface" and the "concrete class"
serves as an "implementation" of the interface. There can be many
implementations of an interface and to use an object, the programmer only needs
to know the specification of the interface and its methods and little to
nothing about the implementation details. This interface-implementation is
made explicit in the Java language where an "interface" cannot syntactically
declare any concrete method behaviours whereas a "class" can "implement" an
interface and declare implementations. In Objective-C/C++ (used in iOS programming)
the concept of an interface is referred to as a "protocol" since the language
takes the "method invocation is a form of message passing" view.

For example, a "Serializable" interface may declare the following methods (shown
in the syntaxes of a few different programming languages) [^ --


.. code:: Java

    // Java
    interface Serializable {
        bytes serialize();
        // Here Stream would also be an interface spec.
        void serializeToStream(Stream s);
    }

.. code:: cpp

    // C++
    class Serializable {
        virtual unsigned char * serialize() = 0;
        // Here Stream would also be an interface class.
        virtual void serializeToStream(Stream *s) = 0;
    }

.. code:: objc

    /* Objective-C/C++ */
    @protocol Serializable
    - (NSData*)serialize;
    /* Here Stream is a protocol that the passed object is expected to meet. */
    - (void)serializeToStream: (id<Stream>)s;
    @end

  .. code:: rust

    trait Stream {
        ...le by
    }

    trait Serializable {
        type CT;
        fn serialize(&self) -> Vec<uint8>;
        fn serializeToStream(&self, Stream:&Self::CT);
    }

In languages like Rust which are not OOP in the traditional sense but have a notion of
a protocol or interface, this idea of an "abstract base class" is known as a "type trait" 
or simply "trait". A trait, therefore, is a specification of all the methods that a concrete
type that declares itself to implement the trait must provide implementations for to qualify
as an implementation of the trait.

Such "abstract base classes" or "type traits" may themselves declare as inheriting from 
other traits. However, since they're all declarations and there can be only one concrete
implementation for the collection of methods indicated through such an inheritance mechanism,
there is no "diamond problem" any more. But yet again, if this structure turns up in a model
of a domain, the responsibility for deciding what must happen when a particular method is invoked
continues to fall on the programmer of that final implementation.

Computable types
----------------

When we think of tagged values, the question arises whether such tags should themselves
be computable by procedures within the language. Most programming languages maintain a 
distinction between a "type" and a "value" within the language and "types" cannot be passed
as arguments to functions and be returned as values.

Some languages deviate from that. Traditional "message passing" OOP languages
like SmallTalk and Ruby feature "classes" that are themselves objects that can
be manipulated in programs. This is also true of OOP-ish languages like
Javascript and python as well. This is not usually done in ahead-of-time compiled
languages such as C++ and Rust though. And yet, some AoT compiled languages
also provide some notion of computable types.

For example, in Zig_, types are values that must be known at compile time.
Though there is a distinction between code that is run during compile time and
runtime, you can use ordinary functions to compute types at compile time. 

.. _Zig: https://ziglang.org

The Julia_ language places dispatch based on types of multiple/all function
arguments a central feature of the language to enable the kinds of polymorphism
needed for mathematical applications. In Julia_, types are actually normal
runtime values too and functions can take types as arguments and return types
as values. For the kinds of domains Julia works well for, this is a very
practical choice, especially with the notion of `generated functions`_ where a
function is called to generate its own body of code depending only on the types
of its arguments. Such a function, when called with actual arguments, will call
the generation code to compute the body and then compile that body and run it.
Having cached the generated body, it no longer needs to recompute the body if
the function is passed arguments of the same types again later. This way, a
function can be written to eliminate code that typically dispatches based on
argument types.

Julia_ is not an "ahead-of-time" compiled language though and is perhaps better
described as "just-ahead-of-time compiled" language since compilation of a
function is not incremental, but is done without fail before calling it. In
contrast, in "just-in-time compiled" languages such as Java and Smalltalk, a
function or procedure may end up being compiled only if it invoked sufficiently
often. Otherwise, it gets interpreted either directly, or via an intermediate
byte-code interpreter. Single pass compilation to an intermediate byte code
representation is usually much faster than compilation to machine code and is
therefore viable in such a scenario.

.. _Julia: https://julialang.org/
.. _generated functions: https://docs.julialang.org/en/v1/manual/metaprogramming/#Generated-functions

The case with Julia
-------------------

Julia supports 
