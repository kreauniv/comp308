A language for arithmetic
=========================

This starter language is based on the original PLAI course, but adapted
to the setting we're doing it in.

Language structure
------------------

We'll choose to implement an "expression-based language", where
everything is an "expression" and all expressions reduce to "values".
We'll also choose to do this using "eager evaluation", meaning
the reduction of an argument to a function, for example, is not
delayed until the point where the argument is required.

A plausible vocabulary
----------------------

Let's consider 2 categories of arithmetical expressions that students gave examples of --

1. "Core" such as literal numbers, addition, multiplication and reciprocal.

2. "Sugar" such as subtraction and division. The reason we call these
   as "sugar" is that these can be rewritten in terms of the "Core" terms,
   so that our interpreter will not have to deal with these terms.

We'll also need to be able to write functions on top of such expressions.

A first step to making an interpreter
-------------------------------------

In Racket, we can evaluate arithmetic expressions like this -

.. code:: scheme

    (* (- 2 4) (* (- 10 15) 24))

What we're going to consider now is suppose we're given the literal
list ``'(* (- 2 4) (* (- 10 15) 24))``, how do we write an "interpreter"
procedure that will compute the resultant answer.

Initially, we'll restrict ourselves to the core terms ``+``, ``*``
and ``inv`` and we'll define the "sugar" terms ``-`` and ``/`` in terms
of these.

The first order of affairs therefore is to convert expressions containing
a mixture of core and sugar terms into expressions that consist only of core
terms. 

.. admonition:: **Note**

    The reason for having a small core language with a growable "syntactic
    sugar" on top is that the core language becomes easier to reason about,
    since every new addition to the core language needs to be consistent
    with the other facilities we've already added.

The :rkt:`racket/match` library provides a :rkt:`match` macro that makes it
easy for us to write an :index:`interpreter` for such expressions.

.. code-block:: racket

    #lang racket
    (require racket/match)

    ; Our interpreter takes a "picture expression" and computes a picture
    ; by interpreting the instructions in it. Since these expressions can
    ; themselves contain other picture expressions, the interpreter is
    ; invoked recursively to compute them.
    (define interp-v1
        (λ (aexpr)
           (match aexpr
             [(list '+ a b) (+ (interp-v1 a) (interp-v1 b))]
             [(list '* a b) (* (interp-v1 a) (interp-v1 b))]
             [(list 'inv a) (/ 1 (interp-v1 a))]
             [_ (raise-argument-error 'interp-v1 "Arithmetic expression" aexpr)])))


We also need to define what our "sugar terms" mean. The process of converting
an expression containing sugar terms to a core-only expression is something we'll
call "desugar".

.. code:: scheme

    (define (desugar-v1 aexpr)
        (match aexpr
            [(list '- a b) (list '+ (desugar-v1 a) (list '* -1 (desugar-v1 b)))]
            [(list '/ a b) (list '* (desugar-v1 a) (list 'inv (desugar-v1 b)))]
            [(list '+ a b) (list '+ (desugar-v1 a) (desugar-v1 b))]
            [(list '* a b) (list '* (desugar-v1 a) (desugar-v1 b))]
            [(list 'inv a) (list 'inv (desugar-v1 a))]
            [_ aexpr]))
            
Observe the following -

1. To desugar a term, we must  desugar any expressions that the term may contain
   as well.
2. The desugar process must define it for all core terms in addition to the
   sugar terms.
3. Our implementation merely borrows the meanings of those operations from Racket
   directly. Unless we do this consciously and specify what we want in our language,
   we should borrowing the implementation of the underlying language into the
   language you're constructing can be a dangerous thing to do. For example, our
   from our interpreter, we cannot say what'll happen when we reduce ``'(inv 0)``.
   In this case, we'll encounter the Racket "divide by zero" error and our language
   has nothing to say about such errors at this point.

.. admonition:: **Exercise**

    What are our options for capturing this "divide by zero" situation?

.. _match: https://docs.racket-lang.org/reference/match.html

An alternative representation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We represented the "program" as simply an s-expression. Our program in this
case consisted of a single expression which our interpret "evaluated". More
typically when working on programming languages, the sub-expressions we used
are given their own data structure and a tree is made by composing these
sub-expressions. The tree is referred to as the ":index:`abstract syntax tree`"
as it captures the syntactic structure of the program, leaving aside (i.e.
absracting) the sequence of characters from which it s constructed.

In the interest of being explicit with aspects of our language and the procedures
we define on expressions in our language, we'll use Racket structs to represent
our terms and the values they reduce to.

.. code-block:: racket

    ; Core terms
    (struct NumC (n) #:transparent)
    (struct AddC (e1 e2) #:transparent)
    (struct MulC (e1 e2) #:transparent)
    (struct InvC (e1) #:transparent)

    ; Sugar terms.
    (struct SubS (e1 e2) #:transparent)
    (struct DivS (e1 e2) #:transparent)

    ; Value types.
    (struct NumV (n) #:transparent)

    ; Takes a "core-only expression" and produces a "value" struct.
    (define (interp-v2 aexpr)
        (match aexpr
            [(AddC e1 e2)
             (NumV (+ (NumV-n (interp-v2 e1))
                      (NumV-n (interp-v2 e2))))]
            [(MulC e1 e2)
             (NumV (* (NumV-n (interp-v2 e1))
                      (NumV-n (interp-v2 e2))))]
            [(InvC e1)
             (NumV (/ 1 (NumV-n (interp-v2 e1))))]
            [_ (raise-argument-error 'arith-expression "Invalid expression" aexpr)]))

    ; Takes a mixed core+sugar expression and transforms it to a
    ; core-only expression.
    (define (desugar-v2 aexpr)
        (match aexpr
            [(SubS e1 e2)
             (AddC (desugar-v2 e1)
                   (MulC (NumC -1)
                         (desugar-v2 e2)))]
            [(DivS e1 e2)
             (MulC (desugar-v2 e1)
                   (InvC (desugar-v2 e2)))]
            [(AddC e1 e2)
             (AddC (desugar-v2 e1) (desugar-v2 e2))]
            [(MulC e1 e2)
             (MulC (desugar-v2 e1) (desugar-v2 e2))]
            [(InvC e1)
             (InvC (desugar-v2 e1))]

             (NumV (+ (NumV-n (interp-v2 e1))
                      (NumV-n (interp-v2 e2))))]
            [(MulC e1 e2)
             (NumV (* (NumV-n (interp-v2 e1))
                      (NumV-n (interp-v2 e2))))]
            [(InvC e1)
             (NumV (/ 1 (NumV-n (interp-v2 e1))))]
            [_ (raise-argument-error 'arith-expression "Invalid expression" aexpr)])

    (define (interpS-v2 aexpr) (interp-v2 (desugar-v2 aexpr)))


Why bother?
~~~~~~~~~~~

We already had good enough functions that we can make use of to construct
pictures. Why would we bother to make such an "interpreter" that so blatantly
uses the same functions to do the same thing?

One part of the answer is that we're trying to understand programming
languages through the construction of such interpreters. 

The second part is the process that we went through here. We modelled a domain
using plain functions to understand what we're building first. We then turned
the kinds of expressions we wish to construct into an "abstract syntax tree"
and built an "interpreter" to build what we want. Even if we do not build a
full fledged programming language and stop here, we've done a powerful and
highly under-used program transformation or "refactoring" technique called
":index:`defunctionalization`". It is called so because we took what's
initially a set of functions and turned calculations using those functions into
a pure data structure -- the AST. The advantage of this is that this AST can
now be stored on mass media and transmitted over networks, which most host
languages will not let you do with ordinary functions, especially if they have
variables they close over.

We're however going to go further than defunctionalization and build "proper"
programming ability into our arithmetic language.

