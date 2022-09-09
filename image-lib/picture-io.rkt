#lang racket

#|

Task: Write procedures that read-from/write-to "Plain PPM" files.

An image for this purpose is a 2D array of colour values represented
as a vector of vectors.

A typical "Plain PPM" file is a text file that looks like this -

    P3
    W H
    <maxval>
    R11 G11 B11 R12 G12 B12 ... R1W G1W B1W
    R21 G21 B21 R22 G22 B22 ... R2W G2W B2W
    ...
    RH1 GH1 BH1 RH2 GH2 BH2 ... RWH GWH BWH


... where W is the width of the image in pixels and H is its height
and <maxval> is maximum value of any colour component in the image.
All numbers are whole numbers (i.e. integers >= 0).

Note that according to spec, the parts only need to be separated
by "white space". There is no mandate on whether the white space should
be newline or space character. Both are acceptable.

|#

; color values to be in the range [0.0,1.0]
; color-r color-a color-g color-b color?
(struct color (a r g b))

; (require "./image-io.rkt")
(provide write-image-to-ppm read-image-from-ppm)
(provide color)
(provide (struct-out color)) ; Also exports functions like color-r, color-g etc.
(provide image-width image-height)
(provide is-valid-image? is-valid-color?)

; filename :: String
; image :: (Vectorof (Vectorof color))
(define (write-image-to-ppm filename image)
  (if (is-valid-image? image)
      (call-with-output-file filename
        (λ (f)
          (write-ppm-header image f)
          (write-ppm-pixels image f)))
      (raise-argument-error 'write-image-to-ppm
                            "2D matrix of color values"
                            image)))

(define (is-valid-image? image)
  (and
   ; Image must be a vector
   (vector? image)

   ; Height of image > 0
   (> (vector-length image) 0)

   ; Check that all rows have color values.
   (check-all image (λ (row)
                      (check-all row is-valid-color?)))

   ; All rows must be of same width
   (let ([width (vector-length (vector-ref image 0))])
     (check-all image (λ (row)
                        (equal? (vector-length row) width))))

   ; When all the above conditions are met, is-image-valid?
   ; will return the image itself. Else it will return #f.
   image))

; Evaluates to #t if the predicate (i.e. function of a value
; that evaluates to a boolean) returns #t for all the elements
; of the vector and #f if any one of them returned #f.
(define (check-all vec predicate)
  (define (check i N)
    (if (< i N)
        (if (predicate (vector-ref vec i))
            (check (+ i 1) N)
            #f)
        #t))
  (check 0 (vector-length vec)))

(define (is-valid-color? c)
  (and (color? c)
       (color-value-in-range? (color-a c))
       (color-value-in-range? (color-r c))
       (color-value-in-range? (color-g c))
       (color-value-in-range? (color-b c))))

(define (color-value-in-range? val)
  (and (>= val 0.0) (<= val 1.0)))


(define (write-ppm-header image f)
  (write-string "P3\n" f)
  (write (image-width image) f)
  (write-string " " f)
  (write (image-height image) f)
  (write-string "\n" f)
  (write 255 f)
  (write-string "\n" f))

(define (write-ppm-pixels image f)
  (for-each-row 0 image (λ (row)
                          (write-row row f)
                          (write-string "\n" f))))

(define (for-each-row i vec proc)
  (when (< i (vector-length vec))
    (proc (vector-ref vec i))
    (for-each-row (+ i 1) vec proc)))

(define (write-row row f)
  (for-each-row 0 row (λ (c)
                      (write-color c f))))

(define (write-color c f)
  (let ([a (color-a c)])
    (let ([r (colorval->int (* a (color-r c)))]
          [g (colorval->int (* a (color-g c)))]
          [b (colorval->int (* a (color-b c)))])
      (write r f)
      (write-string " " f)
      (write g f)
      (write-string " " f)
      (write b f)
      (write-string " " f))))

(define (colorval->int val)
  (floor (inexact->exact (* val 255.99))))

(define (image-width image)
  (vector-length (vector-ref image 0)))

(define (image-height image)
  (vector-length image))
  
      
#|
P3
3 3
255 # some comment
0 255 0 0 255 0 0 255 0 
255 0 0 255 0 0 255 0 0 
0 0 255 0 0 255 0 0 255 
|#

(require racket/match)

; -> (Vectorof (Vectorof color))
; (is-image-valid? result)
(define (read-image-from-ppm filename)
  (call-with-input-string (ppm-strip-comments filename)
    (λ (f)
      (match (read-ppm-header f)
        [(list 'P3 width height maxval)
         (is-valid-image? (read-ppm-pixels width height maxval f))]
        [header (raise-argument-error 'read-image-from-ppm
                                      "P3 plain PPM header"
                                      header)]))))

(define (ppm-strip-comments filename)
  (call-with-input-file filename
      (λ (f)
        (call-with-output-string
         (λ (s)
           (read-until-eof (λ ()
                             (let ([line (read-line f)])
                               (if (eof-object? line)
                                   eof
                                   (begin (write-string (line-without-comments line) s)
                                          (write-string "\n" s)))))))))))

(define (read-until-eof proc)
  (if (eof-object? (proc))
      eof
      (read-until-eof proc)))

(define (line-without-comments line)
  (let ([parts (string-split (string-append " " line) "#")])
    (if (empty? parts)
        ""
        (first parts))))

#|
P3
3 3
255 # comment1
# comment2
0 255 0 0 255 0 0 255 0
255 0 0 255 0 0 255 0 0
0 0 255 0 0 255 0 0 255
|#

        
           
(define (read-ppm-header f)
  (let ([tag (read f)])
    (if (equal? tag 'P3)
        (let ([width (read f)]
              [height (read f)])
          (if (and (> width 0) (> height 0))
              (let ([maxval (read f)])
                (if (>= maxval 0)
                    ; Valid result
                    (list 'P3 width height maxval)
                    
                    (raise-argument-error 'read-ppm-header
                                          "maxval >= 0"
                                          maxval)))
              (raise-argument-error 'read-ppm-header
                                    "width and height must be > 0"
                                    (list width height))))
        (raise-argument-error 'read-ppm-header
                              "File tag must be P3"
                              tag))))

          
(define (read-ppm-pixels width height maxval f)
  (fill-vector 0 (make-vector height)
               (λ (i)
                 (fill-vector 0 (make-vector width)
                              (λ (j)
                                (read-color maxval f))))))

(define (fill-vector i vec fn)
  (if (< i (vector-length vec))
      (begin (vector-set! vec i (fn i))
             (fill-vector (+ i 1) vec fn))
      vec))

(define (read-color maxval f)
  (let ([r (read f)]
        [g (read f)]
        [b (read f)])
    (if (or (eof-object? r)
            (eof-object? g)
            (eof-object? b))
        (raise-argument-error 'read-color
                              "Integer R G B values"
                              (list r g b))
        (if (and (>= r 0) (<= r maxval)
                 (>= g 0) (<= g maxval)
                 (>= b 0) (<= b maxval))
            (color 1.0
                   (int->colorval (/ r maxval))
                   (int->colorval (/ g maxval))
                   (int->colorval (/ b maxval)))
            (raise-argument-error 'read-color
                                  "Color values in range 0 to maxval"
                                  (list r g b maxval))))))

(define (int->colorval  val)
  (exact->inexact val))




















