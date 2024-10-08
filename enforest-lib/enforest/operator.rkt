#lang racket/base
(require racket/base
         syntax/stx
         "private/transform.rkt"
         "syntax-local.rkt")

;; See "main.rkt" for general information about operators and parsing.
;;
;; An operator's predence is represented as a list of
;;
;;   (cons/c (or/c identifier? 'default)
;;           (or/c 'stronger 'same 'weaker))
;;
;; where the `car`s of the pairs should be distinct, and 'default
;; stands for every identifier not mentioned. The value 'stronger
;; means that the operator that has this list has a stronger
;; precedence than the one referenced by the identifier. An operator
;; is implicitly the 'same as itself (i.e., not covered by 'default).

(provide operator
         operator?
         operator-precedences
         operator-protocol
         operator-proc ; convention depends on category

         prefix-operator
         prefix-operator?
         prefix-operator-ref

         infix-operator
         infix-operator?
         infix-operator-assoc
         infix-operator-ref)

(module+ for-parse
  (provide relative-precedence

           lookup-infix-implicit
           lookup-prefix-implicit

           information-about-bindings
           lookup-space-description

           apply-prefix-direct-operator
           apply-infix-direct-operator
           apply-prefix-transformer-operator
           apply-infix-transformer-operator))

(struct operator (precedences protocol proc)
  #:guard (lambda (precedences protocol proc who)
            (when #f ;; change to #t for a debugging check
              (let ([precedences (cond
                                   [(and (procedure? precedences)
                                         (procedure-arity-includes? precedences 0))
                                    (precedences)]
                                   [else precedences])])
                (unless (and (list? precedences)
                             (for/and ([p (in-list precedences)])
                               (and (pair? p)
                                    (or (eq? (car p) 'default)
                                        (identifier? (car p)))
                                    (memq (cdr p) '(weaker stronger same same-on-left same-on-right)))))
                  (raise-argument-error who
                                        (let ([s (string-append "(listof (cons/c (or/c identifier? 'default)"
                                                                " (or/c 'stronger 'weaker 'same 'same-on-left 'same-on-right))))")])
                                          (string-append "(or/c " s "(-> " s "))"))
                                        precedences))))
            (unless (memq protocol '(automatic macro))
              (raise-argument-error who "(or/c 'automatic 'macro)" protocol))
            (unless (procedure? proc)
              (raise-argument-error who "procedure?" proc))
            (values precedences protocol proc)))
            
(struct prefix-operator operator ())
(struct infix-operator operator (assoc)
  #:guard (lambda (precedences protocol proc assoc who)
            (unless (memq assoc '(left right none))
              (raise-argument-error who "(or/c 'left 'right 'none)" assoc))
            (values precedences protocol proc assoc)))

(define (prefix-operator-ref v) (and (prefix-operator? v) v))
(define (infix-operator-ref v) (and (infix-operator? v) v))

;; `op` is the operator just found, and `left-op` is the
;; "current" operator previously found on the left;
;; returns either
;;   * a successful comparison:
;;       - 'stronger (left takes precedence)
;;       - 'weaker (right takes precedence)
;;   * an error comparison, where the result describes why:
;;       - 'inconsistent-prec
;;       - 'inconsistent-assoc
;;       - 'same (error because no associativity)
;;       - 'same-on-left (error because on right)
;;       - #f (no precedence relation)
(define (relative-precedence left-op-name left-op op-name op)
  (define (find op-name this-op-name precs)
    (let loop ([precs precs] [default #f])
      (cond
        [(null? precs) (if (free-identifier=? op-name this-op-name)
                           'same
                           default)]
        [(eq? (caar precs) 'default) (loop (cdr precs) (cdar precs))]
        [(free-identifier=? op-name (caar precs)) (cdar precs)]
        [else (loop (cdr precs) default)])))
  (define (invert dir)
    (case dir
      [(stronger) 'weaker]
      [(weaker) 'stronger]
      [(same-on-right) 'same-on-left]
      [(same-on-left) 'same-on-right]
      [else dir]))
  (define (extract precs) (if (procedure? precs) (precs) precs))
  (define dir1 (find left-op-name op-name (extract (operator-precedences op))))
  (define dir2 (invert (find op-name left-op-name (extract (operator-precedences left-op)))))
  (cond
    [(and dir1 dir2 (not (eq? dir1 dir2)))
     'inconsistent-prec]
    [else
     (define dir (or dir1 dir2
                     (and (free-identifier=? op-name left-op-name)
                          'same)))
     (cond
       [(or (eq? 'same dir)
            (eq? 'same-on-right dir))
        (define op-a (infix-operator-assoc op))
        (cond
          [(and (infix-operator? left-op)
                (not (eq? op-a (infix-operator-assoc left-op))))
           'inconsistent-assoc]
          [else
           (case op-a
             [(left) 'stronger]
             [(right) 'weaker]
             [else 'same])])]
       [(eq? 'stronger dir) 'weaker]
       [(eq? 'weaker dir) 'stronger]
       [else dir])]))

(define (extract-context adj-context)
  (define e (syntax-e adj-context))
  (if (and (pair? e)
           (eq? 'op (syntax-e (car e))))
      (let ([e (cdr e)])
        (car (if (syntax? e) (syntax-e e) e)))
      adj-context))

(define (lookup-prefix-implicit alone-name adj-context adj-form in-space operator-ref operator-kind form-kind)
  (define op-stx (in-space (datum->syntax (extract-context adj-context) alone-name)))
  (define op (syntax-local-value* op-stx operator-ref))
  (unless op
    (raise-syntax-error #f
                        (format (string-append
                                 "misplaced term;\n"
                                 " no infix operator is between this term and the preceding ~a"
                                 #;
                                 ",\n and `~a` is not bound as an implicit prefix ~a")
                                form-kind
                                #;
                                alone-name
                                #;
                                operator-kind)
                        adj-form))
  (values op op-stx))

(define (lookup-infix-implicit adjacent-name prev-form adj-context adj-form in-space operator-ref operator-kind form-kind
                               stop-on-unbound? lookup-space-description)
  (define op-stx (in-space (datum->syntax (extract-context adj-context) adjacent-name)))
  (define op (syntax-local-value* op-stx operator-ref))
  (unless op
    (cond
      [(identifier? prev-form)
       (raise-syntax-error #f
                           (format
                            (string-append
                             "unbound or misplaced ~a;\n"
                             " the identifier is not bound as a macro,"
                             " and no infix operator appears afterward"
                             #;
                             ",\n and `~a` is not bound as an implicit infix ~a")
                            form-kind
                            #;
                            adjacent-name
                            #;
                            operator-kind)
                           prev-form
                           #f
                           null
                           (information-about-bindings prev-form lookup-space-description))]
      [(not stop-on-unbound?)
       (raise-syntax-error #f
                           (format
                            (string-append
                             "misplaced term;\n"
                             " no infix operator is between this term and the preceding ~a"
                             #;
                             ",\n and `~a` is not bound as an implicit infix ~a")
                            form-kind
                            #;
                            adjacent-name
                            #;
                            operator-kind)
                           adj-form)]))
  (values op op-stx))


(define (information-about-bindings id lookup-space-description)
  (let ([syms (append
               (if (identifier-binding id)
                   (list #f)
                   null)
               (for/list ([sym (in-list (syntax-local-module-interned-scope-symbols))]
                          #:when (identifier-distinct-binding ((make-interned-syntax-introducer sym) id 'add)
                                                              id))
                 sym))])
    (if (null? syms)
        ""
        (apply string-append
               "\n  bound in spaces:"
               (for/list ([sym (in-list syms)])
                 (format "\n   ~a" (or (lookup-space-description sym)
                                       (format "space with path ~s" sym))))))))

(define (lookup-space-description space-sym)
  #f)

(define (apply-prefix-direct-operator env op form stx track-origin use-site-scopes? checker)
  (define proc (operator-proc op))
  (checker (call-as-transformer
            stx
            (list form)
            track-origin use-site-scopes?
            (lambda (form)
              (apply proc form stx env)))
           proc))

(define (apply-infix-direct-operator env op form1 form2 stx track-origin use-site-scopes? checker)
  (define proc (operator-proc op))
  (checker (call-as-transformer
            stx
            (list form1 form2)
            track-origin use-site-scopes?
            (lambda (form1 form2)
              (apply proc form1 form2 stx env)))
           proc))

(define (apply-prefix-transformer-operator env op op-stx tail track-origin use-site-scopes? checker)
  (define proc (operator-proc op))
  (define-values (form new-tail)
    (call-as-transformer
     op-stx
     (list tail)
     track-origin use-site-scopes?
     (lambda (tail)
       (define-values (form new-tail) (apply proc tail env))
       (values (apply checker form proc env)
               new-tail))))
  (check-transformer-result form new-tail proc))

(define (apply-infix-transformer-operator env op op-stx form1 tail track-origin use-site-scopes? checker)
  (define proc (operator-proc op))
  (define-values (form new-tail)
    (call-as-transformer
     op-stx
     (list form1 tail)
     track-origin use-site-scopes?
     (lambda (form1 tail)
       (define-values (form new-tail) (apply proc form1 tail env))
       (values (apply checker form proc env)
               new-tail))))
  (check-transformer-result form new-tail proc))
