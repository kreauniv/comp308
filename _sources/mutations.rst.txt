Mutations
=========

Much in the history of programming languages has been concerned with what we'd
call "imperative" style of programming. This involves thinking of a program as
"performing a sequence of steps" and less as "computing a particular value from
some set of input values".

While the notion of "sequencing" appears to dominate that description, we need to
look deeper to see why such a sequencing even deserves a mention there. 

Let's look at a typical computer architecture --

.. figure:: images/computer.png
   :align: center
   :alt: A diagram of components of a modern computer. Features a CPU, data storage,
         program memory, I/O devices and the network.

   Core components of a modern "computer".

Such a computer features a CPU at the heart, which pull a sequence of instructions
from the "program memory" and "executes" them one by one. Some of these instructions
may ask the CPU to fetch some data from the data storage, or to write data into
some locations in the data storage, or to read/write data to the network or chosen
I/O devices.

So the journey of a program is close enough to how we've been expressing the
:rkt:`stack-machine` in earlier sections, except we didn't have explicit notions
of I/O devices or network. The :rkt:`stack-machine` function serves as our "CPU"
model, the list of instructions or "program" serves as our model of the "program
memory" and the stack and bindings are part of the data storage.

In the "expression evaluator" formulation though, we formulated our language
there as though evaluating an expression has no other consequences than
computing the result value. The "bindings" argument (i.e. the "environment")
was incidental to this calculation. This corresponds to the stack picture as
well, if we throw away the bindings as a "result" and only consider what's on
the stack as the intended result.

If you think of data memory as addressed using whole numbers, then both our
languages don't quite have the equivalent of "read an integer from memory
location 132357" and "write the integer value 42 to memory location 238576".
With these kinds of operations, it is clear that the order of the operations
critically affects the computation performed. If you write to a memory location
and read it back, you'll get the value you wrote, but if you read it and then
write a different value back, the value you read in could be something else.

Therefore, the need for sequencing arises (at least in this case) as a side
effect of a model of computation where we're reading from and writing to
addressable memory locations that're **mutable**.

The Racket "box"
----------------

Racket provides an entity called a "box" that is akin to a one-element mutable
vector. A box is either empty or has something in it and you can change the
contents of the box.

.. code-block:: racket

    (define b (box 24))
    (display (unbox b))  ; Prints 24
    (set-box! b 42)
    (display (unbox b))  ; Prints 42

We can treat such a mutable box as a reference to a storage location in data
memory of our computer. The symbol :rkt:`b` in the above example is bound to
this "memory location". So the :rkt:`unbox` procedure can fetch the contents of
this memory location and the :rkt:`set-box!` procedure can modify its contents.
As seen in the example above, between the first :rkt:`display` call and the
next, something has happened to the box. It is this "something" that we intend
to model in our interpreter. We'll consider both models -- the expression
evaluator we've called :rkt:`interp` as well as the :rkt:`stack-machine`.








