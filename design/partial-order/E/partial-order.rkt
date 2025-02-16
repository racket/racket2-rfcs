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
                     >=~
                     =?
                     !=?
                     <?
                     >?
                     <=?
                     >=?))
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
                  (procedure-arity-includes? (car val) 4)
                  (procedure-arity-includes? (cadr val) 3))
       (raise-argument-error* 'prop:partial-compare
                              rhombus-realm
                              (string-append
                               "(list/c (procedure-arity-includes/c 3)\n"
                               "        (procedure-arity-includes/c 2))")
                              val))
     ;; a `cons` here creates a unique identity for each time the
     ;; property is attached to a structure type
     (cons (car val) (cdr val)))))

;; partial-compare/recur :
;; Any Any [Any Any -> PartialOrdering] Boolean -> PartialOrdering
(define (partial-compare/recur a b recur mode)
  (let ([cmp (lambda (ai bi) (partial-ordering-normalize (recur ai bi)))])
    (cond
      [(partial-order? a)
       (cond
         [(partial-order? b)
          (let ([av (partial-order-ref a)])
            (cond
              [(eq? av (partial-order-ref b))
               (partial-ordering-normalize ((car av) a b cmp mode))]
              [else +nan.0]))]
         [else +nan.0])]
      [(realish? a)
       (cond
         [(realish? b) (partial-compare-realish a b)]
         [else +nan.0])]
      [else
       (product-compare/recur a b cmp mode)])))

;; compare-hash-code/recur : Any [Any -> Fixnum] Boolean -> Fixnum
(define (compare-hash-code/recur x recur mode)
  (cond
    [(partial-order? x)
     (->fx ((cadr (partial-order-ref x)) x recur mode) 'compare-hash-code)]
    [(realish? x) (equal-hash-code (realish-key x))]
    [else (product-hash-code/recur x recur #true)]))

(define-values (prop:PartialOrder PartialOrder? PartialOrder-ref)
  (make-struct-type-property
   'PartialOrder
   #false
   (list (cons prop:partial-order
               (lambda (v)
                 (unless (and (vector? v) (= 2 (vector-length v)))
                   (raise-argument-error* 'PartialOrder
                                          rhombus-realm
                                          "method vector"
                                          v))
                 (define compare_key (vector-ref v 0))
                 (define partial_compare (vector-ref v 1))
                 (unless (and (procedure? compare_key)
                              (procedure-arity-includes? compare_key 1))
                   (raise-argument-error* 'compare_key
                                          rhombus-realm
                                          "(procedure-arity-includes/c 1)"
                                          compare_key))
                 (unless (and (procedure? partial_compare)
                              (procedure-arity-includes? partial_compare 4))
                   (raise-argument-error* 'partial_compare
                                          rhombus-realm
                                          "(procedure-arity-includes/c 4)"
                                          partial_compare))
                 (define (compare-hash-code-proc x rec mode)
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
    (partial_compare a b recur-cmp #true))

  ;; hash-proc/compare-key : Self (Any -> Integer) -> Integer
  (define (hash-proc/compare-key a recur-hsh)
    (define compare_key (vector-ref (PartialOrder-ref a) 0))
    (recur-hsh (compare_key a))))

(define (partial_order/key self other recur mode)
  (define self.compare_key (vector-ref (PartialOrder-ref self) 0))
  (define other.compare_key (vector-ref (PartialOrder-ref other) 0))
  (and mode (recur (self.compare_key self) (other.compare_key other))))

;; ---------------------------------------------------------

;; Public operations

(define-name-root PartialOrder
  #:fields
  (partial_compare_now
   partial_compare_always
   compare_now
   compare_always
   compare_now_hash_code
   compare_always_hash_code
   within))

(define (partial_compare_now a b)
  (partial-compare/recur a b partial_compare_now #true))

(define (partial_compare_always a b)
  (partial-compare/recur a b partial_compare_always #false))

(define (compare_now a b)
  (ordering-normalize (partial-compare/recur a b compare_now #true)))

(define (compare_always a b)
  (ordering-normalize (partial-compare/recur a b compare_always #false)))

(define (compare_now_hash_code a)
  (compare-hash-code/recur a compare_now_hash_code #true))

(define (compare_always_hash_code a)
  (compare-hash-code/recur a compare_always_hash_code #false))

(define (partial-compare/=~ a b)
  (early-nan/= (partial-compare/recur a b partial-compare/=~ #true)))

(define (partial-compare/<=~ a b)
  (early-nan/<= (partial-compare/recur a b partial-compare/<=~ #true)))

(define (partial-compare/>=~ a b)
  (early-nan/>= (partial-compare/recur a b partial-compare/>=~ #true)))

(define (partial-compare/=? a b)
  (early-nan/= (partial-compare/recur a b partial-compare/=? #false)))

(define (partial-compare/<=? a b)
  (early-nan/<= (partial-compare/recur a b partial-compare/<=? #false)))

(define (partial-compare/>=? a b)
  (early-nan/>= (partial-compare/recur a b partial-compare/>=? #false)))

(define (within a b epsilon)
  (define (cmp ai bi)
    (early-nan/=
     (cond
       [(realish? ai)
        (ord-and/bool (realish? bi) (partial-compare-realish/within ai bi epsilon))]
       [else
        (partial-compare/recur ai bi cmp #true)])))
  (zero? (cmp a b)))

(define (op=~ a b) (zero? (partial-compare/=~ a b)))
(define (op!=~ a b) (not (zero? (partial-compare/=~ a b))))

(define (op<~ a b) (negative? (partial-compare/<=~ a b)))
(define (op>~ a b) (positive? (partial-compare/>=~ a b)))
(define (op<=~ a b) (<= (partial-compare/<=~ a b) 0))
(define (op>=~ a b) (>= (partial-compare/>=~ a b) 0))

(define (op=? a b) (zero? (partial-compare/=? a b)))
(define (op!=? a b) (not (zero? (partial-compare/=? a b))))

(define (op<? a b) (negative? (partial-compare/<=? a b)))
(define (op>? a b) (positive? (partial-compare/>=? a b)))
(define (op<=? a b) (<= (partial-compare/<=? a b) 0))
(define (op>=? a b) (>= (partial-compare/>=? a b) 0))

(define-syntax-rule (define-comp~-infix name racket-name)
  (define-infix name racket-name
    #:weaker-than (rhombus+ rhombus- rhombus* rhombus/)
    #:same-as (<~ <=~ =~ !=~ >=~ >~ <? <=? =? !=? >=? >?)
    #:stronger-than (\|\| &&)
    #:associate 'none))

(define-comp~-infix <~ op<~)
(define-comp~-infix <=~ op<=~)
(define-comp~-infix =~ op=~)
(define-comp~-infix !=~ op!=~)
(define-comp~-infix >=~ op>=~)
(define-comp~-infix >~ op>~)

(define-comp~-infix <? op<?)
(define-comp~-infix <=? op<=?)
(define-comp~-infix =? op=?)
(define-comp~-infix !=? op!=?)
(define-comp~-infix >=? op>=?)
(define-comp~-infix >? op>?)
