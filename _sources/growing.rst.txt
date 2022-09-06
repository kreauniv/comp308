Growing the language
====================

So far, we have a few "primitives" for creating pictures and some for
transforming pictures. Let's list them out to recap --

.. code-block:: racket

    ; Shapes
    (Disc <radius>)
    (Circle <radius> <thickness>)
    (Qquare <width>)
    (Rectangle <width> <height>)

    ; Transformations
    (Translate <dx> <dy> <picture>)
    (Rotate <deg> <picture>)
    (Scale <xscale> <yscale> <picture>)
    (InvertColour <picture>)
    (Opacity <alpha> <picture>)
    (Colourize <colour> <picture>)

    ; Combinations
    (Overlay <pictureA> <pictureB>)
    (Intersect <pictureA> <pictureB>)
    (LayoutHoriz <hstep> <pictureA> <pictureB>)
    (LayoutVert <vstep> <pictureA> <pictureB>)


.. admonition:: **Exercise**

    Implement some of these operations as ordinary lambda functions
    to convince yourself that the representation we've chosen still
    serves to model this whole set.

Some of you may have noticed that if we have :rkt:`Rectangle`,
we don't really need :rkt:`Square` since a square is just a rectangle
with equal sides. Even in the case of :rkt:`Disc` and :rkt:`Circle`,
we can see that a :rkt:`Disc` or radius :math:`R` can be thought of
as a circle of radius :math:`R/2` of thickness :math:`R`.

Those who have your linear algebra course still on top of your minds
will perhaps be able to see that :rkt:`Translate`, :rkt:`Rotate`
and :rkt:`Scale` are all special cases of "affine transforms" which
we can model using a single :rkt:`Affine` operator which applies a
matrix operation followed by translation.

.. code-block:: racket

    (struct Affine (mxx mxy myx myy dx dy pic))

We also see how something like :rkt:`LayoutHoriz` can be expressed
in terms of :rkt:`Overlay` and :rkt:`Translate` like this -

.. code-block:: racket

    (LayoutHoriz xstep picA picB) = (Overlay picA (Translate xstep 0.0 picB))

So :rkt:`LayoutHoriz` is not really "fundamental" or "core" in that sense.
Having a small "core" for our language is valuable because it reduces the
possibilities over which we need to reason in order to be convinced that
our language is good. [#sound]_

.. [#sound] There are theoretical "goodness" properties we won't get into
   right now (and likely not in this course). These go by "soundness",
   in reference to type systems, and "consistency" with respect to logic.
   We'll bank on our intuitive sense of "this looks right" until we need
   more formal support.

It would appear that a language that has a small "core" is at loggerheads
with the goal of growing the language to be able to do more interesting
things with it. To meet this, we'll still keep the core small, but add a
transformation from a larger set of "sugary" constructs to the core language,
so we can have our cake and eat it too. We'll refer to this transformation
as "**desugaring**". You've already seen examples of desugaring in Scheme,
when we talked about how the :rkt:`let` construct can be expressed using
:rkt:`lambda` and application.

To make our core language terms stand out compared to the "surface" or
"sugar" layer, we'll add a ``C`` suffix to core terms and ``S`` suffix to
sugar/syntax terms.

.. code-block:: racket

    (define (desugar picexprS)
        (match picexprS
            [(LayoutHorizS xstep picA picB)
             (OverlayC (desugar picA) (desugar (TranslateS xstep 0.0 picB)))]
            [(TranslateS xstep ystep picA)
             (AffineC 1.0 0.0 0.0 1.0 xstep 0.0 (desugar picA))]
            ; ... other such conversion rules.
            ; Our contract is that desugar must not produce any
            ; of the sugar terms. The result expression must only involve
            ; the core terms.
            [_ picexprS]))

It is easy to forget to call :rkt:`desugar` recursively. Remember that everywhere
we have a "surface expression", we'll need to convert it into a "core expression"
and that's the purpose of :rkt:`desugar`.

Now, when we want to add a new operation that we know can be expressed in terms
of our "core expressions", we can add it to our :rkt:`desugar` function without
touching our core interpreter. So this "surface-vs-core" split helps us grow
the language in one way.

Typed racket (**advanced** / optional)
--------------------------------------

We stepped out of :rkt:`#lang plai-typed` into plain racket because it was
too restrictive for the picture language we're setting out to build. In perhaps
a later version of this course, we'll augment the language to help meet this
constraint. For now though, you can use either plain Racket or :rkt:`#lang typed/racket`
if you're brave enough to get similar type checking as :rkt:`#lang plai-typed`.
Below is some of our code in :rkt:`typed/racket`.

The advantage of using a type system is that the "compilation" step will
detect places where you're being inconsistent and throw up errors so that
you don't face these errors when running your program. Using a type system
also helps design your program in the initial stages.

.. code-block:: racket

    #lang typed/racket

    (require typed-racket-datatype)
    (require racket/match)

    (struct Colour [a : Float] [r : Float] [g : Float] [b : Float])

    (define-datatype PicExprC
        (DiscC [radius : Float])
        (CircleC [radius : Float] [thickness : Float])
        (RectangleC [width : Float] [height : Float])
        (AffineC [mxx : Float] 
                 [mxy : Float]
                 [myx : Float]
                 [myy : Float]
                 [dx  : Float]
                 [dy  : Float]
                 [pic : PicExprC])
        (ColourizeC [colour : Colour] [pic : PicExprC]))

    (define-datatype PicExprS
        (DiscS [radius : Float])
        (CircleS [radius : Float] [thickness : Float])
        (RectangleS [width : Float] [height : Float])
        (SquareS [width : Float])
        (TranslateS [dx : Float] [dy : Float] [pic : PicExprS])
        (RotateS [angle : Float] [pic : PicExprS])
        (ScaleS [xscale : Float] [yscale : Float] [pic : PicExprS])
        (ColourizeS [colour : Colour] [pic : PicExprS]))

    (: desugar (-> PicExprS PicExprC))
    (define (desugar picexprS)
        (match picexprS
            [(DiscS radius)
             (DiscC radius)]
            [(CircleS radius thickness)
             (CircleC radius thickness)]
            [(RectangleS width height)
             (RectangleC width height)]
            [(SquareS width)
             (RectangleC width width)]
            [(TranslateS dx dy picS)
             (AffineC 1.0 0.0 0.0 1.0 dx dy (desugar picS))]
            [(RotateS angle picS)
             (let ([c (cos angle)] [s (sin angle)])
                (AffineC c (- s) s c 0.0 0.0 (desugar picS)))]
            [(ScaleS xscale yscale picS)
             (AffineC xscale 0.0 0.0 yscale 0.0 0.0 (desugar picS))]
            [(ColourizeS colour picS)
             (ColourizeC colour (desugar picS))]
            (_ (raise-argument-error 'desugar "PicExprS" picexprS))))
            

    (define-type Picture (-> Float Float Colour))

    (: affine (-> Float Float Float Float Float Float Picture Picture))
    (define (affine mxx mxy myx myy dx dy pic)
        ; Note that we need to apply the inverse of
        ; the specified Affine transform on the given
        ; (x y) coordinates to get the coordinates to
        ; be passed to the given pic. The given transform
        ; is to apply the matrix followed by the translation,
        ; so the inverse would be the inverse translation
        ; followed by the inverse of the matrix.
        (let ([det (- (* mxx myy) (* mxy myx))])
            (let ([mixx (/ myy det)]
                  [mixy (- (/ mxy det))]
                  [miyy (/ mxx det)]
                  [miyx (- (/ myx det))])
                (λ ([x : Float] [y : Float])
                    (let ([x2 (- x dx)]
                          [y2 (- y dy)])
                        (let ([x3 (+ (* mixx x2) (* mixy y2))]
                              [y3 (+ (* miyx x2) (* miyy y2))])
                            (pic x3 y3)))))))

    ; ... and so on.

.. admonition:: **Exercise**

    Write the interpreter using :rkt:`typed/racket`.

A mental model for the machine
------------------------------

The way we've written the interpreter thus far, using a recursive function
to evaluate the sub-expressions constituting an container expression
(such as :rkt:`TranslateS`), offers us some initial view into how we might
build a language from ground up. However, we're using a base -- or "host" --
language that is too powerful to gain insights into the mechanics of the language.
We've simply used the host's own recursion capability to express recursive
interpretation in our mini language. When we're looking to further develop
our language into a programmable image synthesizer, we're going to have to do
better than that and understand how we might actually implement the control
flow implicit in the expressions we've been writing thus far.

To dive in, we can restrict ourselves to simple loops (expressed as "tail
recursion") and try to capture a mental model of our machine as a program in
its own right. When we do that, we now get something concrete on our hands to
work with and ask questions about. We can therefore use this approach to
inquire into language construction and meaning.

When we interpret an expression like :rkt:`(rotate 30 (translate 2 3 (disc 5.0)))`,
the sequence of calculations being performed by the interpreter is actually

.. code-block:: racket

    (disc 5.0)
    (translate 2 3 <result>)
    (rotate 30 <result>)

i.e. it goes in the order from innermost to outermost.

We can take a cue from this observation and consider the simplest machine we
can think of -- something that does the following --

1. Take a list of instructions -- i.e. the "program"
2. Take the first instruction and execute it. Store its result in a bucket.
3. Take the second instruction and execute it, passing the results of the bucket 
   in case it needs any input. Ask it to store its result in the same bucket.
4. Take the third instruction ... and so on.

The simplest construct for the "bucket" is the "stack", where we get access
to the most recent results on the top and earlier results go below the more
recent ones.

Our "machine", therefore, is a function that accepts a list of instructions to
perform and a stack containing data on which it should perform them and into
which it must store the result in the end. We can easily model such a stack
using a simple list - using :rkt:`cons` to "push" values at the head
and :rkt:`rest` to drop the top value and pick the rest of the stack.

.. code-block:: racket

    (define (stack-machine program stack)
        (if (empty? program)
            ; The result is the stack when we're done
            ; with the program or there is nothing to do.
            stack

            ; As the Red Queen says in "Alice in Wonderland"
            ; take the first instruction.
            ; execute it.
            ; go on until you reach the end.
            (let ([instr (first program)])
                ; "perform-instruction" is the name we're giving to
                ; the part of our interpreter that evaluates a single
                ; instruction and modifies the stack accordingly.
                ; Since we expect it to return the result stack, 
                ; we can pass that as input to the next step of our
                ; machine.
                (let ([next-stack (perform-instruction instr stack)])
                    (stack-machine (rest program) next-stack)))))

Now let's look at what :rkt:`perform-instruction` must do --

.. code-block:: racket

    (define (perform-instruction instr stack)
        (match instr
            [(list 'disc radius) (disc/s radius stack)]
            [(list 'translate dx dy) (translate/s dx dy stack)]
            [(list 'rotate deg) (rotate/s deg stack)]
            ; ...
            [_ (raise-argument-error 'perform-instruction
                                     "Machine instruction"
                                     instr)]))

In this code, we've used :rkt:`disc/s` (read "disc with stack")
and so on to stand for slightly different functions that compute
our pictures based on data on the stack and store their results on the
stack. Here is how we might implement them --

.. code-block:: racket

    (define background (color 0.0 0.0 0.0 0.0))
    (define white (color 1.0 1.0 1.0 1.0))

    (define (disc/s radius stack)
        (push (λ (x y)
                 (if (< (sqrt (+ (* x x) (* y y))) radius)
                    white
                    background))
              stack))

    ; And along the way we'll define what push/pop etc mean
    (define (push val stack) (cons val stack))
    (define (pop stack) (rest stack))
    (define (top stack) (first stack))

    (define (translate/s dx dy stack)
        ; What's on top of the stack is the input image
        ; we want translated.
        (let ([input-image (top stack)])
            (let ([result (λ (x y)
                                (input-image (- x dx) (- y dy)))])
                ; We replace the top of the stack with the
                ; translated result. i.e. we "consume" the image
                ; on the top of the stack and push the result
                ; which then takes its place.
                (push result (pop stack)))))


    ; Essentially the same idea as for translate/s above.
    (define (rotate/s angle stack)
        (let ([c (cos angle)]
              [s (sin angle)]
              [img (top stack)])
            (push (λ (x y)
                    ; Applies the inverse of the rotation matrix.
                    (img (+ (* c x) (* s y)) (+ (* (- s) x) (* c y))))
                  (pop stack))))

In the above examples of the "/s" (i.e. "with stack") functions,
they take their input from the top of the stack and add the result 
that they compute to the stack and return the new stack.

Note that the "push" and "pop" operations do not mutate the stack, but just
deconstruct parts of it and make a new stack. For example, if the stack was
:rkt:`(<one> <two>)`, doing a :rkt:`(push <three> stack)` will produce
:rkt:`(<three> <one> <two>)` and doing :rkt:`(push <three> (pop stack))` will
produce :rkt:`(<three> <two>)`.
        
.. code-block:: racket

    (define stack (list 1 2))
    (display stack)             ; Prints out (1 2)
    (display (push 3 stack))    ; Prints out (3 1 2)
    (display stack)             ; Prints out (1 2). Shows that the original
                                ; is not mutated with the new entry.
    (display (pop stack))       ; Prints (2)
    (display (push 3 (pop stack))) ; Prints (3 2).
    (display stack)             ; Prints (1 2)


The :rkt:`stack-machine` we defined above offers a closer picture to how the
Racket runtime evaluates the program that we give it in the form of the nested
expression. 

.. admonition:: **Exercise**

    Define the "compose/s" operator which combines two images present on the
    stack and pushes a composite image that consists of the contents of both
    the images. **Tip**: If at a given point :math:`(x,y)`, :math:`c_1` and
    :math:`c_2` are the colours that the two images being composed produce,
    then the result :math:`c` can be computed using -- :math:`c_a = c_{1a} + (1 - c_{1a}) c_{2a}`
    and :math:`c_{rgb} = (c_{1a} c_{1rgb} + (1 - c_{1a}) c_{2a} c_{2rgb}) / c_a`.
    For more ways to compose two images with transparency, see `Alpha compositing`_.
    Also define :rkt:`compose` in a way suitable for our original expression
    interpreter.


.. _Alpha compositing: https://en.wikipedia.org/wiki/Alpha_compositing

