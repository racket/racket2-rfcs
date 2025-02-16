#lang racket/base

(require rhombus/private/provide)
(provide (for-spaces (rhombus/class
                      rhombus/namespace)
                     PartialOrder)
         (for-spaces (#f
                      rhombus/repet)
                     =~
                     !=~
                     <~
                     >~
                     <=~
                     >=~))
(module+ private
  (provide PartialOrder?
           equal-proc/partial-compare
           hash-proc/compare-key))

(require (for-syntax racket/base
                     rhombus/private/interface-parse)
         rhombus/private/define-operator
         (only-in rhombus/private/arithmetic
                  \|\| &&
                  [+ rhombus+]
                  [- rhombus-]
                  [* rhombus*]
                  [/ rhombus/])
         rhombus/private/name-root
         rhombus/private/realm
         (only-in rhombus/private/class-desc define-class-desc-syntax)
         "../common/partial-order-util.rkt")

;; ---------------------------------------------------------

;; PartialOrder struct type property and interface

(define-values (prop:partial-order partial-order? partial-order-ref)
  (make-struct-type-property
   'partial-order
   (λ (val _info)
     (unless (and (list? val)
                  (= 2 (length val))
                  (procedure? (car val))
                  (procedure? (cadr val))
                  (procedure-arity-includes? (car val) 3)
                  (procedure-arity-includes? (cadr val) 2))
       (raise-argument-error* 'partial_compare
                              rhombus-realm
                              (string-append
                               "(list/c (procedure-arity-includes/c 3)\n"
                               "        (procedure-arity-includes/c 2))")
                              val))
     ;; a `cons` here creates a unique identity for each time the
     ;; property is attached to a structure type
     (cons (car val) (cdr val)))))

;; partial-compare/recur : Any Any [Any Any -> PartialOrder] -> PartialOrder
(define (partial-compare/recur a b recur)
  (let ([cmp (lambda (ai bi) (partial-ordering-normalize (recur ai bi)))])
    (cond
      [(partial-order? a)
       (cond
         [(partial-order? b)
          (let ([av (partial-order-ref a)])
            (cond
              [(eq? av (partial-order-ref b))
               (partial-ordering-normalize ((car av) a b cmp))]
              [else +nan.0]))]
         [else +nan.0])]
      [(realish? a)
       (cond
         [(realish? b) (partial-compare-realish a b)]
         [else +nan.0])]
      [else
       (product-compare/recur a b cmp #true)])))

;; partial-compare : Any Any -> PartialOrder
(define (partial-compare a b)
  (partial-compare/recur a b partial-compare))

;; Any -> Fixnum
(define (compare-hash-code x)
  (cond
    [(partial-order? x)
     (->fx ((cadr (partial-order-ref x)) x compare-hash-code) 'compare-hash-code)]
    [(realish? x) (equal-hash-code (realish-key x))]
    [else (product-hash-code/recur x compare-hash-code #true)]))

(define-values (prop:PartialOrder PartialOrder? PartialOrder-ref)
  (make-struct-type-property
   'PartialOrder
   #false
   (list (cons prop:partial-order
               (lambda (v)
                 (define compare_key (vector-ref v 0))
                 (define partial_compare (vector-ref v 1))
                 (define (compare-hash-code-proc x rec)
                   (rec (compare_key x)))
                 (list partial_compare compare-hash-code-proc))))))

(define-class-desc-syntax PartialOrder
  (interface-desc #'PartialOrder
                  #'PartialOrder
                  #'()
                  #'prop:PartialOrder
                  #'PartialOrder-ref
                  (vector-immutable (box-immutable 'compare_key)
                                    (box-immutable 'partial_compare))
                  #'#(#:abstract partial_order/key)
                  (hasheq 'compare_key 0 'partial_compare 1)
                  #hasheq()
                  #t))

(module+ private
  ;; equal-proc/partial-compare : Self Imp (Any Any -> Boolean) -> Boolean
  (define (equal-proc/partial-compare a b recur-eql)
    (define partial_compare (vector-ref (PartialOrder-ref a) 1))
    (define (recur-cmp ai bi) (if (recur-eql ai bi) 0 +nan.0))
    (partial_compare a b recur-cmp))

  ;; hash-proc/compare-key : Self (Any -> Integer) -> Integer
  (define (hash-proc/compare-key a recur-hsh)
    (define compare_key (vector-ref (PartialOrder-ref a) 0))
    (recur-hsh (compare_key a))))

(define (partial_order/key self other recur)
  (define self.compare_key (vector-ref (PartialOrder-ref self) 0))
  (define other.compare_key (vector-ref (PartialOrder-ref other) 0))
  (recur (self.compare_key self) (other.compare_key other)))

;; ---------------------------------------------------------

;; Public operations

(define-name-root PartialOrder
  #:fields
  (partial_compare
   compare
   compare_hash_code
   within))

(define (partial_compare a b) (partial-compare a b))

(define (compare a b)
  (ordering-normalize (partial-compare/recur a b compare)))

(define (compare_hash_code a) (compare-hash-code a))

(define (partial-compare/= a b)
  (early-nan/= (partial-compare/recur a b partial-compare/=)))

(define (partial-compare/<= a b)
  (early-nan/<= (partial-compare/recur a b partial-compare/<=)))

(define (partial-compare/>= a b)
  (early-nan/>= (partial-compare/recur a b partial-compare/>=)))

(define (partial-compare/within a b epsilon)
  (early-nan/=
   (cond
     [(realish? a)
      (ord-and/bool (realish? b) (partial-compare-realish/within a b epsilon))]
     [else
      (define (cmp ai bi) (partial-compare/within ai bi epsilon))
      (partial-compare/recur a b cmp)])))

(define (within a b epsilon)
  (zero? (partial-compare/within a b epsilon)))

(define (=~? a b) (zero? (partial-compare/= a b)))
(define (!=~? a b) (not (zero? (partial-compare/= a b))))

(define (<~? a b) (negative? (partial-compare/<= a b)))
(define (>~? a b) (positive? (partial-compare/>= a b)))
(define (<=~? a b) (<= (partial-compare/<= a b) 0))
(define (>=~? a b) (>= (partial-compare/>= a b) 0))

(define-syntax-rule (define-comp~-infix name racket-name)
  (define-infix name racket-name
    #:weaker-than (rhombus+ rhombus- rhombus* rhombus/)
    #:same-as (<~ <=~ =~ !=~ >=~ >~)
    #:stronger-than (\|\| &&)
    #:associate 'none))

(define-comp~-infix <~ <~?)
(define-comp~-infix <=~ <=~?)
(define-comp~-infix =~ =~?)
(define-comp~-infix !=~ !=~?)
(define-comp~-infix >=~ >=~?)
(define-comp~-infix >~ >~?)
