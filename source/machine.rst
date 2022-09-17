A mental model for the machine
==============================

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

To dive in, we can restrict ourselves to simple loops (expressed as
":index:`tail recursion`") and try to capture a mental model of our machine as
a program in its own right. When we do that, we now get something concrete on
our hands to work with and ask questions about. We can therefore use this
approach to inquire into language construction and meaning.

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

.. index:: Stack machine

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

