#lang racket

(require "./picture-lib.rkt")
(require racket/match)

(provide desugar interp subst)
(provide PicFromFileC RectangleC CircleC DiscC BoxC
         AffineC ColorizeC OpacityC CropC OverlayC
         FunDefC ApplyC IdC PictureC
         SquareS TranslateS RotateS ScaleS)

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

(struct FunDefC (name arg expr))
(struct ApplyC (fname expr))
(struct IdC (name))
(struct PictureC (pic))

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
    [(ApplyC fname expr)
     (ApplyC fname (desugar expr))]
    [(ColorizeC c expr)
     (ColorizeC c (desugar expr))]
    [(CropC x1 y1 x2 y2 expr)
     (CropC x1 y1 x2 y2 (desugar expr))]
    [(OverlayC pic1 pic2)
     (OverlayC (desugar pic1) (desugar pic2))]
    ; The rest are just identity transformation of core terms.
    [_ picexprS]))

; interp :: PicExprC -> Listof FunDefC -> Picture
(define (interp picexprC fundefs)
  (match picexprC
    [(PicFromFileC filename x1 y1 x2 y2)
     (picture-from-file filename x1 y1 x2 y2)]
    [(RectangleC width height thickness)
     (rectangle width height thickness)]
    [(CircleC radius thickness)
     (circle radius thickness)]
    [(DiscC radius)
     (disc radius)]
    [(BoxC width height)
     (box width height)]
    [(AffineC mxx mxy myx myy dx dy picexpr)
     (affine mxx mxy myx myy dx dy (interp picexpr fundefs))]
    [(ColorizeC c picexpr)
     (colorize c (interp picexpr fundefs))]
    [(OpacityC alpha picexpr)
     (opacity alpha (interp picexpr fundefs))]
    [(CropC x1 y1 x2 y2 picexpr)
     (crop x1 y1 x2 y2 (interp picexpr fundefs))]
    [(OverlayC pic1 pic2)
     (overlay (interp pic1 fundefs) (interp pic2 fundefs))]
    [(ApplyC fname expr)
     (let ([fdef (lookup-fundef fname fundefs)])
       (interp (subst (interp expr fundefs) (FunDefC-arg fdef) (FunDefC-expr fdef))))]
    [(IdC name) (error "Not expecting free variable")]
    [(PictureC pic) pic]))

; lookup-fundef :: Symbol -> Listof FunDefC -> FundefC
(define (lookup-fundef fname fundefs)
  (if (empty? fundefs)
      (error "Name not found")
      (let ([fdef (first fundefs)])
        (if (equal? fname (FunDefC-name fdef))
            fdef
            (lookup-fundef fname (rest fundefs))))))

; subst :: PicExprC -> Symbol -> PicExprC -> PicExprC (without IdC terms)
; Note that in this implementation, because subst is called at the top
; level by interp only, the "thing" is already supplied as an evaluated
; PictureC value, so no further "eager evaluation" step is needed.
(define (subst thing for-identifier in-expression)
  (when (not (PictureC? thing))
    (raise-argument-error 'subst
                          "Expecting eager evaluated expression"
                          thing))
  (match in-expression
    [(AffineC mxx mxy myx myy dx dy picexpr)
     (AffineC mxx mxy myx myy dx dy (subst thing for-identifier picexpr))]
    [(ColorizeC c picexpr)
     (ColorizeC c (subst thing for-identifier picexpr))]
    [(OpacityC alpha picexpr)
     (OpacityC alpha (subst thing for-identifier picexpr))]
    [(CropC x1 y1 x2 y2 picexpr)
     (CropC x1 y1 x2 y2 (subst thing for-identifier picexpr))]
    [(OverlayC pic1 pic2)
     (OverlayC (subst thing for-identifier pic1)
               (subst thing for-identifier pic2))]
    [(ApplyC fname expr)
     (ApplyC fname (subst thing for-identifier expr))]
    [(IdC name) (if (equal? name for-identifier)
                    thing
                    (error "Free variable"))]
    ; None of the remaining cases contain sub-expressions that
    ; we need to traverse to perform substitution.
    [_ in-expression]))




