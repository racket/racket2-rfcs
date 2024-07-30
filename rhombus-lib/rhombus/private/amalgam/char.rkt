#lang racket/base
(require (for-syntax racket/base)
         "provide.rkt"
         "name-root.rkt"
         "define-arity.rkt"
         "number.rkt"
         "call-result-key.rkt"
         "compare-key.rkt"
         (submod "annotation.rkt" for-class)
         (submod "literal.rkt" for-info)
         (submod "symbol.rkt" for-static-info)
         "realm.rkt"
         "static-info.rkt"
         "class-primitive.rkt")

(provide (for-spaces (rhombus/annot
                      rhombus/namespace)
                     Char)
         (for-space rhombus/annot
                    CharCI))

(module+ for-builtin
  (provide char-method-table))

(module+ for-static-info
  (provide (for-syntax get-char-static-infos)))

(define-primitive-class Char char
  #:lift-declaration
  #:no-constructor-static-info
  #:instance-static-info ((#%compare ((< char<?)
                                      (<= char<=?)
                                      (= char=?)
                                      (!= char!=?)
                                      (>= char>=?)
                                      (> char>?))))
  #:existing
  #:opaque
  #:fields ()
  #:namespace-fields
  ([from_int Char.from_int])
  #:properties
  ()
  #:methods
  (to_int
   utf8_length
   is_alphabetic
   is_lowercase
   is_uppercase
   is_titlecase
   is_numeric
   is_symbolic
   is_punctuation
   is_graphic
   is_whitespace
   is_blank
   is_extended_pictographic
   general_category
   grapheme_break_property
   upcase
   downcase
   foldcase
   titlecase
   grapheme_step))

(define-annotation-syntax Char (identifier-annotation char? #,(get-char-static-infos)))

(define-annotation-syntax CharCI
  (identifier-annotation char? ((#%compare ((< char-ci<?)
                                            (<= char-ci<=?)
                                            (= char-ci=?)
                                            (!= char-ci!=?)
                                            (>= char-ci>=?)
                                            (> char-ci>?))))
                         #:static-only))

(define/method (Char.to_int c)
  #:primitive (char->integer)
  #:static-infos ((#%call-result #,(get-int-static-infos)))
  (char->integer c))

(define/arity (Char.from_int i)
  #:primitive (integer->char)
  #:static-infos ((#%call-result #,(get-char-static-infos)))
  (integer->char i))

(define/method (Char.utf8_length c)
  #:primitive (char-utf-8-length)
  (char-utf-8-length c))

(define/method (Char.is_alphabetic c)
  #:primitive (char-alphabetic?)
  (char-alphabetic? c))

(define/method (Char.is_lowercase c)
  #:primitive (char-lower-case?)
  (char-lower-case? c))

(define/method (Char.is_uppercase c)
  #:primitive (char-upper-case?)
  (char-upper-case? c))

(define/method (Char.is_titlecase c)
  #:primitive (char-title-case?)
  (char-title-case? c))

(define/method (Char.is_numeric c)
  #:primitive (char-numberic?)
  (char-numeric? c))

(define/method (Char.is_symbolic c)
  #:primitive (char-symbolic?)
  (char-symbolic? c))

(define/method (Char.is_punctuation c)
  #:primitive (char-punctuation?)
  (char-punctuation? c))

(define/method (Char.is_graphic c)
  #:primitive (char-graphics?)
  (char-graphic? c))

(define/method (Char.is_whitespace c)
  #:primitive (char-whitespace?)
  (char-whitespace? c))

(define/method (Char.is_blank c)
  #:primitive (char-blank?)
  (char-blank? c))

(define/method (Char.is_extended_pictographic c)
  #:primitive (char-extended-pictographic?)
  (char-extended-pictographic? c))

(define/method (Char.general_category c)
  #:primitive (char-general-category)
  #:static-infos ((#%call-result #,(get-symbol-static-infos)))
  (char-general-category c))

(define/method (Char.grapheme_break_property c)
  #:primitive (char-grapheme-break-property)
  #:static-infos ((#%call-result #,(get-symbol-static-infos)))
  (char-grapheme-break-property c))

(define/method (Char.upcase c)
  #:primitive (char-upcase)
  #:static-infos ((#%call-result #,(get-char-static-infos)))
  (char-upcase c))

(define/method (Char.downcase c)
  #:primitive (char-downcase)
  #:static-infos ((#%call-result #,(get-char-static-infos)))
  (char-downcase c))

(define/method (Char.foldcase c)
  #:primitive (char-foldcase)
  #:static-infos ((#%call-result #,(get-char-static-infos)))
  (char-foldcase c))

(define/method (Char.titlecase c)
  #:primitive (char-titlecase)
  #:static-infos ((#%call-result #,(get-char-static-infos)))
  (char-titlecase c))

(define/method (Char.grapheme_step c state)
  #:primitive (char-grapheme-step)
  (char-grapheme-step c state))

(define (char!=? a b)
  (if (and (char? a) (char? b))
      (not (char=? a b))
      (raise-argument-error* '!= rhombus-realm "Char" (if (char? a) b a))))

(define (char-ci!=? a b)
  (if (and (char? a) (char? b))
      (not (char-ci=? a b))
      (raise-argument-error* '!= rhombus-realm "Char" (if (char? a) b a))))

(begin-for-syntax
  (install-get-literal-static-infos! 'char get-char-static-infos))
