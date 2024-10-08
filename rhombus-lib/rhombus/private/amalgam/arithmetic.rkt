#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         "provide.rkt"
         "expression.rkt"
         "repetition.rkt"
         "define-operator.rkt"
         "realm.rkt"
         "compare-key.rkt"
         "static-info.rkt")

(provide (for-spaces (#f
                      rhombus/repet)

                     (rename-out [rhombus+ +]
                                 [rhombus- -]
                                 [rhombus* *]
                                 [rhombus/ /]
                                 [rhombus** **])
                     .<
                     .<=
                     .=
                     .!=
                     .>=
                     .>

                     div
                     mod
                     rem

                     !
                     &&
                     \|\|

                     ==
                     !=

                     ===
                     is_now
                     is_same_number_or_object))

(module+ static-infos
  (provide (for-syntax get-number-static-infos
                       get-real-static-infos
                       get-rational-static-infos
                       get-int-static-infos
                       get-flonum-static-infos)))

(module+ precedence
  (provide (for-syntax comparison-precedences)))

(define-static-info-getter get-number-static-infos
  ;; comparison actually requires real numbers, but we want to
  ;; propagate a comparison operation from things like `+`, and
  ;; so it's simplest (and good enough in practice) to overapproximate
  ;; by pointing all numbers to `>`, etc.
  (#%compare ((< <)
              (<= <=)
              (= =)
              (!= number!=?)
              (>= >=)
              (> >))))

(define-for-syntax (get-real-static-infos)
  (get-number-static-infos))
(define-for-syntax (get-rational-static-infos)
  (get-real-static-infos))
(define-for-syntax (get-int-static-infos)
  (get-real-static-infos))
(define-for-syntax (get-flonum-static-infos)
  (get-real-static-infos))

(define-infix rhombus+ +
  #:weaker-than (rhombus** rhombus* rhombus/ div mod rem)
  #:same-as (rhombus-)
  #:static-infos #,(get-number-static-infos))

(define-values-for-syntax (minus-expr-prefix minus-repet-prefix)
  (prefix -
          #:weaker-than (rhombus** rhombus* rhombus/ div mod rem)
          #:static-infos #,(get-number-static-infos)))
(define-values-for-syntax (minus-expr-infix minus-repet-infix)
  (infix -
         #:weaker-than (rhombus** rhombus* rhombus/ div mod rem)
         #:static-infos #,(get-number-static-infos)))

(define-syntax rhombus-
  (expression-prefix+infix-operator
   minus-expr-prefix
   minus-expr-infix))

(define-repetition-syntax rhombus-
  (repetition-prefix+infix-operator
   minus-repet-prefix
   minus-repet-infix))

(define-infix rhombus* *
  #:weaker-than (rhombus**)
  #:same-as (rhombus/)
  #:static-infos #,(get-number-static-infos))

(define-infix rhombus/ /
  #:weaker-than (rhombus**)
  #:static-infos #,(get-number-static-infos))

(define-infix #:who ** rhombus** expt
  #:associate 'right
  #:static-infos #,(get-number-static-infos))

(define-infix #:who div quotient
  #:weaker-than (rhombus**)
  #:static-infos #,(get-real-static-infos))
(define-infix #:who mod modulo
  #:weaker-than (rhombus**)
  #:static-infos #,(get-real-static-infos))
(define-infix #:who rem remainder
  #:weaker-than (rhombus**)
  #:static-infos #,(get-real-static-infos))

(define-prefix ! not
  #:stronger-than (&& \|\|))

(define-infix && and
  #:weaker-than (rhombus+ rhombus- rhombus* rhombus/ mod div rem rhombus**)
  #:stronger-than (\|\|))

(define-infix \|\| or
  #:weaker-than (rhombus+ rhombus- rhombus* rhombus/ mod div rem rhombus**))

(define-for-syntax (comparison-precedences)
  `((,(expr-quote rhombus+) . weaker)
    (,(expr-quote rhombus-) . weaker)
    (,(expr-quote rhombus*) . weaker)
    (,(expr-quote rhombus/) . weaker)
    (,(expr-quote mod) . weaker)
    (,(expr-quote div) . weaker)
    (,(expr-quote rem) . weaker)
    (,(expr-quote rhombus**) . weaker)
    (,(expr-quote .>) . same)
    (,(expr-quote .>=) . same)
    (,(expr-quote .=) . same)
    (,(expr-quote .!=) . same)
    (,(expr-quote .<) . same)
    (,(expr-quote .<=) . same)
    (,(expr-quote \|\|) . stronger)
    (,(expr-quote &&) . stronger)))

(define-syntax (define-comp-infix stx)
  (syntax-parse stx
    [(_ (~optional (~and who #:who)) name racket-name)
     #'(define-infix (~? who) name racket-name
         #:precedences comparison-precedences
         #:associate 'none)]))

(define (number!=? a b)
  (define (check n)
    (unless (number? n)
      (raise-argument-error* '.!= rhombus-realm "Number" n)))
  (check a)
  (check b)
  (not (= a b)))

(define-comp-infix #:who .< <)
(define-comp-infix #:who .<= <=)
(define-comp-infix #:who .= =)
(define-comp-infix .!= number!=?)
(define-comp-infix #:who .>= >=)
(define-comp-infix #:who .> >)

(define-syntax (define-eql-infix stx)
  (syntax-parse stx
    [(_ name racket-name)
     #'(define-infix name racket-name
         #:weaker-than (rhombus+ rhombus- rhombus* rhombus/ mod div rem rhombus**)
         #:stronger-than (\|\| &&)
         #:associate 'none)]))

(define (not-equal-always? a b)
  (not (equal-always? a b)))

(define-eql-infix == equal-always?)
(define-eql-infix != not-equal-always?)
(define-eql-infix === eq?)
(define-eql-infix is_now equal?)
(define-eql-infix is_same_number_or_object eqv?)
