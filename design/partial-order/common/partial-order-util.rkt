#lang racket/base

(provide ordering-normalize
         partial-ordering-normalize
         ord-and/bool
         ord-and/prod
         realish?
         realish-key
         partial-compare-realish
         partial-compare-realish/within
         product-compare/recur
         product-hash-code/recur
         ->fx
         early-nan/=
         early-nan/<=
         early-nan/>=)

(require (for-syntax racket/base)
         racket/fixnum
         racket/flonum
         racket/extflonum
         racket/hash-code
         racket/math
         syntax/parse/define)

;; A Ordering is a ComparableReal where:
;;  - zero?     represents =~
;;  - negative? represents <~
;;  - positive? represents >~
;; this excludes NaN

;; ordering-normalize : Ordering -> Ordering
(define (ordering-normalize c)
  (cond
    [(zero? c) 0]
    [(negative? c) -1]
    [(positive? c) 1]
    [else (error 'compare "bad ~v" c)]))

;; A PartialOrdering is a Real where:
;;  - zero?     represents =~
;;  - negative? represents <~
;;  - positive? represents >~
;;  - nan?      represents incomparable

;; partial-ordering-normalize : PartialOrdering -> PartialOrdering
(define (partial-ordering-normalize c)
  (cond
    [(zero? c) 0]
    [(negative? c) -1]
    [(positive? c) 1]
    [(nan? c) +nan.0]
    [else (error 'partial_compare "bad ~v" c)]))

;; ord-and/bool : Boolean ... PartialOrdering -> PartialOrdering
(define-syntax-parser ord-and/bool
  [(_) #'0]
  [(_ c) #'c]
  [(_ b . rst)
   #'(if b (ord-and/bool . rst) +nan.0)])

;; ord-and/prod2 : PartialOrdering PartialOrdering -> PartialOrdering
(define (ord-and/prod2 c0 c1)
  (cond
    [(zero? c0) c1]
    [(zero? c1) c0]
    [(and (negative? c0) (negative? c1)) -1]
    [(and (positive? c0) (positive? c1)) 1]
    [else +nan.0]))

;; ord-and/prod : PartialOrdering ... PartialOrdering
(define-syntax-parser ord-and/prod
  [(_) #'0]
  [(_ c) #'c]
  [(_ c0 c1 . rst)
   #'(let ([c0v c0])
       (if (nan? c0v)
           +nan.0
           (ord-and/prod (ord-and/prod2 c0v c1) . rst)))])

;; A Realish is one of:
;;  - Real
;;  - Extflonum
(define (realish? v)
  (or (real? v) (extflonum? v)))

;; realish-key : Realish -> Real
(define (realish-key x)
  (cond
    [(or (eq? x +inf.0) (eq? x +inf.f) (eq? x +inf.t)) +inf.0]
    [(or (eq? x -inf.0) (eq? x -inf.f) (eq? x -inf.t)) -inf.0]
    [(or (eq? x +nan.0) (eq? x +nan.f) (eq? x +nan.t)) +nan.0]
    [(extflonum? x) (extfl->exact x)]
    [else (inexact->exact x)]))

;; partial-compare-realish : Realish Realish -> PartialOrdering
(define (partial-compare-realish a b)
  (cond
    [(and (real? a) (real? b)) (partial-compare-real a b)]
    [(and (extflonum? a) (extflonum? b)) (partial-compare-extflonum a b)]
    [else (partial-compare-real (realish-key a) (realish-key b))]))

;; partial-compare-real : Real Real -> PartialOrdering
(define (partial-compare-real a b)
  (cond
    [(= a b) 0]
    [(< a b) -1]
    [(> a b) 1]
    [else +nan.0]))

;; partial-compare-extflonum : Extflonum Extflonum -> PartialOrdering
(define (partial-compare-extflonum a b)
  (cond
    [(extfl= a b) 0]
    [(extfl< a b) -1]
    [(extfl> a b) 1]
    [else +nan.0]))

;; partial-compare-realish/within : Realish Realish Real -> PartialOrdering
(define (partial-compare-realish/within a b epsilon)
  (cond
    [(and (real? a) (real? b)) (partial-compare-real/within a b epsilon)]
    [else (partial-compare-real/within (realish-key a) (realish-key b) epsilon)]))

;; partial-compare-real/within : Real Real Real -> PartialOrdering
(define (partial-compare-real/within a b epsilon)
  (define d (- a b))
  (cond
    [(<= (- epsilon) d epsilon) 0]
    [(< d (- epsilon)) -1]
    [(> d epsilon) 1]
    [else +nan.0]))

;; product-compare/recur :
;; Any Any [Any Any -> PartialOrdering] Boolean -> PartialOrdering
(define (product-compare/recur a b cmp mode)
  (cond
    [(eq? a b) 0]
    [(flvector? a)
     (ord-and/bool
      mode
      (flvector? b)
      (= (flvector-length a) (flvector-length b))
      (for/fold ([acc 0])
                ([ai (in-flvector a)]
                 [bi (in-flvector b)])
        #:break (nan? acc)
        (ord-and/prod acc (cmp ai bi))))]
    [(extflvector? a)
     (ord-and/bool
      mode
      (extflvector? b)
      (= (extflvector-length a) (extflvector-length b))
      (for/fold ([acc 0])
                ([ai (in-extflvector a)]
                 [bi (in-extflvector b)])
        #:break (nan? acc)
        (ord-and/prod acc (cmp ai bi))))]
    [else
     (define (<=? ai bi) (<= (cmp ai bi) 0))
     (define (>=? ai bi) (>= (cmp ai bi) 0))
     (define le (if mode (equal?/recur a b <=?) (equal-always?/recur a b <=?)))
     (define ge (if mode (equal?/recur a b >=?) (equal-always?/recur a b >=?)))
     (cond
       [(and le ge) 0]
       [le -1]
       [ge 1]
       [else +nan.0])]))

;; product-hash-code/recur : Any [Any -> Integer] Boolean -> Integer
(define (product-hash-code/recur x recur mode)
  (cond
    [(flvector? x)
     (if mode
         (let loop ([acc (equal-hash-code (make-flvector 0))] [i 0])
           (cond
             [(<= (flvector-length x) i) acc]
             [else
              (loop (hash-code-combine acc (recur (flvector-ref x i)))
                    (add1 i))]))
         (eq-hash-code x))]
    [(extflvector? x)
     (if mode
         (let loop ([acc (equal-hash-code (make-extflvector 0))] [i 0])
           (cond
             [(<= (extflvector-length x) i) acc]
             [else
              (loop (hash-code-combine acc (recur (extflvector-ref x i)))
                    (add1 i))]))
         (eq-hash-code x))]
    [else
     (if mode
         (equal-hash-code/recur x recur)
         (equal-always-hash-code/recur x recur))]))

;; maps non-fixnum integers to positive fixnums
(define (->fx v [who '->fx])
  (cond
    [(fixnum? v) v]
    [(exact-integer? v) (bitwise-and v (most-positive-fixnum))]
    [else (raise-argument-error who "exact-integer?" v)]))

;; PartialOrdering -> PartialOrdering
(define (early-nan/= c) (if (zero? c) 0 +nan.0))
(define (early-nan/<= c) (if (<= c 0) c +nan.0))
(define (early-nan/>= c) (if (>= c 0) c +nan.0))

