#lang typed/racket

; This is a demonstration of what *else* we can do post
; "defunctionalization". Students are not required to
; know this. It implements a "compile to C code" facility
; for our "image language" so that complex images can be
; generated at large sizes efficiently.
;
; With the "pictures as functions" approach, generation of
; each pixel entails a series of nested function calls. With
; this "picture to C compiler", the number of ("C") function calls
; to produce each pixel is a small constant independent of the
; complexity of the picture composition.
;
; Usage: (compile-to-file "mypic.c" (desugar <picexpr>) 1)
;
; Will output a file named "mypic.c" containing the generated
; code. You'll need to compile it and run it. For example -
;
; clang -O3 -o mypic mypic.c
; <or>
; gcc -O3 -o mypic mypic.c
;
; followed by -
;
; ./mypic -2.0 -2.0 2.0 2.0 512 512 > mypic.ppm
;
; The C program will output the PPM file to stdout, so
; you'll need to redirect it to a file with "> mypic.ppm".
; For a comparison, try generating a 2048x2048 image with
; the function based interpreter and then try the same picture
; via the C compiler and time it, to see the difference in 
; performance.
;
; PS: This version also removes a redundancy we saw with the
; "Sugar" and "Core" terms. This file uses parameterized structs
; to model terms that can feature in both types of expressions.

(require "color.rkt")
(require "picture-lib.rkt")

; Sugar free
(struct Circle [[radius : Float]
                [thickness : Float]]
  #:transparent)
(struct (t) Overlay [[pic1 : t]
                     [pic2 : t]]
  #:transparent)
(struct (t) Colorize [[a : Float]
                      [r : Float]
                      [g : Float]
                      [b : Float]
                      [pic : t]]
  #:transparent)
(struct (t) Affine [[mxx : Float]
                    [mxy : Float]
                    [myx : Float]
                    [myy : Float]
                    [dx : Float]
                    [dy : Float]
                    [pic : t]]
  #:transparent)

; Sugar form
(struct (t) Translate [[dx : Float]
                       [dy : Float]
                       [pic : t]]
  #:transparent)

(define-type PicSugar (U Circle
                         (Overlay PicSugar)
                         (Colorize PicSugar)
                         (Affine PicSugar)
                         (Translate PicSugar)))

(define-type PicCore (U Circle
                        (Overlay PicCore)
                        (Colorize PicCore)
                        (Affine PicCore)))

(define picexpr : PicSugar
  (Overlay ; 1
   (Colorize 1.0 1.0 0.0 0.0 ; 2
             (Circle 1.5 0.1)) ; 4
   (Translate 0.5 0.0 ; 3
              (Colorize 1.0 0.0 0.0 1.0 ; 6
                        (Circle 1.5 0.1))))) ; 12

(: interpret-picexpr (-> PicCore Picture))
(define (interpret-picexpr picexpr)
  (match picexpr
    [(Circle radius thickness)
     (circle radius thickness)]
    [(Affine mxx mxy myx myy dx dy picexpr2)
     (affine mxx mxy myx myy dx dy (interpret-picexpr picexpr2))]
    [(Overlay picexpr1 picexpr2)
     (overlay (interpret-picexpr picexpr1)
              (interpret-picexpr picexpr2))]
    [(Colorize a r g b pic)
     (colorize a r g b (interpret-picexpr pic))]))

; Note that the desugar operation is the same whether the result
; is fed into the interpreter or the compiler.
(: desugar (-> PicSugar PicCore))
(define (desugar picexpr)
  (match picexpr
    [(Translate dx dy picexpr2)
     (Affine 1.0 0.0 0.0 1.0 dx dy (desugar picexpr2))]
    [(Colorize a r g b picexpr2)
     (Colorize a r g b (desugar picexpr2))]
    [(Overlay picexpr1 picexpr2)
     (Overlay (desugar picexpr1) (desugar picexpr2))]
    [(Circle radius thickness)
     (Circle radius thickness)]))

(: compile-to-file (-> String PicCore Positive-Integer Any))
(define (compile-to-file file picexpr varn)
  (call-with-output-file file
    (λ ([f : Output-Port])
      (show f
            "#include \"picbase.h\"\n"
            "int main(int argc, const char **argv) {\n"
            "    if (argc < 7) { printf(\"Usage: pic x1 y1 x2 y2 nx ny\\n\"); exit(-1); }\n"
            "    float x1 = atof(argv[1]), y1 = atof(argv[2]), x2 = atof(argv[3]), y2 = atof(argv[4]);\n"            
            "    int nx = atoi(argv[5]), ny = atoi(argv[6]);\n"
            "    float dx = (x2 - x1) / nx;\n"
            "    float dy = (y2 - y1) / ny;\n"
            "    color *result = malloc(nx * ny * sizeof(color));\n"
            "    color white = argb(1.0, 1.0, 1.0, 1.0);\n"
            "    color background = argb(0.0, 0.0, 0.0, 0.0);\n")
      (declare-fields f picexpr varn)

      (show f
            "    for (int r = 0; r < ny; ++r) {\n"
            "        for (int c = 0; c < nx; ++c) {\n"
            "            float v0_x = x1 + dx * c, v0_y = y2 - dy * r;\n")
      (compile-calculations f picexpr 0 varn)
      (show f
            "            color result_color = v" (number->string varn) "_color;\n"
            "            result[r * nx + c] = result_color;\n"
            "        }\n"
            "    }\n\n"
            "    write_ppm(nx, ny, result);\n"
            "    free(result);\n"
            "}\n"))))

(: show (-> Output-Port Any * Any))
(define (show f . vals)
  (for-each (λ (x) (display x f)) vals))

(: vn (-> Nonnegative-Integer String String))
(define (vn n suffix) (string-append "v" (number->string n) "_" suffix))

(struct Compiler ([decl : (-> Output-Port String (Listof Nonnegative-Integer) Any)]
                  [compute : (-> Output-Port String (Listof Nonnegative-Integer) Any)]
                  [output : (-> Output-Port String (Listof Nonnegative-Integer) Any)]))

(: circle/c (-> Float Float Compiler))
(define (circle/c radius thickness)
  (Compiler
   (λ (f indent vs)
     (match vs
       [(list vout)
        (show f
              indent "float "
              (vn vout "radius") " = " (number->string radius) ", "
              (vn vout "thickness") " = " (number->string thickness) ";\n")]))
   (λ (f indent vs)
     (match vs
       [(list vin vout)
        (show f
              indent "float " (vn vout "r") " = sqrt(v0_x * v0_x + v0_y * v0_y);\n"
              indent "if (" (vn vout "r") " >= " (vn vout "radius") " - " (vn vout "thickness") " && " (vn vout "r") " <= " (vn vout "radius") " + " (vn vout "thickness") ") {\n"
              indent "    " (vn vout "color") " = white;\n"
              indent "} else {\n"
              indent "    " (vn vout "color") " = background;\n"
              indent "}\n")]))
   (λ (f indent vs) #f)))

(: affine/c (-> Float Float Float Float Float Float PicCore Compiler))
(define (affine/c mxx mxy myx myy dx dy picexpr)
  (Compiler
   (λ (f indent vs)
     (match vs
       [(list vout)
        (show f
              indent "float "
              (vn vout "mxx") " = " (number->string mxx) ", "
              (vn vout "mxy") " = " (number->string mxy) ", "
              (vn vout "myx") " = " (number->string myx) ", "
              (vn vout "myy") " = " (number->string myy) ", "
              (vn vout "dx") " = " (number->string dx) ", "
              (vn vout "dy") " = " (number->string dy) ";\n"
              indent "float " (vn vout "det") " = " (vn vout "mxx") " * " (vn vout "myy") " - " (vn vout "mxy") " * " (vn vout "myx") ";\n"
              indent "float " (vn vout "mxxi") " = " (vn vout "myy") " / " (vn vout "det") ";\n"
              indent "float " (vn vout "myyi") " = " (vn vout "mxx") " / " (vn vout "det") ";\n"
              indent "float " (vn vout "mxyi") " = -" (vn vout "mxy") " / " (vn vout "det") ";\n"
              indent "float " (vn vout "myxi") " = -" (vn vout "mxy") " / " (vn vout "det") ";\n")]))
   (λ (f indent vs)
     (match vs
       [(list vin vout)
        (show f
              indent "float " (vn vout "tmp_x") " = v0_x, " (vn vout "tmp_y") " = v0_y;\n"
              indent "v0_x = " (vn vout "mxxi") " * (" (vn vin "x") " - " (vn vout "dx") ") + " (vn vout "mxyi") " * (" (vn vin "y") " - " (vn vout "dy") ");\n"
              indent "v0_y = " (vn vout "myxi") " * (" (vn vin "x") " - " (vn vout "dx") ") + " (vn vout "myyi") " * (" (vn vin "y") " - " (vn vout "dy") ");\n")]))
   (λ (f indent vs)
     (match vs
       [(list vout vo)
        (show f
              indent "v0_x = " (vn vout "tmp_x") "; v0_y = " (vn vout "tmp_y") ";\n"
              indent (vn vout "color") " = " (vn vo "color") ";\n")]))))

(: colorize/c (-> Float Float Float Float PicCore Compiler))
(define (colorize/c a r g b picexpr)
  (Compiler
   (λ (f indent vs)
     (match vs
       [(list v)
        (show f
              indent "float " (vn v "a") " = " (number->string a) ", "
              (vn v "r") " = " (number->string r) ", "
              (vn v "g") " = " (number->string g) ", "
              (vn v "b") " = " (number->string b) ";\n"
              indent "color " (vn v "colorize") " = argb(" (vn v "a") ", " (vn v "r") ", " (vn v "g") ", " (vn v "b") ");\n")]))
   (λ (f indent vs)
     (match vs
       [(list vin vout)
        (let ([vout2 (* 2 vout)])
          (show f
                indent "if (" (vn vout2 "color.a") " > 0.01) {\n"
                indent "    " (vn vout "color") " = " (vn vout "colorize") ";\n"
                indent "} else {\n"
                indent "    " (vn vout "color") " = background;\n"
                indent "}\n"))]))
   (λ (f indent _) #f)))

(: overlay/c (-> PicCore PicCore Compiler))
(define (overlay/c pic1 pic2)
  (Compiler
   (λ (f indent _) #f)
   (λ (f indent vs)
     (match vs
       [(list vout vout1 vout2)
        (show f indent (vn vout "color") " = mix(" (vn vout1 "color") ", " (vn vout2 "color") ");\n")]))
   (λ (f indent _)
     #f)))
     
(: declare-fields (-> Output-Port PicCore Positive-Integer Any))
(define (declare-fields f picexpr varn)
  (match picexpr
    [(Circle radius thickness)
     ((Compiler-decl (circle/c radius thickness)) f "\t" (list varn))]
    [(Affine mxx mxy myx myy dx dy picexpr2)
     ((Compiler-decl (affine/c mxx mxy myx myy dx dy picexpr2)) f "\t" (list varn))
     (declare-fields f picexpr2 (* varn 2))]
    [(Overlay picexpr1 picexpr2)
     (declare-fields f picexpr1 (* varn 2))
     (declare-fields f picexpr2 (+ (* varn 2) 1))]
    [(Colorize a r g b pic)
     ((Compiler-decl (colorize/c a r g b pic)) f "\t" (list varn))
     (declare-fields f pic (* varn 2))]))

(: compile-calculations (-> Output-Port PicCore Nonnegative-Integer Positive-Integer Any))
(define (compile-calculations f picexpr varin varout)
  (show f "\t\t\tcolor " (vn varout "color") ";\n")
  (match picexpr
    [(Circle radius thickness)
     ((Compiler-compute (circle/c radius thickness)) f "\t\t\t" (list varin varout))]
    [(Affine mxx mxy myx myy dx dy picexpr2)
     (let ([compiler (affine/c mxx mxy myx myy dx dy picexpr2)])
       ((Compiler-compute compiler) f "\t\t\t" (list varin varout))
       (compile-calculations f picexpr2 varout (* varout 2))
       ((Compiler-output compiler) f "\t\t\t" (list varout (* varout 2))))]
    [(Overlay picexpr1 picexpr2)
     (compile-calculations f picexpr1 varin (* varout 2))
     (compile-calculations f picexpr2 varin (+ 1 (* varout 2)))
     ((Compiler-compute (overlay/c picexpr1 picexpr2)) f "\t\t\t" (list varout (* varout 2) (+ 1 (* varout 2))))]
    [(Colorize a r g b pic)
     (compile-calculations f pic varout (* 2 varout))
     ((Compiler-compute (colorize/c a r g b pic)) f "\t\t\t" (list varin varout))]))
  








