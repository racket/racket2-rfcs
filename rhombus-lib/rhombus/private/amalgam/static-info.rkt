#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest/property
                     enforest/syntax-local
                     "introducer.rkt"
                     "srcloc.rkt"
                     (for-syntax racket/base))
         "dotted-sequence-parse.rkt")

;; Represent static information in either of two ways:
;;
;;   - bind an identifier (in some space) to a `static-info` record,
;;     which maps keys to values; the static info applies to a use of
;;     the identifier
;;
;;   - wrap a form with `(begin (quote-syntax (key val)) form)`, where
;;     the pattern can be nested in `form`, and the static info
;;     applies to the form

(begin-for-syntax
  (provide (property-out static-info)
           (property-out static-info-key)
           static-info-get-stxs
           in-static-info-space
           wrap-static-info
           wrap-static-info*
           :static-info
           syntax-local-static-info
           extract-static-infos
           normalize-static-infos
           normalize-static-infos/values
           unwrap-static-infos
           discard-static-infos
           relocate-wrapped
           static-info-lookup
           static-infos-or
           static-infos-and
           static-info-identifier-or
           static-info-identifier-and
           static-infos-result-or
           static-infos-result-and
           static-infos-remove
           get-empty-static-infos))

(provide define-static-info-getter
         define-static-info-syntax
         define-static-info-syntaxes
         define-static-info-syntax/maybe
         define-static-info-syntax/maybe/maybe-extension

         define-static-info-key-syntax/provide

         #%indirect-static-info
         #%values)

(begin-for-syntax
  (property static-info (get-stxs))
  (property static-info-key (or and))

  (define in-static-info-space (make-interned-syntax-introducer/add 'rhombus/statinfo))

  (define (wrap-static-info expr key-id val-stx)
    (relocate+reraw
     expr
     #`(begin (quote-syntax (#,key-id #,val-stx))
              #,expr)))

  (define (wrap-static-info* expr stxes)
    (for/foldr ([expr expr]) ([stx (in-list (if (syntax? stxes)
                                                (syntax->list stxes)
                                                stxes))])
      (syntax-parse stx
        [(key:identifier val) (wrap-static-info expr #'key #'val)])))

  (define-syntax-class (:static-info key-id)
    #:attributes (val)
    #:literals (begin quote-syntax)
    (pattern id:identifier
             #:do [(define v (syntax-local-value* (in-static-info-space #'id)
                                                  static-info-ref))
                   (define val (and v
                                    (static-info-lookup ((static-info-get-stxs v)) key-id)))]
             #:when val
             #:with val val)
    (pattern (begin (quote-syntax (key:identifier val)) _)
             #:when (free-identifier=? #'key key-id))
    (pattern (begin (quote-syntax (key:identifier indirect-id)) _)
             #:when (free-identifier=? #'key #'#%indirect-static-info)
             #:do [(define val (indirect-static-info-ref #'indirect-id key-id))]
             #:when val
             #:with val val)
    (pattern (begin (quote-syntax (_:identifier _)) (~var || (:static-info key-id)))))

  (define (syntax-local-static-info expr key-id)
    (syntax-parse expr
      [(~var dp (:static-info key-id))
       #'dp.val]
      [_ #f]))

  (define (indirect-static-info-ref id key-id)
    (syntax-local-static-info id key-id))

  (define (extract-static-infos e)
    (let loop ([e e])
      (syntax-parse e
        #:literals (begin quote-syntax)
        [id:identifier
         (cond
           [(syntax-local-value* (in-static-info-space #'id)
                                 static-info-ref)
            => (lambda (v)
                 ((static-info-get-stxs v)))]
           [else null])]
        [(begin (quote-syntax (~and form (_:identifier _))) e)
         (cons #'form (loop #'e))]
        [_ null])))

  (define (normalize-static-infos infos)
    (car (normalize-static-infos/values 1 infos)))

  (define (normalize-static-infos/values num infos)
    (define infoss
      (syntax-parse infos
        #:literals (#%values)
        [((#%values (si ...))) (syntax->list #'(si ...))]
        [_ (list infos)]))
    (if (eqv? (length infoss) num)
        (for/list ([infos (in-list infoss)])
          (let loop ([infos infos])
            (syntax-parse infos
              #:literals (#%values)
              [((#%values (only-infos))) (loop #'only-infos)]
              [((#%values _)) #'()]
              [_ infos])))
        (for/list ([_ (in-range num)])
          #'())))

  ;; use on sub-expressions to discover otherwise immediate forms that
  ;; are hidden
  (define (unwrap-static-infos e)
    (define unwrapped-e
      (let loop ([e e] [unwrapped? #f])
        (syntax-parse e
          #:literals (begin quote-syntax)
          [(begin (quote-syntax (_:identifier _)) e) (loop #'e #t)]
          [_ (and unwrapped? e)])))
    (if unwrapped-e
        ;; we need to track origin here to transfer any potential
        ;; information added by enforestation, but don't merge raw
        (reraw e (syntax-track-origin unwrapped-e e #'begin))
        e))

  ;; use on sub-expressions when constructing a parsed primitive form
  ;; with the goal of simplifying the result expansion
  (define (discard-static-infos e)
    (unwrap-static-infos e))

  (define (static-info-lookup static-infos find-key)
    (for/or ([static-info (in-list (if (syntax? static-infos)
                                       (syntax->list static-infos)
                                       static-infos))])
      (syntax-parse static-info
        [(key val) (or (and (free-identifier=? #'key find-key)
                            #'val)
                       (and (free-identifier=? #'key #'#%indirect-static-info)
                            (indirect-static-info-ref #'val find-key)))]
        [_ #f])))

  ;; it's better to relocate and then wrap, since wrapping propagates
  ;; the location, but sometimes it's so much easier to relocate
  ;; afterward that it's worth the extra cost
  (define (relocate-wrapped srcloc e)
    (syntax-parse e
      #:literals (begin quote-syntax)
      [((~and tag begin) (~and qs (quote-syntax (_:identifier _))) e)
       (define e2 (relocate-wrapped srcloc #'e))
       (relocate+reraw e2 #`(tag qs #,e2))]
      [_ (relocate+reraw srcloc e)])))

(define-syntax (define-static-info-key-syntax/provide stx)
  (syntax-parse stx
    [(_ id:identifier rhs)
     #`(begin
         (define-syntax id rhs)
         (provide id))]))

(define-syntax #%indirect-static-info
  (static-info-key (lambda (a b) (error "should not ``or'' indirect statinfos"))
                   (lambda (a b) (error "should not ``and'' indirect statinfos"))))

(define-syntax #%values
  (let ([merge (lambda (a b combine)
                 (define as (syntax->list a))
                 (define bs (syntax->list b))
                 (and as bs (equal? (length as) (length bs))
                      (datum->syntax
                       #f
                       (map combine as bs))))])
    (static-info-key (lambda (a b)
                       (merge a b static-infos-or))
                     (lambda (a b)
                       (merge a b static-infos-and)))))

(define-for-syntax (make-static-info-getter stx)
  (define (->compact rhss)
    (for/list ([rhs (in-list rhss)])
      ;; recognizes some common patterns to generate
      ;; code that's slightly more compact
      (syntax-parse rhs
        [(us:identifier e)
         #:when (free-transformer-identifier=? #'us #'unsyntax)
         #'e]
        [(key (us:identifier val))
         #:when (free-transformer-identifier=? #'us #'unsyntax)
         #'(datum->syntax #f (list (quote-syntax key) val))]
        [rhs #'(quasisyntax rhs)])))
  (syntax-parse stx
    [(rhs ... us:identifier rhs*)
     #:when (free-transformer-identifier=? #'us #'unsyntax)
     #`(lambda () (list* #,@(->compact (syntax->list #'(rhs ...))) rhs*))]
    [(rhs ... (us*:identifier rhs*))
     #:when (free-transformer-identifier=? #'us* #'unsyntax-splicing)
     #`(lambda () (list* #,@(->compact (syntax->list #'(rhs ...))) rhs*))]
    [(rhs ...)
     #`(lambda () (list #,@(->compact (syntax->list #'(rhs ...)))))]))

(define-syntax (define-static-info-getter stx)
  (syntax-parse stx
    [(_ id:identifier . tail)
     #`(define-for-syntax id
         #,(make-static-info-getter #'tail))]))

(define-syntax (define-static-info-syntax stx)
  (syntax-parse stx
    [(_ id:identifier #:getter getter:id)
     #`(define-syntax #,(in-static-info-space #'id)
         (static-info getter))]
    [(_ id:identifier . tail)
     #`(define-syntax #,(in-static-info-space #'id)
         (static-info #,(make-static-info-getter #'tail)))]))

(define-syntax (define-static-info-syntaxes stx)
  (syntax-parse stx
    [(_ (id:identifier ...) . tail)
     #'(begin
         (define-static-info-getter getter . tail)
         (define-static-info-syntax id #:getter getter)
         ...)]))

(define-syntax (define-static-info-syntax/maybe stx)
  (syntax-parse stx
    [(_ id) #'(begin)]
    [(_ id rhs ...) #'(define-static-info-syntax id rhs ...)]))

(define-syntax (define-static-info-syntax/maybe/maybe-extension stx)
  (syntax-parse stx
    [(_ id prefix) #'(begin)]
    [(_ id prefix rhs ...)
     (if (syntax-e #'prefix)
         (build-syntax-definition/maybe-extension
          'rhombus/statinfo #'id #'prefix
          #`(static-info #,(make-static-info-getter #'(rhs ...))))
         #'(define-static-info-syntax id rhs ...))]))

(define-static-info-getter get-empty-static-infos)

(define-for-syntax (flatten-indirects as)
  (and as
       (for*/list ([a (in-list as)]
                   [e (in-list
                       (syntax-parse a
                         [(a-key a-val)
                          #:when (free-identifier=? #'a-key #'#%indirect-static-info)
                          (define si (and (identifier? #'a-val)
                                          (syntax-local-value* (in-static-info-space #'a-val)
                                                               static-info-ref)))
                          (if si
                              (flatten-indirects ((static-info-get-stxs si)))
                              null)]
                         [_ (list a)]))])
         e)))

;; note that `||` at the annotation level feels like "intersection" on statinfo tables
(define-for-syntax (static-infos-or as bs)
  (cond
    [(or (null? as) (and (syntax? as) (null? (syntax-e as)))) as]
    [(or (null? bs) (and (syntax? bs) (null? (syntax-e bs)))) bs]
    [else
     (let ([as (flatten-indirects (if (syntax? as) (syntax->list as) as))]
           [bs (flatten-indirects (if (syntax? bs) (syntax->list bs) bs))])
       (or
        (and as
             bs
             (for/list ([a (in-list as)]
                        #:do [(define new-val
                                (syntax-parse a
                                  [(a-key a-val)
                                   (for/or ([b (in-list bs)])
                                     (syntax-parse b
                                       [(b-key b-val)
                                        #:when (free-identifier=? #'a-key #'b-key)
                                        (let ([key (syntax-local-value* #'a-key static-info-key-ref)])
                                          (cond
                                            [key
                                             ((static-info-key-or key) #'a-val #'b-val)]
                                            [else
                                             (static-infos-result-or #'a-val #'b-val)]))]
                                       [_ #f]))]
                                  [_ #f]))]
                        #:when new-val)
               (syntax-parse a
                 [(a-key . _) (datum->syntax #f (list #'a-key new-val))])))
        #'()))]))

;; note that `&&` at the annotation level feels like "union" on statinfo tables
(define-for-syntax (static-infos-and as bs)
  (cond
    [(or (null? as) (and (syntax? as) (null? (syntax-e as)))) bs]
    [(or (null? bs) (and (syntax? bs) (null? (syntax-e bs)))) as]
    [else
     (let ([as (flatten-indirects (if (syntax? as) (syntax->list as) as))]
           [bs (flatten-indirects (if (syntax? bs) (syntax->list bs) bs))])
       (cond
         [(not as) (or bs #'())]
         [(not bs) as]
         [else
          (append
           (for/list ([a (in-list as)]
                      #:do [(define new-val
                              (syntax-parse a
                                [(a-key a-val)
                                 (define v
                                   (for/or ([b (in-list bs)])
                                     (syntax-parse b
                                       [(b-key b-val)
                                        #:when (free-identifier=? #'a-key #'b-key)
                                        (let ([key (syntax-local-value* #'a-key static-info-key-ref)])
                                          (list
                                           (cond
                                             [key
                                              ((static-info-key-and key) #'a-val #'b-val)]
                                             [else
                                              (static-infos-result-and #'a-val #'b-val)])))]
                                       [_ #f])))
                                 (if v
                                     (car v)
                                     #'a-val)]
                                [_ #f]))]
                      #:when new-val)
             (syntax-parse a
               [(a-key . _) (datum->syntax #f (list #'a-key new-val))]))
           (for/list ([b (in-list bs)]
                      #:unless (syntax-parse b
                                 [(b-key . _)
                                  (for/or ([a (in-list as)])
                                    (syntax-parse a
                                      [(a-key b-val)
                                       (free-identifier=? #'a-key #'b-key)]
                                      [_ #f]))]
                                 [_ #f]))
             b))]))]))

(define-for-syntax static-info-identifier-and
  (lambda (a b)
    ;; biased toward `a`
    a))

(define-for-syntax static-info-identifier-or
  (lambda (a b)
    (and (identifier? a)
         (identifier? b)
         (free-identifier=? a b)
         a)))

(define-for-syntax (static-infos-result-and as bs)
  ;; With `#:at_arities`, for now, we handle only the simple case that the masks coincide
  (syntax-parse as
    [(#:at_arities (a-mask a-results) ...)
     (syntax-parse bs
       [(#:at_arities (b-mask b-results) ...)
        (if (equal? (syntax->datum #'(a-mask ...)) (syntax->datum #'(b-mask ...)))
            #`(#:at_arities #,(for/list ([a-results (in-list (syntax->list #'(a-results ...)))]
                                         [b-results (in-list (syntax->list #'(b-results ...)))])
                                (static-infos-and a-results b-results)))
            as)]
       [_
        as])]
    [_
     (syntax-parse bs
       [(#:at_arities (b-mask b-results) ...)
        as]
       [_ (static-infos-and as bs)])]))

(define-for-syntax (static-infos-result-or as bs)
  ;; With `#:at_arities`, for now, we handle only the simple case that the masks coincide
  (syntax-parse as
    [(#:at_arities (a-mask a-results) ...)
     (syntax-parse bs
       [(#:at_arities (b-mask b-results) ...)
        (if (equal? (syntax->datum #'(a-mask ...)) (syntax->datum #'(b-mask ...)))
            #`(#:at_arities #,(for/list ([a-results (in-list (syntax->list #'(a-results ...)))]
                                         [b-results (in-list (syntax->list #'(b-results ...)))])
                                (static-infos-or a-results b-results)))
            #f)]
       [_
        #f])]
    [_
     (syntax-parse bs
       [(#:at_arities (b-mask b-results) ...)
        #f]
       [_ (static-infos-or as bs)])]))

(define-for-syntax (static-infos-remove as key)
  (for/list ([a (in-list (if (syntax? as) (syntax->list as) as))]
             #:when (syntax-parse a
                      [(a-key a-val) (not (free-identifier=? #'a-key key))]))
    a))

(define-for-syntax (equal-static-info-value? a b)
  (cond
    [(identifier? a)
     (and (identifier? b)
          (free-identifier=? a b))]
    [(identifier? b) #f]
    [(syntax? a)
     (equal-static-info-value? (syntax-e a) b)]
    [(syntax? b)
     (equal-static-info-value? a (syntax-e b))]
    [(null? a) (null? b)]
    [(pair? a)
     (and (pair? b)
          (and (equal-static-info-value? (car a) (car b))
               (equal-static-info-value? (cdr a) (cdr b))))]
    [(vector? a)
     (and (vector? b)
          (= (vector-length a) (vector-length b))
          (for/and ([ae (in-vector a)]
                    [be (in-vector b)])
            (equal-static-info-value? (car ae) (car be))))]
    [(box? a)
     (and (box? b)
          (equal-static-info-value? (unbox a) (unbox b)))]
    [else (equal? a b)]))
