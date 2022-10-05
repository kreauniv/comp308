Objects
=======

You can't browse around many popular programming languages without running into
some claiming to be "object oriented". This sketch is to examine what objects
are and how to provide linguistic facilities for working with them. The
approach here will be demonstrate these ideas in Racket code, with the
understanding that it can be translated into PicLang given support for
:rkt:`FunC` and :rkt:`ApplyC`.

Anton's Koan
------------

(By Anton van Straaten in a `2003 discussion thread with Guy Steele <qcna_>`_.)

    The venerable master Qc Na was walking with his student, Anton. Hoping to
    prompt the master into a discussion, Anton said "Master, I have heard that
    objects are a very good thing - is this true?" Qc Na looked pityingly at
    his student and replied, "Foolish pupil - objects are merely a poor man’s
    closures."

    Chastised, Anton took his leave from his master and returned to his cell,
    intent on studying closures. He carefully read the entire "Lambda: The
    Ultimate…" series of papers and its cousins, and implemented a small Scheme
    interpreter with a closure-based object system. He learned much, and looked
    forward to informing his master of his progress.

    On his next walk with Qc Na, Anton attempted to impress his master by
    saying "Master, I have diligently studied the matter, and now understand
    that objects are truly a poor man’s closures." Qc Na responded by hitting
    Anton with his stick, saying "When will you learn? Closures are a poor
    man’s object." At that moment, Anton became enlightened.

.. _qcna: https://people.csail.mit.edu/gregs/ll1-discuss-archive-html/msg03277.html

The original post by van Straaten is also worth reading in its entirety.
[#lament]_ You have some idea of closures at this point. If you already have some
ideas about what objects are, I'd urge you to go off and read the original post
and possibly even descend into the rabbit hole of writings linked to from
there.

.. admonition:: **Notes**

    Other links from the above archived message -

    "Oleg Kiselyov has a short article on the subject:
        http://okmij.org/ftp/Scheme/oop-in-fp.txt" (`ipfs link <olegipfs_>`_,
        `pure-oo-system.scm`_)

    "... as I mentioned in the last paragraph of this message:
        https://people.csail.mit.edu/gregs/ll1-discuss-archive-html/msg01488.html"

    "A closure is an object that supports exactly one method: 'apply'." 
        -- Guy Steele Jr., co-creator of Scheme

        (I'm a tad unsure whether Guy is quoting/paraphrasing Christian Quiennec
        or it is his own statement.)

    From - https://people.csail.mit.edu/gregs/ll1-discuss-archive-html/msg03269.html

.. _olegipfs: ipfs://bafybeibuwysdkmmgjfsb3uz5ijvccanx3cjz46istvitjugknt5edlwdie/
.. _pure-oo-system.scm: ipfs://bafybeigfxmcyrr5we76op5mmf4b45iwakaslkl5uhvbjnxc2adpcdhqyaq/

The above discussion pertains to which is "more fundamental", and as with such
questions both answers (closures vs. objects) are correct, and both answers are
wrong. That was the point of the "Koan".

.. [#lament] I'm so glad this discussion happened on the open internet back then.
   If this way today and these computer scientists had this discussion on a closed
   medium like Facebook, we'll be the poorer for it. -- Srikumar 

In this chapter, we'll examine objects from both approaches, and add a third
perspective too -- concurrency -- in order to get a more complete grasp of the
variations you're likely to encounter in the wild. The interesting bit is that
much of this should already look quite familiar to you. [#ctheno]_

.. [#ctheno] This is also the reason why we did :doc:`control` before objects.


The many faces of "objects"
---------------------------

The literature of computer science and software engineering is littered with
several notions of objects and methodologies for software design based on them.
While some characteristics seem to recur, it may even appear that there is no
true consensus among conputer scientists about what exactly is to be considered
*essential* to the notion of an "object".

But despair not, for we'll examine several notions in these lectures, all of
which feature in one or more programming languages in wide use today. Our goal
here is to understand, from a mechanistic perspective, how one might go about
constructing any particular view of objects in a language. The goal underlying
that is to enable you to ask the right questions when faced with a new "object
oriented" language so you can quicky narrow down to its model of objects.


Objects using closures
----------------------

Let's take a simple object - a two-dimensional point with some properties and
behaviours and see how we can express it using only closures ... which is about
all we've used so far. Before that though, we need to agree on how we're
going to use objects in Racket code. We'll use an expression of the following
form --

.. code-block:: racket

    (<object> 'message-name <arg1> <arg2> ...)

... to represent the computation that we verbally describe as "send the message
named ``message-name`` with the given arguments to the object ``<object>``". A
common notion of objects maps the idea of "sending a message to an object" to
"invoking a method function on the object". We'll be looking at this approach
first.

So let's write a function to make a "2D point object".

.. code-block:: racket

    (define (make-point x y)

        ; "x" is a "property" of a point.
        ; It is modeled by two "methods"
        (define (get-x) x)
        (define (set-x val) (set! x val))

        (define (get-y) y)
        (define (set-y val) (set! y val))

        (define (dist2origin) (sqrt (+ (* x x) (* y y))))
        
        (define (dispatcher message-name . args)
            (match message-name
                ['get-x (get-x)]
                ['set-x (set-x (first args))]
                ['get-y (get-y)]
                ['set-y (set-y (first args))]
                ['dist2origin (dist2origin)]
                [_ (raise-argument-error 'point
                                         "Valid message name"
                                         message)]))

        dispatcher)

Observe the following in the above piece of code --

1. We model the two "properties" of our "point" object -- ``x`` and ``y`` --
   using a pair of methods each with the prefix ``get-`` and ``set-``. This is
   a common convention, but nothing sacrosanct about it.

2. The "identity" of our object is just the function that chooses which method
   function to call based on the passed message name. We've called this
   function the "dispatcher" because it functions like a post office,
   dispatching the given name and arguments to the right method function.

3. We've treated the ``x`` and ``y`` as mutable state. So our point carries
   state that is mutable.

The essence of objects through β-abstraction
--------------------------------------------

We're doing a bunch of things in the definition of our point object in the
preceding code sample. Which parts of that are essential to our definition?
That is, which of the parts are specific to the concept of a point and which
parts would be common code no matter what such object we try to define?

Let's examine that using β-abstraction.

Lookup table
~~~~~~~~~~~~

The dispatcher code can be factored into two parts -- a) a function that looks
up the method function given the message name, and b) a function that makes
a dispatcher function given such a lookup function.

.. code-block:: racket

    (define (lookup-method message-name)
        (match message-name
            ['get-x get-x]
            ['set-x set-x]
            ['get-y get-y]
            ['set-y set-y]
            ['dist2origin dist2origin]
            [_ #f]))

    ; Observe that make-dispatcher is independent of the idea
    ; of a "point". So we can now pull it outside the make-point
    ; function.
    (define (make-dispatcher lookup-method)
        (λ (message-name . args)
            (define method (lookup-method message-name))
            (if method
                (apply method args)
                (raise-argument-error 'lookup-method
                                      "Valid message name"
                                      message-name))))

    (define dispatcher (make-dispatcher lookup-method))
    

The `lookup-method` is just a mapping function. This is something we can capture in 
a simple table data structure as follows --

.. code-block:: racket

    (define point-lookup-table 
        (list (list 'get-x get-x)
              (list 'set-x set-x)
              (list 'get-y get-y)
              (list 'set-y set-y)
              (list 'dist2origin dist2origin)))

    ; Note that this function is also now independent of the
    ; idea of a "point" and can therefore be moved out of the
    ; make-point function.
    (define (make-lookup table)
        (λ (message-name)
            (match (assoc message-name table)
                [(list name method) method]
                [#f #f])))

    (define lookup-method (make-lookup point-lookup-table))

We can now combine the method function definitions and the lookup table
itself like this for convenience of reasoning --

.. code-block:: racket

    (define point-lookup-table
        (list (list 'get-x (λ () x))
              (list 'set-x (λ (val) (set! x val)))
              (list 'get-y (λ () y))
              (list 'set-y (λ (val) (set! y val)))
              (list 'dist2origin (λ () (sqrt (+ (* x x) (* y y)))))))

We now no longer need the separate :rkt:`(define (get-x) x)` and so on,
and our :rkt:`make-point` function just reduces to --

.. code-block:: racket

    (define (make-point x y)
        (define point-lookup-table
            (list (list 'get-x (λ () x))
                  (list 'set-x (λ (val) (set! x val)))
                  (list 'get-y (λ () y))
                  (list 'set-y (λ (val) (set! y val)))
                  (list 'dist2origin (λ () (sqrt (+ (* x x) (* y y)))))))

        (make-dispatcher (make-lookup point-lookup-table)))

With the :rkt:`make-dispatcher` and :rkt:`make-lookup` functions having
been pulled out considering their independence of the "point" concept.

With this last form, we see that the essence of an object is "message
dispatch".

Adding new behaviour
--------------------

What if we want to make an "enhanced point" object which is capable of
calculating the distance to another point, as a new behaviour. We want
to accomplish this by reusing everything that our current point can do
without rewriting any of that code. Here is one way --

.. code-block:: racket

    (define (make-dispatcher lookup-method parent)
        (λ (message-name . args)
            (define method (lookup-method message-name))
            (if method
                (apply method args)
                (apply parent (cons message-name args)))))

    (define (make-enhanced-point x y)
        (define p (make-point x y)

        (define ep-lookup-table
            (list (list 'dist2pt (λ (p2) (let ([dx (- (p 'get-x) (p2 'get-x))]
                                               [dy (- (p 'get-y) (p2 'get-y))])
                                            (sqrt (+ (* dx dx) (* dy dy))))))))

        (make-dispatcher (make-lookup ep-lookup-table) p))


We've now changed the dispatcher in an interesting way -- pay attention to the
:rkt:`#f` case. Our underlying representation is the same as that of the original
:rkt:`make-point`, but we're now adding a new piece of functionality to it
to get an "enhanced point".

.. admonition:: **Terminology**

    An enhancement such as done above which adds functionality to an object
    without adding new state is usually called a **mixin**. The intention is that
    you can "mix in" many such granular pieces of functionality when defining
    new objects and they'll automatically work with your objects because they add
    no state. For example, in our case, the :rkt:`dist2pt` method just relies on
    sending the :rkt:`'get-x` message to our object and the object passed in.

    Also note that in our implementation so far, as long as the :rkt:`p2`
    argument responds to the :rkt:`'get-x` message in the appropriate manner --
    i.e. by returning a numeric value, our method will happily calculate a
    distance, even if the meaning of the returned number is different. The
    :rkt:`p2` object just has to quack like a point for us to use it. This
    principle is often referred to as **duck typing** -- taking off from "If it
    looks like a duck and quacks like a duck, it is a duck."

Observe that while :rkt:`make-point` used the internal :rkt:`x` and :rkt:`y`
variables as its state, our :rkt:`make-enhanced-point` does not. What if it
wanted to add some new mutable properties -- i.e. some new state?

Adding new state
----------------

The previous enhancement added a new method that reused the internal state of
the point object constructed by :rkt:`make-point`. What if instead of that we
wanted to make a point that had a name attached to it -- a "named point"?
We need new state to capture that.


.. code-block:: racket

    (define (make-named-point name x y)
        (define p (make-point x y))

        (define np-lookup-table
            (list (list 'get-name (λ () name))
                  (list 'set-name (λ (val) (set! name val)))))

        (make-dispatcher (make-lookup np-lookup-table) p))

Lessons so far
--------------

What we've seen so far is the following --

1. Objects have state which methods may read or write to.

2. The act of "sending a message to an object" can be modelled as the act
   of "calling a corresponding method function". This can be arranged via
   a simplpe lookup table.

3. When a give message name is not found in an object's lookup table,
   we can arrange for the message to be redirected to another object
   -- a "parent" which is then responsible for handling it. If the
   message cannot be handled by the parent, or transitively its parent,
   an error will eventually be raised. This "passing on to a parent" serves
   to reuse functionality defined in another object in case our object
   is unable to handle something.

4. Handling state is tricky. Thus far, we have only managed to handle
   state correctly because our :rkt:`make-named-point` function creates
   a new point using :rkt:`make-point` within it. If the point object
   were, for example, passed as an argument, we'll face problems.

.. admonition:: **Exercise**

    What are the consequences if :rkt:`make-named-point`, instead of calling
    :rkt:`make-point` within it, took an extra argument for the "parent" like
    this? --

    .. code-block:: racket

        (define (make-named-point parent name x y)
            (define nl-lookup-table
                (list (list 'get-name (λ () name))
                      (list 'set-name (λ (val) (set! name val)))))

            (make-dispatcher (make-lookup np-lookup-table) parent))


Objects as the foundation
-------------------------

Much like we initially played a game of "what if lambda functions were the only
things we had?" and showed how we can represent numbers, data structures etc.
with it, we can also start with the idea of objects and message sends as
fundamental and see if we can build a system around it.

.. note:: This is not a theoretical "thought experiment". To varying degrees,
   actual languages such as Java, Javascript, Ruby, Python, Smalltalk and Self
   function on these principles. So do pay attention.

So we have objects that can be bound to symbols and we can send messages
to these objects like :rkt:`(obj 'message arg1 arg2 ...)`. 

.. note:: Think about what values these :rkt:`arg1` and :rkt:`arg2` can be and,
   for that matter, what :rkt:`'message` can be? You know the answer because we
   just saw it in the earlier paragraph!

So, how do we create this kind of an object in the first place? Can you come
up with an answer for that? Remember that objects and message sending are the only
two things available to us! 

**Think a little about this before reading on**.

You probably guessed it right -- by sending a message to another object. For
simplicity, we'l grant ourselves the :rkt:`define` expression similar to how
we did that when we explored the use of :rkt:`lambda`. 

.. code-block:: racket

    (define obj (obj-maker 'make init-arg1 init-arg2 ...))
    (obj 'message arg1 arg2 ...)

This :rkt:`obj-maker` object somehow packages the recipe to make the kind of
object we want. To be consistent, we'd expect it to make the same **kind** of
object every time we send it the :rkt:`'make` message. This is not a strict
requirement, but more to keep our sanity. For if it made random objects every
time we sent the :rkt:`'make` message, we will find it frustrating to work with
those objects.

So, in a sense, the :rkt:`obj-maker` itself stands for the "type" of the object
that gets made. We call this a **class**. To solidify this relationship
between an object and its maker, we can agree to a protocol that all objects
respond to an :rkt:`'isa` message by returning the object that made them.

.. code-block:: racket

    (define obj (objclass 'make init-arg1 init-arg2 ...))
    (display (equal? (obj 'isa) objclass)) ; Prints #t 

.. admonition:: **Terminology**

    We call an object like :rkt:`obj-maker`, whose sole purpose is to
    manufacture objects and serve to identify what kind they are, as a
    **class**. We call the objects a class manufactures as **instances of the
    class**. A class is therefore also responsible for giving specific
    **behaviours** to the objects it manufactures.

A question - what should we get when we send the :rkt:`'isa` message to the
:rkt:`objclass` object? In words, what is the class of the class object?

The language gets tricky here because of our assumption that we only have
objects and message sending in our system. So our classes also have to be
objects themselves. Since a class lends behaviour to the objects it manufactures,
what class lends the "object manufacturing behaviour" to the class object?
We call such a class a **metaclass**.

Here are some behaviours you want and you can infer by following the same line
of thinking --

1. Since a class lends behaviour to an object, to add behaviour to objects, you
   have to add methods to its class. How do you add methods? By sending a
   message to the class object! :rkt:`(objclass 'add-method 'method-name
   block-of-code)`. "Code" in our case consists of a sequence of message sends
   to various objects. We could model it as a block expression :rkt:`(block
   (arg1 arg2 ..) ...sequence...)` for understanding purposes.

2. A class is therefore also responsible for looking up a method when one
   of its objects receives a message. Therefore if the received message does
   not have a corresponding defined method, the class can look it up
   in another "parent" class. The term usually used for such a parent class
   is **super class**.

3. Creating a new class of objects therefore requires a message send of the
   form -- :rkt:`(metaclass 'make-class "class-name" super-class
   set-of-properties)`. Subsequent to that, you can send :rkt:`'add-method`
   messages to that class to define behaviour.

4. At the top of this hierarchy of classes, there usually sits a "root object".
   This object serves as a parent for all objects in the system via the
   inheritance chain. It is in this sense that a language can claim "everything
   is an object". In Javascript, Ruby, Smalltalk and Python, :rkt:`Object` is
   this root object. 

.. csv-table:: Types and hierarchy in traditional OOP languages
   :header: "Thing", "instance of (isa)", "super class", "Comment"
   :widths: 2,2,2,6

    "aPoint", "PointClass", _, "No superclass because aPoint is not a class"
    "PointClass", "PointMetaClass", "Object", "Everything is an object, including classes"
    "PointMetaClass", "MetaClass", "Object",  ".. and metaclasses. Metaclass hierarchy parallels class hierarchy."
    "MetaClass", "MetaClass", "Object", ".. and Metaclass itself"
    "Object", "MetaClass", "Object",


The above table is but one way to organize objects. This scheme or a variation
of it is followed in dynamic "pure" object oriented languages like Smalltalk
and Ruby. The addition of "meta classes" seems like a bit of unnecessary
complexity and is often a point of confusion when learning about them. However,
they also offer power in the language -- best captured in the book `The Art of
the metaobject protocol`_. 

Meta classes hold methods for classes and the meta class hierarchy parallels
the class hierarchy. What that means is that if :rkt:`PointClass` has
:rkt:`VectorSpace` as its super class, then :rkt:`PointMetaClass` will have
:rkt:`VectorSpaceMetaClass` as its superclass. Meta classes also usually
operate behind the scenes and you won't have to deal with them in normal code,
as the act of creating a class should also create its associated metaclass
(like :rkt:`PointClass`) automatically. This structure is very useful when
constructing highly reflective systems -- i.e. systems that can introspect and
modify any aspect of themselves within themselves. For example, in Smalltalk,
the Smalltalk virtual machine is itself written in Smalltalk and is modifiable
within the Smalltalk environment while the program is running. This kind
of dynamism is also present in Ruby which is heavily inspired by Smalltalk.

For our purposes, this is just to let you know that such an organization
exists, so that when you encounter it, you aren't surprised.

.. note:: You **won't** be quizzed on "what is the metaclass of Metaclass?" for example,
   because this organization is not universal.

.. _The Art of the metaobject protocol: https://mitpress.mit.edu/9780262610742/the-art-of-the-metaobject-protocol/

The meta class system is not found in more conventional languages like C++ and
Java. It is a language design choice. In Java, for example, the class of any
class is just :rkt:`Class`. In C++, classes are not objects. In that sense,
C++ is not considered a "pure" object oriented language. In C++, the only
purpose classes serve is to instantiate objects and give them behaviour.
Furthermore, pure object oriented languages completely encapsulate the state
of objects -- meaning you cannot peep into them except and can ony interact with
them via message passing. Languages like C++ chose not to go that route for 
efficiency reasons when considering ahead-of-time compilation. 

Prototypes
----------

While a "meta class" system offers additional power to a pure OOP language, it is
indeed somewhat complex to have in a language. Is it possible to have the benefits
of objects and delegation without having to deal with such hierarchy?

The answer is yes .. and it is also the basis of an earlier exercise in this chapter
where you were asked to explore the consequences of passing in a "parent object" instead
of creating one within :rkt:`make-named-point`.

.. note:: Revisit that case if you haven't already.

While the most famous prototype based object system is Javascript, the concept
was first introduced in Self_. A bit of interesting history there is that Self
was developed by a team at Sun Microsystems and the team developed the dynamic
compilation techniques that later on when into the Java programming language.
Self_, for example, does not have the notions of classes or metaclasses, only
objects and delegation!

.. _Self: https://en.wikipedia.org/wiki/Self_(programming_language)

**Delegation** is the term used in prototype based languages to refer to how
one object leverages another object to get functionality. Whenever an object
sees a message that it does not understand, it passes it on to a "delegate"
(sometimes confusingly referred to as "parent") instead and lets it handle it.
The Self_ language creators showed that this system is better able to model
real world relationships that are subject to frequent change and evolution, as
compared to class-based object oriented languages which have to freeze
behaviour in hierarchies before they're fully known, and end up breaking
relationships when something about the problem domain changes.

While Javascript *can* be used as prototype object system, it is often used in
a traditional single inheritance class structure. This is because the
"prototype chain" of an object in Javascript is used to resolve method lookup
instead of having messages passed up a delegation chain. This means the methods
declared in the prototype actually operate on the target object and not on the
prototype pbject. However, it is possible (though not usually done) to organize
the prototype object such that its methods operate on the prototype object
instead of the target object whose prototype is set to the prototype object.

Here is code to illustrate that --

.. code-block:: js

    function Point(x, y) {
        this.x = x;
        this.y = y;
    }


    function dist2pt(p) {
        let dx = this.x - p.x;
        let dy = this.y - p.y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    Point.prototype.dist2pt = dist2pt;

    let p1 = new Point(3, 4);
    let p2 = new Point(30, 40);
    console.log(p1.dist2pt(p2)); // Prints 45
    console.log(p2.dist2pt(p1)); // Prints 45

    let specificPoint = {x: 100, y: 200};
    Point.prototype.dist2pt = dist2pt.bind(specificPoint);
        // The "bind" call force-associates the "this" inside the
        // dist2pt function with the given object instead of
        // it taking on the target object.

    p1 = new Point(3, 4);
    p2 = new Point(30, 40);
    console.log(p1.dist2pt(p2)); // Prints 174.64249196572982
    console.log(p2.dist2pt(p1)); // Prints 218.68927728629038

Note that the target is being completely ignored in the second case. The way to
understand that in Javascript is that a method call like
``obj1.methodName(arg1,arg2)`` is equivalent to ``obj1.methodName.call(obj1,
arg1, arg2)``. The expression ``obj1.methodName`` will give you the method
function, whose ``call`` method is invoked with the given arguments, explicitly
supplying the object to be used as the ``this`` parameter within the function.
After the ``bind``, the method function gets bound to the given object
so that when it is called, it becomes equivalent to ``dist2pt.call(specificPoint, p2)``
irrespective of whether we call it as ``p1.dist2pt(p2)`` or ``p2.dist2pt(p2)``.

In this sense, Javascript is able to support both class based programming as
well as prototype based programming.

Interfaces and traits
---------------------

The term **interface** or **protocol** is used to refer to the collection of
messages that can be sent to an object -- or, in languages that treat message
passing as method invocation, the collection of methods that can be invoked on
the object.

In some languages that aren't particularly "object oriented" (like Rust_), you
may still find groups of functions that can be called on a value being referred
to by the term **trait**. Since traits/interfaces/protocols refer to the
**pattern** of interaction with compound structures like objects and not to
specific implementations of those patterns, they can usually be freely mixed to
indicate compound functionality in these systems.

.. _Rust: https://www.rust-lang.org/


