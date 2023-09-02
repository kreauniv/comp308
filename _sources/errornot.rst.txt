On the choice between "error" and "do something reasonable" in design
=====================================================================

As some of you noted in your implementations, you faced a choice between using
(error ..) and returning a default or nil-potent value of some kind (like zero,
empty list). This is common choice point that we need to face when designing
functions. There is relatively little in terms of "science" to this though and
in the case of user interfaces is more "art" than "science". To the extent
there is, here are some thoughts --

A function is said to be "**total**" in the domain of its arguments, if for
every possible argument it terminates with a valid value in its co-domain.
Total functions are easy to program and reason with. However they're somewhat
of a rarity as well. Given that the reason to lean towards total functions is
that they become **easier to reason with**, that ought to be useful as a
criterion to go for making a function total by specification. i.e. if making it
total is not making it easier to reason with, then there may be benefit to
introducing error behaviours. 

One way a function can be (somewhat artificially) made total is to make its
result a "**sum type**" or (in Racket teminology) a "**union**" of possible
types. For example, we've used :rkt:`(U False Value)` as the result type of
lookup functions. When choosing this, consider whether the types involved in
the union have any overlap. It is easier to reason if they don't overlap (i.e.
are "disjoint"). For example, if :rkt:`Value` can include :rkt:`Boolean`, then
:rkt:`(U False Value)` is superfluous and not informative or useful as a type.
Go for a sum type result if the function cannot know whether the conditions
under which it returns the various types are true "errors" as far as the
program goes and the caller has to decide that. In some cases, the caller may
choose to wrap such a function into a total function and in other cases the
caller may wrap it to raise an error. An example of this is our "lookup"
function that **may** give you a value associated with an identifier. Go for an
error if there is some **contract** that would be violated if some property of
the arguments does not hold. This is often the case in writing interpreters
where you (usually) want to fail early on encountering an invalid program
instead of trying to do something "reasonable" with invalid input. One of the
points in favour of compiled languages (especially those with good type
systems) is to signal "bad program" **BEFORE** the program gets to run and
(maybe) cause damage -- think programs used in nuclear reactor control or X-ray
machine control. We'll discuss type systems soon in this course. 

So far, we've only used :rkt:`(error ...)` in a way where our programs bomb
totally and terminate on encountering an :rkt:`(error ...)` expression. In case
you missed a central point of this course -- **this is also a design choice**!
For many kinds of target domains, such "unwind the stack until you reach a
handler or terminate" is a usable and efficient means of dealing with such
errors. Such an "unwinding of the stack" is a simple "one shot continuation"
that can be efficiently implemented on most hardware at O(1) space and time
cost. Some languages like Common Lisp don't unwind the stack, but give control
to the higher level error handlers so they can decide what to do -- whether to
terminate the program, or "bubble up" the condition to the next handler, or
make a correction and resume or restart the operation that produced the
condition with a different starting point. This is a powerful tool in the hands
of good programmers who know that higher up in the call sequence there is more
information available to decide what to do about an error condition than down
in the deeps of the call sequence. Common Lisp therefore does not call these
"errors" and uses "conditions" to talk about them, because the handler may
choose to ignore a condition if it sees fit. A limited version of this flexible
approach was also useful in the context of my own muSE dialect of Scheme used
to express video editing styles -
https://github.com/srikumarks/muSE/wiki/ExceptionHandlingLinks to an external
site. . 

The language Erlang and its newer protege "Elixir" use "processes"
(memory-isolated concurrent distributed computational units with a message
queue) as a primitive. Processes are cheap in Erlang and can cost as little as
300 bytes compared to about 1MB for a thread in, say, C++. So the Erlang design
philosophy encourages a kind of "happy path" style - where it is considered
perfectly reasonable to "**just crash**" on error. Only the process running the
code will terminate and Erlang libraries (called "OTP" for Open Telephony
Platform) provide utilities and patterns for how to handle such crashes to
build error resilient systems -- through restarts and process "supervisor
trees". 

You can design **arbitrary** control structures using reified continuations. So
you could work out the details of the ideal control mechanisms for a particular
domain and model them using continuations to understand their semantics before
you commit to an existing mechanism such as "exceptions". You'll then be in a
position to decide whether a new control structure is appropriate or an
existing one will do. In most of the common programming languages, the language
designers have made some reasonable default choice of mechanism for you. You're
now a language designer too, so you may find their choice "unreasonable" in
your context and can do something about it.
