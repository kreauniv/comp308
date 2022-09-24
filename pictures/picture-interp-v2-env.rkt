#lang racket

#|
This module is an enhanced reimplementation of the "picture-interp-v1" module,
with the following changes made in alignment with the lecture notes shared
here - https://kreauniv.github.io/comp308/fun-in-piclang.html

The key changes are -

1. Get rid of FunExprC .. which is not a PicExprC and stands outside our
   core expression language.

2. Introduce FunC as a replacement, but without needing to name functions.
   These FunC expressions are valid PicExprC terms. They result in FunV values,
   which means we introduce PicV as a result value for terms that produce
   pictures.

3. ApplyC doesn't take the "name" of a function, but takes an expression that
   expected to evaluate to a FunV and then applies it to the value expression.

4. "subst" is gone. This version uses bindings within the interpreter to
   give meaning to identifiers used in expressions via IdC terms and to 
   give meaning to free variabes in FunC terms that are expected to take on
   meaning from their lexical scope. i.e. bindings form "environments"
   that lend meaning to identifiers in our language.

Exercise: Extend the notion of FunC/FunV in this file to support
functions that accept mutiple arguments rather than just one.
|#

(require "./picture-lib.rkt")
(require racket/match)

(provide desugar interp)
(provide (struct-out PicFromFileC) (struct-out RectangleC) (struct-out CircleC) (struct-out DiscC) (struct-out BoxC)
         (struct-out AffineC) (struct-out ColorizeC) (struct-out OpacityC) (struct-out CropC) (struct-out OverlayC)
         (struct-out FunC) (struct-out ApplyC) (struct-out IdC) (struct-out PictureC)
         (struct-out FunV) (struct-out PicV)
         (struct-out SquareS) (struct-out TranslateS) (struct-out RotateS) (struct-out ScaleS))
(provide color color->list)
(provide (struct-out color))
(provide lookup-binding extend-bindings make-empty-bindings)

; PicExprC type
(struct PicFromFileC (filename x1 y1 x2 y2))
(struct RectangleC (width height thickness))
(struct CircleC (radius thickness))
(struct DiscC (radius))
(struct BoxC (width height))
(struct AffineC (mxx mxy myx myy dx dy picexpr))
(struct ColorizeC (color picexpr))
(struct OpacityC (alpha picexpr))
(struct CropC (x1 y1 x2 y2 picexpr))
(struct OverlayC (picexpr1 picexpr2))

(struct FunC (argname expr))
(struct ApplyC (fname expr))
(struct IdC (name))
(struct PictureC (pic))

; Value terms that are part of the result type of the
; interpreter.
(struct FunV (argname bindings expr))
(struct PicV (pic))

; We still keep a few as "syntactic sugar" for
; illustrative purposes.

; PicExprS tyle
(struct SquareS (side thickness))
(struct TranslateS (dx dy picexpr))
(struct RotateS (degrees picexpr))
(struct ScaleS (sx sy picexpr))


; desugar :: (Union PicExprS PicExprC) -> PicExprC
(define (desugar picexprS)
  (match picexprS
    [(SquareS side thickness)
     (RectangleC side side thickness)]
    [(TranslateS dx dy picexpr)
     (AffineC 1.0 0.0 0.0 1.0 dx dy (desugar picexpr))]
    [(RotateS degrees picexpr)
     (let ([c (cos (degrees->radians degrees))]
           [s (sin (degrees->radians degrees))])
       (AffineC c (- s) s c 0.0 0.0 (desugar picexpr)))]
    [(ScaleS sx sy picexpr)
     (AffineC sx 0.0 0.0 sy 0.0 0.0 (desugar picexpr))]
    [(AffineC mxx mxy myx myy dx dy picexpr)
     (AffineC mxx mxy myx myy dx dy (desugar picexpr))]
    [(ApplyC funexpr valexpr)
     (ApplyC (desugar funexpr) (desugar valexpr))]
    [(ColorizeC c expr)
     (ColorizeC c (desugar expr))]
    [(CropC x1 y1 x2 y2 expr)
     (CropC x1 y1 x2 y2 (desugar expr))]
    [(OverlayC pic1 pic2)
     (OverlayC (desugar pic1) (desugar pic2))]
    [(FunC argname fexpr)
     (FunC argname (desugar fexpr))]
    ; The rest are just identity transformation of core terms.
    [_ picexprS]))

; interp :: PicExprC -> Listof FunDefC -> Picture
(define (interp picexprC bindings)
  (match picexprC
    ; Note that any term that evaluates to a picture (λ (x y) -> color)
    ; now needs to be wrapped in a PicV value because our interpreter
    ; can now also produce FunV values.
    [(PicFromFileC filename x1 y1 x2 y2)
     (PicV (picture-from-file filename x1 y1 x2 y2))]
    [(RectangleC width height thickness)
     (PicV (rectangle width height thickness))]
    [(CircleC radius thickness)
     (PicV (circle radius thickness))]
    [(DiscC radius)
     (PicV (disc radius))]
    [(BoxC width height)
     (PicV (box width height))]
    [(AffineC mxx mxy myx myy dx dy picexpr)
     (PicV (affine mxx mxy myx myy dx dy (interp picexpr bindings)))]
    [(ColorizeC c picexpr)
     (PicV (colorize c (interp picexpr bindings)))]
    [(OpacityC alpha picexpr)
     (PicV (opacity alpha (interp picexpr bindings)))]
    [(CropC x1 y1 x2 y2 picexpr)
     (PicV (crop x1 y1 x2 y2 (interp picexpr bindings)))]
    [(OverlayC pic1 pic2)
     (PicV (overlay (interp pic1 bindings) (interp pic2 bindings)))]
    [(FunC argname fexpr)
     (FunV argname bindings fexpr)]
    [(ApplyC funexpr valexpr)
     (let ([funv (interp funexpr bindings)]
           [val (interp valexpr bindings)])
       (match funexpr
         [(FunV argname definition-time-bindings fexpr)
          (interp valexpr (extend-bindings argname val definition-time-bindings))]
         [_ (raise-argument-error 'interp/ApplyC
                                  "FunV term"
                                  funexpr)]))]
    [(IdC name) (lookup-binding name bindings)]
    [(PictureC pic) (PicV pic)]))

; We've so far assumed the existence of functions extend-bindings
; and lookup-binding -- i.e. we've not committed to a representation
; for the bindings yet. Let's do a simple one. We'll also need the
; ability to make an "empty environment". The simple representation
; we'll use is ... a lambda! One that will perform the lookup task
; given a name .. which is the sole purpose of the environment.
(define (make-empty-bindings)
  (λ (name)
    (raise-argument-error 'lookup-binding
                          "Valid name"
                          name)))

(define (lookup-binding name bindings)
  (bindings name)) ; Now that was simple!

; Extending bindings with one more name-value binding
; is also simple. We wrap the bindings in a lambda that
; checks for the name and supplies the value and if the
; name doesn't match, passes on the lookup task to the
; "parent" bindings.
(define (extend-bindings name value bindings)
  (λ (n)
    (if (equal? n name)
        value
        (lookup-binding n bindings))))

; Making a standard library
; In any language, we'll usually want to start off with a predefined
; set of functions that we think are useful for users of our language
; so they don't have to write repeated code. For example, we may wish
; to produce a function that places two pictures side by side like this -
; (FunC 'a (FunC 'b (OverlayC (IdC 'a) (TranslateC 5.0 (IdC 'b)))))
; So given a set of mappings from names to FunC terms, we want to produce
; a "bindings" or "environment" value that can perform name lookup
; that maps names to FunV values corresponding to these expressions.
; The main thing is that the standard library needs to be available to
; itself!
; 
; See https://kreauniv.github.io/comp308/fun-in-piclang.html#a-standard-library
; for more info.

; Here "definitions" is a list of two-element lists where the first element
; gives the name of the stdlib function and the second gives its FunC expression.
; This is like the "cheat" version of our intended "standard library maker" function
; that assumes that the standard library is already made and supplied as the argument
; named stdlib.
; So this satisfies the equation -
;   stdlib = (make-standard-library/spec definitions stdlib)
(define (make-standard-library/spec definitions stdlib)
    (if (empty? definitions)
        (make-empty-bindings)
        (let ([def (first definitions)])
            (extend-bindings
                (first def)
                (interp (second def) stdlib)
                (make-standard-library/spec (rest definitions) stdlib)))))

(define (stdlib/spec definitions)
  (λ (stdlib) (make-standard-library/spec definitions stdlib)))

; Use the Theta combinator ... modified for eager evaluation.
(define G (λ (f) (λ (spec) (spec (λ (g) (((f f) spec) g))))))
(define Θ (G G))
; TADA! Now all you need to do is to decide which functions you want
; to include in the "standard library" for your language.
(define (make-standard-library definitions) (Θ (stdlib/spec definitions)))
