#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         racket/symbol
         syntax/parse/pre
         syntax/stx
         "operator.rkt"
         (submod "operator.rkt" for-parse)
         "private/transform.rkt"
         "syntax-local.rkt"
         "name-parse.rkt"
         "name-root.rkt"
         (submod "name-root.rkt" for-parse)
         "private/name-path-op.rkt"
         "private/check.rkt"
         "implicit.rkt")

(provide define-enforest)

;; The `enforest` function generated below is based on the one
;; described in figure 1 of "Honu: Syntactic Extension for Algebraic
;; Notation through Enforestation". Some key differences:
;;
;; * The stack of pending operators is represented through the
;;   continuation, instead of an explicit stack. The `enforest-step`
;;   function and `:...-op+form+tail` syntax classes provide a way to
;;   reenter enforestation given a preceding operator (for
;;   precedence), which is useful for operator transformers. All
;;   operators could be implemented as transformers, but we provide
;;   support for non-transformer operators as a convenience and as a
;;   way to understand the implementation.
;;
;; * When the inital term is an identifier followed by a name-path
;;   operator and the `lookup` analog produces a name root for the
;;   identifier, the name-root transformer is applied. Its result, a
;;   new term and tail, are used for the new state, without changing
;;   the current operator (if any).
;;
;; * A prefix or infix operator has an associated combiner procedure
;;   to produce a Racket expression form, instead of always making a
;;   `bin` or `un` AST node.
;;
;; * A prefix or infix operator can be bound to a macro transformer,
;;   in which case all parsing for the (second) argument is up to the
;;   transformer. Note that an macro infix transformer that doesn't
;;   consume further input is effectively a postfix operator.
;;
;; * Function calls, array references, and list construction are not
;;   quite built-in. Instead, those positions correspond to the use
;;   of implicit operators, such as `#%call`. The enforestation
;;   function is parameterized over the mapping from head terms to
;;   implicit operators, but there must be at least a `#%juxtapose`
;;   implicit for use when, for example, an identifier follows a
;;   term without an infix operator in between.
;;
;; * The paper's prefix-operator case seems wrong; the old operator
;;   and combiner should be pushed onto the stack, as reflected by a
;;   recursive call here.
;;
;; * Operator precedence is not based on numerical levels or even a
;;   transitive order. Instead, each operator can declare an order
;;   relative to specific other operators, and an error is reported if
;;   two operators must be compared fr precedence and have no declared
;;   order. See "operator.rkt" for more on precedence.
;;
;;  * Already-parsed forms that are encoded with `parsed` (which are
;;   "term"s in the figure's terminology) are immediately converted to
;;   parsed form (i.e., "tree term"s in the figure) by removing the
;;   `parsed` wrapper.
;;
;; Terminology compared to the paper: "form" means "tree term", and
;; "stx" means "term". A "head" or "tail" is a stx/term.

(define-syntax-rule (where expr helper ...) (begin helper ... expr))

(define-syntax (define-enforest stx)
  (syntax-parse stx
    [(_ (~alt (~optional (~seq #:enforest enforest)
                         #:defaults ([enforest #'enforest]))
              (~optional (~seq #:enforest-step enforest-step)
                         #:defaults ([enforest-step #'enforest-step]))
              (~optional (~seq #:relative-precedence relative-precedence))
              (~optional (~seq #:syntax-class form-class)
                         #:defaults ([form-class #':form]))
              (~optional (~seq #:prefix-more-syntax-class prefix-op+form+tail)
                         #:defaults ([prefix-op+form+tail #':prefix-op+form+tail]))
              (~optional (~seq #:infix-more-syntax-class infix-op+form+tail)
                         #:defaults ([infix-op+form+tail #':infix-op+form+tail]))
              (~optional (~seq #:desc form-kind-str)
                         #:defaults ([form-kind-str #'"form"]))
              (~optional (~seq #:operator-desc operator-kind-str)
                         #:defaults ([operator-kind-str #'"operator"]))
              (~optional (~seq #:parsed-tag parsed-tag:keyword)
                         #:defaults ([parsed-tag #'enforested]))
              (~optional (~seq #:in-space in-space)
                         #:defaults ([in-space #'values]))
              (~optional (~seq #:name-path-op name-path-op)
                         #:defaults ([name-path-op #'name-path-op]))
              (~optional (~seq #:name-root-ref name-root-ref)
                         #:defaults ([name-root-ref #'name-root-ref]))
              (~optional (~seq #:in-name-root-space in-name-root-space)
                         #:defaults ([in-name-root-space #'values]))
              (~optional (~seq #:prefix-operator-ref prefix-operator-ref)
                         #:defaults ([prefix-operator-ref #'prefix-operator-ref]))
              (~optional (~seq #:infix-operator-ref infix-operator-ref)
                         #:defaults ([infix-operator-ref #'infix-operator-ref]))
              (~optional (~seq #:check-result check-result)
                         #:defaults ([check-result #'check-is-syntax]))
              (~optional (~seq #:track-origin track-origin)
                         #:defaults ([track-origin #'syntax-track-origin]))
              (~optional (~seq #:make-identifier-form make-identifier-form)
                         #:defaults ([make-identifier-form #'values]))
              (~optional (~seq #:make-operator-form make-operator-form)
                         #:defaults ([make-operator-form #'#f]))
              (~optional (~seq #:select-prefix-implicit -select-prefix-implicit)
                         #:defaults ([-select-prefix-implicit #'select-prefix-implicit]))
              (~optional (~seq #:select-infix-implicit -select-infix-implicit)
                         #:defaults ([-select-infix-implicit #'select-infix-implicit]))
              (~optional (~seq #:juxtapose-implicit-name -juxtapose-implicit-name)
                         #:defaults ([-juxtapose-implicit-name #'juxtapose-implicit-name]))
              (~optional (~seq #:lookup-space-description lookup-space-description)
                         #:defaults ([lookup-space-description #'lookup-space-description])))
        ...)
     #:with (tl-decl ...) (if (eq? (syntax-local-context) 'top-level)
                              #`((define-syntaxes (enforest enforest-step) (values)))
                              #'())
     #'(begin
         tl-decl ...
         (define-syntax-class form-class
           #:attributes (parsed)
           (pattern ((~datum group) . tail)
                    #:cut
                    ;; The calls to `transform-out` and `transform-in` here are in case
                    ;; of an enclosing macro transformer, analogous to the use of
                    ;; `syntax-local-introduce` within `local-expand`
                    #:attr parsed (transform-in (enforest (transform-out #'tail)))))

         ;; For reentering the enforestation loop within a group, stopping when
         ;; the group ends or when an operator with weaker precedence than `op`
         ;; is found
         (define-syntax-class (prefix-op+form+tail op-name)
           #:attributes (parsed tail)
           (pattern ((~datum group) . in-tail)
                    #:with op-name::name/group op-name
                    #:do [(define op (lookup-operator 'prefix-op+form+tail 'prefix (in-space #'op-name.name) prefix-operator-ref))
                          (define-values (form new-tail) (enforest-step (transform-out #'in-tail) op #'op-name.name #t))]
                    #:attr parsed (transform-in form)
                    #:attr tail (transform-in new-tail)))
         (define-syntax-class (infix-op+form+tail op-name)
           #:attributes (parsed tail)
           (pattern ((~datum group) . in-tail)
                    #:with op-name::name/group op-name
                    #:do [(define op (lookup-operator 'infix-op+form+tail 'infix (in-space #'op-name.name) infix-operator-ref))
                          (define-values (form new-tail) (enforest-step (transform-in #'in-tail) op #'op-name.name #t))]
                    #:attr parsed (transform-in form)
                    #:attr tail (transform-in new-tail)))

         (define enforest-step (make-enforest-step form-kind-str operator-kind-str
                                                   in-space prefix-operator-ref infix-operator-ref
                                                   name-path-op in-name-root-space name-root-ref
                                                   check-result track-origin 'parsed-tag
                                                   make-identifier-form
                                                   make-operator-form
                                                   -select-prefix-implicit -select-infix-implicit -juxtapose-implicit-name
                                                   lookup-space-description))
         (define enforest (make-enforest enforest-step))

         (~? (define relative-precedence (make-relative-precedence
                                          'relative-precedence
                                          operator-kind-str
                                          in-space
                                          name-path-op prefix-operator-ref infix-operator-ref))))]))

(define (make-enforest enforest-step)
  (lambda (stxes)
    ;; either `stxes` starts with a prefix operator or this first step
    ;; will dispatch to a suitable implicit prefix operator
    (define-values (form tail) (enforest-step stxes #f #f #f))
    (let loop ([init-form form] [stxes tail])
      (cond
        [(stx-null? stxes) init-form]
        [else
         ;; either `stxes` starts with an infix operator (which was weaker
         ;; precedence than consumed in the previous step), or this step will
         ;; dispatch to a suitable implicit infix operator, like `#%juxtapose`
         (define-values (form tail) (enforest-step init-form stxes #f #f #f))
         (loop form tail)]))))

(define (make-enforest-step form-kind-str operator-kind-str
                            in-space prefix-operator-ref infix-operator-ref
                            name-path-op in-name-root-space name-root-ref
                            check-result track-origin parsed-tag
                            make-identifier-form
                            make-operator-form
                            select-prefix-implicit select-infix-implicit juxtapose-implicit-name
                            lookup-space-description)
  (define (raise-unbound-operator op-stx)
    (raise-syntax-error #f
                        (string-append "unbound " operator-kind-str)
                        op-stx
                        #f
                        null
                        (information-about-bindings op-stx lookup-space-description)))

  ;; Takes 3 or 4 arguments, depending on whether a preceding expression is available
  (define enforest-step
    (case-lambda
      [(stxes current-op current-op-stx stop-on-unbound?)
       ;; No preceding expression, so dispatch to prefix (possibly implicit)
       ((syntax-parse stxes
          [() (raise-syntax-error #f (format "missing ~a" form-kind-str) stxes)]
          [(head::name . tail)
           (define name-path? (starts-like-name-path? #'head #'tail))
           (cond
             [(and name-path?
                   (syntax-local-value* (in-name-root-space #'head.name) name-root-ref))
              => (lambda (v)
                   (define-values (head tail) (apply-name-root #'head.name v in-space stxes))
                   (enforest-step (datum->syntax #f (cons head tail)) current-op current-op-stx stop-on-unbound?))]
             [else
              (define head-id (in-space #'head.name))
              (define v (syntax-local-value* head-id (lambda (v)
                                                       (or (prefix-operator-ref v)
                                                           (infix-operator-ref v)))))
              (cond
                [(prefix-operator? v)
                 (dispatch-prefix-operator v #'tail stxes head-id)]
                [(infix-operator? v)
                 (raise-syntax-error #f "infix operator without preceding argument" #'head.name)]
                [(identifier? #'head)
                 (enforest-step (make-identifier-form #'head) #'tail current-op current-op-stx stop-on-unbound?)]
                [else
                 (if make-operator-form
                     (enforest-step (make-operator-form #'head.name) #'tail current-op current-op-stx stop-on-unbound?)
                     (raise-unbound-operator #'head.name))])])]
          [(((~datum parsed) tag inside) . tail)
           (unless (eq? (syntax-e #'tag) parsed-tag) (parsed-wrong-context-error form-kind-str (car (syntax-e stxes))))
           (enforest-step #'inside #'tail current-op current-op-stx stop-on-unbound?)]
          [(head . _)
           (define-values (implicit-name ctx) (select-prefix-implicit #'head))
           (dispatch-prefix-implicit implicit-name ctx #'head)])

        . where .

        (define (dispatch-prefix-operator op tail stxes op-stx)
          (cond
            [(eq? (operator-protocol op) 'macro)
             ;; it's up to the transformer to consume whatever it wants after the operator
             (define-values (form new-tail) (apply-prefix-transformer-operator op op-stx stxes track-origin check-result))
             (enforest-step form new-tail current-op current-op-stx stop-on-unbound?)]
            [else
             ;; new operator sets precedence, defer application of operator until a suitable
             ;; argument is parsed
             (define-values (form new-tail) (enforest-step (check-empty op-stx tail form-kind-str) op op-stx stop-on-unbound?))
             (enforest-step (apply-prefix-direct-operator op form op-stx track-origin check-result)
                            new-tail
                            current-op
                            current-op-stx
                            stop-on-unbound?)]))

        (define (dispatch-prefix-implicit implicit-name context-stx head-stx)
          (define-values (op op-stx) (lookup-prefix-implicit implicit-name context-stx head-stx in-space
                                                             prefix-operator-ref
                                                             operator-kind-str form-kind-str))
          (define synthetic-stxes (datum->syntax #f (cons op-stx stxes)))
          (dispatch-prefix-operator op stxes synthetic-stxes op-stx)))]

      [(init-form stxes current-op current-op-stx stop-on-unbound?)
       ;; Has a preceding expression, so dispatch to infix (possibly implicit)
       ((syntax-parse stxes
          [() (values init-form stxes)]
          [(head::name . tail)
           (define name-path? (starts-like-name-path? #'head #'tail))
           (cond
             [(and name-path?
                   (syntax-local-value* (in-name-root-space #'head.name) name-root-ref))
              => (lambda (v)
                   (define-values (head tail) (apply-name-root #'head.name v in-space stxes))
                   (enforest-step init-form (datum->syntax #f (cons head tail)) current-op current-op-stx stop-on-unbound?))]
             [else
              (define head-id (in-space #'head.name))
              (define v (syntax-local-value* head-id (lambda (v)
                                                       (or (infix-operator-ref v)
                                                           (prefix-operator-ref v)))))
              (cond
                [(infix-operator? v)
                 (dispatch-infix-operator v #'tail stxes head-id)]
                [(prefix-operator? v)
                 (dispatch-infix-implicit juxtapose-implicit-name #'head #'head)]
                [stop-on-unbound? (values init-form stxes)]
                [(identifier? #'head)
                 (dispatch-infix-implicit juxtapose-implicit-name #'head #'head)]
                [else
                 (if make-operator-form
                     (dispatch-infix-implicit juxtapose-implicit-name #'head #'head)
                     (raise-unbound-operator #'head.name))])])]
          [((~and head ((~datum parsed) . _)) . _)
           (dispatch-infix-implicit juxtapose-implicit-name #'head #'head)]
          [(head . _)
           (define-values (implicit-name ctx) (select-infix-implicit #'head))
           (dispatch-infix-implicit implicit-name ctx #'head)])

        . where .

        (define (dispatch-infix-operator op tail stxes op-stx)
          (define rel-prec (if (not current-op)
                               'weaker
                               (relative-precedence current-op op)))
          (cond
            [(eq? rel-prec 'weaker)
             (cond
               [(eq? (operator-protocol op) 'macro)
                ;; it's up to the transformer to consume whatever it wants after the operator
                (define-values (form new-tail) (apply-infix-transformer-operator op op-stx init-form stxes track-origin check-result))
                (enforest-step form new-tail current-op current-op-stx stop-on-unbound?)]
               [else
                ;; new operator sets precedence, defer application of operator until a suitable
                ;; right-hand argument is parsed
                (define-values (form new-tail) (enforest-step (check-empty op-stx tail form-kind-str) op op-stx stop-on-unbound?))
                (enforest-step (apply-infix-direct-operator op init-form form op-stx track-origin check-result)
                               new-tail
                               current-op
                               current-op-stx
                               stop-on-unbound?)])]
            [(eq? rel-prec 'stronger)
             (values init-form stxes)]
            [else
             (raise-syntax-error
              (syntax-e op-stx)
              (string-append
               "explicit parenthesization needed"
               ";\n found operators "
               (cond
                 [(or (and (eq? rel-prec 'inconsistent-prec) "precedence")
                      (and (eq? rel-prec 'inconsistent-assoc) "associativity"))
                  => (lambda (what)
                       (string-append "with inconsistently declared " what))]
                 [(or (and (eq? rel-prec 'same) "both are non-associative")
                      (and (eq? rel-prec 'same-on-left) "only in the other order"))
                  => (lambda (why)
                       (string-append "at same precedence, but " why))]
                 [else "without declared precedence or associativity"])
               "\n  operator kind: " operator-kind-str
               "\n  earlier operator: " (symbol->immutable-string (syntax-e current-op-stx)))
              stxes
              #f
              (list current-op-stx op-stx))]))

        (define (dispatch-infix-implicit implicit-name context-stx head-stx)
          (define-values (op op-stx) (lookup-infix-implicit implicit-name init-form context-stx head-stx in-space
                                                            infix-operator-ref
                                                            operator-kind-str form-kind-str
                                                            stop-on-unbound?
                                                            lookup-space-description))
          (cond
            [(not op) ; => `stop-on-unbound?`
             (values init-form stxes)]
            [else
             (define synthetic-stxes (datum->syntax #f (cons op-stx stxes)))
             (dispatch-infix-operator op stxes synthetic-stxes op-stx)])))]))

  (define (starts-like-name-path? head tail)
    (and (identifier? head)
         (syntax-parse tail
           [(((~datum op) sep) . _) (eq? (syntax-e #'sep) name-path-op)]
           [_ #f])))

  ;; improves errors when nothing appears after an operator:
  (define (check-empty op-stx tail form-kind-str)
    (cond
      [(or (null? tail)
           (and (syntax? tail)
                (null? (syntax-e tail))))
       (raise-syntax-error #f
                           (format "missing ~a after operator" form-kind-str)
                           op-stx)]
      [else tail]))

  enforest-step)

;; see `relative-precedence` in "operator.rkt" for possible results,
;; but add 'unbound to the set of possibilities
(define (make-relative-precedence who
                                  operator-kind-str
                                  in-space
                                  name-path-op prefix-operator-ref infix-operator-ref)
  (lambda (left-mode left-op-stx right-mode right-op-stx)
    (define (lookup mode op-stx)
      (case mode
        [(prefix)
         (prefix-operator-ref (syntax-local-value* (in-space op-stx)
                                                   prefix-operator-ref))]
        [(infix)
         (infix-operator-ref (syntax-local-value* (in-space op-stx)
                                                  infix-operator-ref))]
        [else
         (raise-argument-error who "(or/c 'prefix 'infix)" mode)]))
    (define left-op (lookup left-mode left-op-stx))
    (define right-op (lookup right-mode right-op-stx))
    (if (and left-op right-op)
        (relative-precedence left-op right-op)
        'unbound)))

(define (lookup-operator who what id ref)
  (define op (syntax-local-value* id ref))
  (unless op
    (raise-syntax-error who
                        (format "not bound as ~a operator" what)
                        id))
  op)
