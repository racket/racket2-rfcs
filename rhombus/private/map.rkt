#lang racket/base
(require racket/unsafe/undefined
         (for-syntax racket/base
                     racket/syntax
                     racket/symbol
                     syntax/parse/pre
                     "srcloc.rkt"
                     "with-syntax.rkt"
                     "tag.rkt"
                     shrubbery/print)
         "provide.rkt"
         "expression.rkt"
         "binding.rkt"
         "repetition.rkt"
         "compound-repetition.rkt"
         (submod "annotation.rkt" for-class)
         (submod "dot.rkt" for-dot-provider)
         "literal.rkt"
         "static-info.rkt"
         "index-result-key.rkt"
         "index-key.rkt"
         "append-key.rkt"
         "call-result-key.rkt"
         "function-arity-key.rkt"
         "sequence-constructor-key.rkt"
         "composite.rkt"
         (submod "list.rkt" for-compound-repetition)
         "parse.rkt"
         "realm.rkt"
         "reducer.rkt"
         "name-root.rkt"
         "setmap-parse.rkt"
         "dot-parse.rkt"
         "parens.rkt"
         (only-in "lambda-kwrest.rkt" hash-remove*)
         "op-literal.rkt"
         (only-in "pair.rkt"
                  Pair)
         "hash-snapshot.rkt"
         "mutability.rkt"
         "rest-bind.rkt")

(provide (for-spaces (rhombus/namespace
                      #f
                      rhombus/bind
                      rhombus/repet
                      rhombus/annot
                      rhombus/reducer)
                     Map)
         (for-spaces (rhombus/namespace
                      #f
                      rhombus/repet
                      rhombus/annot)
                     MutableMap)
         (for-spaces (rhombus/namespace
                      rhombus/bind
                      rhombus/annot)
                     ReadableMap
                     ;; temporary:
                     (rename-out [ReadableMap MapView])))

(module+ for-binding
  (provide (for-syntax parse-map-binding)))

(module+ for-info
  (provide (for-syntax map-static-info)
           Map-build))

(module+ for-builtin
  (provide map-method-table
           mutable-map-method-table))

(module+ for-build
  (provide hash-append
           hash-append/proc
           hash-extend*
           hash-assert
           list->map))

(define readable-map-method-table
  (hash 'length (method1 hash-count)
        'values (method1 hash-values)
        'keys (lambda (ht)
                (lambda ([try-sort? #f])
                  (hash-keys ht try-sort?)))
        'has_key (lambda (ht) (lambda (key) (hash-has-key? ht key)))
        'copy (method1 hash-copy)
        'get (lambda (ht)
               (let ([get (case-lambda
                            [(key) (hash-ref ht key)]
                            [(key default) (hash-ref ht key default)])])
                 get))
        'hash-snapshot (method1 hash-snapshot)))

(define map-method-table
  (hash-set readable-map-method-table
            'remove (method2 hash-remove)))

(define mutable-map-method-table
  (hash-set readable-map-method-table
        'delete (method2 hash-remove!)))

(define Map-build hashalw) ; inlined version of `Map.from_interleaved`

(define (Map.from_interleaved . args)
  (define ht (hashalw))
  (let loop ([ht ht] [args args])
    (cond
      [(null? args) ht]
      [(null? (cdr args))
       (raise-arguments-error* 'Map rhombus-realm
                               (string-append "key does not have a value"
                                              " (i.e., an odd number of arguments were provided)")
                               "key" (car args))]
      [else (loop (hash-set ht (car args) (cadr args)) (cddr args))])))

(define Map-pair-build
  (let ([Map (lambda args
               (build-map 'Map args))])
    Map))

(define (build-map who args)
  (define ht (hashalw))
  (let loop ([ht ht] [args args])
    (cond
      [(null? args) ht]
      [else
       (define arg (car args))
       (cond
         [(and (pair? arg) (pair? (cdr arg)) (null? (cddr arg)))
          (loop (hash-set ht (car arg) (cadr arg)) (cdr args))]
         [else
          (raise-argument-error* who rhombus-realm "[_, _]" arg)])])))

(define (list->map key+vals)
  (for/hashalw ([key+val (in-list key+vals)])
    (values (car key+val) (cdr key+val))))

(define (hash-pairs ht)
  (for/list ([p (in-hash-pairs ht)]) p))

(define-syntaxes (empty-map empty-map-view)
  (let ([t (expression-transformer
            (lambda (stx)
              (syntax-parse stx
                [(form-id . tail)
                 (values #'#hashalw() #'tail)])))])
    (values t t)))

(define-for-syntax (make-empty-map-binding name+hash?-id)
  (binding-transformer
   (lambda (stx)
     (syntax-parse stx
       [(form-id . tail)
        (values (binding-form #'empty-map-infoer name+hash?-id) #'tail)]))))
  
(define-binding-syntax empty-map (make-empty-map-binding #'("Map.empty" immutable-hash?)))
(define-binding-syntax empty-map-view (make-empty-map-binding #'("ReadableMap.empty" hash?)))

(define-syntax (empty-map-infoer stx)
  (syntax-parse stx
    [(_ static-infos (name-str hash?))
     (binding-info #'name-str
                   #'empty-map
                   #'static-infos
                   #'()
                   #'empty-map-matcher
                   #'literal-bind-nothing
                   #'literal-commit-nothing
                   #'hash?)]))

(define-syntax (empty-map-matcher stx)
  (syntax-parse stx
    [(_ arg-id hash? IF success fail)
     #'(IF (and (hash? arg-id) (eqv? 0 (hash-count arg-id)))
           success
           fail)]))

(define-for-syntax (parse-map stx repetition?)
  (syntax-parse stx
    #:datum-literals (braces)
    [(form-id (~and content (braces . _)) . tail)
     (define-values (shape argss) (parse-setmap-content #'content
                                                        #:shape 'map
                                                        #:who (syntax-e #'form-id)
                                                        #:repetition? repetition?
                                                        #:list->map #'list->map))
     (values (relocate-wrapped
              (respan (datum->syntax #f (list #'form-id #'content)))
              (build-setmap stx argss
                            #'Map-build
                            #'hash-extend*
                            #'hash-append
                            #'hash-assert
                            map-static-info
                            #:repetition? repetition?
                            #:list->setmap #'list->map))
             #'tail)]
    [(_ . tail) (values (cond
                          [repetition? (identifier-repetition-use #'Map-pair-build)]
                          [else #'Map-pair-build])
                        #'tail)]))

(define-name-root Map
  #:fields
  ([empty empty-map]
   [length hash-count]
   [keys hash-keys]
   [values hash-values]
   [has_key hash-has-key?]
   [copy hash-copy]
   [snapshot hash-snapshot]
   [get hash-ref]
   [ref hash-ref] ; temporary
   [remove hash-remove]
   of))

(define-name-root MutableMap
  #:fields
  ([delete hash-remove!]))

(define-name-root ReadableMap
  #:fields
  ([empty empty-map-view]))

(define-syntax Map
  (expression-transformer
   (lambda (stx) (parse-map stx #f))))

(define-for-syntax (make-map-binding-transformer mode)
  (binding-transformer
   (lambda (stx)
     (syntax-parse stx
       [(form-id (~and content (_::braces . _)) . tail)
        (parse-map-binding (syntax-e #'form-id) stx "braces" mode)]
       [(form-id (_::parens arg ...) . tail)
        (let loop ([args (syntax->list #'(arg ...))] [keys '()] [vals '()])
          (cond
            [(null? args) (generate-map-binding (reverse keys) (reverse vals) #f #'tail mode)]
            [else
             (syntax-parse (car args)
               #:datum-literals (group brackets)
               [(group (brackets key val))
                (loop (cdr args) (cons #'key keys) (cons #'val vals))]
               [_ (raise-syntax-error #f
                                      "expected [<key-expr>, <value-binding>]"
                                      stx
                                      (car args))])]))]))))

(define-binding-syntax Map
  (make-map-binding-transformer 'Map))
(define-binding-syntax ReadableMap
  (make-map-binding-transformer 'ReadableMap))

(define-repetition-syntax Map
  (repetition-transformer
   (lambda (stx) (parse-map stx #t))))

(define-for-syntax any-map-static-info
  #'((#%index-get hash-ref)
     (#%sequence-constructor in-hash)))

(define-for-syntax readable-map-static-info
  #`((#%dot-provider readable-hash-instance)
     . #,any-map-static-info))

(define-for-syntax map-static-info
  #`((#%dot-provider hash-instance)
     (#%append hash-append)
     . #,any-map-static-info))

(define-for-syntax mutable-map-static-info
  #`((#%index-set hash-set!)
     (#%dot-provider mutable-hash-instance)
     . #,any-map-static-info))

(define-annotation-constructor (Map of)
  ()
  #'immutable-hash? map-static-info
  2
  #f
  (lambda (arg-id predicate-stxs)
    #`(for/and ([(k v) (in-hash #,arg-id)])
        (and (#,(car predicate-stxs) k)
             (#,(cadr predicate-stxs) v))))
  (lambda (static-infoss)
    #`((#%index-result #,(cadr static-infoss))))
  #'map-build-convert #'())

(define-syntax (map-build-convert arg-id build-convert-stxs kws data)
  #`(for/fold ([map #hashalw()])
              ([(k v) (in-hash #,arg-id)])
      #:break (not map)
      (#,(car build-convert-stxs)
       k
       (lambda (k)
         (#,(cadr build-convert-stxs)
          v
          (lambda (v)
            (hash-set map k v))
          (lambda () #f)))
       (lambda () #f))))

(define-for-syntax readable-hash-instance-dispatch
  (lambda (field-sym field ary 0ary nary fail-k)
    (case field-sym
      [(length) (0ary #'hash-count)]
      [(keys) (nary #'hash-keys 3 #'hash-keys list-static-infos)]
      [(values) (0ary #'hash-values)]
      [(has_key) (nary #'hash-has-key? 2 #'hash-has-key?)]
      [(copy) (0ary #'hash-copy mutable-map-static-info)]
      [(snapshot) (0ary #'hash-snapshot map-static-info)]
      [(get) (nary #'hash-ref 6 #'hash-ref)]
      [else (fail-k)])))

(define-syntax readable-hash-instance
  (dot-provider
   (dot-parse-dispatch
    readable-hash-instance-dispatch)))

(define-syntax hash-instance
  (dot-provider
   (dot-parse-dispatch
    (lambda (field-sym field ary 0ary nary fail-k)
      (case field-sym
        [(remove) (nary #'hash-remove 2 #'hash-remove map-static-info)]
        [else (readable-hash-instance-dispatch field-sym field ary 0ary nary fail-k)])))))

(define-syntax mutable-hash-instance
  (dot-provider
   (dot-parse-dispatch
    (lambda (field-sym field ary 0ary nary fail-k)
      (case field-sym
        [(delete) (nary #'hash-remove! 2 #'hash-remove! map-static-info)]
        [else (readable-hash-instance-dispatch field-sym field ary 0ary nary fail-k)])))))

(define-static-info-syntax Map-pair-build
  (#%call-result #,map-static-info)
  (#%function-arity -1))

(define-reducer-syntax Map
  (reducer-transformer
   (lambda (stx)
     (syntax-parse stx
       [(_ . tail)
        (values
         (reducer/no-break #'build-map-reduce
                           #'([ht #hashalw()])
                           #'build-map-add
                           map-static-info
                           #'ht)
         #'tail)]))))

(define-syntax (build-map-reduce stx)
  (syntax-parse stx
    [(_ ht-id e) #'e]))

(define-syntax (build-map-add stx)
  (syntax-parse stx
    [(_ ht-id e)
     #'(let-values ([(k v) e])
         (hash-set ht-id k v))]))

(define-annotation-syntax MutableMap (identifier-annotation #'mutable-hash? mutable-map-static-info))
(define-annotation-syntax ReadableMap (identifier-annotation #'hash? readable-map-static-info))

(define MutableMap-build
  (let ([MutableMap (lambda args
                      (hash-copy (build-map 'MutableMap args)))])
    MutableMap))

(define-for-syntax (parse-mutable-map stx repetition?)
  (syntax-parse stx
    #:datum-literals (braces)
    [(form-id (~and content (braces . _)) . tail)
     (define-values (shape argss)
       (parse-setmap-content #'content
                             #:shape 'map
                             #:who (syntax-e #'form-id)
                             #:repetition? repetition?
                             #:list->map #'list->map
                             #:no-splice "mutable maps"))
     (values (cond
               [repetition?
                (build-compound-repetition
                 stx
                 (car argss)
                 (lambda args
                   (values (quasisyntax/loc stx
                             (hash-copy (Map-build #,@args)))
                           mutable-map-static-info)))]
               [else
                (wrap-static-info*
                 (quasisyntax/loc stx
                   (hash-copy (Map-build #,@(if (null? argss) null (car argss)))))
                 mutable-map-static-info)])
             #'tail)]
    [(_ . tail) (values (if repetition?
                            (identifier-repetition-use #'MutableMap-build)
                            #'MutableMap-build)
                        #'tail)]))

(define-syntax MutableMap
  (expression-transformer
   (lambda (stx) (parse-mutable-map stx #f))))

(define-repetition-syntax MutableMap
  (repetition-transformer
   (lambda (stx) (parse-mutable-map stx #t))))

(define-static-info-syntax MutableMap-build
  (#%call-result #,mutable-map-static-info))

(define-for-syntax (parse-map-binding who stx opener+closer [mode 'Map])
  (syntax-parse stx
    #:datum-literals (parens block group)
    [(form-id (_ (group key-e ... (block (group val ...))) ...
                 (group key-b ... (block (group val-b ...)))
                 (group _::...-bind))
              . tail)
     (generate-map-binding (syntax->list #`((#,group-tag key-e ...) ...)) #`((#,group-tag val ...) ...)
                           #`(group Pair (parens (#,group-tag key-b ...) (#,group-tag val-b ...)))
                           #'tail
                           mode
                           #:rest-repetition? #t)]
    [(form-id (_ (group key-e ... (block (group val ...))) ...
                 (group _::&-bind rst ...))
              . tail)
     (generate-map-binding (syntax->list #`((#,group-tag key-e ...) ...)) #`((#,group-tag val ...) ...)
                           #`(#,group-tag rest-bind #,map-static-info
                              (#,group-tag rst ...))
                           #'tail
                           mode)]
    [(form-id (_ (group key-e ... (block (group val ...))) ...) . tail)
     (generate-map-binding (syntax->list #`((#,group-tag key-e ...) ...)) #`((#,group-tag val ...) ...)
                           #f
                           #'tail
                           mode)]
    [(form-id wrong . tail)
     (raise-syntax-error who
                         (format "bad key-value combination within ~a" opener+closer)
                         #'wrong)]))

(define-for-syntax (generate-map-binding keys vals maybe-rest tail mode
                                         #:rest-repetition? [rest-repetition? #f])
  (with-syntax ([(key ...) keys]
                [(val ...) vals]
                [tail tail])
    (define tmp-ids (generate-temporaries #'(key ...)))
    (define rest-tmp (and maybe-rest (generate-temporary 'rest-tmp)))
    (define-values (composite new-tail)
      ((make-composite-binding-transformer (cons (symbol->immutable-string mode) (map shrubbery-syntax->string keys))
                                           #'(lambda (v) #t) ; predicate built into map-matcher
                                           (for/list ([tmp-id (in-list tmp-ids)])
                                             #`(lambda (v) #,tmp-id))
                                           (for/list ([arg (in-list tmp-ids)])
                                             #'())
                                           #:static-infos map-static-info
                                           #:index-result-info? #t
                                           #:rest-accessor
                                           (and maybe-rest
                                                (if rest-repetition?
                                                    #`(lambda (v) (hash-pairs #,rest-tmp))
                                                    #`(lambda (v) #,rest-tmp)))
                                           #:rest-repetition? (and rest-repetition?
                                                                   'pair))
       #`(form-id (parens val ...) . tail)
       maybe-rest))
    (with-syntax-parse ([composite::binding-form composite])
      (values
       (binding-form #'map-infoer
                     #`(#,mode
                        (key ...)
                        #,tmp-ids
                        #,rest-tmp
                        composite.infoer-id
                        composite.data))
       new-tail))))

(define-syntax (map-infoer stx)
  (syntax-parse stx
    [(_ static-infos (mode keys tmp-ids rest-tmp composite-infoer-id composite-data))
     #:with composite-impl::binding-impl #'(composite-infoer-id static-infos composite-data)
     #:with composite-info::binding-info #'composite-impl.info
     (binding-info #'composite-info.annotation-str
                   #'composite-info.name-id
                   #'composite-info.static-infos
                   #'composite-info.bind-infos
                   #'map-matcher
                   #'map-committer
                   #'map-binder
                   #'(mode keys tmp-ids rest-tmp
                           composite-info.matcher-id composite-info.committer-id composite-info.binder-id
                           composite-info.data))]))

(define-syntax (map-matcher stx)
  (syntax-parse stx
    [(_ arg-id (mode keys tmp-ids rest-tmp composite-matcher-id composite-committer-id composite-binder-id composite-data)
        IF success failure)
     (define key-tmps (generate-temporaries #'keys))
     #`(IF (#,(if (eq? (syntax-e #'mode) 'ReadableMap) #'hash? #'immutable-hash?) arg-id)
           #,(let loop ([keys (syntax->list #'keys)]
                        [key-tmp-ids key-tmps]
                        [val-tmp-ids (syntax->list #'tmp-ids)])
               (cond
                 [(and (null? keys) (syntax-e #'rest-tmp))
                  #`(begin
                      (define rest-tmp (hash-remove*/copy arg-id (list #,@key-tmps)))
                      (composite-matcher-id 'map composite-data IF success failure))]
                 [(null? keys)
                  #`(composite-matcher-id 'map composite-data IF success failure)]
                 [else
                  #`(begin
                      (define #,(car key-tmp-ids) (rhombus-expression #,(car keys)))
                      (define #,(car val-tmp-ids) (hash-ref arg-id #,(car key-tmp-ids) unsafe-undefined))
                      (IF (not (eq? #,(car val-tmp-ids) unsafe-undefined))
                          #,(loop (cdr keys) (cdr key-tmp-ids) (cdr val-tmp-ids))
                          failure))]))
           failure)]))

;; hash-remove*/copy : (Hashof K V) (Listof K) -> (ImmutableHashof K V)
(define (hash-remove*/copy h ks)
  (hash-remove* (if (immutable? h) h (hash-map/copy h values #:kind 'immutable)) ks))

(define-syntax (map-committer stx)
  (syntax-parse stx
    [(_ arg-id (mode keys tmp-ids rest-tmp composite-matcher-id composite-committer-id composite-binder-id composite-data))
     #`(composite-committer-id 'map composite-data)]))

(define-syntax (map-binder stx)
  (syntax-parse stx
    [(_ arg-id (mode keys tmp-ids rest-tmp composite-matcher-id composite-committer-id composite-binder-id composite-data))
     #`(composite-binder-id 'map composite-data)]))


;; macro to optimize to an inline functional update
(define-syntax (hash-append stx)
  (syntax-parse stx
    [(_ map1 map2)
     (syntax-parse (unwrap-static-infos #'map2)
       [(id:identifier k:keyword v)
        #:when (free-identifier=? (expr-quote Map-build) #'id)
        #'(hash-set map1 'k v)]
       [(id:identifier k v)
        #:when (free-identifier=? (expr-quote Map-build) #'id)
        #'(hash-set map1 k v)]
       [_
        #'(hash-append/proc map1 map2)])]))

(define (hash-append/proc map1 map2)
  (for/fold ([ht map1]) ([(k v) (in-hash map2)])
    (hash-set ht k v)))

(define hash-extend*
  (case-lambda
    [(ht key val) (hash-set ht key val)]
    [(ht . args) (hash-extend*/proc ht args)]))

(define (hash-extend*/proc ht args)
  (let loop ([ht ht] [args args])
    (cond
      [(null? args) ht]
      [(null? (cdr args)) (error 'hash-extend* "argument count went wrong")]
      [else (loop (hash-set ht (car args) (cadr args)) (cddr args))])))

(define (hash-assert v)
  (unless (immutable-hash? v)
    (raise-arguments-error* 'Map rhombus-realm
                            "not an immutable map for splicing"
                            "value" v))
  v)

(define-static-info-syntaxes (hash-count hash-values)
  (#%function-arity 2))

(define-static-info-syntaxes (hash-keys)
  (#%function-arity 6))

(define-static-info-syntaxes (hash-has-key?)
  (#%function-arity 4))

(define-static-info-syntaxes (hash-copy)
  (#%function-arity 1)
  (#%call-result #,mutable-map-static-info))

(define-static-info-syntaxes (hash-snapshot)
  (#%function-arity 1)
  (#%call-result #,map-static-info))
  
(define-static-info-syntaxes (hash-ref)
  (#%function-arity 12))

(define-static-info-syntaxes (hash-remove)
  (#%function-arity 4)
  (#%call-result #,map-static-info))

(define-static-info-syntaxes (hash-remove!)
  (#%function-arity 4))
