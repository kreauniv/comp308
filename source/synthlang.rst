A language for basic sound synthesis
====================================

.. admonition:: **Note**

    For the track based on arithmetic expressions, see :doc:`arithlang`.

The original PLAI course used arithmetic to introduce some ideas. In this
variant, we use a simple model of sound synthesis processes to construct a
language we can use analogous to :doc:`piclang`. The motivation to introduce
these small "domains" is that they help anchor the discussions on programming
languages, and when they are not too familiar, help students ask key questions.

.. note:: We're not going to be building a full fledged synth toolkit. What
   we're interested in is making (hopefully) some simple sounds and compositions.
   The ideas here form the basis for `Synth.jl`_.

.. _Synth.jl: https://github.com/srikumarks/Synth.jl

Growing a language for sounds
-----------------------------

We're about to launch off a precipice in our efforts to figure out a language
for generating sounds. When we set out on such a task in any domain, there are
a few things we need to do to build up our understanding of the domain first.
What are you going to build a language for if you don't understand it in the
first place? We'll need to --

1. Get a sense of the ":index:`vocabulary`" we want for working with sound generation.

2. Get a sense of how we wish to be able to generate sounds, transform them
   or combine more than one to form a new sounds.

3. Figure out the essence of sound composition -- i.e. a minimal ":index:`core
   language`" in which we we can express the ideas we're interested in. Translate
   more specific ideas into this core language.

Note that we do not need to get all of this right at the first shot. We can
take some reasonable steps and improve what we have at hand when we recognize
the opportunity. To do that effectively, we'll need to keep our eye on the
mentioned "minimal core" as we go along.

.. index:: Guy Steele, Growing a language talk

.. admonition:: **Credits**

    This section is named in honour of an amazing talk of the same title by Guy
    Steele, the co-creator of Scheme - `Growing a language, by Guy Steele
    <gal_>`_ (youtube link) given in 1998. It is a fantastic talk and a great
    performance & delivery, that I much recommend students watch and
    contemplate on. The beginning of the talk may unfortunately put off some as
    it appears sexist, but Guy is aware of it and explains himself a little
    into the talk. So do press on.

.. _gal: https://www.youtube.com/watch?v=_ahvzDzKdB0

A plausible vocabulary
----------------------

We hear a sound when a pattern of vibration hits our ear drums, causing them to
vibrate according to the incoming air pressure patterns. When these vibrations
are represented in a computer, we need to convert them into numbers and so we
"sample" them at a sufficiently high frequency (called the "sample rate") and
measure the pressure values at these instants. This process is called "analog
to digital conversion" ("ADC" for short). We can then reproduce these sounds by
converting this sequence of numbers into air pressure influences emitted
through a speaker. This process is called "digital to analog conversion" ("DAC"
for short).

The auditorily simplest sound is a tone with a specific "pitch" and "volume".
Such a tone is a periodic (in time) waveform with a specific *period*
corresponding to its pitch and a specific *amplitude* corresponding to its
volume. The two pairs of concepts are related but not the same. While "pitch"
is a perceptual aspect comparable to "colour" in the visual field, "period" or
equivalently "frequency" is a definable objective property of the waveform
itself. Similarly, while "volume" is a perceptual aspect, "amplitude" is a
definable objective property of the waveform.

.. math::

    \begin{array}{rcl}
    \text{pitch} & \approx \propto & 12 \log_2(\text{frequency}) \text{  } (\text{in semitones}) \\
    \text{volume} & \approx \propto & 20 \log_{10}(|\text{amplitude}|) \text{  } (\text{in dB})
    \end{array}

A tone that lasts for ever at the same amplitude and frequency doesn't make
for much music, does it? At the very least, we want tones to decay over time
to mimic, say, a vibrating string. And we want a pattern of frequencies in
time to make a melody. 

The shape of the periodic waveform that makes a tone defines its "timbre"
(pronounced "tahmbur") or "colour". The most colourless of these tones is
perhaps the "sinewave" - which is easily modelled by the mathematical expression
:math:`\sin(2\pi ft)` where :math:`f` is its frequency and :math:`t` is the
time. This tone has amplitude :math:`1.0` and to get a different amplitude,
we just have to multiply it by the scale factor we need, such as :math:`0.5`.

It so happens that we can build up more complex tones if we only had sinewaves
available at our disposal, by mixing sine waves of different frequencies with
different amplitudes.

The above description gives us a starting point for building up our vocabulary.
To build up our language, we are free to think at as high a level as we want to.
Our only intent here is to capture the idea of how we wish to construct a sound,
without concern for how we're actually going to turn the construction into actual
sound. S-expressions are great for this purpose, so let's dive in.

A sinewave oscillator that is vibrating at a particular frequency can be written
as --

.. code:: racket

   (oscil <freq>)

If we want to scale this oscillation to a different
amplitude, we can write it as -- 

.. code:: racket

    (mod <amp> (oscil <freq>))

This is already interesting in many ways.

1. By writing :rkt:`(mod <amp> (oscil <freq>))` we're saying "make a new tone with
   a different volume by scaling this oscillation. This means the following expression
   should be interpretable too - :rkt:`(mod <amp1> (mod <amp2> (oscil <freq>)))`.
   There is already a "sound transformation as expression composition" emerging here.

2. We have another choice at hand - where if we're always going to think of an oscillator
   as having an amplitude and a frequency, we could've written :rkt:`(oscil <amp> <freq>)`
   and the leave the details for later. 

.. admonition:: **Think**

   Is any one approach better than the other in some objective sense for our
   domain? Note that neither of the approaches is "wrong".

We've left out what the :rkt:`<amp>` and :rkt:`<freq>` are supposed to be. Obviously we
want to be able use fixed numbers for these like :rkt:`(mod 0.5 (oscil 440.0))` which
is a tone oscillating at :math:`440\text{Hz}` with an amplitude of :math:`0.5` ... and
we should have that make sense in our language. But what would something like this mean?

.. code:: racket

    (mod (oscil 2.0) (oscil 440.0))

The only reading is that we're varying the ampltiude of the 440Hz oscillation
at a low frequency of 2Hz. When we render this as a sound snippet, we would perhaps
expect the volume to go up and down audibly. 

.. admonition:: **Question**

   How many times should you expect the **volume** to go up and down every
   second in this case?

This is called "amplitude modulation" in synthesis parlance. To "modulate" means
to "vary" and in this context we're varying the "amplitude". So could we also perhaps have
the frequency of the oscillator here be modulated? -

.. code:: racket

    (oscil (mod 440.0 (oscil 2.0)))

Let's think about what the above expression could mean. We can pick it apart bit by bit.

1. :rkt:`(oscil 2.0)` is something we know - a sine wave oscillation between :math:`-1.0`
   and :math:`1.0` that oscillates twice every second.

2. So :rkt:`(mod 440.0 (oscil 2.0))` is a sinewave oscillation that varies between 
   :math:`-440.0` and :math:`440.0` twice every second.

3. If step 2 is supposed to be in the frequency position of the outermost
   :rkt:`(oscil ...)`, that would stand for the concept "an osciallator whose
   frequency varies from :math:`-440.0` to :math:`440.0` Hz twice every second.
   Negative frequencies are indistinguishable to the ear from positive
   frequencies since they're both "oscillations". So this will sound like the
   frequency is oscillating between :math:`0.0` Hz to :math:`440.0` Hz four
   times a second. 

In audio synthesis parlance, we call this "frequency modulation".

We're building up a language for expressing simple sounds. So now we may want to
ask what if I want to express the idea of the frequency oscillating between, say, 300Hz
and 400Hz twice a second instead of from 0 to 440Hz. How might we want to write that?

.. admonition:: **Think**

   Try to come up with a few ways of expressing that idea on your own first,
   using s-expressions. It is just a way to write it down. We don't yet need
   to consider how we're evaluating it.

Here is a candidate.

.. code:: racket

    (oscil (+ 350.0 (mod 50.0 (oscil 2.0))))

While that looks reasonable, we're playing too loose with our notation here.

.. admonition:: **Think**

    What exactly is too loose about that notation? Think about it first for 5
    minutes before proceeding because spoilers are ahead.

It is like we want to think about adding a number ("350.0") with an expression
that we think of as sound (:rkt"(mod 50.0 (oscil 2.0))") or at least as an
"oscillation". The simpler thing to do here instead of rethinking the notion
of addition is to look closely at what we meant when we used the number 
:math:`440.0` as a frequency or the number :math:`0.5` as the amplitude.
In particular, we considered using an :rkt:`(oscil 2.0)` in place of the
amplitude number :math:`0.5`!

While we wrote a number, we chose to model these two aspects as plain numbers,
but what we meant was that these numbers stand for values that don't change over
time. If we make that notion explicit, we may write it as :rkt:`(konst 440.0)`
and :rkt:`(konst 0.5)`.

Now since :rkt:`(konst 300.0)` and :rkt:`(oscil 2.0)` are the same *kinds* of 
things, we can define the operation of "mixing" two such waveforms by introducing
another word :rkt:`mix`.

.. code:: racket

    (oscil (mix (konst 350.0) (mod (konst 50.0) (oscil 2.0))))

In our case, we might just want to define :rkt:`mix` using mathematical
addition sample by sample, i.e. :rkt:`(mix (konst a) (konst b)) = (konst (+ a
b))`. Similarly we have :rkt:`(mod (konst 0.0) <expr>) = (konst 0.0)`.
We should also be expecting the following to hold --

.. code:: racket

    (mix <s1> <s2>) = (mix <s2> <s1>)
    (mix <s1> (konst 0.0)) = <s1>
    (mod <s1> (konst 0.0)) = (mod (konst 0.0) <s1>) = (konst 0.0)
    (mod (konst 1.0) <s1>) = <s1>
    (mix <s1> (mix <s2> <s3>)) = (mix (mix <s1> <s2>) <s3>)
    (mod <s1> (mod <s2> <s3>)) = (mod (mod <s1> <s2>) <s3>)
    (mod <s1> (mix <s2> <s3>)) = (mix (mod <s1> <s2>)
                                      (mod <s1> <s3>))

If we further wish to generalize :rkt:`(mod (mix (konst a) (konst b)) <s1>) =
(mix (mod (konst a) <s1>) (mod (konst b) <s1>))`, we might want to add the
following symmetry as well, though it is not an inevitable conclusion. --

.. code:: racket

    (mod <s1> <s2>) = (mod <s2> <s1>)

So we understand what our "mix" and "mod" expressions now mean and we're
starting to describe properties of these operations. Given how closely we
thought of "mix" as being addition and "mod" as being multiplication, we should
very much expect to model these using those mathematical operations.

.. admonition:: **Stuff, structure and properties**

    When we're working out a particular domain, it is useful to look at three
    aspects - a) what is the "stuff" we're working with .. the nouns, b) how
    are we making this stuff using other stuff .. i.e. what is the structure
    we're adding to these nouns? and c) what properties do these combination
    and transformation operations have.

While we can describe some sounds that last forever using the above constructs,
we also want to be able to describe time limited and time shifted sounds.

1. If we want to talk about sound :rkt:`<a>` **starting** 4.0 seconds from t=0, we
   can write :rkt:`(after 4.0 <a>)` where :rkt:`<a>` is any expression that
   stands for a sound. This adds another "structure", whose "property" is
   :rkt:`(after d1 (after d2 <s1>)) = (after (+ d1 d2) <s1>)`. Since we can't
   move sounds into the past, we treat all the :rkt:`d1` and :rkt:`d2` that are
   less than 0.0 as equivalent to 0.0. So we should more precisely express that
   property as - :rkt:`(after d1 (after d2 <s1>)) = (after (+ (max 0.0 d1) (max
   0.0 d2)) <s1>)`.

2. We also want to be able to stop or "cut" a sound after some seconds. We can write
   this idea as :rkt:`(cut dur <snd>)`. The meaning here is that until :rkt:`dur`
   elapses, this expression is indistinguishable from :rkt:`<snd>`. After :rkt:`dur`
   elapses, this expression is equivalent to :rkt:`(konst 0.0)`. Such a "cut"
   has the property :rkt:`(cut d1 (cut d2 <snd>)) = (cut (min d1 d2) <snd>)`
   assuming both durations to be positive.

Wait a minute. We want to make music, i.e. we want to be able to **sequence** or
"stitch" sounds one after another to make patterns. We can introduce another
operator to stitch two sounds together at a certain time.

.. code:: racket

    (stitch <s1> dur <s2>)

The meaning being before :rkt:`dur` has elapsed, the resultant sound is equivalent to
:rkt:`<s1>` and :rkt:`<s2>` begins and :rkt:`<s1>` ends exactly after :rkt:`dur`
has elapsed. Just by how we're talking about it, it should be apparent that we can
express this idea using things we've already described.

.. code:: racket

    (stitch <s1> dur <s2>) = (mix (cut dur <s1>) (after dur <s2>))

.. admonition:: **Syntactic sugar**

    We just defined a "new" concept in terms of structure we've already
    articulated. At such a point, we should pause and think whether we want
    this new word to be genuinely a new word in our language or something we
    introduce as "syntactic sugar" in it - something that we'll mechanically
    expand out into its definitionally equivalent form before constructing the
    specified sound using only the primitive structures. On the other hand, we
    can still choose to make this a primitive for other auxiliary reasons such
    as performance -- for example if we're able to implement the "stitch"
    operator more efficiently if we do it directly rather than through the
    primitive operators in our language.

    If we perform the expansion, then we gain the ability to examine the
    correctness properties of our audio renderer without having to worry about
    another operator that needs to be examined/tested with every other
    operator. The savings from this during language design are significant
    enough that it is an important consideration before you choose your stand.

.. admonition:: **Think**

    What is the difference between the above definition of :rkt:`stitch`
    and the alternative below? (Refer to definitions of ``cut`` and ``after``
    given earlier.) --

    .. code:: racket

        (stitch <s1> dur <s2>) 
            = (mix (mod (cut dur (konst 1.0)) <s1>)
                   (mod (after dur (konst 1.0)) <s2>))

Apart from oscillations, it is useful to be able to modulate sounds using linear
"envelopes". So we'll add one final operator for that.

.. code:: racket

    (line a dur b)

This represents a "sound" (not really a sound, but just a time varying value)
that starts at the value :rkt:`a` and over the course of :rkt:`dur` seconds
linearly rises (or falls) to :rkt:`b` and after :rkt:`dur` seconds stays fixed
at value :rkt:`b`.

The language and its interpreter
--------------------------------

Now we need to be able to express any expression in our language as a data structure
we can process into a sound using some, as yet unknown, algorithm.

.. code:: racket

    (define-type SndExpr (U oscil mod mix konst after cut line))
    (struct oscil ([freq : SndExpr]))
    (struct mod ([a : SndExpr] [b : SndExpr]))
    (struct mix ([a : SndExpr] [b : SndExpr]))
    (struct konst ([v : Real]))
    (struct after ([dur : Real] [snd : SndExpr]))
    (struct cut ([dur : Real] [snd : SndExpr]))
    (struct line ([a : Real] [dur : Real] [b : Real]))

To define an interpreter for SndExpr, we need to decide what interpreting such
an expression is expected to produce. Since we want to render our sounds to
a file, we can think of our interpreter as producing a vector of samples generated
at a certain sampling rate that we can then write to a file using a separate
utility function.

.. code:: racket

    (: interp (-> Real Real SndExpr (Vectorof Real)))
    (define (interp sample-rate duration sndexpr)
        ...)


This would perhaps be not a bad way to do it in the general case. However,
we've designed our language as an "expression language" where there is some
recursive structure to how we can "compose" our sound specification
expressions. We can therefore use the general nature of lambda functions to
model our operators and write a separate renderer using the underlying function
based representation. We might call this the "reference implementation" of the
language.

A model for the sound expressions
---------------------------------

In our case, we can model each sound as a "generator" which, when asked,
produces a sample and another generator for the rest of the sound.
Note the recursive way we've described it. We can directly model this
structural recursion using functions.

.. code:: racket

    (struct step ([val : Real] [gen : Gen]))
    (define-type Gen (-> Real step))

    ; As a warm up, we define the simplest of them.
    (: konst (-> Real Gen))
    (define (konst v)
      (lambda (dt)
        (step v (konst v))))

The above definition of :rkt:`konst` already demonstrates the "temporal
recursion" in the definition. For the other operators, we're going to
have to do something similar.

.. code:: racket

  (: oscil (-> Gen Gen))
  (define (oscil freq)
    ; Using a helper function here since we need to accumulate
    ; phase from one time step to the next.
    (define (oscil* freq phase)
      (lambda (dt)
        (let ([f (freq dt)])
          (step (sin (* 2 pi phase))
                (oscil* (step-gen f) (+ phase (* (step-val f) dt)))))))
    (oscil* freq 0.0))
  
  (: mod (-> Gen Gen Gen))
  (define (mod a b)
    (lambda (dt)
      (let ([av (a dt)] [bv (b dt)])
        (step (* (step-val av) (step-val bv))
              (mod (step-gen av) (step-gen bv))))))
  
  
  (: mix (-> Gen Gen Gen))
  (define (mod a b)
    (lambda (dt)
      (let ([av (a dt)] [bv (b dt)])
        (step (+ (step-val av) (step-val bv))
              (mod (step-gen av) (step-gen bv))))))
  
  
  (: after (-> Real Gen Gen))
  (define (after dur s)
    (if (<= dur 0.0)
        s
        (lambda (dt)
          (step 0.0 (after (- dur dt) s)))))
  
  (: cut (-> Real Gen Gen))
  (define (cut dur s)
    (if (<= dur 0.0)
        (konst 0.0)
        (lambda (dt)
          (let ([v (s dt)])
            (step (step-val v)
                  (cut (- dur dt) (step-gen s)))))))
  
  (: line (-> Real Real Real Gen))
  (define (line a dur b)
    ; Helper function since we need to keep track of time.
    (define (line* a dur b t)
      (if (>= t dur)
          (konst b)
          (lambda (dt)
            (step (+ a (* (/ t dur) (- b a)))
                  (line* a dur b (+ t dt))))))
    (line* a dur b 0.0))
  
Given this representation, we can render a sound to a file using a procedure of
the following shape (i.e. pseudo-code) -

.. code:: racket
   
    (define (render-to-file filename sndgen dur sample-rate)
      (call-with-output-file filename #:exists 'replace
        (lambda (f) 
          <write-file-header>
          (define (loop dt t gen)
            (when (<= t dur)
              (let ([v (g dt)])
                (write-sample-to-file f (as-float32 (step-val v)))
                (loop dt (+ t dt) (step-gen v)))))
          (loop (/ 1.0 sample-rate) 0.0 sndgen))))

.. admonition:: **See `asynth.rkt`_**

    You can simply load the linked :rkt:`asynth.rkt` file to define the
    interpreter we're working through here as it provides all the necessary
    code and more sound operators if you want to play around. Since the
    symbols it provides have the same name as the structs we've defined here,
    you'll want to import it with a prefix like -

    .. code:: racket

        (require (prefix-in a: "./asynth.rkt"))

    The function ``konst`` in the file will now be available as ``a:konst``.

.. _asynth.rkt: https://github.io/kreauniv/comp308/blob/main/source/asynth.rkt

The interpreter
---------------

We've chosen to define our language as an "expression language", which has
recursive structure in its syntax. The :rkt:`struct` s we've defined above to
hold the various terms help us represent the various sub-expressions as we
write out our intended sound using them.

Expression languages lend themselves nicely to being modelled in terms of
lambda functions for the purpose of studying their structure and properties
since lambda expressions themselves have an aligned structure. This doesn't
mean that if we hadn't defined our language as an expression language we
couldn't have used lambda functions. It is just that our modelling task will
get more complicated in such cases.

So, given the lambda-based model in `asynth.rkt`_ and the availability of
a procedure to render a sound to a WAV file, we can redefine the type of
our interpreter (for the moment) like this --

.. code:: racket

    (require racket/match)

    (: interp (-> SndExpr a:Gen))
    (define (interp sndexpr)
        (match sndexpr
            [(konst v) (a:konst v)]
            ...
            ))

.. admonition:: **TODO**

    Read the documentation for match_ in the Racket docs to understand how the
    pattern is being specified in the code above. In particular, lists can be
    matched using the :rkt:`list` constructor based expression. Quoted symbols
    will be matched literally and unquoted symbols will be taken as variables
    to be bound to the values in the corresponding slots in the list.

.. _match: https://docs.racket-lang.org/reference/match.html


.. admonition:: **TODO**

    Try and fill out the match branches for the other operators in our language.
    We'll need one for each struct we've defined above since we need to cover
    all the cases in ``SndExpr``. It is not a coincidence that the AST terms
    and our lambda-based reference implementation share a similarity.

.. admonition:: **AST: Abstract Syntax Tree**

    The ``SndExpr`` type characterizes a tree of expressions that makes
    up terms in our language. Looking at ``interp`` and how it directly
    interprets this tree, we can see how the interpreter operationalizes
    the meaning of our terms. This tree captures the logical structure of
    our terms, even if we might choose to literally write out our terms
    in a different form, say --

    .. code::

        (oscil(300.0) + oscil(200.0)) * oscil(2.0)

    This is what we meant when we said we aren't going to be concerned
    about "syntax" - we'd convert both into the same "abstract syntax tree"
    anyway.

Syntactic sugar and "desugaring"
--------------------------------

We haven't yet made up our minds about how we'll bring the ``stitch`` operator
into our language - as syntactic sugar or as a primitive. But before that, we
have to examine what we expect of it. Consider this --

.. code:: racket

    (stitch (konst 0.0) dur <s>)
        = (mix (cut dur (konst 0.0))
               (after dur <s>)) ; By definition
        = (mix (konst 0.0) ; Since (cut dur (konst 0.0)) = (konst 0.0)
               (after dur <s>))
        = (after dur <s>) ; By the `mix` identity stated earlier.

And also this --

.. code:: racket

    (stitch <s> dur (konst 0.0))
        = (mix (cut dur <s>)
               (after dur (konst 0.0))) ; By definition
        = (mix (cut dur <s>)
               (konst 0.0)) ; Since (after dur (konst 0.0)) = (konst 0.0)
        = (cut dur <s>) ; By the `mix` identity stated earlier.

So it looks like if we have ``stitch`` as an operator, we can **desugar**
both ``after`` and ``cut`` using ``stitch``! This would reduce the number
of primitives by one, simplifying our language. Accounting for such
syntactic sugar has some consequences.

1. Our interpreter ``interp`` does not have to change in its structure!
   This is great, but its type does change slightly to make clear what
   kinds of expressions it works with. We'll see how it changes shortly.

2. We need a new ``desugar`` procedure to translate the sugar terms into
   ordinary terms in our language.

So let's introduce ``stitch`` as a primitive into our language and the
other ``after`` and ``cut`` as syntactic sugar on top of ``stitch``.

.. code:: racket

    (define-type SndExpr (U oscil mod mix konst stitch line))
    (struct oscil ([freq : SndExpr]))
    (struct mod ([a : SndExpr] [b : SndExpr]))
    (struct mix ([a : SndExpr] [b : SndExpr]))
    (struct konst ([v : Real]))
    (struct stitch ([a : SndExpr] [dur : Real] [b : SndExpr]))
    (struct line ([a : Real] [dur : Real] [b : Real]))

    
So should we introduce the new sugar terms below?

.. code:: racket

    (struct after ([dur : Real] [a : SndExpr]))
    (struct cut ([dur : Real] [a : SndExpr]))

.. admonition:: **Think**

    Take 5 mins to think about what the above type declarations are saying
    and what the consequences of choosing this type declaration would be.
    Do this *now*, 'cos spoilers ahead.

.. dropdown:: Click to reveal spoilers

    In our case, ``SndExpr`` is a union of the "core" terms in our language
    only. So we cannot add ``stitch`` to that set. However, we need an
    expression type for the ``a`` parts of ``(cut dur a)`` and ``(after dur
    a)``. If we use ``SndExpr`` for that, we're saying that we can only use
    core terms within the ``cut`` and ``after`` expressions. Furthermore, we're
    saying that we these core terms cannot themselves contain ``cut`` or
    ``after``!

    i.e. ``cut`` and ``after``, specified this way, are not as good as any
    other operator in our language as far as the language's users (pretending
    we have some) are concerned. We want them to be on the same grounding and
    therefore we must handle nested forms for both sugar expressions **and**
    core expressions.

Consider :rkt:`(struct oscil ([freq : SndExpr]))`. With desugaring in the
picture, we have to now realize that this ``oscil`` concept is not one, but
two -- a) oscil which only permits core terms in its frequency expression
place, and b) oscil which permits sugar terms as well for its frequency
specification.

Like we do with abstraction of ordinary expressions, we can parameterize the
``oscil`` type like this --

.. code:: racket

    (struct (e) oscil ([freq : e]))

This makes ``oscil`` not a type, but a "type constructor". We get a type when
we "apply" ``oscil`` to another type. We can likewise parameterize all our
terms so that we can construct their sugar and core variants. Of all our terms,
``konst`` and ``line`` don't need such parameterization.

.. code:: racket

    (struct (e) oscil ([freq : e]))
    (struct (e) mod ([a : e] [b : e]))
    (struct (e) mix ([a : e] [b : e]))
    (struct konst ([v : Real]))
    (struct (e) stitch ([a : e] [dur : Real] [b : e]))
    (struct line ([a : Real] [dur : Real] [b : Real]))

    (struct (e) after ([dur : Real] [snd : e]))
    (struct (e) cut ([dur : Real] [snd : e]))

Now we're ready to define what "core expressions" and "sugar expressions" are.

.. code:: racket

    (define (e) SndExpr (U (oscil e) (mod e) (mix e) konst (stitch e) line))

    ; Core expressions can only contain other core expressions as sub-terms.
    (define-type SndCore (SndExpr SndCore))

    ; Sugar expressions permit sugar terms or core terms which may in turn
    ; contain other sugar expressions as sub-terms.
    (define-type SndSugar (U (after SndSugar) (cut SndSugar) (SndExpr SndSugar)))

The type of our ``interp`` function now changes slightly, though its implementation
does not (apart from getting rid of ``after`` and ``cut`` and replacing it with ``stitch``).

.. code:: racket

    (: interp (-> SndCore a:Gen))

We now need to define the process of "desugaring" expressions into their
core form. The type of this procedure should now make sense.

.. code:: racket

    (: desugar (-> SndSugar SndCore))
    (define (desugar expr)
        (match expr
            [(after dur a)
             (stitch (konst 0.0) dur a)]
            [(cut dur a)
             (stitch a dur (konst 0.0))]))

.. admonition:: That doesn't work! Fix it!

    If you run that definition by typed/racket, you'll find that it does not
    type check. Find out what's wrong with it and fix it.

.. dropdown:: So what's wrong? (spoilers)

    In the body of the expanded form of ``stitch``, we use ``a`` and ``b``.
    These are, according to the type of the input ``expr``, of type ``SndSugar``.
    In order to produce an ``SndCore`` result, these need to be of type
    ``SndCore``. But we now have a procedure to convert ``SndSugar`` to ``SndCore``
    -- it's called ``desugar``! So we desugar recursively.

    That should also remind us to desugar all core forms recursively too!

    .. code:: racket

        (: desugar (-> SndSugar SndCore))
        (define (desugar expr)
            (match expr
                [(after dur a)
                 (stitch (konst 0.0) dur (desugar a))]
                [(cut dur a)
                 (stitch (desugar a) dur (konst 0.0))]
                [(konst v) (konst v)]
                [(oscil e) (oscil (desugar e))]
                [(mod a b) (mod (desugar a) (desugar b))]
                [(mix a b) (mix (desugar a) (desugar b))]
                [(stitch a dur b)
                 (stitch (desugar a) dur (desugar b))]))

        (: interp-sugar(-> SndSugar a:Gen))
        (define (interp-sugar sugarexpr)
           (interp (desugar sugarexpr)))


Desugaring and compilation
--------------------------

We described "desugaring" as the process of taking a term and *reducing* it to
other more "primitive" terms. This process goes by another word - "compilation"
- and compilers do in essence just that - reduce terms in one language (given as
an AST) into terms in, usually, a "lower level" language. Procedures that translate
between languages may also be known as "cross compilers".

This step affords us some interesting possibilities. For instance, we can
transform code into equivalent but more efficient forms. In our case, say, if
we see :rkt:`(mix (konst 0.0) <snd>)` we can simply expand it into
:rkt:`<snd>`. This is where the "properties" we outlined come into play in an
explicit way.
 





