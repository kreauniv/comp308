Notional machine
================
:author: Srikumar K. S.
:date: 5 Aug 2023

.. note:: This section contains notes for the same content as the previous
   section :doc:`machine`, except that it is presented in the context of what
   students in the 2023 July batch had worked on up to this point. It also
   takes a more "gentle" approach to the topic.

A "notional machine" offers a mental model of how computation happens in a
machine. Making these machines explicit as programs gives us concrete artifacts
that we can study as we build up our programming language.

We've so far built an interpreter that relies on Racket's semantics to do its
job. In this session, we'll be diving into what these semantics are and lifting
the hood to peek under the machinery a bit.

First the base definitions we need --

.. code:: racket

    #lang typed/racket

    (require "color.rkt")
    (require "picture-lib.rkt")
    (require racket/match)

    ; Sugar free
    (struct Circle ([radius : Float]
                    [thickness : Float])
      #:transparent)
    (struct (t) Overlay ([pic1 : t]
                         [pic2 : t])
      #:transparent)
    (struct (t) Colorize ([a : Float]
                          [r : Float]
                          [g : Float]
                          [b : Float]
                          [pic : t])
      #:transparent)
    (struct (t) Affine ([mxx : Float]
                        [mxy : Float]
                        [myx : Float]
                        [myy : Float]
                        [dx : Float]
                        [dy : Float]
                        [pic : t])
      #:transparent)

    ; Sugar form
    (struct (t) Translate ([dx : Float]
                           [dy : Float]
                           [pic : t])
      #:transparent)

    (define-type PicSugar (U Circle
                             (Overlay PicSugar)
                             (Colorize PicSugar)
                             (Affine PicSugar)
                             (Translate PicSugar)))

    (define-type PicCore (U Circle
                            (Overlay PicCore)
                            (Colorize PicCore)
                            (Affine PicCore)))

    (: interpret-picexpr (-> PicCore Picture))
    (define (interpret-picexpr picexpr)
      (match picexpr
        [(Circle radius thickness)
         (circle radius thickness)]
        [(Affine mxx mxy myx myy dx dy picexpr2)
         (affine mxx mxy myx myy dx dy (interpret-picexpr picexpr2))]
        [(Overlay picexpr1 picexpr2)
         (overlay (interpret-picexpr picexpr1)
                  (interpret-picexpr picexpr2))]
        [(Colorize a r g b pic)
         (colorize a r g b (interpret-picexpr pic))]))

    ; Note that the desugar operation is the same whether the result
    ; is fed into the interpreter or the compiler.
    (: desugar (-> PicSugar PicCore))
    (define (desugar picexpr)
      (match picexpr
        [(Translate dx dy picexpr2)
         (Affine 1.0 0.0 0.0 1.0 dx dy (desugar picexpr2))]
        [(Colorize a r g b picexpr2)
         (Colorize a r g b (desugar picexpr2))]
        [(Overlay picexpr1 picexpr2)
         (Overlay (desugar picexpr1) (desugar picexpr2))]
        [(Circle radius thickness)
         (Circle radius thickness)]))

We'll also define a sample "picture expression" that we can use
as an aid to think through how we want to compute the result
picture.

.. code:: racket

    (define picexpr : PicSugar
      (Overlay
       (Colorize 1.0 1.0 0.0 0.0
                 (Circle 0.75 0.1))
       (Translate 0.5 0.0
                  (Colorize 1.0 0.0 0.0 1.0
                        (Circle 1.5 0.1)))))

Let's look at what the steps our interpreter takes to evaluate
this expression and come up with a picture. First let's translate it
into "core" form.

.. code:: racket

    (define picexpr-core : PicCore
      (desugar picexpr))

Instruction sequence
--------------------

Let's write down the individual steps it does. We'll note only
those steps where actual computation happens - i.e. our Racket
functions that calculate pictures are called.

1. ``(Circle 0.75 0.1)`` gets evaluated using ``(circle 0.75 0.1)`` to get, say,
   ``result1``

2. The ``result1`` is used to calculate ``(Colorize 1.0 1.0 0.0 0.0 result1)``
   using ``(colorize 1.0 1.0 0.0 0.0 result1)`` to get ``result2``

3. ``(Circle 1.5 0.1)`` gets evaluated using ``(circle 1.5 0.1)`` to get ``result3``

4. The ``result3`` is used to calculate ``(colorize 1.0 0.0 0.0 1.0 result3)`` to
   get ``result4``

5. That ``result4`` is then used to calculate ``(Translate 0.5 0.0 result4)`` to
   get ``result5``

6. ``result2`` and ``result5`` are then used to calculate ``(overlay result2
   result5)``

7. The result of step 6 is the final picture.

If we were to write that out as a Racket function that computes the picture,
we'd do it like this.

.. code:: racket

    (define (picexpr-in-racket)
      (define result1 (circle 0.75 0.1))
      (define result2 (colorize 1.0 1.0 0.0 0.0 result1))
      (define result3 (circle 1.5 0.1))
      (define result4 (colorize 1.0 0.0 0.0 1.0 result3))
      (define result5 (translate 0.5 0.0 result4))
      (define result6 (overlay result2 result5))
      result6)

Some observations to be made. We need result1 to compute result2 but not any of
the results following that. Similarly we need result3 to compute result4, and
need result4 to compute result5 but we don't need result3 and result4 after we
compute result5.

We could use those observations to rewrite it this way using fewer "result"
variables.

.. code:: racket

    (define (picexpr-in-racket2)
      (define result1 (circle 0.75 0.1))
      (set! result1 (colorize 1.0 1.0 0.0 0.0 result1))
      (define result2 (circle 1.5 0.1))
      (set! result2 (colorize 1.0 0.0 0.0 1.0 result2))
      (set! result2 (translate 0.5 0.0 result2))
      (set! result1 (overlay result1 result2))
      result1)

We see that we needed only two variables to complete the computation. Also,
Racket is pulling off a lot of tricks of performing this specific series of
computations when given our recursive interpreter.

Instructions for our "machine"
------------------------------

So let's step in and look at a more "barebones machine". A "program" in the
simplest sense can be thought of as a list of instructions that a computer
performs from start to end and then stops.

What will this list of instructions look like? Let's make some structs to
capture that. We'll define new struct names for the purpose of this discussion.

The circle instruction is straightforward.

.. code:: racket

    (struct SCircle ([radius : Float]
                     [thickness : Float]))

Consider the "colorize" instruction.
Should it be the following one?

.. code:: racket

    (struct SColorize1 ([a : Float]
                        [r : Float]
                        [g : Float]
                        [b : Float]
                        [pic : NewPicExpression]))

What should NewPicExpression be then? We were formerly thinking in terms of
"expressions" and "values" they "evaluate" to, and leveraged the semantics of
Racket which also offers expressions evaluate to concrete values as part of its
semantics. We're now thinking in terms of "instructions sent to a computer"
instead. We want to capture the data required to instruct "pick a picture from
your storage, colorize it with the given ARGB color, and store the result
colorized picture into the storage". This is an "instruction" - which involves
a "fetch", "perform" and "store" sequence. You'll find this a characteristic of
"low level" languages like Assembly, for example. Since we have no concept of
an "embedded expression" when we're looking at sending "instructions", our data
structures correspondingly change. Our SColorize should simply be -

.. code:: racket

    (struct SColorize ([a : Float]
                       [r : Float]
                       [g : Float]
                       [b : Float])
      #:transparent)

with the implication that when this instruction is processed, a picture will be
fetched from "storage", colorized, and the result will be placed back into the
"storage".

Storage
-------

We haven't made any consideration for what we should use for "storage".
Earlier, we'd relied on Racket semantics to handle the storage part for us too,
by relying on function call/return semantics and binding values to identifiers
(either using let or lambda).

Let's pick the simplest "storage" we can for starters -- the humble list. So
when we need a value to be taken from our "storage", we'll pick the head
element of the list we're using to represent our storage. When we want to store
something, we'll extend our list at the head with the new value. In our case,
the only types of values we're dealing with are ``Picture`` values, so we don't
need to worry about any others.

.. code:: racket

    (define-type Storage (Listof Picture))

    (: new-storage (-> Storage))
    (define (new-storage) empty)

    (: store (-> Picture Storage Storage))
    (define (store pic storage)
        (cons pic storage))

    (: take1 (-> Storage (List Picture Storage)))
    (define (take1 storage)
        (if (empty? storage)
            (error "Empty storage")
            (list (first storage) (rest storage))))

    (: take2 (-> Storage (List Picture Picture Storage)))
    (define (take2 storage)
        (let ([v1 (take1 storage)])
            (let ([v2 (take1 (second v1))])
                (list (first v1) (first v2) (second v2)))))

Now that we're clear about both the nature of our "instructions" and
our computer's "storage", let's make them all explicit.

.. code:: racket

    (struct SCircle ([radius : Float] 
                     [thickness : Float])
        #:transparent)

    (struct SColorize ([a : Float]
                       [r : Float]
                       [g : Float]
                       [b : Float])
        #:transparent)

    (struct STranslate ([dx : Float]
                        [dy : Float])
        #:transparent)

    (struct SOverlay ()
        #:transparent)

    (define-type Instruction (U SCircle 
                                SColorize 
                                STranslate 
                                SOverlay))

Instruction processor
---------------------

So our "machine" for processing instructions needs to have a very
simple type -- we need to give it the storage to work on,
a list of instructions and it will need to give us back the
storage at the end of processing all the instructions. So
its type will simply be -

.. code:: racket

    (: run-machine (-> Storage (Listof Instruction) Storage))

... and our machine is such a simpleton that it is nearly trivial
to specify what it does.

.. code:: racket

    (define (run-machine storage instructions)
        (if (empty? instructions)
            storage
            (run-machine (process-instruction storage (first instructions))
                     (rest instructions))))
     

Here we've delegated the job of figuring out what to do for each type of
instruction to another function ``process-instruction``. What this is expected
to do, for each type of instruction, is the three steps we saw earlier -

1. **Fetch** any input it needs from the storage. It is ok for an
   instruction to not need any input too.

2. **Work** on the input according to the instruction and produce
   an output result.

3. **Store** the output result into the storage and return the
   storage.

.. code:: racket

    (: process-instruction (-> Storage Instruction Storage))
    (define (process-instruction storage instruction)
        (match instruction
            [(SCircle radius thickness)
             (store (circle radius thickness) storage)]
            [(SColorize a r g b)
             (let ([input (take1 storage)])
                (store (colorize a r g b (first input)) (second input)))]
            [(STranslate dx dy)
             (let ([input (take1 storage)])
                (store (translate dx dy (first input)) (second input)))]
            [(SOverlay)
             (let ([input (take2 storage)])
                (store (overlay (first input) (second input)) (third input)))]))


So how do we invoke this machine to produce the same picture we computed
earlier using ``picexpr`` and ``interpret-picexpr``?

.. code:: racket

    (define result 
        (run-machine (new-storage)
                     (list (SCircle 0.75 0.1)
                           (SColorize 1.0 1.0 0.0 0.0)
                           (SCircle 1.5 0.1)
                           (SColorize 1.0 0.0 0.0 1.0)
                           (STranslate 0.5 0.0)
                           (SOverlay))))

What our "machine" does with the given "program" is the following --

1. It makes a new circle and puts it into storage.

2. It pulls the circle picture from storage, colorizes it and puts that back
   into storage, removing the previous circle.

3. It puts another circle into storage.

4. It pulls the latest circle, colorizes it and puts it into storage. Now our
   storage contains two colorized circles.

5. It pulls the latest colorized circle from storage, translates it and puts
   that back into storage. Now our storage contains one colorized circle and
   one translated colorized circle.

6. It pulls two pictures from storage and overlays one on top of the other, and
   puts the result overlaid picture into the storage. Finally our storage
   contains only one picture which is the result.

This closely mimics the way we wrote what our first version of the interpreter
did when it processed things recursively. Except that now, we have an "under
the hood" understanding of what the interpreter is doing. We may not work
extensively with this "notional machine", but it is a very useful construct to
keep in mind and try to work out in parallel as we add more capabilities to our
interpreter.

Reflections
-----------

We'd used generic words like "storage" and "instructions" here. If you look
carefully at how our storage operates, you can see that it behaves like a
"stack" -- i.e. a "last-in first-out" data structure. We might as well have
written our storage to be like this --

.. code:: racket

    (define-type Stack (Listof Picture))

    (: push (-> Picture Stack Stack)) 
    (define (push val stack)
        (cons val stack))

    (: pop1 (-> Stack Stack))
    (define (pop1 stack)
        (rest stack))

    (: pop2 (-> Stack Stack))
    (define (pop2 stack)
        (rest (rest stack)))

... and use the usual ``first`` and ``second`` to access the top two elements
of our stack.

This stack machine is not an unusual construct and actually entire programming
languages such as Forth, J and Postscript are built around this approach. yes,
Postscript (and by extension PDF) is not merely a data format, but PS files are
actually programs that draw things into the device. This is the way we get PDF
and PS documents to behave correctly independent of device resolution.

Because it takes very little to build up such a "stack based programming
language", you'll find such languages in very low level programmable hardware
as well. For example, OpenFirmware is a protocol for control of computing
hardware and I/O devices and it is programmed in Forth.

Originally, we wanted to rely less on Racket's semantics to implement our
interpreter. But we again find ourselves using Racket's function call
semantics including recursion -- our ``run-machine`` function calls
itself. However there is one crucial difference that suggests that we're
relying less. The recursive step in ``run-machine`` appears in what is
called the "tail position". It is the last step when evaluating a particular
``run-machine`` call. This means there is no need to remember all the state
and history of calling ``run-machine`` earlier and we can simply move to
processing the next instruction. This is also the trick that Racket/Scheme
use to perform "tail recursive" procedures without blowing the stack.
To see the difference, try the following two functions -- one in Racket
and the other in Javascript in your browser.

.. code:: racket

    (define (sum m n total)
        (if (< m n)
            (sum (+ m 1) n (+ m total))
            total))

    (sum 1 1000000 0)

.. code:: javascript

    function sum(m, n, total) {
        if (m < n) {
            return sum(m+1, n, m+total);
        } else {
            return total;
        }
    }

    sum(1, 1000000, 0)

To evaluate the Javascript code, you can open your browser, go to the
"developer console" and paste the code in. Firefox, for example,
will complain of "too much recursion", whereas for Racket, the 
recursion is equivalent to doing the following in Javascript -

.. code:: javascript

    function sum(m, n, total) {
        while (m < n) {
            let next_m = m + 1;
            let next_total = total + m;
            m = next_m;
            total = next_total;
        }
        return total;
    }

Introducing identifiers
-----------------------

We're now ready to dip our toes into permitting some degree of abstraction in
our "picture expressions". We now have a machine that performs a *sequence* of
instructions while threading a "storage mechanism" through the steps. We can
now support simple reuse of computation by associating identifiers with
computed results so they can be reused when needed. What we'll be doing here is
not the most powerful "core" approach, but since it will introduce a few
mechanisms we'll need later on, it serves as a useful intermediate step.

We'll define a new term that lets us associate an identifier with a picture
expression, with the expectation that the picture computation will be performed
and the resultant picture associated with the identifier in our storage. Note
that we actually don't need to include an expression to compute to determine
what the id needs to be bound do. We can simply pick up that value from our
storage.

.. code:: racket

    (define-type Identifier Symbol)
    (struct SDefine ([id : Identifier]))

    ; We'll also have to augment our instruction set to permit
    ; this new construct.

    (define-type Instruction (U SCircle 
                                SColorize 
                                STranslate 
                                SOverlay 
                                SDefine))

Now, how will we use this defined identifier to construct other pictures?
Recall that an instruction like :rkt:`(Colorize a r g b)` will fetch the
input picture from storage, colorize it and place the result back into
the storage. So all we need to add is a way to lookup the picture associated
with an identifier and place the picture into our storage, to be picked
up by subsequent instructions. This is a simple enough instruction.

.. code:: racket

    (struct SUse ([id : Identifier]))
    (define-type Instruction (U SCircle 
                                SColorize 
                                STranslate 
                                SOverlay 
                                SDefine 
                                SUse))

We also need to augment our storage with a new component -- something that can
let us associate identifiers with values and lets us look it up. For simplicity,
we'll reuse the same list structure of our storage, except that we'll augment
what we can put into it with a new "Binding" type. We'll search through the
storage linearly for the first occurrence of the value we're interested in
and pick that up. So we'll modify the getter functions accordingly.

.. code:: racket

    ; Note that we're binding an *evaluated* picture here.
    (struct Binding ([id : Identifier]
                     [value : Picture]))

    (define-type Datum (U Picture Binding))
    (define-type Storage (Listof Datum))

    (: new-storage (-> Storage))
    (define (new-storage) empty)

    (: store (-> Datum Storage Storage))
    (define (store datum storage)
        (cons datum storage))

    (: take1 (-> Storage (List Picture Storage)))
    (define (take1 storage)
        (if (empty? storage)
            (error "Empty storage")
            (let ([top (first storage)])
                (if (Binding? top)
                    ; Keep bindings while dropping values from storage.
                    (let ([v (take1 (rest storage))])
                        (list (first v) (cons top (second v))))
                    (list top (rest storage))))))

Since we defined :rkt:`take2` in terms of :rkt:`take1`, its definition remains
the same since it was defined independent of the internal structure of Storage.
We also need a function to lookup a bound identifier from the storage.

.. code:: racket

    (: lookup (-> Storage Identifier Picture))
    (define (lookup storage id)
        (if (empty? storage)
            (raise-user-error 'unbound-identifier "Identifier '~s' is not defined" id)
            (let ([v (first storage)])
                (if (and (Binding? v)
                         (equal? (Binding-id v) id))
                    (Binding-value v)
                    (lookup (rest storage) id)))))

Using these two, we can modify our :rkt:`process-instruction` to account for
making and using definitions as follows -

.. code:: racket

    (: process-instruction (-> Storage Instruction Storage))
    (define (process-instruction storage instruction)
        (match instruction
            [(SCircle radius thickness)
             (store (circle radius thickness) storage)]
            [(SColorize a r g b)
             (let ([input (take1 storage)])
                (store (colorize a r g b (first input)) (second input)))]
            [(STranslate dx dy)
             (let ([input (take1 storage)])
                (store (translate dx dy (first input)) (second input)))]
            [(SOverlay)
             (let ([input (take2 storage)])
                (store (overlay (first input) (second input)) (third input)))]
            [(SDefine id)
             (let ([input (take1 storage)])
                (store (Binding id (first input)) (second input)))]
            [(SUse id)
             (store (lookup storage id) storage)]))

With these two additions, we can now have some degree of reuse
when constructing pictures using our "language".

.. code:: racket

    (define result 
        (run-machine (new-storage)
                     (list (SCircle 0.75 0.1)
                           (SDefine 'pic) ; After this, the pic in storage is dropped.
                           (SUse 'pic)    ; ... so we need to add it back.
                           (SColorize 1.0 1.0 0.0 0.0)
                           (SUse 'pic)
                           (SColorize 1.0 0.0 0.0 1.0)
                           (STranslate 0.5 0.0)
                           (SOverlay))))

We can now compute a picture once and reuse it in as many parts as we want to.
Usually, such reuse of computations results in a bit of efficiency gain and
sure it does in this case, but only a tiny bit because much of the computation
in our case is spent not evaluating pictures, but in rendering pictures to
images. As we saw with :rkt:`compiler.rkt`, addressing that is a different kind
of "optimization".
