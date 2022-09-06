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

