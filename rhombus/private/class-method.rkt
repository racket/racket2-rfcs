#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest/syntax-local
                     "class-parse.rkt"
                     "interface-parse.rkt"
                     "srcloc.rkt"
                     "statically-str.rkt"
                     (submod "entry-point-adjustment.rkt" for-struct))
         racket/stxparam
         "expression.rkt"
         "parse.rkt"
         "expression.rkt"
         "entry-point.rkt"
         "class-this.rkt"
         "class-method-result.rkt"
         "function-indirect-key.rkt"
         "index-key.rkt"
         "append-indirect-key.rkt"
         "static-info.rkt"
         (submod "dot.rkt" for-dot-provider)
         (submod "assign.rkt" for-assign)
         "parens.rkt"
         (submod "function-parse.rkt" for-call)
         "is-static.rkt"
         "realm.rkt"
         "wrap-expression.rkt"
         (only-in "syntax-parameter.rkt"
                  with-syntax-parameters
                  syntax-parameters-key))

(provide (for-syntax extract-method-tables
                     build-interface-vtable
                     build-quoted-method-map
                     build-quoted-method-shapes
                     build-quoted-private-method-list
                     build-method-results
                     build-method-result-expression
                     build-methods

                     get-private-table)

         this
         super

         prop:methods
         prop-methods-ref
         method-ref
         method-curried-ref

         raise-not-an-instance)

(define-values (prop:methods prop-methods? prop-methods-ref)
  (make-struct-type-property 'methods))

(define-syntax (method-ref stx)
  (syntax-parse stx
    [(_ ref obj pos) #`(vector-ref (ref obj) pos)]))

(define (method-curried-ref ref obj pos)
  (curry-method (method-ref ref obj pos) obj))

(define (raise-not-an-instance name v)
  (raise-arguments-error* name rhombus-realm "not an instance for method call" "value" v))

;; Results:
;;   method-mindex   ; symbol -> mindex
;;   method-names    ; index -> symbol-or-identifier; symbol is inherited
;;   method-vtable   ; index -> function-identifier or '#:abstract
;;   method-results  ; symbol -> nonempty list of identifiers; first one implies others
;;   method-private  ; symbol -> identifier or (list identifier); list means property; non-super symbol's identifier attached as 'lhs-id
;;   method-decls    ; symbol -> identifier, intended for checking distinct
;;   abstract-name   ; #f or identifier for a still-abstract method

(define-for-syntax (extract-method-tables stx added-methods super interfaces private-interfaces final? prefab?)
  (define supers (if super (cons super interfaces) interfaces))
  (define-values (super-str supers-str)
    (cond
      [(null? interfaces)
       (values "superclass" "superclasses(!?)")]
      [(not super)
       (values "interface" "superinterfaces")]
      [else
       (values "class or interface" "classes or superinterfaces")]))

  (define dot-ht
    (for/fold ([ht #hasheq()]) ([super (in-list supers)])
      (for/fold ([ht #hasheq()]) ([sym (in-list (super-dots super))])
        (when (hash-ref ht sym #f)
          (raise-syntax-error #f (format "dot syntax supplied by multiple ~a" supers-str) stx sym))
        (hash-set ht sym #t))))

  ;; create merged method tables from the superclass (if any) and all superinterfaces;
  ;; we start with the superclass, if any, so the methods from its vtable stay
  ;; in the same place in the new vtable
  (define-values (ht            ; symbol -> (cons mindex id)
                  super-priv-ht ; symbol -> identifier or (list identifier), implies not in `ht`
                  vtable-ht     ; int -> accessor-identifier or '#:abstract
                  from-ht)      ; symbol -> super
    (for/fold ([ht #hasheq()] [priv-ht #hasheq()] [vtable-ht #hasheqv()] [from-ht #hasheq()]) ([super (in-list supers)])
      (define super-vtable (super-method-vtable super))
      (define private? (hash-ref private-interfaces super #f))
      (for/fold ([ht ht] [priv-ht priv-ht] [vtable-ht vtable-ht] [from-ht from-ht])
                ([shape (super-method-shapes super)]
                 [super-i (in-naturals)])
        (define new-rhs (let ([rhs (vector-ref super-vtable super-i)])
                          (if (eq? (syntax-e rhs) '#:abstract) '#:abstract rhs)))
        (define-values (key val i old-val)
          (let* ([arity (and (vector? shape) (vector-ref shape 1))]
                 [shape (if (vector? shape) (vector-ref shape 0) shape)]
                 [property? (pair? shape)]
                 [shape (if (pair? shape) (car shape) shape)]
                 [final? (not (box? shape))]
                 [shape (if (box? shape) (unbox shape) shape)])
            (define old-val (or (hash-ref ht shape #f)
                                (hash-ref priv-ht shape #f)))
            (define i (if (pair? old-val)
                          (mindex-index (car old-val))
                          (hash-count ht)))
            (values shape
                    (cons (mindex i final? property? arity #t) shape)
                    i
                    old-val)))
        (when (hash-ref dot-ht key #f)
          (raise-syntax-error #f (format "name supplied as both method and dot syntax by ~a" supers-str) stx key))
        (cond
          [old-val
           (define old-rhs (cond
                             [(and (pair? old-val)
                                   (mindex? (car old-val)))
                              (let ([old-i (car old-val)])
                                (hash-ref vtable-ht (mindex-index old-i)))]
                             [(pair? old-val) (car old-val)]
                             [else old-val]))
           (unless (or (if (identifier? old-rhs)
                           ;; same implementation?
                           (and (identifier? new-rhs)
                                (free-identifier=? old-rhs new-rhs))
                           ;; both abstract?
                           (eq? old-rhs new-rhs))
                       ;; from a common superclass/superinterface?
                       (and (not (and (identifier? new-rhs) (identifier? old-rhs)))
                            (in-common-superinterface? (hash-ref from-ht key) super key))
                       ;; overridden
                       (for/or ([added (in-list added-methods)])
                         (and (eq? key (syntax-e (added-method-id added)))
                              (eq? 'override (added-method-replace added)))))
             (raise-syntax-error #f (format "method supplied by multiple ~a and not overridden" supers-str) stx key))
           (if (or private?
                   (and (pair? old-val) (mindex? (car old-val))
                        (not (and (identifier? new-rhs)
                                  (not (identifier? old-rhs)))))
                   (and (identifier? old-rhs)
                        (not (identifier? new-rhs))))
               (values ht priv-ht vtable-ht from-ht)
               (values (hash-set ht key val)
                       (hash-remove priv-ht key)
                       (hash-set vtable-ht i new-rhs)
                       (hash-set from-ht key super)))]
          [private?
           (define (property-shape? shape) (or (pair? shape) (and (vector? shape) (pair? (vector-ref shape 0)))))
           (values ht
                   (hash-set priv-ht key (if (property-shape? shape)
                                             (list new-rhs)
                                             new-rhs))
                   vtable-ht
                   (hash-set from-ht key super))]
          [else
           (values (hash-set ht key val)
                   priv-ht
                   (hash-set vtable-ht i new-rhs)
                   (hash-set from-ht key super))]))))

  ;; merge method-result tables from superclass and superinterfaces,
  ;; assuming that the names all turn out to be sufficiently distinct
  (define super-method-results
    (for/fold ([method-results (if super
                                   (for/hasheq ([(sym id) (in-hash (class-desc-method-result super))])
                                     (values sym (list id)))
                                   #hasheq())])
              ([intf (in-list interfaces)])
      (for/fold ([method-results method-results]) ([(sym id) (in-hash (interface-desc-method-result intf))])
        (hash-set method-results sym (cons id (hash-ref method-results sym '()))))))

  (define (private-id/property lhs-id added)
    (let ([id (syntax-property (added-method-rhs-id added)
                               'lhs-id
                               lhs-id)])
      (if (eq? (added-method-kind added) 'property)
          (list id)
          id)))

  ;; add methods for the new class/interface
  (define-values (new-ht new-vtable-ht priv-ht here-ht)
    (for/fold ([ht ht] [vtable-ht vtable-ht] [priv-ht #hasheq()] [here-ht #hasheq()]) ([added (in-list added-methods)])
      (define id (added-method-id added))
      (define new-here-ht (hash-set here-ht (syntax-e id) id))
      (define (check-consistent-property property?)
        (if property?
            (when (eq? (added-method-kind added) 'method)
              (raise-syntax-error #f (format "cannot override ~a's property with a non-property method" super-str)
                                  stx id))
            (when (eq? (added-method-kind added) 'property)
              (raise-syntax-error #f (format "cannot override ~a's non-property method with a property" super-str)
                                  stx id))))
      (when (hash-ref dot-ht (syntax-e id) #f)
        (raise-syntax-error #f (format "method name is supplied as dot syntax by ~a" super-str) stx id))
      (cond
        [(hash-ref here-ht (syntax-e id) #f)
         (raise-syntax-error #f "duplicate method name" stx id)]
        [(hash-ref ht (syntax-e id) #f)
         => (lambda (mix+id)
              (define mix (car mix+id))
              (cond
                [(eq? 'override (added-method-replace added))
                 (when (eq? (added-method-disposition added) 'private)
                   (raise-syntax-error #f (format "method is not in private ~a" super-str) stx id))
                 (when (mindex-final? mix)
                   (raise-syntax-error #f (format "cannot override ~a's final method" super-str) stx id))
                 (check-consistent-property (mindex-property? mix))
                 (define idx (mindex-index mix))
                 (define final? (eq? (added-method-disposition added) 'final))
                 (values (if (or final?
                                 (not (equal? (added-method-arity added) (mindex-arity mix))))
                             (let ([property? (eq? (added-method-kind added) 'property)]
                                   [arity (added-method-arity added)])
                               (hash-set ht (syntax-e id) (cons (mindex idx final? property? arity #f) id)))
                             ht)
                         (hash-set vtable-ht idx (added-method-rhs-id added))
                         priv-ht
                         new-here-ht)]
                [else
                 (raise-syntax-error #f (format "method is already in ~a" super-str) stx id)]))]
        [(hash-ref super-priv-ht (syntax-e id) #f)
         => (lambda (rhs)
              (cond
                [(and (eq? (added-method-replace added) 'override)
                      (eq? (added-method-disposition added) 'private))
                 (check-consistent-property (list? rhs))
                 (values ht
                         vtable-ht
                         (hash-set priv-ht (syntax-e id) (private-id/property id added))
                         new-here-ht)]
                [(eq? (added-method-replace added) 'override)
                 (raise-syntax-error #f (format "method is in private ~a" super-str) stx id)]
                [else
                 (raise-syntax-error #f (format "method is already in private ~a" super-str) stx id)]))]
        [else
         (cond
           [(eq? (added-method-replace added) 'override)
            (raise-syntax-error #f (format "method is not in ~a" super-str) stx id)]
           [(eq? (added-method-disposition added) 'private)
            (values ht
                    vtable-ht
                    (hash-set priv-ht (syntax-e id) (private-id/property id added))
                    new-here-ht)]
           [else
            (define pos (hash-count vtable-ht))
            (when prefab?
              (unless (eq? (added-method-disposition added) 'final)
                (raise-syntax-error #f "methods in a prefab class must be final" stx id)))
            (values (hash-set ht (syntax-e id)
                              (cons (mindex pos
                                            (or final?
                                                (eq? (added-method-disposition added) 'final))
                                            (eq? (added-method-kind added) 'property)
                                            (added-method-arity added)
                                            #f)
                                    id))
                    (hash-set vtable-ht pos (added-method-rhs-id added))
                    priv-ht
                    new-here-ht)])])))

  (for ([(name rhs) (in-hash super-priv-ht)])
    (when (eq? rhs '#:abstract)
      (unless (hash-ref priv-ht name #f)
        (raise-syntax-error #f (format "method from private ~a must be overridden" super-str) stx name))))

  (define method-mindex
    (for/hasheq ([(k mix+id) (in-hash new-ht)])
      (values k (car mix+id))))
  (define method-names
    (for/hasheqv ([(s mix+id) (in-hash new-ht)])
      (values (mindex-index (car mix+id)) (cdr mix+id))))
  (define method-vtable
    (for/vector ([i (in-range (hash-count new-vtable-ht))])
      (hash-ref new-vtable-ht i)))
  (define method-results
    (for/fold ([method-results super-method-results]) ([added (in-list added-methods)]
                                                       #:when (added-method-result-id added))
      (define sym (syntax-e (added-method-id added)))
      (hash-set method-results sym (cons (added-method-result-id added)
                                         (hash-ref method-results sym '())))))
  (define method-private
    (for/fold ([ht super-priv-ht]) ([(k v) (in-hash priv-ht)])
      (hash-set ht k v)))
  
  (define abstract-name
    (for/or ([v (in-hash-values new-vtable-ht)]
             [i (in-naturals)])
      (and (eq? v '#:abstract)
           (hash-ref method-names i))))

  (values method-mindex
          method-names
          method-vtable
          method-results
          method-private
          here-ht
          abstract-name))

(define-for-syntax (build-interface-vtable intf method-mindex method-vtable method-names method-private)
  (for/list ([shape (in-vector (interface-desc-method-shapes intf))])
    (define name (let* ([shape (if (vector? shape) (vector-ref shape 0) shape)]
                        [shape (if (pair? shape) (car shape) shape)]
                        [shape (if (box? shape) (unbox shape) shape)])
                   shape))
    (cond
      [(hash-ref method-private name #f)
       => (lambda (id) (if (pair? id) (car id) id))]
      [else
       (define pos (mindex-index (hash-ref method-mindex name)))
       (vector-ref method-vtable pos)])))

(define-for-syntax (build-quoted-method-map method-mindex)
  (for/hasheq ([(sym mix) (in-hash method-mindex)])
    (values sym (mindex-index mix))))

(define-for-syntax (build-quoted-method-shapes method-vtable method-names method-mindex)
  (for/vector ([i (in-range (vector-length method-vtable))])
    (define name (hash-ref method-names i))
    (define mix (hash-ref method-mindex (if (syntax? name) (syntax-e name) name)))
    (define sym ((if (mindex-property? mix) list values)
                 ((if (mindex-final? mix) values box)
                  name)))
    (if (mindex-arity mix)
        (vector sym (mindex-arity mix))
        sym)))

(define-for-syntax (build-quoted-private-method-list mode method-private)
  (sort (for/list ([(sym v) (in-hash method-private)]
                   #:when (eq? mode (if (pair? v) 'property 'method)))
          sym)
        symbol<?))

(define-for-syntax (build-method-results added-methods
                                         method-mindex method-vtable method-private
                                         method-results
                                         in-final?
                                         methods-ref-id
                                         call-statinfo-indirect-stx callable?
                                         index-statinfo-indirect-stx indexable?
                                         index-set-statinfo-indirect-stx setable?
                                         append-statinfo-indirect-stx appendable?)
  (define defs
    (for/list ([added (in-list added-methods)]
               #:when (added-method-result-id added))
      #`(define-method-result-syntax #,(added-method-result-id added)
          #,(added-method-maybe-ret added)
          #,(cdr (hash-ref method-results (syntax-e (added-method-id added)) '(none)))
          ;; When calls do not go through vtable, also add static info
          ;; as #%call-result to binding; non-vtable calls include final methods
          ;; and `super` calls to non-final methods... which is all methods,
          ;; since non-final methods are potentially targets of `super` calls
          #,(or (let ([id/property (hash-ref method-private (syntax-e (added-method-id added)) #f)])
                  (if (pair? id/property) (car id/property) id/property))
                (and (not (eq? (added-method-body added) 'abstract))
                     (let ([mix (hash-ref method-mindex (syntax-e (added-method-id added)) #f)])
                       (vector-ref method-vtable (mindex-index mix)))))
          ;; result annotation can convert if final
          #,(or in-final?
                (eq? (added-method-disposition added) 'final))
          #,(added-method-kind added)
          #,(added-method-arity added)
          #,(and callable?
                 (eq? 'call (syntax-e (added-method-id added)))
                 call-statinfo-indirect-stx)
          #,(and indexable?
                 (eq? 'get (syntax-e (added-method-id added)))
                 #`[#,index-statinfo-indirect-stx #,(added-method-rhs-id added)])
          #,(and setable?
                 (eq? 'set (syntax-e (added-method-id added)))
                 #`[#,index-set-statinfo-indirect-stx #,(added-method-rhs-id added)])
          #,(and appendable?
                 (eq? 'append (syntax-e (added-method-id added)))
                 #`[#,append-statinfo-indirect-stx #,(added-method-rhs-id added)]))))
  ;; may need to add info for inherited `call`, etc.:
  (define (add-able which statinfo-indirect-stx able? key defs abstract-args)
    (if (and statinfo-indirect-stx
             able?
             (not (for/or ([added (in-list added-methods)])
                    (eq? which (syntax-e (added-method-id added))))))
        ;; method is inherited, so bounce again to inherited method's info
        (let* ([index (mindex-index (hash-ref method-mindex which))]
               [impl-id (vector-ref method-vtable index)])
          (define abstract? (eq? impl-id '#:abstract))
          (if (or (not abstract?) abstract-args)
              (cons
               #`(define-static-info-syntax #,statinfo-indirect-stx
                   (#,key #,(if abstract?
                                #`(lambda (obj . #,abstract-args)
                                    ((method-ref #,methods-ref-id obj #,index) obj . #,abstract-args))
                                impl-id)))
               defs)
              defs))
        defs))
  (let* ([defs (add-able 'call call-statinfo-indirect-stx callable? #'#%function-indirect defs #f)]
         [defs (add-able 'get index-statinfo-indirect-stx indexable? #'#%index-get defs #'(index))]
         [defs (add-able 'set index-set-statinfo-indirect-stx setable? #'#%index-set defs #'(index val))]
         [defs (add-able 'append append-statinfo-indirect-stx appendable? #'#%append/checked defs #'(val))])
    defs))

(define-for-syntax (build-method-result-expression method-result)
  #`(hasheq
     #,@(apply append
               (for/list ([(sym ids) (in-hash method-result)])
                 (list #`(quote #,sym)
                       #`(quote-syntax #,(car ids)))))))

(define-for-syntax (super-method-vtable p)
  (syntax-e
   (if (class-desc? p)
       (class-desc-method-vtable p)
       (interface-desc-method-vtable p))))

(define-for-syntax (super-method-shapes p)
  (if (class-desc? p)
      (class-desc-method-shapes p)
      (interface-desc-method-shapes p)))

(define-for-syntax (super-method-map p)
  (if (class-desc? p)
      (class-desc-method-map p)
      (interface-desc-method-map p)))

(define-for-syntax (super-dots p)
  (if (class-desc? p)
      (class-desc-dots p)
      (interface-desc-dots p)))

(define-for-syntax (in-common-superinterface? i j key)
  (define (lookup id)
    (and id (syntax-local-value* (in-class-desc-space id)
                                 (lambda (v)
                                   (or (class-desc-ref v)
                                       (interface-desc-ref v))))))
  (define (gather-from-interfaces int-ids ht saw-abstract?)
    (let ([int-ids (syntax->list int-ids)])
      (for/fold ([ht ht]) ([int-id (in-list int-ids)])
        (gather (lookup int-id) ht saw-abstract?))))
  (define (gather i ht saw-abstract?)
    (cond
      [(and i (hash-has-key? (super-method-map i) key))
       (define idx (hash-ref (super-method-map i) key))
       (define impl (vector-ref (super-method-vtable i) idx))
       (cond
         [(and (not (eq? (syntax-e impl) '#:abstract))
               saw-abstract?)
          ;; no superinterface abstract is the relevant abstract
          ht]
         [else
          (define new-saw-abstract? (or saw-abstract? (eq? (syntax-e impl) '#:abstract)))
          (gather-from-interfaces (if (class-desc? i)
                                      (class-desc-interface-ids i)
                                      (interface-desc-super-ids i))
                                  (let ([ht (hash-set ht i #t)])
                                    (if (class-desc? i)
                                        (gather (lookup (class-desc-super-id i))
                                                ht
                                                new-saw-abstract?)
                                        ht))
                                  new-saw-abstract?)])]
      [else ht]))
  (define i-ht (gather i #hasheq() #f))
  (define j-ht (gather j #hasheq() #f))
  (for/or ([k (in-hash-keys i-ht)])
    (hash-ref j-ht k #f)))

(define-syntax this
  (expression-transformer
   (lambda (stxs)
     (syntax-parse stxs
       [(head . tail)
        (cond
          [(let ([v (syntax-parameter-value #'this-id)])
             (and (not (identifier? v)) v))
           => (lambda (id+dp+isi+supers)
                (syntax-parse id+dp+isi+supers
                  [(id dp indirect-static-infos . _)
                   (values (wrap-static-info*
                            (wrap-static-info (datum->syntax #'id (syntax-e #'id) #'head #'head)
                                              #'#%dot-provider
                                              #'dp)
                            #'indirect-static-infos)
                           #'tail)]))]
          [else
           (raise-syntax-error #f
                               "allowed only within methods"
                               #'head)])]))))

(define-syntax super
  (expression-transformer
   (lambda (stxs)
     (define c-or-id+dp+isi+supers (syntax-parameter-value #'this-id))
     (cond
       [(not c-or-id+dp+isi+supers)
        (raise-syntax-error #f
                            "allowed only within methods and constructors"
                            #'head)]
       [(keyword? (syntax-e (car (syntax-e c-or-id+dp+isi+supers))))
        ;; in a constructor
        (syntax-parse c-or-id+dp+isi+supers
          [(_ make-name)
           (syntax-parse stxs
             [(head . tail)
              (values (relocate+reraw #'head #'make-name) #'tail)])])]
       [else
        ;; in a method
        (define id+dp+isi+supers c-or-id+dp+isi+supers)
        (syntax-parse id+dp+isi+supers
          [(id dp isi)
           (raise-syntax-error #f "class has no superclass"
                               (syntax-parse stxs #:datum-literals (op |.|) [(head . _) #'head]))]
          [(id dp isi . super-ids)
           (syntax-parse stxs
             #:datum-literals (op |.|)
             [(head (op (~and dot-op |.|)) method-id:identifier . tail)
              (define super+pos
                (for/fold ([found #f]) ([super-id (in-list (syntax->list #'super-ids))])
                  (define super (syntax-local-value* (in-class-desc-space super-id)
                                                     (lambda (v)
                                                       (or (class-desc-ref v)
                                                           (interface-desc-ref v)))))
                  (unless super
                    (raise-syntax-error #f "class or interface not found" super-id))
                  (define pos (hash-ref (super-method-map super) (syntax-e #'method-id) #f))
                  (when found
                    (unless (in-common-superinterface? (car found) super (syntax-e #'method-id))
                      (raise-syntax-error #f "inherited method is ambiguous" #'method-id)))
                  (and pos (cons super pos))))
              (unless super+pos
                (raise-syntax-error #f "no such method in superclass" #'head #'method-id))
              (define super (car super+pos))
              (define pos (cdr super+pos))
              (define impl (vector-ref (super-method-vtable super) pos))
              (when (eq? (syntax-e impl) '#:abstract)
                (raise-syntax-error #f "method is abstract in superclass" #'head #'method-id))
              (define shape+arity (vector-ref (super-method-shapes super) pos))
              (define shape (if (vector? shape+arity) (vector-ref shape+arity 0) shape+arity))
              (define shape-arity (and (vector? shape+arity) (vector-ref shape+arity 1)))
              (define static? (is-static-context? #'dot-op))
              (cond
                [(pair? shape)
                 ;; a property
                 (syntax-parse #'tail
                   [assign::assign-op-seq
                    (define-values (assign-call assign-empty-tail)
                      (parse-function-call impl (list #'id #'v) #'(method-id (parens))
                                           #:static? static?
                                           #:rator-stx #'head
                                           #:rator-kind 'property
                                           #:rator-arity shape-arity))
                    (define-values (assign-expr tail) (build-assign
                                                       (attribute assign.op)
                                                       #'assign.name
                                                       #`(lambda () (#,impl obj))
                                                       #`(lambda (v) #,assign-call)
                                                       #'obj
                                                       #'assign.tail))
                    (values #`(let ([obj id])
                                #,assign-expr)
                            tail)]
                   [_
                    (define-values (call new-tail)
                      (parse-function-call impl (list #'id) #'(method-id (parens))
                                           #:static? static?
                                           #:rator-stx #'head
                                           #:rator-kind 'property
                                           #:rator-arity shape-arity))
                    (values call
                            #'tail)])]
                [else
                 ;; a method
                 (syntax-parse #'tail
                   [((~and args (tag::parens arg ...)) . tail)
                    (define-values (call new-tail)
                      (parse-function-call impl (list #'id) #'(method-id args)
                                           #:static? static?
                                           #:rator-stx #'head
                                           #:rator-kind 'method
                                           #:rator-arity shape-arity))
                    (values call #'tail)])])])])]))))

(define-for-syntax (get-private-table desc)
  (define tables (get-private-tables))
  (or (for/or ([t (in-list tables)])
        (and (free-identifier=? (car t) (if (class-desc? desc)
                                            (class-desc-id desc)
                                            (interface-desc-id desc)))
             (cdr t)))
      #hasheq()))

(define-for-syntax (make-field-syntax id static-infos accessor-id maybe-mutator-id)
  (expression-transformer
   (lambda (stx)
     (syntax-parse stx
       [(head . tail)
        #:when (syntax-e maybe-mutator-id)
        #:with assign::assign-op-seq #'tail
        (syntax-parse (syntax-parameter-value #'this-id)
          [(obj-id . _)
           (build-assign (attribute assign.op)
                         #'assign.name
                         #`(lambda () (#,accessor-id obj-id))
                         #`(lambda (v) (#,maybe-mutator-id obj-id v))
                         #'id
                         #'assign.tail)])]
       [(head . tail)
        (syntax-parse (syntax-parameter-value #'this-id)
          [(id . _)
           (values (wrap-static-info* (datum->syntax #'here
                                                     (list accessor-id #'id)
                                                     #'head
                                                     #'head)
                                      static-infos)
                   #'tail)])]))))

(define-for-syntax (make-method-syntax id index/id result-id kind methods-ref-id)
  (define (add-method-result call r)
    (if r
        (wrap-static-info* call (method-result-static-infos r))
        call))
  (cond
    [(eq? kind 'property)
     (expression-transformer
      (lambda (stx)
        (syntax-parse (syntax-parameter-value #'this-id)
          [(obj-id . _)
           (define rator (if (identifier? index/id)
                             index/id
                             #`(vector-ref (#,methods-ref-id obj-id) #,index/id)))
           (syntax-parse stx
             [(head . tail)
              #:with assign::assign-op-seq #'tail
              (define r (and (syntax-e result-id)
                             (syntax-local-method-result result-id)))
              (when (and r (eqv? 2 (method-result-arity r)))
                (raise-syntax-error #f
                                    (string-append "property does not support assignment" statically-str)
                                    id))
              (build-assign (attribute assign.op)
                            #'assign.name
                            #`(lambda () (#,rator obj-id))
                            #`(lambda (v) (#,rator obj-id v))
                            #'id
                            #'assign.tail)]
             [(head . tail)
              (define call (relocate+reraw #'head #`(#,rator obj-id)))
              (define r (and (syntax-e result-id)
                             (syntax-local-method-result result-id)))
              (values (add-method-result call r)
                      #'tail)])])))]
    [else
     (expression-transformer
      (lambda (stx)
        (syntax-parse stx
          [(head (~and args (tag::parens arg ...)) . tail)
           (syntax-parse (syntax-parameter-value #'this-id)
             [(id . _)
              (define rator (if (identifier? index/id)
                                index/id
                                #`(vector-ref (#,methods-ref-id id) #,index/id)))
              (define r (and (syntax-e result-id)
                             (syntax-local-method-result result-id)))
              (define-values (call new-tail)
                (parse-function-call rator (list #'id) #'(head args)
                                     #:static? (is-static-context? #'tag)
                                     #:rator-stx #'head
                                     #:rator-arity (and r (method-result-arity r))
                                     #:rator-kind 'method))
              (define wrapped-call (add-method-result call r))
              (values wrapped-call #'tail)])]
          [(head . _)
           (raise-syntax-error #f
                               (string-append "method must be called" statically-str)
                               #'head)])))]))
    

(define-for-syntax (build-methods method-results
                                  added-methods method-mindex method-names method-private
                                  reconstructor-rhs reconstructor-stx-params
                                  names)
  (with-syntax ([(name name-instance name? reconstructor-name
                       methods-ref
                       indirect-static-infos
                       [field-name ...]
                       [field-static-infos ...]
                       [name-field ...]
                       [maybe-set-name-field! ...]
                       [private-field-name ...]
                       [private-field-desc ...]
                       [super-name ...]
                       [(recon-field-accessor recon-field-rhs) ...])
                 names])
    (with-syntax ([(field-name ...) (for/list ([id/l (in-list (syntax->list #'(field-name ...)))])
                                      (if (identifier? id/l)
                                          (datum->syntax #'name (syntax-e id/l) id/l id/l)
                                          (car (syntax-e id/l))))]
                  [((method-name method-index/id method-result-id method-kind) ...)
                   (for/list ([i (in-range (hash-count method-mindex))])
                     (define raw-m-name (hash-ref method-names i))
                     (define m-name (if (syntax? raw-m-name)
                                        (syntax-e raw-m-name)
                                        raw-m-name))
                     (define mix (hash-ref method-mindex m-name))
                     ;; We use `raw-m-name` to support local references
                     ;; to macro-introduced methods
                     (list (datum->syntax #'name raw-m-name)
                           (mindex-index mix)
                           (let ([r (hash-ref method-results m-name #f)])
                             (and (pair? r) (car r)))
                           (if (mindex-property? mix) 'property 'method)))]
                  [((private-method-name private-method-id private-method-id/property private-method-result-id private-method-kind) ...)
                   (for/list ([m-name (in-list (sort (hash-keys method-private)
                                                     symbol<?))])
                     (define id/property (hash-ref method-private m-name))
                     (define id (if (pair? id/property) (car id/property) id/property))
                     (define raw-m-name (or (syntax-property id 'lhs-id) m-name))
                     ;; See above for explanation of `raw-m-name`
                     (list (datum->syntax #'name raw-m-name)
                           id
                           id/property
                           (let ([r (hash-ref method-results m-name #f)])
                             (and (pair? r) (car r)))
                           (if (pair? id/property) 'property 'method)))])
      (list
       #`(define-values (#,@(for/list ([added (in-list added-methods)]
                                       #:when (not (eq? 'abstract (added-method-body added))))
                              (added-method-rhs-id added))
                         #,@(if (and (syntax-e #'reconstructor-name)
                                     (not (eq? reconstructor-rhs 'default)))
                                (list #'reconstructor-name)
                                null)
                         #,@(for/list ([acc (in-list (syntax->list #'(recon-field-accessor ...)))]
                                       [rhs (in-list (syntax->list #'(recon-field-rhs ...)))]
                                       #:when (syntax-e rhs))
                              acc))
           (let ()
             (define-syntax field-name (make-field-syntax (quote-syntax field-name)
                                                          (quote-syntax field-static-infos)
                                                          (quote-syntax name-field)
                                                          (quote-syntax maybe-set-name-field!)))
             ...
             (define-syntax method-name (make-method-syntax (quote-syntax method-name)
                                                            (quote-syntax method-index/id)
                                                            (quote-syntax method-result-id)
                                                            (quote method-kind)
                                                            (quote-syntax methods-ref)))
             ...
             (define-syntax private-method-name (make-method-syntax (quote-syntax private-method-name)
                                                                    (quote-syntax private-method-id)
                                                                    (quote-syntax private-method-result-id)
                                                                    (quote private-method-kind)
                                                                    (quote-syntax methods-ref)))
             ...
             (define-syntax new-private-tables (cons (cons (quote-syntax name)
                                                           (hasheq (~@ 'private-method-name
                                                                       (quote-syntax private-method-id/property))
                                                                   ...
                                                                   (~@ 'private-field-name
                                                                       private-field-desc)
                                                                   ...))
                                                     (get-private-tables)))
             #,@(for/list ([added (in-list added-methods)]
                           #:when (eq? 'abstract (added-method-body added))
                           #:when (syntax-e (added-method-rhs added)))
                  #`(void (rhombus-expression #,(syntax-parse (added-method-rhs added)
                                                  [(_ rhs) #'rhs]))))
             (values
              #,@(for/list ([added (in-list added-methods)]
                            #:when (not (eq? 'abstract (added-method-body added))))
                   (define r (hash-ref method-results (syntax-e (added-method-id added)) #f))
                   #`(let ([#,(added-method-id added) (method-block #,(added-method-rhs added) #,(added-method-stx-params added)
                                                                    name name-instance name?
                                                                    #,(and r (car r)) #,(added-method-id added)
                                                                    new-private-tables
                                                                    indirect-static-infos
                                                                    [super-name ...]
                                                                    #,(added-method-kind added))])
                       #,(added-method-id added)))
              #,@(if (and (syntax-e #'reconstructor-name)
                          (not (eq? reconstructor-rhs 'default)))
                     (list
                      #`(method-block (block #,reconstructor-rhs) #,reconstructor-stx-params
                                      name name-instance #f
                                      #f reconstructor
                                      new-private-tables
                                      indirect-static-infos
                                      ()
                                      reconstructor))
                     null)
              #,@(for/list ([acc (in-list (syntax->list #'(recon-field-accessor ...)))]
                            [rhs (in-list (syntax->list #'(recon-field-rhs ...)))]
                            #:when (syntax-e rhs))
                   #`(method-block (block #,rhs) #f ;; FIXME
                                   name name-instance #f
                                   #f acc
                                   new-private-tables
                                   indirect-static-infos
                                   ()
                                   reconstructor_field)))))))))

(define-syntax (method-block stx)
  (syntax-parse stx
    #:datum-literals (block)
    [(_ (block expr) stx-params
        name name-instance name?
        result-id method-name
        private-tables-id
        indirect-static-infos
        super-names
        kind)
     (define result-desc
       (cond
         [(not (syntax-e #'result-id)) #f]
         [else (syntax-local-method-result #'result-id)]))
     (with-continuation-mark
      syntax-parameters-key #'stx-params
      (syntax-parse #'expr
        [(~var e (:entry-point (entry-point-adjustment
                                (list #'this-obj)
                                (lambda (arity stx)
                                  #`(parsed
                                     #:rhombus/expr
                                     (syntax-parameterize ([this-id (quote-syntax (this-obj name-instance indirect-static-infos
                                                                                            . super-names))]
                                                           [private-tables (quote-syntax private-tables-id)])
                                       ;; This check might be redundant, depending on how the method was called
                                       #,(if (syntax-e #'name?)
                                             #`(unless (name? this-obj) (raise-not-an-instance 'method-name this-obj))
                                             #'(void))
                                       #,(let ([body #`(with-syntax-parameters
                                                         stx-params
                                                         (let ()
                                                           #,(wrap-expression stx)))])
                                           (cond
                                             [(and (eq? (syntax-e #'kind) 'property)
                                                   (eqv? arity 2)) ; mask 2 => 1 argument
                                              #`(begin #,body (void))]
                                             [(and result-desc
                                                   (method-result-handler-expr result-desc))
                                              (if (method-result-predicate? result-desc)
                                                  #`(let ([result #,body])
                                                      (unless (#,(method-result-handler-expr result-desc) result)
                                                        (raise-result-failure 'method-name
                                                                              result
                                                                              '#,(method-result-annot-str result-desc)))
                                                      result)
                                                  #`(let ([result #,body])
                                                      (#,(method-result-handler-expr result-desc)
                                                       result
                                                       (lambda ()
                                                         (raise-result-failure 'method-name
                                                                               result
                                                                               '#,(method-result-annot-str result-desc))))))]
                                             [else body])))))
                                #t)))
         #'e.parsed]))]))
