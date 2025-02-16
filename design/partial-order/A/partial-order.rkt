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
   (λ (value _type-info)
     (unless (and (procedure? value)
                  (procedure-arity-includes? value 3))
       (raise-argument-error* 'partial_compare
                              rhombus-realm
                              "a method of 2 arguments (after this)"
                              value))
     (list (gensym) value))))

(define-values (prop:PartialOrder _PartialOrder? PartialOrder-ref)
  (make-struct-type-property
   'PartialOrder
   #false
   (list (cons prop:partial-order (lambda (v) (vector-ref v 0))))))

(define-class-desc-syntax PartialOrder
  (interface-desc #'PartialOrder
                  #'PartialOrder
                  #'()
                  #'prop:PartialOrder
                  #'PartialOrder-ref
                  (vector-immutable (box-immutable 'partial_compare))
                  #'#(#:abstract)
                  (hasheq 'partial_compare 0)
                  #hasheq()
                  #t))

;; ---------------------------------------------------------

;; Public operations

(define-name-root PartialOrder
  #:fields
  (partial_compare
   compare
   within))

(define (partial-compare/recur a b recur)
  (define (cmp ai bi)
    (partial-ordering-normalize (recur ai bi)))
  (cond
    [(partial-order? a)
     (ord-and/bool
      (partial-order? b)
      (let ([av (partial-order-ref a)])
        (ord-and/bool
         (eq? av (partial-order-ref b))
         (partial-ordering-normalize ((cadr av) a b cmp)))))]
    [(realish? a)
     (ord-and/bool (realish? b) (partial-compare-realish a b))]
    [else
     (product-compare/recur a b cmp #true)]))

(define (partial_compare a b)
  (partial-compare/recur a b partial_compare))

(define (compare/recur a b recur)
  (define (cmp ai bi) (ordering-normalize (recur ai bi)))
  (ordering-normalize (partial-compare/recur a b cmp)))

(define (compare a b)
  (compare/recur a b compare))

(define (partial-compare/within a b epsilon)
  (cond
    [(realish? a)
     (ord-and/bool (realish? b) (partial-compare-realish/within a b epsilon))]
    [else
     (define (cmp ai bi) (partial-compare/within ai bi epsilon))
     (partial-compare/recur a b cmp)]))

(define (within a b epsilon)
  (zero? (partial-compare/within a b epsilon)))

(define (=~? a b) (zero? (partial_compare a b)))
(define (!=~? a b) (not (zero? (partial_compare a b))))

(define (<~? a b) (negative? (compare a b)))
(define (>~? a b) (positive? (compare a b)))
(define (<=~? a b) (<= (compare a b) 0))
(define (>=~? a b) (>= (compare a b) 0))

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
