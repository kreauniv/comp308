A quick introduction to Racket and Scheme
=========================================

We're going to be using the ``#lang plai-typed`` in this course and therefore
it is important that you get some decent familiarity with Scheme. Fortunately,
if you're comfortable with normal algebra -- i.e. mostly substituting one thing
for another that's equal to it -- this is rather easy to pick up compared to
almost any other programming language. In fact, for the purpose of this course,
you do not need to be able to write very complicated programs using lots of
complex language features, which in Scheme's case would've been built in Scheme
itself. You'll need to be able to read and understand expressions and be able
to manipulate them in the Racket IDE. We'll be shooting for minimalism in
concept, with maximum impact on understanding.

So without further ado, here is a basic "lightning" introduction to Scheme. For
the purpose of this introduction, you'll be using ``#lang racket``. We'll be
using other languages during this course, but the basic meaning of expressions
described here is not going to differ between them much.

Things
------

You write programs that compute some things given other things. We call these
things "values" or, if you want to sound sophisticated, "objects". 

.. admonition:: **Preparation**

   Lanch DrRacket, open a new file named "test.rkt" and type ``#lang racket``
   on the very first line of the file. Hit the "Run" button at the top right
   corner and see that the REPL is now ready for you. If you'd typed any
   definitions or expressions into the file, they would've been evaluated
   and the defined symbols will be available in the REPL for you to play with.
   But we're getting ahead of ourselves now.

In Scheme, there are some basic "things" we work with, which you can type
into the REPL and it will promptly give it back to you --

**Booleans**
    The notation ``#t`` stands for "true" and ``#f`` stands for "false".
    Scheme also supports "generalized booleans" - where ``#f`` is
    treated as "false", but everything else is considered to be "true".

**Numbers**
    Ordinary integers like 12 and -456, fractions like 22/7, floating
    point numbers like 31415.926e-4 . The first two types are called
    "exact numerals" since comparison of two numbers is defined.
    The floating point numbers are called "inexact" because the finite
    number of bits used to represent them means there can be round off
    errors that prevent equality comparisons without error bounds.

**Strings**
    You write strings within double quotes like ``"this simple string"``.
    You can use unicode characters within the quotes too.

**Symbols**
    Symbols are written like normal English words. You can also use
    multi-part words (like ``multi-part-word``). Symbols permit
    any character to feature in it including unicode characters,
    except brackets and backslash and spaces. If you want to make
    symbols with spaces in them, you can place the symbol text within
    vertical bars like this -- ``|this is also a symbol|``. 

    If you tried to type a symbol like that into the REPL, you'd have got an
    "undefined" error message in red. This is because when the REPL encounters
    a symbol, it tries to find out what value it has been **bound** to and
    print that instead. When no such definition is found, it prints the error.

    To prevent the REPL from doing that lookup, you can "quote" the symbol
    with a single quote prefix character -- like this ``'a-quoted-symbol``.
    If you typed that instead, you'll see that you get it back as is.


The above "things" are simple data types. Scheme also has compound "things",
given below --

**Pairs**
    These are written like this -- ``'(<first-thing> . <second-thing>)``. Note
    the quote character in front telling the REPL that it is intended to be
    treated as a "literal" and not to lookup any symbol's value or evaluate
    anything. The period character in the middle separates the first and the
    second parts of the "pair". This is also called a "cons pair".

**Lists**
    You can store many things in a compound structure by nesting pairs like
    this -- ``'(first . (second . (third . (fourth . ()))))`` -- where the last
    ``()`` stands for ``empty``. This is essentially a singly linked list which
    also has a short hand form in Scheme. You can write the exact same list as
    -- ``'(first second third fourth)``. In fact, if you'd typed the previous
    nested pair expression into the REPL, it would've shown you the second form
    in the output. Scheme does not distinguish between the two structures
    internally. Making lists is such a common use of pairs in Scheme that
    accessing the two pairs of a pair is done using functions named ``first``
    and ``rest`` respectively.

S-expressions
-------------

And then you have the famous "s-expressions" (for "symbolic expressions"),
which also look like lists, except that there is no quote character sticking in
front of it. A typically s-expression is of the form --

``(<operator> <operand-1> <operand-2> ... <operand-N>)``

The first entry in the list is special and is taken to be an "operator value"
that is then applied to the remainder of the list which would be a list of
operands, and the entire expression will be taken to mean that final result
of application of the operator. For example, type the following into the
REPL to see what you get as a result --

* ``(+ 2 3 4 5)`` 
* ``(cons 10 "hello")``
* ``(list 2 3 4 5)``
* ``(+ (* 3 3) (* 4 4))``
* ``(string->symbol "hello")``
* ``(symbol->string 'hello)``

As you can see, Scheme provides some operators out of the box. It also lets
you define your own symbols bound to values of interest to you, using the
``define`` operator, like this --

``(define <operator-symbol> <value-expression>)``

Go ahead and type the following definitions into your ``test.rkt`` file
and hit "Run" then look at what the defined symbols evaluate to in the
REPL.

.. code-block:: racket

    (define hello (string-copy "hello comp308"))
    (define pyth-triplet (list hello 3 4 (sqrt (+ (* 3 3) (* 4 4)))))

Note how an s-expression is evaluated. First the expressions featuring
in each slot of the list are evaluated. The results are then substituted
into the list. The first slot is taken as the operator and the rest of
the list as its list of operands. Then the operator is "applied" to
the list of operands to get the result. This is recursive. The expression
in the second definition above will be evaluated in the following sequence -

.. code-block:: racket

    list        ; Becomes the predefined list creation procedure
    hello       ; Becomes "hello comp308", a string
    3           ; Becomes 3, i.e. itself
    4           ; Becomes 4
    (* 3 3)     ; Becomes 9
    (* 4 4)     ; Becomes 16
    (+ 9 16)    ; Becomes 25
    (sqrt 25)   ; Becomes 5
    (list "hello comp308" 3 4 5) ; Becomes '("hello comp308" 3 4 5)

Procedures
----------

There is another operator that Scheme provides -- ``lambda`` -- that's
used to create your own procedures. The one below, for example,
creates a "hypotenuse" calculating function.

.. code-block:: racket

    (lambda (x y) (sqrt (+ (* x x) (* y y))))

The parts of a "lambda expression" are --

1. The ``lambda`` word
2. A list of unquoted symbols standing for names of each argument of the
   function.
3. A series of expressions that can make use of the symbols in the
   argument list.

If you typed the lambda expression above into the REPL, it would've printed out
``#<procedure>``, meaning it made a procedure by evaluating that expression.

For those of you familiar with Haskell, the above lambda-expression is
equivalent to the following Haskell expression --

.. code-block:: haskell

    \ x y -> sqrt (x * x + y * y)

A lot of what you see there could be called "surface structure". When
we're trying to understand programs, this surface structure is more of
a hindrance than help, so we tend to prefer simpler structures since we
can manipulate them using programs -- yes, programs manipulating programs
is easily done in Scheme and the lisp family of languages. In Scheme,
there is only one way to express the above computation within the ``lambda``,
which is ``(sqrt (+ (* x x) (* y y)))`` [#xy]_.

Since lambda expressions produce functions which are also values that can be
passed around just like numbers, strings, etc, we can give the hypotenuse
procedure a name using the known ``define`` as follows --

.. code-block:: racket

    (define hypotenuse (lambda (x y) (sqrt (+ (* x x) (* y y)))))

If you put that into the file and "Run" it, you can use ``hypotenuse``
in the REPL like ``(hypotenuse 3 4)``.

.. [#xy] ... barring the exchange of ``x`` and ``y`` variables. We don't
   consider that because in order to see that it is ok to exchange ``x``
   and ``y`` and still get the same answer, you need to know that ``+``
   is commutative -- i.e. its order of operands does not matter. This is
   not within the scope of a language that treats all operators in the same
   spirit. Of course, you're welcome to write program transformations that
   take into account such special information about specific operators.
   When you do that though, you'll still appreciate that an expression has
   unambiguous interpretation just from the syntax alone. The Haskell expression
   ``(x * x + y * y)``,for example, can be interpreted either as 
   ``((x * x) + (y * y))`` or ``(x * (x + y) * y)`` without additional
   information about the order of operations. This ambiguity does not exist
   in Scheme.

Evaluation by substitution
--------------------------

In the absence of side effects, we can evaluate any s-expression
using a process of substitution. Let's take the same example
above --

.. note:: For brevity, we'll write ``#<procedure:list>`` and such as just
   ``#<list>`` and will skip evaluation of simple entities like numbers. Note
   that ``#<procedure:list>`` is not a usable value in Scheme and is just how
   compiled procedures with a name get printed out in the REPL. We're using
   ``#<list>`` and such here only to distinguish between the symbol ``list``
   and the *procedure value* that it is bound to.

.. code-block:: racket

    (list hello 3 4 (sqrt (+ (* 3 3) (* 4 4))))
    (#<list> hello 3 4 (sqrt (+ (* 3 3) (* 4 4)))) 
    (#<list> "hello comp308" 3 4 (sqrt (+ (* 3 3) (* 4 4)))) 
    (#<list> "hello comp308" 3 4 (#<sqrt> (+ (* 3 3) (* 4 4)))) 
    (#<list> "hello comp308" 3 4 (#<sqrt> (#<+> (* 3 3) (* 4 4)))) 
    (#<list> "hello comp308" 3 4 (#<sqrt> (#<+> (#<*> 3 3) (* 4 4)))) 
    (#<list> "hello comp308" 3 4 (#<sqrt> (#<+> 9 (* 4 4)))) 
    (#<list> "hello comp308" 3 4 (#<sqrt> (#<+> 9 (#<*> 4 4)))) 
    (#<list> "hello comp308" 3 4 (#<sqrt> (#<+> 9 16))) 
    (#<list> "hello comp308" 3 4 (#<sqrt> 25)) 
    (#<list> "hello comp308" 3 4 5) 
    '("hello comp308" 3 4 5)

A simpler presentation of the above evaluation sequence can be made, which
shows more clearly that inner operator expressions get evaluated before the
outer ones. In the simpler presentation below, we'll also dispense with the
distinction between pre-defined symbols like ``list`` and their procedure
values ``#<procedure:list>``.

.. code-block:: racket

    (list hello 3 4 (sqrt (+ (* 3 3) (* 4 4))))
    (list "hello comp308" 3 4 (sqrt (+ (* 3 3) (* 4 4))))
    (list "hello comp308" 3 4 (sqrt (+ 9 (* 4 4))))
    (list "hello comp308" 3 4 (sqrt (+ 9 16)))
    (list "hello comp308" 3 4 (sqrt 25))
    (list "hello comp308" 3 4 5)
    '("hello comp308" 3 4 5)

We can similarly think of evaluating the ``(hypotenuse 3 4)``
expression using substitution as follows --

.. code-block:: racket

    ; Replace "hypotenuse" with the defined lambda expression
    ((lambda (x y) (sqrt (+ (* x x) (* y y)))) 3 4)
    ; Substitute the given values in the body of the lambda expression
    ; and get rid of "lambda" and the formal parameters.
    (sqrt (+ (* 3 3) (* 4 4)))
    (sqrt (+ 9 (* 4 4)))
    (sqrt (+ 9 16))
    (sqrt 25)
    5

The main thing to understand in the above sequence is the first step
of substituting 3 for x and 4 for y according to the declared
argument sequence.

Homoiconicity
-------------

You'd have noticed that there are two ways of evaluating expressions depending
on what operator is placed at the head of the list. For example, if you did
``(list (x y) (+ x y))``, the RPEL would've complained about ``x`` and ``y``
not being defined. However ``(lambda (x y) (+ x y))`` turns out ok. 

This is because there indeed are two types of operators in Scheme --
"procedures" and "macros". When evaluating a procedure, all the operands are
evaluated first before substituting their values for the procedure's operands.
For a macro, the argument expressions are bound as is without evaluation to the
arguments, and the macro code can decide when to evaluate them and what to do
with them. This is referred to as "macro expansion". I just mention it here for
now and we'll deal with it soon enough in the course.

We saw that there is a difference between typing ``'(+ 2 3)`` and ``(+ 2 3)``
in the REPL. The first case (with the quote prefix) produces a 3-element list
and the second produces the number ``5``. The first expression happens to be
a shorthand for ``(quote (+ 2 3))`` which is again one of those operators
that don't evaluate their arguments first. To evaluate the expression, you
can use the ``eval`` operator like this -- ``(eval (quote (+ 2 3)))`` which
will result in ``5``. It's like ``(eval (quote (+ 2 3)))`` is equivalent to
``(+ 2 3)`` -- i.e. ``eval`` undoes the ``quote`` in effect.

This "code that produces and consumes code" is possible due to the language's
structure called "homoiconicity" - usually meaning the programmer writes code
in the same structure used to represent the code internally -- in this case,
using nested lists.


What's in the box?
------------------

Scheme comes with many standard functions for working with data. You don't
need to learn all of them. You can just search the `Racket documentation`_
for relevant functions when you need them and then use them. However, a
few common forms such as ``let`` are useful to know.

Some common and useful functions --

* ``(first <list>)`` Gets the first element
* ``(rest <list>)`` Skips the first element and returns the rest of the list.
* ``(length <list>)`` the number of elements in the list.
* The usual math functions
* ``(string? <thing>)`` returns ``#t`` if the thing is a string and ``#f`` otherwise.
* Other type testing functions -- ``list?``, ``number?``, ``boolean?``, etc.
* ``(apply <fn> <list-of-args>)``  -- This results in the given
  function/procedure being applied to the given list of arguments. So ``(apply
  + (list 2 3))`` reduces to ``(+ 2 3)`` which evaluates to ``5``.


Some common useful "macro" operators --

.. code-block:: racket

    ; Sequencing computations
    (begin
        <expr-1>
        <expr-2>
        ...
        <expr-N>)  ; The value of the "begin" expression
                   ; is the value of the last expression.
                   ; The others are evaluated only for their
                   ; side effects.

    ; Choosing one of two based on a boolean expression.
    (if <condition-expression> 
        <then-expression>
        <else-expression>)

    ; Choosing one of N based on as many boolean expressions.
    ; The "else" clause is optional. When present, you can
    ; think of the "else" word being substituted by #t (for "true")
    ; and the effect will be the same.
    (cond (<cond-1> <expr-1>) 
          (<cond-2> <expr-2>)
          ... 
          (else <expr-when-no-condition-above-is-met>))

    ; The "let" form gets you local bindings for symbols
    ; only applicable within the body of the let. The body
    ; consists of a sequence of expressions which are evaluated
    ; similar to "begin" given above.
    (let ((<symbol-1> <value-1>)
          (<symbol-2> <value-2>) 
          ...)
       <expr-1>
       <expr-2>  ; These can use <symbol-1>, <symbol-2> etc.
       ...
       <expr-N>)

Note that white space doesn't matter for meaning, except that some
space must be there between the terms of an s-expression.

``read`` and ``write``
~~~~~~~~~~~~~~~~~~~~~~

The ``write`` procedure can be used to write out a serialized form of the given
value. For example ``(write '(+ 2 3))`` [#quote]_ will print out ``(+ 2 3)``
and ``(write (+ 2 3))`` will print out ``5``.

The ``read`` procedure is like a dual of ``write``, in that it will read one
expression from the input and return it in parsed form. The agreement between
``read`` and ``write`` is that **what** ``write`` **writes out,** ``read``
**can read back in**. So if you evaluate ``(read)`` in the REPL, it will
present you with a box in which you can type your input. If you type ``(+ 2
3)``, which was the output produced by the above ``write``, you'll see that
``(read)`` produced a list of three things - a symbol and two numbers. These
two functions are why the REPL is called the REPL - "read eval print loop".
The first three parts can literally be written as ``(print (eval (read)))``
in Scheme and "loop" refers to doing that over and over.

.. [#quote] Note the quote symbol on the argument to write means the argument
   won't be evaluated. Also note tha the output of ``write`` didn't have the
   quote symbol.

The end (for now)
-----------------

The above is nearly all the Scheme basics we'll need. We'll use a few
constructs built on top of these, but they will have familiar structure and
we'll go through how they can be reduce to these to understand them. There are
also a few variations used mostly for programming convenience and reducing
verbosity. We'll see these as we go along and they'll be obvious to you when we
encounter them. But conceptually, the above is what you need.

Don't be fooled by the short list above though. [#short]_ The Racket system comes with
batteries included -- a whole host of functionalities provided using modules
and sub-languages (which are also made as modules) using which you can build
sophisticated applications including `desktop GUI <GUI_>`_ applications, `web
services`_. 

You may find the absence of "loop" constructs in the above intro strange. We'll
just use recursion to do loops. They're efficient in all Scheme implementations
since the Scheme standard mandates what's called "tail call elimination" which
removes most common recursion overheads and goes a bit beyond as well. TCE
(also sometimes referred to as "tail call optimization" - TCO - or "proper tail
recursion") is gradually seeping into other languages as well.

.. _Racket documentation: https://docs.racket-lang.org/
.. _web services: https://docs.racket-lang.org/web-server/
.. _GUI: https://docs.racket-lang.org/gui/index.html

Some common niceties --

.. code-block:: racket

    (define (hypotenuse x y) (sqrt (+ (* x x) (* y y))))
    
    ; The above way of defining "hypotenuse" function means
    ; exactly the same thing as writing --

    (define hypotenuse (lambda (x y) (sqrt (+ (* x x) (* y y)))))

    ; The first is a little easier to read since it shows how hypotenuse will
    ; be used in code as well.

Racket supports unicode characters in symbol names and the Greek letter ``λ``
can be used instead of ``lambda`` as well (and is commonly used too). To type
such letters and many symbols used in math, the Racket IDE lets you use `LaTeX
symbol names <latex_>`_. To get the ``λ`` symbol, you can type ``\lambda`` and
with the cursor at the end, press the Ctrl-\\ key combination (control +
backslash) to turn the ``\lambda`` into ``λ``.

.. _latex: https://docs.racket-lang.org/drracket/Keyboard_Shortcuts.html#%28part._.La.Te.X_and_.Te.X_inspired_keybindings%29

.. [#short] Compared to what we'd have to learn for a language like Python,
   or C/C++ or Java. The only other language with similar brief explanation
   of how it works is the object oriented language Smalltalk_.

.. _Smalltalk: https://squeak.org/

Exercises
---------

Evaluate the following by the substitution approach and check your result on
the Racket REPL. All examples below are without side effects, so you don't need
to worry about duplicated expressions and can use the simple substitution
method. Hint: Do it mechanically at first, paying attention to the parentheses.
You may want to refer to how lambda expressions simplify when applied to values
in the preceding text.

.. code-block:: racket

    ; 0
    (list (+ 3 4 5 6)
          (* 14 (+ 10 5))
          (string-append "hello" " " "world"))
    (if (= (remainder 8 2) 0)
        (quotient 8 2)
        (+ (* 3 8) 1))

    ; 1
    ((lambda (x) 
       (/ (+ x (/ 1 x)) 
          2)) 
     4)

    ; 2
    (((lambda (f) 
        (lambda (x)
          (+ (f x) (f (/ 1 x)))))
      (lambda (x) (* x x)))
     4)

    ; 3
    (((lambda (f g) (lambda (x) (f (g x)))) 
      (lambda (x) (* x x))
      (lambda (x) (- x 1))) 
     10)

    ; 4
    (((lambda (f1 f2) 
        (lambda (x) (eval (f1 f2 x))))
      cons +)
     (cons 20 (cons 3 empty)))



