#lang racket

(require "./picture-io.rkt")
(require rackunit)

; Remember that our "picture" type is simply a function
; of (x,y) to color. We'll use the word "image" to refer
; to a 2D array of colour values and "picture" to refer
; to a logical composition of a visual.

(provide color color->list)
(provide (struct-out color))
(provide white red green blue black background)
(provide mix same-color?)
(provide render-to-file picture-from-file)
(provide circle disc box rectangle square
         translate rotate scale affine
         colorize opacity crop
         overlay)

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

(define (uniform-color c) (λ (x y) c))

(define white (color 1.0 1.0 1.0 1.0))
(define red (color 1.0 1.0 0.0 0.0))
(define green (color 1.0 0.0 1.0 0.0))
(define blue (color 1.0 0.0 0.0 1.0))
(define black (color 1.0 0.0 0.0 0.0))
(define background (color 0.0 0.0 0.0 0.0))

; Utility provided to you. Mixes the two given colors given
; a fractional value f in range [0.0,1.0] If f is 1.0, you
; get back c1. If it is 0.0 you get back c2. For in between
; values you get a linear mixture.
(define (mix f c1 c2)
  (let ([g (- 1.0 f)])
    (color (+ (* f (color-a c1)) (* g (color-a c2)))
           (+ (* f (color-r c1)) (* g (color-r c2)))
           (+ (* f (color-g c1)) (* g (color-g c2)))
           (+ (* f (color-b c1)) (* g (color-b c2))))))


(define (same-color? c1 c2)
  (and (< (abs (- (color-a c1) (color-a c2))) 0.01)
       (< (abs (- (color-r c1) (color-r c2))) 0.01)
       (< (abs (- (color-g c1) (color-g c2))) 0.01)
       (< (abs (- (color-b c1) (color-b c2))) 0.01)))

(test-case "mix"
           (check same-color? (mix 1.0 red green) red "1.0 means you get the first color")
           (check same-color? (mix 0.0 red green) green "0.0 means you get the second color")
           (check same-color? (mix 0.5 red green) (color 1.0 0.5 0.5 0.0) "0.5 means you get the middle color"))

; Utility to help see color values.
(define (color->list c)
  (list 'color (color-a c) (color-r c) (color-g c) (color-b c)))

; EXAMPLE primitive shape
(define (circle radius thickness)
  (let ([r1 (- radius (* 0.5 thickness))]
        [r2 (+ radius (* 0.5 thickness))])
    (λ (x y)
      (let ([r (sqrt (+ (* x x) (* y y)))])
        (if (and (>= r r1) (<= r r2))
            white
            background)))))


; This should produce a white disc of given radius whose
; insides are white and outsides are transparent black - i.e.
; the color denoted by "background" defined above.
(define (disc radius)
  (circle (* 0.5 radius) radius))

(test-case "disc"
           (check same-color? ((disc 5.0) 0.0 0.0) white "Disc is not white at centre")
           (check same-color? ((disc 5.0) 2.0 3.0) white "Disc is not white where it should be")
           (check same-color? ((disc 5.0) 3.0 4.1) background "Disc has wrong background"))

; This should produce a white rectangle of given width
; height centered around the origin. The inside of the
; "box" must be white and the outside must be "background".
(define (box width height)
  (let ([hw (* 0.5 width)]
        [hh (* 0.5 height)])
  (λ (x y)
    (if (and (<= x hw) (>= x (- hw)) (<= y hh) (>= y (- hh)))
        white
        background))))

(test-case "box"
           (check same-color? ((box 2.0 1.0) 1.1 0.6) background "Box must be centered around origin")
           (check same-color? ((box 2.0 1.0) -1.1 -0.6) background "Box must be centered around origin")
           (check same-color? ((box 2.0 1.0) 0.0 0.0) white "Box must be white in the middle"))

; This should produce a rectangle of given thickness.
; Only a region of the given thickness *around* the given
; width and height must be white in color. The rest (include
; the inside) must be "background".
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

(define (square width thickness)
  (rectangle width width thickness))

; This should produce a white line of given thickness that
; passes through the given point (x,y) and is at the given
; angle from the x axis (measuring in the counter-clockwise
; direction).
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
            (let ([len (sqrt (+ (* px px) (* py py)))])
              (if (< len ht)
                  white
                  background))))))))

(test-case "line"
           (check same-color? ((line 0.0 0.0 (* 0.5 pi) 0.1) 0.0 1.0) white "Line must be white inside")
           (check same-color? ((line 0.0 0.0 (* 0.5 pi) 0.1) 0.1 1.0) background "Line must be of finite thickness")
           (check same-color? ((line 1.0 2.0 pi 0.1) 1.1 1.0) background "Line must be background outside thickness")
           (check same-color? ((line 1.0 -2.0 pi 0.1) 15.0 -2.1) background "Line must be of finite thickness"))

           
; You've seen this function already, so it should be a breeze.
(define (translate dx dy picture)
  (λ (x y)
    (picture (- x dx) (- y dy))))

; Rotates the picture counter-clockwise by the given angle.
(define (rotate degrees picture)
  (let ([ex (cos (degrees->radians degrees))]
        [ey (sin (degrees->radians degrees))])
    (λ (x y)
      (picture (+ (* x ex) (* y ey))
               (+ (* x (- ey)) (* y ex))))))

; Scales the picture by the given factors.
(define (scale sx sy picture)
  (λ (x y)
    (picture (/ x sx) (/ y sy))))

; Try to understand this based on the above three
; transformations. 
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
(define (colorize gc picture)
  (λ (x y)
    (let ([c (picture x y)])
      (let ([f (color-a c)]
            [g (- 1.0 (color-a c))])
        (color (color-a c)
               (+ (* f (color-r gc)) (* g (color-r c)))
               (+ (* f (color-g gc)) (* g (color-g c)))
               (+ (* f (color-b gc)) (* g (color-b c))))))))

; This multiplies the opacity (alpha) of the picture
; by the given factor a. If a is < 1, then it makes it more
; transparent.
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
(define (crop x1 y1 x2 y2 picture)
  (λ (x y)
    (if (and (>= x x1) (<= x x2) (>= y y1) (<= y y2))
        (picture x y)
        background)))

; Sample recursive function to build a more complex picture.
(define (twirl n angle alpha picture)
  (if (equal? n 0)
      picture
      (overlay (rotate (* n angle) picture)
               (opacity alpha (twirl (- n 1) angle alpha picture)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; render-to-file and picture-from-file implementations
; These are provided to you for fun so you can read images
; from ppm files and include them into your compositions
; and write your compositions back out to ppm files.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Conceptually the same as "render" below, but writes the result
; to the given file. The file must not already exist.
(define (render-to-file filename picture x1 y1 x2 y2 nx ny)
  (let ([image (render picture x1 y1 x2 y2 nx ny)])
    (write-image-to-ppm filename image)))


; Produces a 2D matrix of color values for the given
; rectangle (x1,y1)-(x2,y2), sampling nx pixels in the
; x direction and ny pixels in the y direction.
(define (render picture x1 y1 x2 y2 nx ny)
  (when (or (< x2 x1) (< y2 y1))
      (raise-argument-error 'render
                            "View rectangle coordinates must be bottom-left top-right"
                            (list x1 y1 x2 y2)))
  
  (when (or (<= nx 0) (<= ny 0))
    (raise-argument-error 'render
                          "Required image must be at least one pixel in size"
                          (list nx ny)))
    
  (let ([dx (/ (- x2 x1) nx)]
        [dy (/ (- y2 y1) ny)])
    (fill-vector 0 ny (make-vector ny)
                 (λ (yi)
                   (let ([y (- y2 (* dy yi))])
                     (fill-vector 0 nx (make-vector nx)
                                (λ (xi)
                                  (picture (+ x1 (* dx xi)) y))))))))

(define (fill-vector fromix toix vec gen)
  ; This check is redundant to perform every iteration,
  ; but it is here just to document these conditions in code.
  (when (or (< toix 0) (> toix (vector-length vec)))
    (raise-argument-error 'fill-vector
                          "Index range within vector size"
                          (list fromix toix)))
                          
  (if (< fromix toix)
      (begin (vector-set! vec fromix (gen fromix))
             (fill-vector (+ fromix 1) toix vec gen))
      vec))

(test-case "fill-vector"
           (check-equal?
            (fill-vector 0 4 (make-vector 4) (λ (i) (* i i)))
            (vector 0 1 4 9)))


; Conceptually similar to picture-from-image below, but
; reads the "2D matrix of colors" from the given file.
(define (picture-from-file filename x1 y1 x2 y2)
  (picture-from-image (read-image-from-ppm filename) x1 y1 x2 y2))
  

; The given image is a 2D matrix of color values.
; This is mapped to the rectangle (x1,y1)-(x2,y2)
; where (x1,y1) is the lower left corner of the
; rectangle and (x2,y2) is the top right corner.
; When the resultant picture function is called
; with some (x,y), it will produce appropriate
; color values if this point is within the rectangle
; and will produce the background colour if outside.
(define (picture-from-image image x1 y1 x2 y2)
  (when (not (is-valid-image? image))
    (raise-argument-error 'picture-from-image
                          "2D matrix of color values"
                          image))
  
  (let ([w (image-width image)]
        [h (image-height image)])
    (let ([dx (/ (- x2 x1) w)]
          [dy (/ (- y2 y1) h)])
      (λ (x y)
        (let ([i (floor (inexact->exact (/ (- x x1) dx)))]
              [j (floor (inexact->exact (/ (- y y1) dy)))])
          (if (and (>= i 0) (< i w) (>= j 0) (< j h))
              (vector-ref (vector-ref image (- h j 1)) i)
              background))))))
  

