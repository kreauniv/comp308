#lang typed/racket

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

(require "./color.rkt")
(provide write-image-to-ppm read-image-from-ppm)
(provide color Image)
(provide (struct-out color)) ; Also exports functions like color-r, color-g etc.
(provide (struct-out Image))
(provide color-at mk-image premultiply-color)

(struct (t) Image ([width : Positive-Integer]
                   [height : Positive-Integer]
                   [pixels : (Vectorof (color t))]))

(: mk-image (All (t) (-> Positive-Integer Positive-Integer (-> Index Index (color t)) (Image t))))
(define (mk-image width height func)
  (Image width height
         (build-vector (* width height)
                       (λ ([i : Index])
                         (let ([r (quotient i width)]
                               [c (remainder i width)])
                           (func r c))))))

(: color-at (All (t) (-> (Image t) Index Index (color t))))
(define (color-at im r c)
  (vector-ref (Image-pixels im)
              (+ (* r (Image-width im)) c)))


(: quantize-image (-> (Image Number) (Image Byte)))
(define (quantize-image im)
  (Image (Image-width im)
         (Image-height im)
         (vector-map quantize-color (Image-pixels im))))

(: write-image-to-ppm (All (t) (-> String (Image t) Any)))
(define (write-image-to-ppm filename image)
  (call-with-output-file filename
    (λ ([f : Output-Port])
      (write-ppm-header image f)
      (write-ppm-pixels image f))))

(: write-ppm-header (All (t) (-> (Image t) Output-Port Any)))
(define (write-ppm-header image f)
  (write-string "P3\n" f)
  (write (Image-width image) f)
  (write-string " " f)
  (write (Image-height image) f)
  (write-string "\n" f)
  (write 255 f)
  (write-string "\n" f))

(: write-ppm-pixels (All (t) (-> (Image t) Output-Port Any)))
(define (write-ppm-pixels image f)
  (for-each-pixel image (λ ([r : Index] [c : Index] [col : (color t)])
                          (when (= c 0)
                            (write-string "\n" f))
                          (write-color col f))))

(: for-each-pixel (All (t) (-> (Image t) (-> Index Index (color t) Any) Any)))
(define (for-each-pixel im func)
  (let loopr ([r 0] [height (Image-height im)])
    (when (< r height)
      (let loopc ([c 0] [width (Image-width im)])
        (when (< c width)
          (func (assert r index?) (assert c index?)
                (color-at im (assert r index?) (assert c index?)))
          (loopc (+ c 1) width)))
      (loopr (+ r 1) height))))

(: write-color (All (t) (-> (color t) Output-Port Any)))
(define (write-color c f)
  (cond
    ([byte-color? c] (write-quantized-color c f))
    ([unit-color? c] (write-unit-color c f))
    (else (raise-argument-error 'unknown-color
                                "Expected (color Byte) or (color Float)"
                                c))))
         
(: write-quantized-color (-> (color Byte) Output-Port Any))
(define (write-quantized-color c f)
  (write (color-r c) f)
  (write-string " " f)
  (write (color-g c) f)
  (write-string " " f)
  (write (color-b c) f)
  (write-string " " f))

(: write-unit-color (-> (color Float) Output-Port Any))
(define (write-unit-color c f)
  (write-quantized-color (quantize-color c) f))

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
(: read-image-from-ppm (-> String (Image Float)))
(define (read-image-from-ppm filename)
  (call-with-input-string (ppm-strip-comments filename)
                          (λ ([f : Input-Port])
                            (match (read-ppm-header f)
                              [(list 'P3 width height maxval)
                               (read-ppm-pixels width height maxval f)]
                              [header (raise-argument-error 'read-image-from-ppm
                                                            "P3 plain PPM header"
                                                            header)]))))

; Produces the contents of the file with
; # prefixed comments all removed. This makes
; it easier to parse.
(: ppm-strip-comments (-> String String))
(define (ppm-strip-comments filename)
  (call-with-input-file filename
    (λ ([f : Input-Port])
      (call-with-output-string
       (λ ([s : Output-Port])
         (read-until-eof (λ ()
                           (let ([line (read-line f)])
                             (if (eof-object? line)
                                 eof
                                 (begin (write-string (line-without-comments line) s)
                                        (write-string "\n" s)))))))))))

(: read-until-eof (-> (-> Any) EOF))
(define (read-until-eof proc)
  (if (eof-object? (proc))
      eof
      (read-until-eof proc)))

(: line-without-comments (-> String String))
(define (line-without-comments line)
  ; We're expecting to pick the part of the line before any '#"
  ; character. If the '#' character happens to be the first in
  ; the line, then when string-split is called, you can't tell
  ; whether the first element of the result list occurred
  ; before or after the '#". So we prepend a space character to
  ; be able to tell that. Not efficient, but simple for our 
  ; purposes.
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

        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; UTILITY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(: premature-eof-error (-> String Nothing))
(define (premature-eof-error msg)
  (raise-argument-error 'premature-eof
                        msg
                        #f))

(: read-ppm-header (-> Input-Port (List 'P3 Positive-Integer Positive-Integer Positive-Integer)))
(define (read-ppm-header f)
  (let ([tag (read f)])
    (if (equal? tag 'P3)
        (let ([width (read-exact-integer f)]
              [height (read-exact-integer f)])
          (if (or (eof-object? width) (eof-object? height))
              (premature-eof-error "File shouldn't end right in the header")
              (if (and (positive-integer? width) (positive-integer? height))
                  (let ([maxval (read-exact-integer f)])
                    (if (eof-object? maxval)
                        (premature-eof-error "Shouldn't end when reading maxval")
                        (if (positive-integer? maxval)
                            ; Valid result
                            (list 'P3 width height maxval)                    
                            (raise-argument-error 'read-ppm-header
                                                  "maxval >= 0"
                                                  maxval))))
                  (raise-argument-error 'read-ppm-header
                                        "width and height must be > 0"
                                        (list width height)))))
        (raise-argument-error 'read-ppm-header
                              "File tag must be P3"
                              tag))))

(: read-exact-integer (-> Input-Port (U Integer EOF)))
(define (read-exact-integer f)
  (let ([v (read f)])
    (if (eof-object? v)
        v
        (assert v exact-integer?))))

(: read-ppm-pixels (-> Positive-Integer Positive-Integer Positive-Integer Input-Port (Image Float)))
(define (read-ppm-pixels width height maxval f)
  (mk-image width height
            (λ ([r : Index] [c : Index])
              (read-color maxval f))))

(: read-color (-> Integer Input-Port (color Float)))
(define (read-color maxval f)
  (let ([r (read-exact-integer f)]
        [g (read-exact-integer f)]
        [b (read-exact-integer f)])
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
                   (exact->inexact (/ r maxval))
                   (exact->inexact (/ g maxval))
                   (exact->inexact (/ b maxval)))
            (raise-argument-error 'read-color
                                  "Color values in range 0 to maxval"
                                  (list r g b maxval))))))

