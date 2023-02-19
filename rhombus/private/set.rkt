#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     racket/syntax
                     "srcloc.rkt"
                     "tag.rkt"
                     "with-syntax.rkt"
                     shrubbery/print)
         "provide.rkt"
         "expression.rkt"
         "binding.rkt"
         "repetition.rkt"
         "compound-repetition.rkt"
         (submod "annotation.rkt" for-class)
         (submod "dot.rkt" for-dot-provider)
         "name-root.rkt"
         "static-info.rkt"
         "reducer.rkt"
         "map-ref-set-key.rkt"
         "call-result-key.rkt"
         "function-arity-key.rkt"
         "parse.rkt"
         "literal.rkt"
         "realm.rkt"
         "setmap-parse.rkt"
         "dot-parse.rkt"
         "parens.rkt"
         "composite.rkt"
         "define-arity.rkt"
         (only-in "lambda-kwrest.rkt" hash-remove*)
         "op-literal.rkt")

(provide (for-spaces (rhombus/namespace
                      #f
                      rhombus/bind
                      rhombus/repet
                      rhombus/reducer
                      rhombus/annot)
                     Set)
         (for-spaces (#f
                      rhombus/repet)
                     MutableSet))

(module+ for-binding
  (provide (for-syntax parse-set-binding)))

(module+ for-ref
  (provide set?
           set-ht
           set))

(module+ for-builtin
  (provide set?
           set-method-table))

(module+ for-info
  (provide (for-syntax set-static-info)
           Set-build))

(module+ for-build
  (provide set-append
           set-append/proc
           set-extend*
           set-assert
           list->set))

(struct set (ht)
  #:property prop:equal+hash
  (list (lambda (self other eql? mode)
          (eql? (set-ht self) (set-ht other)))
        (lambda (self hash-code mode)
          (hash-code (set-ht self))))
  #:property prop:sequence
  (lambda (s)
    (in-set s)))

(define set-method-table
  (hash 'length (let ([length (lambda (s)
                                (unless (set? s)
                                  (raise-argument-error* 'Set.length rhombus-realm "Set" s))
                                (hash-count (set-ht s)))])
                  (method1 length))))

(define (set-member? s v)
  (hash-ref (set-ht s) v #f))

(define (set-member! s v in?)
  (if in?
      (hash-set! (set-ht s) v #t)
      (hash-remove! (set-ht s) v)))

(define/arity #:name Set.length (set-count s)
  (hash-count (set-ht s)))

(define-syntax set-instance
  (dot-provider-more-static
   (dot-parse-dispatch
    (lambda (field-sym field ary 0ary nary fail-k)
      (case field-sym
        [(length) (0ary #'set-count)]
        [else #f])))))

(define-syntax (Set-build stx)
  (syntax-parse stx
    [(_ elem ...)
     #`(set (hashalw (~@ elem #t) ...))]))

(define Set-build*
  (let ([Set (lambda vals
               (define base-ht (hashalw))
               (set (for/fold ([ht base-ht]) ([val (in-list vals)])
                      (hash-set ht val #t))))])
    Set))

(define (list->set l) (apply Set-build* l))

(define (set->list s) (hash-keys (set-ht s)))

(define-syntax empty-set
  (expression-transformer
   (lambda (stx)
     (syntax-parse stx
       [(form-id . tail)
        (values #'(set #hashalw()) #'tail)]))))

(define-binding-syntax empty-set
  (binding-transformer
   (lambda (stx)
     (syntax-parse stx
       [(form-id . tail)
        (values (binding-form #'empty-set-infoer #'()) #'tail)]))))

(define-syntax (empty-set-infoer stx)
  (syntax-parse stx
    [(_ static-infos datum)
     (binding-info "Set.empty"
                   #'empty-set
                   #'static-infos
                   #'()
                   #'empty-set-matcher
                   #'literal-commit-nothing
                   #'literal-bind-nothing
                   #'datum)]))

(define-syntax (empty-set-matcher stx)
  (syntax-parse stx
    [(_ arg-id datum IF success fail)
     #'(IF (and (set? arg-id) (eqv? 0 (hash-count (set-ht arg-id))))
           success
           fail)]))

(define-reducer-syntax Set
  (reducer-transformer
   (lambda (stx)
     (syntax-parse stx
       [(_)
        #`[set
           ([ht #hashalw()])
           ((lambda (v) (hash-set ht v #t)))
           #,set-static-info]]))))

(define-for-syntax (parse-set stx repetition?)
  (syntax-parse stx
    [(form-id (~and content (_::braces . _)) . tail)
     (define-values (shape argss) (parse-setmap-content #'content
                                                        #:shape 'set
                                                        #:who (syntax-e #'form-id)
                                                        #:repetition? repetition?
                                                        #:list->set #'list->set))
     (values (build-setmap stx argss
                           #'Set-build
                           #'set-extend*
                           #'set-append
                           #'set-assert
                           set-static-info
                           #:repetition? repetition?
                           #:list->setmap #'list->set)
             #'tail)]
    [(_ . tail) (values (if repetition?
                            (identifier-repetition-use #'Set-build*)
                            #'Set-build*)
                        #'tail)]))

(define-name-root Set
  #:fields
  ([empty empty-set]
   [length set-count]
   of))

(define-syntax Set
  (expression-transformer
   (lambda (stx) (parse-set stx #f))))

(define-binding-syntax Set
  (binding-transformer
   (lambda (stx)
     (syntax-parse stx
       [(form-id (~and content (_::braces . _)) . tail)
        (parse-set-binding (syntax-e #'form-id) stx "braces")]
       [(form-id (_::parens arg ...) . tail)
        (parse-set-binding (syntax-e #'form-id) stx "parentheses")]))))

(define-repetition-syntax Set
  (repetition-transformer
   (lambda (stx) (parse-set stx #t))))

(define-for-syntax (parse-set-binding who stx opener+closer)
  (syntax-parse stx
    #:datum-literals (parens block group op)
    [(form-id (_ (group key-e ...) ...
                 (group elem-b ...)
                 (group _::...-bind))
              . tail)
     (generate-set-binding (syntax->list #`((#,group-tag key-e ...) ...))
                           #`(#,group-tag elem-b ...)
                           #'tail
                           #:rest-repetition? #t)]
    [(form-id (_ (group elem-e ...) ...
                 (group _::&-bind rst ...))
              . tail)
     (generate-set-binding (syntax->list #`((#,group-tag elem-e ...) ...))
                           #`(#,group-tag rst ...)
                           #'tail)]
    [(form-id (_ (group elem-e ...) ...) . tail)
     (generate-set-binding (syntax->list #`((#,group-tag elem-e ...) ...)) #f #'tail)]))

(define-for-syntax (generate-set-binding keys maybe-rest tail
                                         #:rest-repetition? [rest-repetition? #f])
  (with-syntax ([(key ...) keys]
                [tail tail])
    (define rest-tmp (and maybe-rest (generate-temporary 'rest-tmp)))
    (define-values (composite new-tail)
      ((make-composite-binding-transformer (cons "Set" (map shrubbery-syntax->string keys))
                                           #'(lambda (v) #t) ; predicate built into set-matcher
                                           '()
                                           '()
                                           #:rest-accessor
                                           (and maybe-rest
                                                (if rest-repetition?
                                                    #`(lambda (v) (set->list #,rest-tmp))
                                                    #`(lambda (v) #,rest-tmp)))
                                           #:rest-repetition? (and rest-repetition?
                                                                   'pair))
       #`(form-id (parens) . tail)
       maybe-rest))
    (with-syntax-parse ([composite::binding-form composite])
      (values
       (binding-form #'set-infoer
                     #`((key ...)
                        #,rest-tmp
                        composite.infoer-id
                        composite.data))
       new-tail))))

(define-syntax (set-infoer stx)
  (syntax-parse stx
    [(_ static-infos (keys rest-tmp composite-infoer-id composite-data))
     #:with composite-impl::binding-impl #'(composite-infoer-id static-infos composite-data)
     #:with composite-info::binding-info #'composite-impl.info
     (binding-info #'composite-info.annotation-str
                   #'composite-info.name-id
                   #'composite-info.static-infos
                   #'composite-info.bind-infos
                   #'set-matcher
                   #'set-committer
                   #'set-binder
                   #'(keys rest-tmp composite-info.matcher-id composite-info.committer-id composite-info.binder-id composite-info.data))]))

(define-syntax (set-matcher stx)
  (syntax-parse stx
    [(_ arg-id (keys rest-tmp composite-matcher-id composite-binder-id composite-committer-id composite-data)
        IF success failure)
     (define key-tmps (generate-temporaries #'keys))
     #`(IF (set? arg-id)
           #,(let loop ([keys (syntax->list #'keys)]
                        [key-tmp-ids key-tmps])
               (cond
                 [(and (null? keys) (syntax-e #'rest-tmp))
                  #`(begin
                      (define rest-tmp (set-remove*/copy arg-id (list #,@key-tmps)))
                      (composite-matcher-id 'set composite-data IF success failure))]
                 [(null? keys)
                  #`(composite-matcher-id 'set composite-data IF success failure)]
                 [else
                  #`(begin
                      (define #,(car key-tmp-ids) (rhombus-expression #,(car keys)))
                      (IF (set-ref arg-id #,(car key-tmp-ids))
                          #,(loop (cdr keys) (cdr key-tmp-ids))
                          failure))]))
           failure)]))

(define (set-remove*/copy s ks)
  (define h (set-ht s))
  (set (hash-remove* (if (immutable? h) h (hash-map/copy h values #:kind 'immutable)) ks)))

(define-syntax (set-committer stx)
  (syntax-parse stx
    [(_ arg-id (keys rest-tmp composite-matcher-id composite-committer-id composite-binder-id composite-data))
     #`(composite-committer-id 'set composite-data)]))

(define-syntax (set-binder stx)
  (syntax-parse stx
    [(_ arg-id (keys rest-tmp composite-matcher-id composite-committer-id composite-binder-id composite-data))
     #`(composite-binder-id 'set composite-data)]))


(define (in-set s)
  (in-hash-keys (set-ht s)))

(define-for-syntax set-static-info
  #'((#%map-ref set-member?)
     (#%map-append set-append)
     (#%sequence-constructor in-set)
     (#%dot-provider set-instance)))

(define-for-syntax mutable-set-static-info
  #`((#%map-set! set-member!)
     . #,set-static-info))

(define-annotation-constructor (Set of)
  ()
  #'set? set-static-info
  1
  #f
  (lambda (arg-id predicate-stxs)
    #`(for/and ([v (in-hash-keys (set-ht #,arg-id))])
        (#,(car predicate-stxs) v)))
  (lambda (static-infoss)
    #`()))

(define-static-info-syntax Set-build*
  (#%call-result #,set-static-info)
  (#%function-arity -1))

(define (MutableSet-build . vals)
  (define ht (make-hashalw))
  (for ([v (in-list vals)])
    (hash-set! ht v #t))
  (set ht))

(define-for-syntax (parse-mutable-set stx repetition?)
  (syntax-parse stx
    [(form-id (~and content (_::braces . _)) . tail)
     (define-values (shape argss)
       (parse-setmap-content #'content
                             #:shape 'set
                             #:who (syntax-e #'form-id)
                             #:repetition? repetition?
                             #:list->set #'list->set
                             #:no-splice "mutable sets"))
     (values (cond
               [repetition?
                (build-compound-repetition
                 stx
                 (car argss)
                 (lambda args
                   (values (quasisyntax/loc stx
                             (MutableSet-build #,@args))
                           mutable-set-static-info)))]
               [else (wrap-static-info*
                      (quasisyntax/loc stx
                        (MutableSet-build #,@(car argss)))
                      mutable-set-static-info)])
             #'tail)]
    [(_ . tail) (values (if repetition?
                            (identifier-repetition-use #'MutableSet-build)
                            #'MutableSet-build)
                        #'tail)]))

(define-syntax MutableSet
  (expression-transformer
   (lambda (stx) (parse-mutable-set stx #f))))

(define-repetition-syntax MutableSet
  (repetition-transformer
   (lambda (stx) (parse-mutable-set stx #t))))

(define-static-info-syntax MutableSet-build
  (#%call-result #,mutable-set-static-info))

(define (set-ref s v)
  (hash-ref (set-ht s) v #f))

;; macro to optimize to an inline functional update
(define-syntax (set-append stx)
  (syntax-parse stx
    [(_ set1 set2)
     (syntax-parse (unwrap-static-infos #'set2)
       [(id:identifier v)
        #:when (free-identifier=? (expr-quote Set-build) #'id)
        #'(set (hash-set (set-ht set1) v #t))]
       [_
        #'(set-append/proc set1 set2)])]))

(define (set-append/proc set1 set2)
  (set (for/fold ([ht (set-ht set1)]) ([k (in-hash-keys (set-ht set2))])
         (hash-set ht k #t))))

(define set-extend*
  (case-lambda
    [(set1 val) (set (hash-set (set-ht set1) val #t))]
    [(set1 . vals) (set-extend*/proc set1 vals)]))

(define (set-extend*/proc set1 vals)
  (set (for/fold ([ht (set-ht set1)]) ([k (in-list vals)])
         (hash-set ht k #t))))

(define (set-assert v)
  (unless (set? v)
    (raise-arguments-error* 'Set rhombus-realm
                            "not a set for splicing"
                            "value" v))
  v)
