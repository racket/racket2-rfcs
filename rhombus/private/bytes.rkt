#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         "provide.rkt"
         "static-info.rkt"
         "define-arity.rkt"
         "call-result-key.rkt"
         "index-key.rkt"
         "append-key.rkt"
         (submod "annotation.rkt" for-class)
         "mutability.rkt"
         "define-arity.rkt"
         "class-primitive.rkt"
         "rhombus-primitive.rkt")

(provide (for-spaces (rhombus/annot
                      rhombus/namespace)
                     Bytes)
         (for-space rhombus/annot
                    MutableBytes
                    ImmutableBytes))

(module+ for-builtin
  (provide bytes-method-table))

(module+ static-infos
  (provide (for-syntax bytes-static-infos)))

(define-primitive-class Bytes bytes
  #:lift-declaration
  #:no-constructor-static-info
  #:instance-static-info ((#%index-get Bytes.get)
                          (#%index-set Bytes.set)
                          (#%append Bytes.append))
  #:existing
  #:opaque
  #:fields ()
  #:namespace-fields
  ([make Bytes.make]
   )
  #:properties
  ()
  #:methods
  (length
   subbytes
   copy
   copy_from
   utf8_string
   latin1_string
   locale_string
   ))

(define-annotation-syntax Bytes (identifier-annotation #'bytes? bytes-static-infos))
(define-annotation-syntax MutableBytes (identifier-annotation #'mutable-bytes? bytes-static-infos))
(define-annotation-syntax ImmutableBytes (identifier-annotation #'immutable-bytes? bytes-static-infos))

(set-primitive-contract! 'bytes? "Bytes")
(set-primitive-contract! '(and/c bytes? (not/c immutable?)) "MutableBytes")

(define/arity (Bytes.get b i)
  #:inline
  #:primitive (bytes-ref)
  (bytes-ref b i))

(define/arity (Bytes.set b i x)
  #:inline
  #:primitive (bytes-set!)
  (bytes-set! b i x))

(define/arity (Bytes.append b1 b2)
  #:inline
  #:primitive (bytes-append)
  (bytes-append b1 b2))

(define/arity Bytes.make
  #:inline
  #:primitive (make-bytes)
  #:static-infos ((#%call-result #,bytes-static-infos))
  (case-lambda
    [(len) (make-bytes len)]
    [(len val) (make-bytes len val)]))

(define/method (Bytes.length bstr)
  #:inline
  #:primitive (bytes-length)
  (bytes-length bstr))

(define/method Bytes.subbytes
  #:inline
  #:primitive (subbytes)
  #:static-infos ((#%call-result #,bytes-static-infos))
  (case-lambda
    [(bstr) (subbytes bstr)]
    [(bstr start) (subbytes bstr start)]
    [(bstr start end) (subbytes bstr start end)]))

(define-syntax (define-string stx)
  (syntax-parse stx
    [(_ utf8 utf-8)
     #:with method-name (datum->syntax #'utf8 (string->symbol (format "Bytes.~a_string" (syntax-e #'utf8))))
     #:with fn-name (datum->syntax #'utf-8 (string->symbol (format "bytes->string/~a" (syntax-e #'utf-8))))
     #'(define/method method-name
         #:inline
         #:primitive (fn-name)
         #:static-infos ((#%call-result #,indirect-string-static-infos))
         (case-lambda
           [(bstr) (string->immutable-string (fn-name bstr))]
           [(bstr err-char) (string->immutable-string (fn-name bstr err-char))]
           [(bstr err-char start) (string->immutable-string (fn-name bstr err-char start))]
           [(bstr err-char start end) (string->immutable-string (fn-name bstr err-char start end))]))]))

(define-string utf8 utf-8)
(define-string latin1 latin-1)
(define-string locale locale)

(define/method (Bytes.copy bstr)
  #:inline
  #:primitive (bytes-copy)
  #:static-infos ((#%call-result #,bytes-static-infos))
  (bytes-copy bstr))

(define/method Bytes.copy_from
  #:inline
  #:primitive (bytes-copy!)
  #:static-infos ((#%call-result #,bytes-static-infos))
  (case-lambda
    [(bstr dest-start src) (bytes-copy! bstr dest-start src)]
    [(bstr dest-start src src-start) (bytes-copy! bstr dest-start src src-start)]
    [(bstr dest-start src src-start src-end) (bytes-copy! bstr dest-start src src-start src-end)]))

(begin-for-syntax
  (install-static-infos! 'bytes bytes-static-infos))
