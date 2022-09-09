Making and composing pictures
=============================

The ``picture-io.rkt`` file contains functions for reading/writing plain PPM
files ("P3 format" PPM files to be specific). Reading one using
``read-image-from-ppm`` will give you a vector of rows where each row is a
vector of color values. We call this a "2D matrix of color values". Similarly
writing to a file using ``write-image-to-ppm`` takes such a 2D matrix and
writes it out in the plain PPM format.

The ``picture-lib.rkt`` contains functions for making pictures and transforming
and composing them. You can use this library by doing ``(require "./picture-lib.rkt")``
in your own ``rkt`` file placed in the same directory as these two files.

Play around with this library and make some interesting pictures by writing
your own functions or using the ones given to make your own compositions.
The upcoming assignments will make use of this library.

