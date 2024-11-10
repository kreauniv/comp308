Polymorphism via dispatch
=========================

When writing our procedures/functions in a programming language, we deal with different
data structures and entities such as files, network sockets and processes. For any given
system, a number of such entities serves as its "API" or "Application Programming Interface".
If each of these entities were to be transacted with using its own vocabulary, it will
become very hard for programmers to retain the vocabularies necessary to work with a
practical subset of these entity types in working memory so they act of programming is
both efficient and reliable. 

Thankfully, many of these entities can be worked with using a much smaller set of "verbs"
using which programmers typically chunk their thinking about them. For example, both hash-tables
and vectors in Racket offer the notion of associating a value with a key. Only, in the case
of hash-tables, the key can be anything "hashable" whereas in the case of a vector, the key
must be in the range :math:`[0,N)`. However, the act of getting a value associated with a
particular key can simply be thought of across all such data structures using the verb "get"
and similarly the setting of a value against a particular key can be thought of using the
verb "set".

For an analogy, consider the Harry Potter world and Hermione Granger's timely use of
the spell "Alohamora" to open a lock. Suppose that in the wizarding world, each kind of
lock required a different spell to be learnt to open it -- "Alohamora Big One", "Alohamora 42",
"Alohamora Locksmith & Sons Tiny 2021 edition" and so on -- wizards might give up pretty soon.
But we have a hint here -- that the word "Alohamora" suggests that the lock needs to be opened,
and the ones programming these locks can determine what to do when the lock hears the spell
"Alohamora", instead of making custom spells for it. This would then obviously be preferrable
for wizards (and students!) since they would then need to remember far fewer spells overall
to be effective in their world. 

Racket library functions kind of work as though they were in that complicated world of
spells. In Racket, though you'll find procedures named according to such common vocabulary,
each data structure carries its own set of procedures to work with it. So vectors come
with ``vector-get`` and ``vector-set!`` and ``vector-length``, and similarly hash-tables have
``hashtable-get``, ``hashtable-set!`` and ``hashtable-length``. If we were to invent another
data structure, say, ``tree-map``, then we'll have to expose yet more procedures named
``tree-map-get``, ``tree-map-set!`` and ``tree-map-length`` that will do analogous things with
tree-maps. If we choose completely different vocabularies -- say, ``tree-map-search-and_retrieve``,
``tree-map-find-and-replace`` and ``tree-map-count-entries`` -- we'd place a huge cognitive
burden on programmers who'd want to adopt our new data structure since they cannot reuse
their vocabulary in the new context.

What if we could simply say ``get``, ``set!`` and ``length`` and when we introduce a new data
structure, be able to declare how these verbs should work with it at that point? That way,
if we have a vector ``v``, we get get its ``k``-th element using ``(get v k)`` and if we have a
hashtable ``h`` and a key ``k``, we can get its associated value using ``(get h k)`` as well,
instead of ``(hashtable-get h k)``. It is quite evident that the cognitive burden is lower
for such a unified concept of "``get``-ting" a value. While doing this makes for concise code
while writing, we also notice that when reading code, ``(get h k)`` tells us very little about
``h`` than "something we can call ``get`` on", whereas ``(hashtable-get h k)`` is amply clear.
This is part of the reason for that design choice in the Scheme language.

Such a multi-purpose definition of a verb like ``get`` and ``set!`` is referred to in programming languages as
"polymorphism" and the verb is said to be "polymorphic" over a collection of types.

.. admonition:: **Polymorphism**
    
    The language facility by which a verb can result in different actions depending on
    which entity/entities it is addressed to.

Simple dispatch
---------------
