Objects - the Self way
======================

The :doc:`previous section on objects<objects>` treated objects by building up
an object system by representing an object using a closure that dispatches on
its first argument. While this is instructive, object systems are never done
this way in practice for various reasons.

In particular, languages such as Self, Smalltalk, Javascript take on a
philosophy of "**everything** is an object" and "anything that happens, does so
by means of **passing a message to an object**". In this section, we'll see
what it takes to have an object system like Javascript and Self -- called
a "prototype based object system".

Prototypes versus classes
-------------------------

The notion of "class" is common in many "object oriented" programming languages
such as C++, Java and Smalltalk. [#ak]_ In these languages, "classes" play the role
of "object factories" - they make families of objects with similar kinds of properties
and behaviour. In these langauges, a "class" can therefore be thought of as a "type"
of an object.

.. [#ak] Alan Kay, the famous computer scientist behind the creation of the Smalltalk
   programming language, once said "I invented the term 'object oriented programming'
   and I did not have C++ in mind".

One issue with such "classes and inheritance" based OOP languages is that an
over-reliance on inheritance leads to an inflexible tangle of code as a system
evolves into a large program. Though some design methods exist to help deal
with this, the problem is particularly acute when we do not know the domain
we're modeling in adequate detail when we start out and we need to figure
things out along the way. For this reason, the language Self (itself based on
Smalltalk's ideas) eschewed classes in favour of more flexible "prototypes". An
object in Self can "borrow" properties from a designated prototype and can
delegate some message handling to its prototype. This is the model adopted
(more or less) in Javascript. In such "prototype based" object systems,
[#cbos]_ an object behaves the "same" as its prototype in some regards and
"overrides" some properties nad behaviours depending on its unique
characteristics. Furthermore, one object can serve as a prototype for many
other objects. Since "objects" are runtime entities, [#ctclasses]_ this
relationship between an object and its prototype is a dynamic relationship.

This is what we'll model using plain :rkt:`#lang racket` in this chapter.

.. [#cbos] ... as opposed to "class based object systems".

.. [#ctclasses] ... whereas classes can be compile-time entities.


What are objects in Javascript?
-------------------------------

Javascript provides the following functionalities for its objects, which we'll
try to replicate in Racket.


Getting a property of an object
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code:: javascript

    object.property_name

Given a property identified by a name, you can get the property of an object
using the above "dot syntax" in Javascript. If an object itself does not have
such a property, the runtime will search up the "prototype chain" of the object
until it gets a value or else it produces an ``undefined`` value.

Modifying a property of an object
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code:: javascript

    object.property_name = new_value;

In the above syntax, a new value is assigned as the property of the object,
against the specified property name. It is important to note that post such an
assignment, if object itself gains such a property if it didn't have it
earlier, even if its prototype did have a value for this property.

Invoke a method
~~~~~~~~~~~~~~~

.. code:: javascript

    result = object.method_name(arg1, arg2, ...)

In Javascript, as with most languages with object systems (except Erlang), the
idea of "message passing" is treated as  "method lookup and invocation", which
means **synchronous** function call. In the general case though, "message
passing" could be asynchronous, which means a reply may or may not be
delivered, instantaneously or later on.

The ``object.method_name`` part in the above Javascript syntax denotes
retrieving an method **function** ``method`` from the prototype chain. This
function is then called as though it were ``method(object, arg1, arg2, ...)``. [#call]_

.. [#call] In Javascript, this is done using ``method.call(object, arg1, arg2, ...)``
   if the programmers wants to invoke a method function, and the "object" argument
   is made available implicitly within the body bound to the identifier ``this``.

.. admonition:: **Constraint:** 

    Once we have our object system's core, we'll place the constraint that
    **anything** we do **must** happen via a message send to an object.


The basic structure of objects
------------------------------

Taking the cue from the previous section, we conceive an object as having a set
of properties and a reference to a "prototype". We'll model the "set of properties"
as a simple list of name-value associations. An important thing to note is that
objects are all about state management and so we'll need all of these to be mutable.

.. code:: scheme

    #lang typed/racket

    (struct Prop (name value attributes) #:mutable)
    (struct Obj (properties prototype) #:mutable)

    (define (lookup name props)
        (if (empty? props)
            #f
            (if (equal? (Prop-name (first props)) name)
                (first props)
                (lookup name (rest props)))))


In the above scheme, :rkt:`Prop` is a triple consisting of a :rkt:`name` symbol,
a :rkt:`value` associated with that symbol and a list of attributes which are
themselves :rkt:`Prop` structures.

Also :rkt:`Obj` is a tuple of :rkt:`properties` which is a list of :rkt:`Prop`
and :rkt:`prototype` which is itself an :rkt:`Obj`.

Now, we need to model the three basic operations on objects provided
by Javascript. Let's do them one by one. First up is :rkt:`get`, which is
expected to retrieve the value associated with a given property name, and if
the object itself does not have such a property, look it up in the prototype
chain.

.. code:: scheme

    (define (get obj propname)
        (let ([p (lookup name (Obj-properties obj))])
            (if p
                (Prop-value p)
                (get (Obj-prototype obj) propname))))


Next up is :rkt:`set` which should associate the given property name with
the given value for **the given object**. Note that it can't use :rkt:`get`
above for the lookup since it might then end up modifying a prototype's
property, which we won't want to.

.. admonition:: **Think now**: 

    So what if the prototype's property gets modified?

.. code:: scheme

    (define (set obj propname val)
        (let ([p (lookup name (Obj-properties obj))])
            (if p
                (set-Prop-value! p val)
                (set-Obj-properties! obj
                                     (cons (Prop propname val empty)
                                           (Obj-properties obj))))
            obj))

The last major piece is the "message passing". We'll call this "send" and denote
it using the :rkt:`!` symbol for brevity ... and also to suggest that all message sends
could potentially change state.

.. code:: scheme

    (define (! obj selector . args)
        (let ([methodfn (get obj selector)])
            (apply methodfn (cons obj args))))

It is kind of amazing that we've covered nearly all of the object mechanism in Javascript
at the foundation level now! What remains (and that's not trivial still) is to build
the object system around these primitives. We'll need to establish many conventions along
the way to make that happen and also "bootstrap" the object hierarchy.

.. code:: scheme

    (define (make proto)
        (Obj empty proto))

    (define (new maker . args)
        (let ([obj (make maker)])
            (apply ! (cons obj (cons 'init args)))))

The above :rkt:`new` procedure mimics what happens in the Javascript "new" operator
which is used like ``new Something(arg1, arg2, ...)`` to manufacture new objects
from the given "constructor function" named ``Something``. In essence, what it does
is two steps -

1. Allocates space for the object, initializing its prototype chain.

2. Calls its :rkt:`init` method with the given args. 

Our implementation of :rkt:`new` models both these steps explicitly -- with the allocation
step handled by :rkt:`make` and the initialization step by the :rkt:`'init` message send.

Creating the object system
--------------------------

With the foundations in place, we now need actual objects to use as prototypes
when making new objects. We also need to live by our maxim that everything we do
must be done by message passing after we've created the basic object system.

To start with, we need to answer the question of what exists at the end of all
prototype chains. Given an object, when you pick out its prototype and then its
prototype and so on, where does that process end? In Javascript, that ends with the
``Object`` object. 

.. note:: Yeah. Terminology  in object oriented systems gets rather confusing
   to keep in head correctly. Objects may have classes and these classes may
   themselves be objects, and so on. We'll spare ourselves that confusion for
   the moment as we work through this.

.. code:: scheme

    (define Object
        (let ([O (make #f)])
            (set-Obj-prototype! O O)
            (set O 'proto (λ (self)
                              (Obj-prototype self)))
            (set O 'init (λ (self . args)
                            self))
            (set O 'display (λ (self)
                                (display "Object")))
            O))

What we've done here is a "bootstrapping" step. We've made an object bound to
:rkt:`Object` whose prototype is itself. We can now make all objects using
:rkt:`Object` as their prototypes. Note that we've endowed all objects with the
ability to retrieve their "prototype" objects for reference anywhere we need it,
and we can now do that within our object system using a message send.

.. note:: While we've so far stuck to the Javascript object model of a
   prototype based object system, we deviate from that in the sections below in
   the interest of keeping our system minimal, and to also illustrate
   approaches used in other object systems such as Smalltalk which take the
   constraints of "everything is an object" and "everything happens via message
   passing" far more seriously than Javascript does. Javascript, in this sense,
   is closer to Scheme than it is to something like Self.

Let's start with a simple one for the primitive entities we'll need in our
object system - numbers, strings, booleans and code blocks.

.. code:: scheme

    (define Num
        (let ([N (new Object)])
            (set N 'init (λ (self val)
                            (set self '_value val)
                            self))
            (set N 'display (λ (self)
                                (display (get self '_value))
                                self))
            (set N '+ (λ (self n)
                        (new Num (+ (get self '_value)
                                    (get n '_value)))))
            (set N '* (λ (self n)
                        (new Num (* (get self '_value)
                                    (get n '_value)))))
            (set N '- (λ (self n)
                        (new Num (- (get self '_value)
                                    (get n '_value)))))
            (set N '/ (λ (self n)
                        (new Num (/ (get self '_value)
                                    (get n '_value)))))
            (set N 'sqrt (λ (self)
                            (new Num (sqrt (get self '_value)))))
            (set N 'square (λ (self)
                                (let ([x (get self '_value)])
                                    (new Num (* x x)))))
            N))

In the above definition of :rkt:`Num`, which uses the :rkt:`Object`
as its prototype, we use a convention that the :rkt:`_value` property
stores a native Racket numeric value rather than an object -- using the
:rkt:`_` prefix to remind us of that. In general though, we want to stay
within the object system, but we can do that only once we have the common
primitive types we need for ordinary programming.

Next up is booleans. It might look like we need to make an object named
:rkt:`Bool` or something which has some properties. However, that isn't
of much use since we need to consider what we need to be able to do with
booleans -- i.e. implement conditionals. So similar to how we modeled
booleans in lambda calculus as selector functions, we can define two new
prototypes for :rkt:`True` and :rkt:`False` that will serve as the boolean
values in our system.

.. code:: scheme

    (define True
        (let ([T (new Object)])
            (set T 'and (λ (self b) b))
            (set T 'or (λ (self b) True))
            (set T 'not (λ (self) False))
            (set T 'display (λ (self) (display "True") self))
            T))

    (define False
        (let ([F (new Object)])
            (set F 'and (λ (self b) False))
            (set F 'or (λ (self b) b))
            (set F 'not (λ (self) True))
            (set F 'display (λ (self) (display "False") self))
            F))

We also need a way to encapsulate blocks of code as objects. We have a choice
at hand -- we can either express such a block of code as a data structure that
is wrapped as an object, or we can fall back on an ordinary Racket function
wrapped as an object. Since you already know how to design such a "code as data
structure" and implement such an interpreter for it, we'll take the latter
simpler route. So what can we do with a block? We can "execute" it. By that, we
mean we'll take the Racket function stored as the "block"'s value and call it
with some arguments. Under normal circumstances, an ordinary Racket function
will do, but in this case, we'll need the ability to do premature returns from
our code blocks, because we may have blocks within blocks and the return path
could be non-linear. To meet that, we need to pass an explicit :rkt:`return`
argument to the function when invoking it so that such premature returns can be
done. We know how to construct such a :rkt:`return` argument -- we use
:rkt:`call/cc`.


.. code:: scheme

    (define Block
        (let ([B (new Object)])
            (set B 'init (λ (self fn)
                            (set self '_value fn)
                            self))
            (set B 'display (λ (self) (display "Block") self))
            (set B 'exec (λ (self . args)
                            (call/cc (λ (return)
                                        (apply (get self '_value) 
                                               (cons return args))))))
            B))

Conditional execution
---------------------

All that is fine, but how do we do things like :rkt:`if` or equivalently
:rkt:`cond` within our object system without again resorting to Racket
Blocks give us immense flexibilty there and we can maybe think of putting
:rkt:`if` expressions within these blocks, but that would be cheating.
We'd be relying too much on Racket's facilities and not really making our
point that we can do everything we need to within our object system.

Indeed, this is possible with the way we've define :rkt:`Block` and our
booleans. We need to add new methods to them.

To execute a block conditional on a boolean value, we'll send an :rkt:`if-true`
message to the boolean object passing a block as argument. If the message is
sent to :rkt:`True`, the block should be evaluated, but if it is sent to
:rkt:`False`, ir shouldn't be.

.. code:: scheme

    (set True 'if-true
        (λ (self block)
            (! block 'exec)))

    (set True 'if-false
        (λ (self block) self))

    (set True 'ifelse
        (λ (self trueblock falseblock)
            (! trueblock 'exec)))

    (set False 'if-true
        (λ (self block) self))

    (set False 'if-false
        (λ (self block)
            (! block 'exec)))

    (set False 'ifelse
        (λ (self trueblock falseblock)
            (! falseblock 'exec)))

So now, if we have a boolean value (i.e. :rkt:`True` or :rkt:`False`) bound to an
identifier :rkt:`c` and we wish to execute a block :rkt:`blk` depending on whether
the boolean is true, all we need to do is :rkt:`(! b 'if-true blk)`.

Loops
-----

Now that we have blocks that know how to execute themselves and produce object 
results, we can use this framework to implement a while loop like this --

.. code:: scheme

    (! condblock 'while-true bodyblock)

... in which we expect the :rkt:`condblock` to be evaluated repeatedly and
as long as it is true, we'll continue to execute :rkt:`bodyblock`. This is
simple to implement as a feature of the :rkt:`Block` object.

.. code:: scheme

    (set Block 'while-true
        (λ (self body)
            (let ([c (! self 'exec)])
                (! c 'if-true (new Block
                                (λ (return)
                                    (! body 'exec)
                                    (! self 'while-true body)))))))

Granted, this is pretty inefficient, creating a new :rkt:`Block` object
for every loop iteration, but we put up with that to stay true to our
commitment of doing everything with objects and message passing.

.. code:: scheme

    (set Num '< (λ (self n)
                    (if (< (get self '_value) (get n '_value))
                        True
                        False)))

    (set Num '= (λ (self n)
                    (if (equal? (get self '_value) (get n '_value))
                        True
                        False)))

    (set Num '<= (λ (self n) (! (! self '< n) 'or (! self '= n))))
    (set Num '>= (λ (self n) (! (! self '< n) 'not)))
    (set Num 'succ (λ (self)
                        (new Num (+ (get self '_value) 1))))
    (set Num 'pred (λ (self)
                        (new Num (- (get self '_value) 1))))

    (set Num 'times-do
        (λ (self block)
            (! (! self '> (new Num 0))
               'if-true
               (new Block (λ (return)
                            (! block 'exec)
                            (! (! self 'pred) 'times-do block))))))

You can now see how the whole system can start working together
and how to create the other "primitive" object types we'll need
for regular programming such as strings.

.. code:: scheme

    (define String
        (let ([S (new Object)])
            (set S 'init (λ (self str)
                            (set self '_value str)
                            self))
            (set S 'display (λ (self)
                                (display (get self '_value))))
            (set S 'concat (λ (self str)
                                (new String (string-append (get self '_value)
                                                           (get str '_value)))))

            ; Add your own methods too.
            S))

Let's now define an aggregate object called :rkt:`Point` that holds two
numbers -- the x/y coordinates of the point -- as an illustration./

.. code:: scheme

    (define Point
        (let ([P (new Object)])
            (set P 'init (λ (self x y)
                            (set self 'x x)
                            (set self 'y y)
                            self))
            (set P 'dist (λ (self p)
                            (! (! (! (! (get self 'x) '- (get p 'x)) 'square)
                                  '+ 
                                  (! (! (get self 'y) '- (get p 'y)) 'square))
                                'sqrt)))
            P))

Note that the :rkt:`x` and :rkt:`y` properties are expected to hold **objects**
and not Racket primitive numbers. We can finally live within our object system!
We'll now extend the functionality provided by :rkt:`Point` to make a mathematical
"vector" that knows how to calculate its own length.

.. code:: scheme

    (define Vec
        (let ([V (make Point)])
            (set V 'length
                (λ (self)
                    (! (! (! (get self 'x) 'square)
                          '+
                          (! (get self 'y) 'square))
                       'sqrt)))
            V))

Now we can do :rkt:`(! (! (new Vec (new Num 3.0) (new Num 4.0)) 'length) 'display)` to get
:rkt:`5.0` printed out. We could've also defined the :rkt:`Vec` like this --

.. code:: scheme
    
    (define Vec
        (let ([V (make Point)])
            (set V 'length
                (λ (self)
                    (! self 'dist (new Vec (new Num 0.0) (new Num 0.0)))))
            V))

Observations
------------

1. Note that we've augmented the various core classes with new functionality
   **after** we created them. This means any object created that uses one of
   these objects as its prototype will automatically "inherit" the newly added
   functionality. Not all object systems permit this kind of extension, but
   all prototype-based object systems do.

2. Taking the example of the :rkt:`'times-do` method, we see that we could've
   also defined that as a method on a :rkt:`Block` object like shown below --

    .. code:: scheme

        (set Block 'times-do
            (λ (self num)
                (! (! num '> (new Num 0))
                   'if-true
                   (new Block (λ (return)
                                 (! self 'exec)
                                 (! self 'times-do (! num 'pred)))))))

    How do we decide which of the two approaches to take, from a designer's
    perspective?

    This is one of the issues that plagues **all** "object oriented" systems.
    Since we can only choose a method based on one selector, we're **forced**
    to make a choice about which object to place the method implementation for
    that selector in, even if there is no such clear choice suggested by the
    domain. In this sense, object systems create some artificial asymmetries in
    theory. However, in practice, it turns out you can do a lot even given this
    ambiguity and as long as the methods are documented well, programmers don't
    have much trouble using the object system.

    In the case of :rkt:`times-do` however, the language suggests a message
    structure like :rkt:`(! (new Num 3) 'times-do ...block...)`.

3. Since we now have the ability to make new objects using an existing object
   as its "recipe" (as embodied in the implementation of the :rkt:`'init`
   method), these base objects such as :rkt:`Num` and :rkt:`True` could be
   called "classes". 

4. It is a useful exercise to try and redo the above code in :rkt:`#lang typed/racket`.
   That way, you can use the Racket type system to enforce our constraints of
   "everything is an object" and "everything happens through message passing"
   that we imposed on ourselves. Well, it is hard to do the latter thoroughly,
   but it is still worth the effort to clarify the object system built above.
   You'll have to carefully maintain a separation between the object system and
   Racket-primitive values, unlike what we've assumed we can do here.

    .. admonition:: **Exercise**: 

        Reimplement this object system using :rkt:`#lang typed/racket`.

5. If you looked carefully at our :rkt:`Vec`, you'll notice that the second
   implementation of :rkt:`length` method makes use of the fact that both
   :rkt:`Vec` and :rkt:`Point` have the coordinates available in the :rkt:`x`
   and :rkt:`y` fields to borrow the :rkt:`dist` implementation to calculate
   :rkt:`length`. i.e. a :rkt:`Vec` is usable as a :rkt:`Point` because both
   have similar properties. This is referred to in some languages (such as
   Ruby) as "duck typing" -- taken from "if it looks like a duck and quacks
   like a duck, it **is** a duck".






