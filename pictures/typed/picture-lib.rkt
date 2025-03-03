#lang typed/racket

(require "./color.rkt")
(require "./picture-io.rkt")
(require "./picture-render.rkt")
(require typed/rackunit)
(require math/flonum)

; Remember that our "picture" type is simply a function
; of (x,y) to color. We'll use the word "image" to refer
; to a 2D array of colour values and "picture" to refer
; to a logical composition of a visual.

(provide mix same-color?)
(provide (all-from-out "./picture-render.rkt"))
(provide circle disc filled-box rectangle square
         translate rotate scale affine
         colorize opacity crop
         overlay twirl premultiply)

#|
Below is a simple vocabulary for generating and composing images
you need to write for this assignment.

1. Remember that a "picture" is represented as a function
   from (x,y) to color.

2. An "image" is a 2D array of color values represented as
   a vector of vectors of color values.

Some functions at the start are implemented to get you going.
Each function is accompanied by one or more "test cases" that
should pass once you've implemented the function.
|#

(: uniform-color (-> (color Float) Picture))
(define (uniform-color c) (λ ([x : Float] [y : Float]) c))


; Utility provided to you. Mixes the two given colors given
; a fractional value f in range [0.0,1.0] If f is 1.0, you
; get back c1. If it is 0.0 you get back c2. For in between
; values you get a linear mixture.
(: mix (-> Float (color Float) (color Float) (color Float)))
(define (mix f c1 c2)
  (let ([g (- 1.0 f)])
    (color (+ (* f (color-a c1)) (* g (color-a c2)))
           (+ (* f (color-r c1)) (* g (color-r c2)))
           (+ (* f (color-g c1)) (* g (color-g c2)))
           (+ (* f (color-b c1)) (* g (color-b c2))))))

(: same-color? (-> (color Float) (color Float) Boolean))
(define (same-color? c1 c2)
  (and (< (abs (- (color-a c1) (color-a c2))) 0.01)
       (< (abs (- (color-r c1) (color-r c2))) 0.01)
       (< (abs (- (color-g c1) (color-g c2))) 0.01)
       (< (abs (- (color-b c1) (color-b c2))) 0.01)))

(test-case "mix"
           (check same-color? (mix 1.0 red green) red "1.0 means you get the first color")
           (check same-color? (mix 0.0 red green) green "0.0 means you get the second color")
           (check same-color? (mix 0.5 red green) (color 1.0 0.5 0.5 0.0) "0.5 means you get the middle color"))

; EXAMPLE primitive shape
(: circle (-> Float Float Picture))
(define (circle radius thickness)
  (let ([r1 (- radius (* 0.5 thickness))]
        [r2 (+ radius (* 0.5 thickness))])
    (λ (x y)
      (let ([r (flsqrt (+ (* x x) (* y y)))])
        (if (and (>= r r1) (<= r r2))
            white
            background)))))


; This should produce a white disc of given radius whose
; insides are white and outsides are transparent black - i.e.
; the color denoted by "background" defined above.
(: disc (-> Float Picture))
(define (disc radius)
  (circle (* 0.5 radius) radius))

(test-case "disc"
           (check same-color? ((disc 5.0) 0.0 0.0) white "Disc is not white at centre")
           (check same-color? ((disc 5.0) 2.0 3.0) white "Disc is not white where it should be")
           (check same-color? ((disc 5.0) 3.0 4.1) background "Disc has wrong background"))

; This should produce a white rectangle of given width
; height centered around the origin. The inside of the
; "box" must be white and the outside must be "background".
(: filled-box (-> Float Float Picture))
(define (filled-box width height)
  (let ([hw (* 0.5 width)]
        [hh (* 0.5 height)])
  (λ (x y)
    (if (and (<= x hw) (>= x (- hw)) (<= y hh) (>= y (- hh)))
        white
        background))))

(test-case "box"
           (check same-color? ((filled-box 2.0 1.0) 1.1 0.6) background "Box must be centered around origin")
           (check same-color? ((filled-box 2.0 1.0) -1.1 -0.6) background "Box must be centered around origin")
           (check same-color? ((filled-box 2.0 1.0) 0.0 0.0) white "Box must be white in the middle"))

; This should produce a rectangle of given thickness.
; Only a region of the given thickness *around* the given
; width and height must be white in color. The rest (include
; the inside) must be "background".
(: rectangle (-> Float Float Float Picture))
(define (rectangle width height thickness)
  (let ([hw (* 0.5 width)]
        [hh (* 0.5 height)]
        [ht (* 0.5 thickness)])
    (let ([xl1 (- (- hw) ht)]
          [xl2 (+ (- hw) ht)]
          [xr1 (- hw ht)]
          [xr2 (+ hw ht)]
          [yb1 (- (- hh) ht)]
          [yb2 (+ (- hh) ht)]
          [yt1 (- hh ht)]
          [yt2 (+ hh ht)])
      (λ (x y)
        (if (or (> x xr2) (< x xl1)
                (> y yt2) (< y yb1))
            background
            (if (and (< x xr1) (> x xl2)
                     (< y yt1) (> y yb2))
                background
                white))))))

(test-case "rectangle"
           (check same-color? ((rectangle 2.0 1.0 0.2) 0.0 0.0) background "Rectangle must be transparent at centre")
           (check same-color? ((rectangle 2.0 1.0 0.2) 1.2 0.0) background "Rectangle must be centered around origin")
           (check same-color? ((rectangle 2.0 1.0 0.2) 1.05 0.0) white "Rectangle must be stroked white")
           (check same-color? ((rectangle 2.0 1.0 0.2) -1.05 0.5) white "Rectangle must be stroked white")
           (check same-color? ((rectangle 2.0 1.0 0.2) 1.0 0.5) white "Rectangle must be stroked white"))

(: square (-> Float Float Picture))
(define (square width thickness)
  (rectangle width width thickness))

; This should produce a white line of given thickness that
; passes through the given point (x,y) and is at the given
; angle from the x axis (measuring in the counter-clockwise
; direction).
(: line (-> Float Float Float Float Picture))
(define (line x0 y0 angle thickness)
  (let ([ex (cos angle)]
        [ey (sin angle)]
        [ht (* 0.5 thickness)])
    (λ (x y)
      (let ([dx (- x x0)]
            [dy (- y y0)])
        (let ([dot (+ (* dx ex) (* dy ey))])
          (let ([px (- dx (* ex dot))]
                [py (- dy (* ey dot))])
            (let ([len (flsqrt (+ (* px px) (* py py)))])
              (if (< len ht)
                  white
                  background))))))))

(test-case "line"
           (check same-color? ((line 0.0 0.0 (* 0.5 pi) 0.1) 0.0 1.0) white "Line must be white inside")
           (check same-color? ((line 0.0 0.0 (* 0.5 pi) 0.1) 0.1 1.0) background "Line must be of finite thickness")
           (check same-color? ((line 1.0 2.0 pi 0.1) 1.1 1.0) background "Line must be background outside thickness")
           (check same-color? ((line 1.0 -2.0 pi 0.1) 15.0 -2.1) background "Line must be of finite thickness"))

           
; You've seen this function already, so it should be a breeze.
(: translate (-> Float Float Picture Picture))
(define (translate dx dy picture)
  (λ (x y)
    (picture (- x dx) (- y dy))))

; Rotates the picture counter-clockwise by the given angle.
(: rotate (-> Float Picture Picture))
(define (rotate degrees picture)
  (let ([ex (cos (degrees->radians degrees))]
        [ey (sin (degrees->radians degrees))])
    (λ (x y)
      (picture (+ (* x ex) (* y ey))
               (+ (* x (- ey)) (* y ex))))))

; Scales the picture by the given factors.
(: scale (-> Float Float Picture Picture))
(define (scale sx sy picture)
  (λ (x y)
    (picture (/ x sx) (/ y sy))))

; Try to understand this based on the above three
; transformations.
(: affine (-> Float Float Float Float Float Float Picture Picture))
(define (affine mxx mxy myx myy dx dy picture)
  (let ([det (- (* mxx myy) (* mxy myx))])
    (let ([mixx (/ myy det)]
          [mixy (/ (- mxy) det)]
          [miyx (/ (- myx) det)]
          [miyy (/ mxx det)])
      (λ (x y)
        (let ([tx (- x dx)]
              [ty (- y dy)])
          (let ([x2 (+ (* mixx tx) (* mixy ty))]
                [y2 (+ (* miyx tx) (* miyy ty))])
            (picture x2 y2)))))))
        

; Takes a picture and wherever the picture is non-transparent, replaces its color
; with the RGB values from the given color, while maintaining the same transparency.
; Think about what you'd want/like to have if the given picture has colour values
; that are only partially transparent (or partially opaque).
(: colorize (-> Float Float Float Float Picture Picture))
(define (colorize a r g b picture)
  (λ (x y)
    (let ([c (picture x y)])
      (let ([f (color-a c)]
            [g (- 1.0 (color-a c))])
        (color (color-a c)
               (+ (* f r) (* g (color-r c)))
               (+ (* f g) (* g (color-g c)))
               (+ (* f b) (* g (color-b c))))))))

; This multiplies the opacity (alpha) of the picture
; by the given factor a. If a is < 1, then it makes it more
; transparent.
(: opacity (-> Float Picture Picture))
(define (opacity a picture)
  (λ (x y)
    (let ([c (picture x y)])
      (color (* a (color-a c))
             (color-r c)
             (color-g c)
             (color-b c)))))

; Places pic1 on top of pic2, mixing their colors
; according to the transparencies of the pictures.
; See https://en.wikipedia.org/wiki/Alpha_compositing
; for ways to combine two images. This function implements
; the "A over B" formula.
(: overlay (-> Picture Picture Picture))
(define (overlay pic1 pic2)
  (let ([eps 0.0000001])
    (λ (x y)
      (let ([c1 (pic1 x y)]
            [c2 (pic2 x y)])
        (let ([a1 (max eps (color-a c1))]
              [a2 (max eps (color-a c2))])
          (let ([ca (max eps (+ a1 (* (- 1.0 a1) a2)))])
            (let ([cr (/ (+ (* (color-r c1) a1) (* (- 1.0 a1) a2 (color-r c2))) ca)]
                  [cg (/ (+ (* (color-g c1) a1) (* (- 1.0 a1) a2 (color-g c2))) ca)]
                  [cb (/ (+ (* (color-b c1) a1) (* (- 1.0 a1) a2 (color-b c2))) ca)])
            (color ca cr cg cb))))))))

; Eliminates all color values outside the given rectangle
; within the picture.
(: crop (-> Float Float Float Float Picture Picture))
(define (crop x1 y1 x2 y2 picture)
  (λ (x y)
    (if (and (>= x x1) (<= x x2) (>= y y1) (<= y y2))
        (picture x y)
        background)))

; Sample recursive function to build a more complex picture.
(: twirl (-> Integer Float Float Picture Picture))
(define (twirl n angle alpha picture)
  (if (equal? n 0)
      picture
      (overlay (rotate (* n angle) picture)
               (opacity alpha (twirl (- n 1) angle alpha picture)))))

(: premultiply (-> Picture Picture))
(define (premultiply pic)
  (λ (x y)
    (premultiply-color (pic x y))))
