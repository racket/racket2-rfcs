#lang racket/base
(require (for-syntax racket/base
                     racket/syntax-srcloc
                     syntax/srcloc
                     syntax/parse/pre
                     enforest/name-parse
                     enforest/syntax-local
                     "tag.rkt"
                     "srcloc.rkt"
                     "statically-str.rkt"
                     "with-syntax.rkt")
         "expression.rkt"
         "binding.rkt"
         "parse.rkt"
         "reducer.rkt"
         (submod "reducer.rkt" for-class)
         "for-clause.rkt"
         "static-info.rkt"
         "index-result-key.rkt"
         "sequence-constructor-key.rkt"
         "sequence-element-key.rkt"
         "values-key.rkt"
         "parse.rkt"
         "parens.rkt"
         (rename-in "values.rkt"
                    [values rhombus-values])
         "is-static.rkt")

(provide (rename-out [rhombus-for for])
         (for-space rhombus/for_clause
                    each
                    keep_when
                    skip_when
                    break_when
                    final_when))

(begin-for-syntax
  (define-syntax-class :maybe_ends_each
    #:attributes (red-parsed
                  [each 1])
    #:datum-literals (group)
    (pattern ((_::parens (~and g (group bind ...+ (_::block . _))) ...))
             #:attr [each 1] (list #'(group each (block g ...)))
             #:attr red-parsed #'#f)
    (pattern ()
             #:attr red-parsed #'#f
             #:attr [each 1] '())
    (pattern (red ...)
             #:with (~var redr (:infix-op+reducer+tail #'#%call)) #'(group red ...)
             #:do [(define eaches
                     (syntax-parse #'redr.tail
                       #:datum-literals (group)
                       [((_::parens (~and g (group bind ...+ (_::block . _))) ...))
                        (list #'(group each (block g ...)))]
                       [()
                        null]))]
             #:attr [each 1] eaches
             #:attr red-parsed #'redr.parsed)))

(define-syntax rhombus-for
  (expression-transformer
   (lambda (stx)
     (syntax-parse (respan stx)
       #:datum-literals (group)
       [(form-id pre_t ... (block-tag::block body ...+ (group #:into red ...)))
        #:cut
        #:with pre::maybe_ends_each #'(pre_t ...)
        (unless (not (syntax-e #'pre.red-parsed))
          (raise-syntax-error #f
                              "cannot have both ~into and reducer terms before block"
                              stx))
        (values (relocate+reraw
                 (respan stx)
                 #'(rhombus-expression
                    (group form-id red ... (block-tag pre.each ... body ...))))
                #'())]
       [(form-id pre_t ... (_::block body ...+))
        #:cut
        #:with pre::maybe_ends_each #'(pre_t ...)
        (cond
          [(not (syntax-e #'pre.red-parsed))
           (define static? (is-static-context? #'form-id))
           (values (relocate+reraw
                    (respan stx)
                    #`(for (#:splice (for-clause-step #,stx #,static? [(begin (void))] pre.each ... body ...))
                        (void)))
                   #'())]
          [else
           (with-syntax-parse ([g-tag group-tag]
                               [f::reducer-form #'pre.red-parsed])
             (define static? (is-static-context? #'form-id))
             (values (wrap-static-info*
                      (relocate+reraw
                       (respan stx)
                       #`(f.wrapper
                          f.data
                          (for/fold f.binds (#:splice (for-clause-step #,stx #,static? [(f.body-wrapper f.data)] pre.each ... body ...))
                            #,@(if (syntax-e #'f.break-whener)
                                   #`(#:break (f.break-whener f.data))
                                   null)
                            #,@(if (syntax-e #'f.final-whener)
                                   #`(#:final (f.final-whener f.data))
                                   null)
                            (f.finisher f.data))))
                      #'f.static-infos)
                     #'()))])]))))

(define-splicing-for-clause-syntax for-clause-step
  (lambda (stx)
    (syntax-parse stx
      #:datum-literals (group block parens)
      [(_ orig static? [finish] . bodys)
       ;; initialize state
       #`(#:splice (for-clause-step orig static? [finish () () (void) (void)]
                                    . bodys))]
      [(_ orig static? [(body-wrapper data) rev-clauses rev-bodys matcher binder])
       (when (null? (syntax-e #'rev-bodys))
         (raise-syntax-error #f
                             "empty body (after any clauses such as `each`)"
                             (respan #'orig)))
       #`(#,@(reverse (syntax->list #'rev-clauses))
          #:do [matcher
                binder
                (body-wrapper
                 data
                 (rhombus-body
                  . #,(reverse (syntax->list #'rev-bodys))))])]
      [(_ orig static? (~and state [finish rev-clauses rev-bodys matcher binder])
          body0
          . bodys)
       #:when (for-clause? #'body0)
       (cond
         [(pair? (syntax-e #'rev-bodys))
          ;; emit accumulated body and clauses before starting more clauses
          #`(#,@(reverse (syntax->list #'rev-clauses))
             #:do (matcher
                   binder
                   (rhombus-body-sequence
                    . #,(reverse (syntax->list #'rev-bodys))))
             #:splice (for-clause-step orig static?
                                       [finish () () (void) (void)]
                                       body0 . bodys))]
         [(pair? (syntax-e #'rev-clauses)) ; assert: empty rev-bodys
          ;; emit clauses before starting a new group
          #`(#,@(reverse (syntax->list #'rev-clauses))
             #:do [matcher binder]
             #:splice (for-clause-step orig static?
                                       [finish () () (void) (void)]
                                       body0 . bodys))]
         [else
          (syntax-parse #'body0
            #:datum-literals (group block parens)
            #:literals (prim-for-clause)
            [(group prim-for-clause #:each any ...+ rhs-blk)
             ;; parse binding as binding group
             #`(#:splice (for-clause-step
                          orig static?
                          #,(build-binding-clause/values #'orig
                                                         #'state
                                                         #`((#,group-tag any ...))
                                                         #'rhs-blk
                                                         (syntax-e #'static?))
                          . bodys))]
            [(group prim-for-clause #:each (block (group any ...+ rhs-blk)
                                                  ...))
             ;; parse binding as binding group
             #`(#:splice (for-clause-step
                          orig static?
                          #,(build-binding-clause*/values #'orig
                                                          #'state
                                                          (syntax->list #`(((#,group-tag any ...)) ...))
                                                          (syntax->list #'(rhs-blk ...))
                                                          (syntax-e #'static?))
                          . bodys))]
            [(group prim-for-clause (~and kw (~or #:keep_when #:skip_when #:break_when #:final_when))
                    rhs)
             #:with new-kw (case (syntax-e #'kw)
                             [(#:keep_when) (datum->syntax #'kw '#:when #'kw #'kw)]
                             [(#:skip_when) (datum->syntax #'kw '#:unless #'kw #'kw)]
                             [(#:break_when) (datum->syntax #'kw '#:break #'kw #'kw)]
                             [(#:final_when) (datum->syntax #'kw '#:final #'kw #'kw)]
                             [else #'kw])
             #`(new-kw rhs
                       #:splice (for-clause-step orig static? state . bodys))]
            [body0::for-clause
             #:with f::for-clause-form #'body0.parsed
             #`(#:splice (for-clause-step orig static? state f.parsed ... . bodys))])])]
      [(_ orig static? [finish rev-clauses rev-bodys matcher binder]
          body0
          . bodys)
       #`(#:splice (for-clause-step
                    orig static?
                    [finish
                     rev-clauses
                     (body0 . rev-bodys)
                     matcher
                     binder]
                    . bodys))])))

(define-for-syntax (build-binding-clause/values orig-stx
                                                state-stx
                                                bindings-stx
                                                rhs-block-stx
                                                static?)
  (build-binding-clause orig-stx
                        state-stx
                        (syntax-parse bindings-stx
                          #:datum-literals (group parens block)
                          [((group (~optional values-id::name) (parens g ...)))
                           #:when (or (not (attribute values-id))
                                      (free-identifier=? (in-binding-space #'values-id.name)
                                                         (bind-quote rhombus-values)))
                           #'(g ...)]
                          [else bindings-stx])
                        rhs-block-stx
                        static?))

(define-for-syntax (build-binding-clause orig-stx
                                         state-stx
                                         bindings-stx
                                         rhs-blk-stx
                                         static?)
  (define lhs-parsed-stxes (for/list ([binding-stx (in-list (syntax->list bindings-stx))])
                             (syntax-parse binding-stx
                               [lhs::binding #'lhs.parsed]
                               [_ (raise-syntax-error #f
                                                      "expected a binding"
                                                      (respan orig-stx)
                                                      (respan binding-stx))])))
  (syntax-parse lhs-parsed-stxes
    [(lhs-e::binding-form ...)
     #:with rhs (rhombus-local-expand (enforest-expression-block rhs-blk-stx))
     #:with all-static-infos (or (syntax-local-static-info #'rhs #'#%sequence-element)
                                 (syntax-local-static-info #'rhs #'#%index-result)
                                 #'())
     #:with (static-infos ...) (syntax-parse #'all-static-infos
                                 #:literals (#%values)
                                 [((#%values (si ...)))
                                  #:when (= (length (syntax->list #'(si ...)))
                                            (length (syntax->list #'(lhs-e ...))))
                                  #'(si ...)]
                                 [_ (for/list ([lhs-e (syntax->list #'(lhs-e ...))])
                                      #'all-static-infos)])
     #:with (lhs-impl::binding-impl ...) #'((lhs-e.infoer-id static-infos lhs-e.data)...)
     #:with (lhs-i::binding-info ...) #'(lhs-impl.info ...)
     #:with (form-id . _) orig-stx
     #:with (tmp-id ...) (for/list ([name-id (syntax->list #'(lhs-i.name-id ...))])
                           ((make-syntax-introducer) (datum->syntax #f (syntax-e name-id) name-id)))
     (define seq-ctr (syntax-local-static-info #'rhs #'#%sequence-constructor))
     (when (and static? (not seq-ctr))
       (raise-syntax-error #f
                           (string-append "no specific iteration implementation available" statically-str)
                           (respan orig-stx)
                           (respan rhs-blk-stx)))
     (syntax-parse state-stx
       [[finish rev-clauses rev-bodys matcher binder]
        #`[finish
           ([(tmp-id ...) #,(cond
                              [(identifier? seq-ctr)
                               (if (syntax-local-value* seq-ctr expression-prefix-operator-ref)
                                   (unwrap-static-infos
                                    (rhombus-local-expand
                                     #`(rhombus-expression (group #,seq-ctr (parens (group (parsed #:rhombus/expr rhs)))))))
                                   #`(#,seq-ctr rhs))]
                              [else (unwrap-static-infos #'rhs)])]
            . rev-clauses)
           ()
           (begin
             matcher
             (lhs-i.matcher-id tmp-id
                               lhs-i.data
                               flattened-if
                               (void)
                               (rhs-binding-failure 'form-id tmp-id 'lhs-i.annotation-str))
             ...)
           (begin
             binder
             (begin
               (lhs-i.committer-id tmp-id lhs-i.data)
               (lhs-i.binder-id tmp-id lhs-i.data)
               (define-static-info-syntax/maybe lhs-i.bind-id lhs-i.bind-static-info ...)
               ...)
             ...)]])]))

(define-for-syntax (build-binding-clause*/values orig-stx
                                                 state-stx
                                                 bindings-stxs
                                                 rhs-blk-stxs
                                                 static?)
    (cond
      [(null? bindings-stxs) state-stx]
      [else
       (define new-state-stx (build-binding-clause/values orig-stx
                                                          state-stx
                                                          (car bindings-stxs)
                                                          (car rhs-blk-stxs)
                                                          static?))
       (build-binding-clause*/values orig-stx
                                     new-state-stx
                                     (cdr bindings-stxs)
                                     (cdr rhs-blk-stxs)
                                     static?)]))

(define-syntax (flattened-if stx)
  (syntax-parse stx
    [(_ check-expr success-expr fail-expr)
     #'(begin
         (unless check-expr fail-expr)
         success-expr)]))

(define (rhs-binding-failure who val binding-str)
  (raise-binding-failure who "element" val binding-str))

;; ----------------------------------------

;; To recognize all primitive forms:
(define-syntax prim-for-clause
  (for-clause-transformer
   (lambda (stx)
     (raise-syntax-error #f "should not try to expand" (respan stx)))))

(begin-for-syntax
  ;; Like `:var-decl`, but we don't allow `=` here
  (define-splicing-syntax-class :each-decl
    #:datum-literals (group block)
    #:attributes ([bind 1] blk)
    (pattern (~seq bind ...+ (~and rhs (_::block . _)))
             #:attr blk #'rhs)))

(define-for-clause-syntax each
  (for-clause-transformer
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (group block)
       [(form-id d::each-decl)
        #`[(#,group-tag prim-for-clause #:each d.bind ... d.blk)]]
       [(form-id (tag::block (group d::each-decl) ...))
        #`[(#,group-tag prim-for-clause #:each (tag
                                                (group d.bind ... d.blk)
                                                ...))]]
       [_
        (raise-syntax-error #f
                            "needs a binding followed by a block, or it needs a block of bindings (each with a block)"
                            (respan stx))]))))

(define-for-syntax (parse-when stx kw)
  (syntax-parse stx
    #:datum-literals ()
    [(form-id (tag::block g ...))
     #`[(#,group-tag prim-for-clause #,kw (rhombus-body-at tag g ...))]]
    [(form-id expr ...+)
     #`[(#,group-tag prim-for-clause #,kw (rhombus-expression (#,group-tag expr ...)))]]
    [(form-id)
     (raise-syntax-error #f
                         "missing expression"
                         (respan #'stx))]))

(define-for-clause-syntax keep_when
  (for-clause-transformer
   (lambda (stx)
     (parse-when stx '#:keep_when))))

(define-for-clause-syntax skip_when
  (for-clause-transformer
   (lambda (stx)
     (parse-when stx '#:skip_when))))

(define-for-clause-syntax break_when
  (for-clause-transformer
   (lambda (stx)
     (parse-when stx '#:break_when))))

(define-for-clause-syntax final_when
  (for-clause-transformer
   (lambda (stx)
     (parse-when stx '#:final_when))))

;; not exported, but referenced by `:maybe_ends_each` so that
;; reducer parsing terminates appropriately
(define-reducer-syntax #%call
  (reducer-infix-operator
   (reducer-quote #%call)
   `((default . stronger))
   'macro
   (lambda (stx) (error "should not get here"))
   'none))
