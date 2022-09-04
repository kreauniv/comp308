Growing the language
====================

So far, we have a few "primitives" for creating pictures and some for
transforming pictures. Let's list them out to recap --

.. code-block:: racket

    ; Shapes
    (disc <radius>)
    (circle <radius> <thickness>)
    (square <width>)
    (rectangle <width> <height>)

    ; Transformations
    (translated <dx> <dy> <picture>)
    (rotated <deg> <picture>)
    (scaled <xscale> <yscale> <picture>)
    (inverted-colour <picture>)
    (opacity <alpha> <picture>)
    (colourized <colour> <picture>)

    ; Combinations
    (overlid <pictureA> <pictureB>)
    (intersected <pictureA> <pictureB>)


We've chosen the names as past tense verbs since we're interested in building
expressions such as :rkt:`(translated 2 3 (circle 5.0 1.0))` which we'd like to
read and interpret as a "translated circle".

.. admonition:: **Exercise**

    Implement some of these operations as ordinary lambda functions
    to convince yourself that the representation we've chosen still
    serves to model this whole set.

Some of you may have noticed that if we have :rkt:`rectangle`,
we don't really need :rkt:`square` since a square is just a rectangle
with equal sides. Even in the case of :rkt:`disc` and :rkt:`circle`,
we can see that a :rkt:`disc` or radius :math:`R` can be thought of
as a circle of radius :math:`R/2` of thickness :math:`R`.




