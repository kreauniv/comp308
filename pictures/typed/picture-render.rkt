#lang typed/racket

(require "./picture-io.rkt")
(require rackunit)
(require math/flonum)

(provide render-to-file picture-from-file background)

(define-type Coord Float)
(define-type ColorComp Float)
(define-type Picture (-> Coord Coord (color ColorComp)))

(: background (color ColorComp))
(define background (color 0.0 0.0 0.0 0.0))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; render-to-file and picture-from-file implementations
; These are provided to you for fun so you can read images
; from ppm files and include them into your compositions
; and write your compositions back out to ppm files.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Conceptually the same as "render" below, but writes the result
; to the given file. The file must not already exist.
(: render-to-file (-> String Picture Coord Coord Coord Coord Positive-Integer Positive-Integer Any))
(define (render-to-file filename picture x1 y1 x2 y2 nx ny)
  (if (not (file-exists? filename))
      (let ([image (render picture x1 y1 x2 y2 nx ny)])
        (write-image-to-ppm filename image))
      (raise-argument-error 'file-exists
                            "File with given name should not exist"
                            filename)))


; Produces a 2D matrix of color values for the given
; rectangle (x1,y1)-(x2,y2), sampling nx pixels in the
; x direction and ny pixels in the y direction.
(: render (-> Picture Coord Coord Coord Coord Positive-Integer Positive-Integer (Image Flonum)))
(define (render picture x1 y1 x2 y2 nx ny)
  (when (or (< x2 x1) (< y2 y1))
      (raise-argument-error 'render
                            "View rectangle coordinates must be bottom-left top-right"
                            (list x1 y1 x2 y2)))
  
  (let ([dx (/ (- x2 x1) nx)]
        [dy (/ (- y2 y1) ny)])
    (mk-image nx ny
              (λ ([r : Index] [c : Index])
                (picture (+ x1 (* dx c)) (- y2 (* dy r)))))))

; Conceptually similar to picture-from-image below, but
; reads the "2D matrix of colors" from the given file.
(: picture-from-file (-> String Coord Coord Coord Coord Picture))
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
(: picture-from-image (-> (Image ColorComp) Coord Coord Coord Coord Picture))
(define (picture-from-image image x1 y1 x2 y2)
  (let ([w (Image-width image)]
        [h (Image-height image)])
    (let ([dx (/ (- x2 x1) w)]
          [dy (/ (- y2 y1) h)])
      (λ (x y)
        (let ([i (exact-floor (/ (- x x1) dx))]
              [j (exact-floor (/ (- y2 y) dy))])
          (if (and (>= i 0) (< i w) (>= j 0) (< j h) (index? i) (index? j))
              (color-at image i j)
              background))))))
  

