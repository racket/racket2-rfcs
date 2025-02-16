#lang racket/base
(require (for-syntax racket/base
                     rhombus/private/interface-parse)
         racket/hash-code
         rhombus/private/provide
         rhombus/private/name-root
         (submod rhombus/private/annotation for-class)
         (submod rhombus/private/dot for-dot-provider)
         rhombus/private/realm
         rhombus/private/class-dot
         (only-in rhombus/private/class-desc define-class-desc-syntax)
         rhombus/private/static-info
         (submod "partial-order.rkt" private))

(provide (for-spaces (rhombus/class
                      rhombus/namespace)
                     Equatable))

(define-values (prop:Equatable Equatable? Equatable-ref)
  (make-struct-type-property
   'Equatable
   #false
   (list (cons prop:equal+hash (lambda (_) bounced-equal+hash-implementation)))))

(define (bounce-to-equal-mode-proc this other recur mode)
  (cond
    [(and mode (PartialOrder? this))
     (equal-proc/partial-compare this other recur)]
    [else
     (equal-recur-internal-method this other recur)]))

(define (bounce-to-hash-mode-proc this recur mode)
  (cond
    [(and mode (PartialOrder? this))
     (hash-proc/compare-key this recur)]
    [else
     (hash-recur-internal-method this recur)]))

(define bounced-equal+hash-implementation
  (list bounce-to-equal-mode-proc bounce-to-hash-mode-proc))

(define-class-desc-syntax Equatable
  (interface-desc #'Equatable
                  #'Equatable
                  #'()
                  #'prop:Equatable
                  #'Equatable-ref
                  (vector-immutable (box-immutable 'equals)
                                    (box-immutable 'hash_code))
                  #'#(#:abstract #:abstract)
                  (hasheq 'equals 0 'hash_code 1)
                  #hasheq()
                  #t))

(define (equal-recur-internal-method this other recur)
  ((vector-ref (Equatable-ref this) 0) this other recur))

(define (hash-recur-internal-method this recur)
  ((vector-ref (Equatable-ref this) 1) this recur))

(define-name-root Equatable
  #:fields
  (hash_code_combine
   hash_code_combine_unordered))

(define hash_code_combine
  (case-lambda
    [() (hash-code-combine)]
    [(a)
     (unless (exact-integer? a)
       (raise-argument-error* 'Equatable.hash_code_combine rhombus-realm "Integer" a))
     (hash-code-combine a)]
    [(a b)
     (unless (exact-integer? a)
       (raise-argument-error* 'Equatable.hash_code_combine rhombus-realm "Integer" a))
     (unless (exact-integer? b)
       (raise-argument-error* 'Equatable.hash_code_combine rhombus-realm "Integer" b))
     (hash-code-combine a b)]
    [lst
     (for ([e (in-list lst)])
       (unless (exact-integer? e)
         (raise-argument-error* 'Equatable.hash_code_combine rhombus-realm "Integer" e)))
     (hash-code-combine* lst)]))

(define-static-info-syntax hash_code_combine (#%function-arity -1))
                                                               
(define hash_code_combine_unordered
  (case-lambda
    [() (hash-code-combine-unordered)]
    [(a)
     (unless (exact-integer? a)
       (raise-argument-error* 'Equatable.hash_code_combine_unordered rhombus-realm "Integer" a))
     (hash-code-combine-unordered a)]
    [(a b)
     (unless (exact-integer? a)
       (raise-argument-error* 'Equatable.hash_code_combine_unordered rhombus-realm "Integer" a))
     (unless (exact-integer? b)
       (raise-argument-error* 'Equatable.hash_code_combine_unordered rhombus-realm "Integer" b))
     (hash-code-combine-unordered a b)]
    [lst
     (for ([e (in-list lst)])
       (unless (exact-integer? e)
         (raise-argument-error* 'Equatable.hash_code_combine_unordered rhombus-realm "Integer" e)))
     (hash-code-combine-unordered* lst)]))

(define-static-info-syntax hash_code_combine_unoredered (#%function-arity -1))
