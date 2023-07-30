#lang racket

(require "./picture-io.rkt")
(require rackunit)

(provide render-to-file picture-from-file background)
(define background (color 0.0 0.0 0.0 0.0))

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
  

