#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     enforest
                     enforest/operator
                     enforest/property
                     enforest/proc-name
                     enforest/name-root
                     enforest/name-parse
                     "srcloc.rkt"
                     "introducer.rkt"
                     "name-path-op.rkt"
                     "macro-result.rkt"
                     "module-path-parse.rkt")
         "provide.rkt"
         (only-in "implicit.rkt"
                  #%literal)
         (only-in "arithmetic.rkt"
                  [/ rhombus/])
         "name-root.rkt")

;; The syntax of module paths is not meant to be extensible, but it
;; may be useful to expose `:module-path` parsing. For imports, we
;; bind module-path operators in the same space as import operators,
;; so that they can be mixed more freely. For exports, we distinguish
;; module paths and export operators.

(provide (for-space rhombus/modpath
                    #%literal
                    (rename-out [rhombus/ /]
                                [rhombus-! !]
                                [rhombus-self self]
                                [rhombus-parent parent]
                                [rhombus-file file]
                                [rhombus-lib lib]
                                [rhombus. |.|])))

(module+ for-import-export
  (provide (for-syntax make-module-path-literal-operator
                       make-module-path-/-operator
                       make-module-path-file-operator
                       make-module-path-lib-operator
                       make-module-path-submod-operator
                       make-module-path-submod-same-operator
                       make-module-path-submod-up-operator

                       :module-path

                       current-module-path-context

                       convert-symbol-module-path)))

(module+ for-meta
  (provide (for-syntax in-module-path-space)
           (for-space rhombus/namespace
                      modpath)))

(begin-for-syntax
  (property module-path-prefix-operator prefix-operator)
  (property module-path-infix-operator infix-operator)

  (define in-module-path-space (make-interned-syntax-introducer/add 'rhombus/modpath))

  (define current-module-path-context (make-parameter 'import))

  (define (check-module-path-result form proc)
    (unless (and (syntax? form)
                 (module-path? (syntax->datum form)))
      (raise-bad-macro-result (proc-name proc) "module path" form))
    form)

  (define (make-identifier-module-path id)
    (unless (module-path? (syntax-e id))
      (raise-syntax-error (current-module-path-context)
                          "not a valid module path element"
                          id))
    id)

  (define-enforest
    #:syntax-class :module-path
    #:desc "module path"
    #:operator-desc "module-path operator"
    #:in-space in-module-path-space
    #:name-path-op #f
    #:prefix-operator-ref module-path-prefix-operator-ref
    #:infix-operator-ref module-path-infix-operator-ref
    #:check-result check-module-path-result
    #:make-identifier-form make-identifier-module-path))

(define-for-syntax (convert-symbol-module-path mp)
  (cond
    [(identifier? mp)
     (define name (module-symbol-to-lib-string (syntax-e mp)))
     (datum->syntax mp `(,#'lib ,name) mp mp)]
    [else mp]))

(define-syntax (define-module-path-syntax stx)
  (syntax-parse stx
    [(_ name:id rhs)
     (quasisyntax/loc stx
       (define-syntax #,(in-module-path-space #'name) rhs))]))

(define-for-syntax (make-module-path-literal-operator prefix-operator)
  (prefix-operator
   #'%literal
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       [(_ a . tail)
        (define d (syntax->datum #'a))
        (unless (and (module-path? d)
                     (not (equal? d "."))
                     (not (equal? d "..")))
          (raise-syntax-error (current-module-path-context)
                              "not a valid module path"
                              #'a))
        (values #'a
                #'tail)]))))

(define-module-path-syntax #%literal
  (make-module-path-literal-operator module-path-prefix-operator))

(define-for-syntax (make-module-path-/-operator infix-operator)
  (infix-operator
   #'rhombus/
   '((default . stronger))
   'macro
   (lambda (form1 stx)
     (unless (identifier? form1)
       (raise-syntax-error (current-module-path-context)
                           "not a valid module path element"
                           form1))
     (syntax-parse stx
       [(_ a . tail)
        (unless (and (identifier? #'a)
                     (module-path? (syntax->datum #'a)))
          (raise-syntax-error (current-module-path-context)
                              "not a valid module path element"
                              #'a))
        (values (datum->syntax #'a
                               (string->symbol
                                (format "~a/~a"
                                        (syntax-e form1)
                                        (syntax-e #'a)))
                               (span-srcloc form1 #'a)
                               #'a)
                #'tail)]))
   'left))

(define-module-path-syntax rhombus/
  (make-module-path-/-operator module-path-infix-operator))

(define-for-syntax (make-module-path-string-arg-operator prefix-operator name mp-form-id check)
  (prefix-operator
   name
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals (parens group)
       [(form-id ((~and tag parens) (group str:string)) . tail)
        (define new-str (check #'str))
        (values (datum->syntax #'str
                               (list mp-form-id new-str)
                               (span-srcloc #'form-id #'tag)
                               #'form-id)
                #'tail)]))))

(define-for-syntax (make-module-path-file-operator prefix-operator)
  (make-module-path-string-arg-operator
   prefix-operator #'rhombus-file #'file
   (lambda (str)
     (unless (path-string? (syntax->datum str))
       (raise-syntax-error (current-module-path-context)
                           "not a valid path"
                           str))
     str)))

(define-module-path-syntax rhombus-file
  (make-module-path-file-operator module-path-prefix-operator))

(define-for-syntax (make-module-path-lib-operator prefix-operator)
  (make-module-path-string-arg-operator
   prefix-operator #'rhombus-lib #'lib
   (lambda (str)
     (define new-str (module-lib-string-to-lib-string (syntax-e str)))
     (unless new-str
       (raise-syntax-error (current-module-path-context)
                           "not a valid library path"
                           str))
     new-str)))

(define-module-path-syntax rhombus-lib
  (make-module-path-lib-operator module-path-prefix-operator))

(define-for-syntax (make-module-path-submod-operator infix-operator)
  (infix-operator
   (in-module-path-space #'rhombus-!)
   '((default . stronger))
   'macro
   (lambda (mp stx)
     (unless (module-path? (syntax->datum mp))
       (raise-syntax-error (current-module-path-context)
                           "not a valid submodule prefix"
                           mp))
     (let ([mp (convert-symbol-module-path mp)])
       (syntax-parse stx
         #:datum-literals ()
         [(form-id id:identifier . tail)
          (values (datum->syntax #'id
                                 (syntax-parse mp
                                   #:datum-literals (submod)
                                   [(submod base path ...)
                                    (syntax->list #'(submod base path ... id))]
                                   [else
                                    (list #'submod mp #'id)])
                                 #'id
                                 #'id)
                  #'tail)])))
   'left))

(define-module-path-syntax rhombus-!
  (make-module-path-submod-operator module-path-infix-operator))

(begin-for-syntax
  (define-syntax-class :!
    #:description "submodule separator"
    #:opaque
    (pattern name::name
             #:when (free-identifier=? (in-module-path-space #'name.name) (in-module-path-space #'rhombus-!)))))

(define-for-syntax (make-module-path-submod-same-operator prefix-operator)
  (prefix-operator
   #'rhombus-self
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals ()
       [(form-id name::! id:identifier . tail)
        (values (datum->syntax #'id
                               (if (eq? 'top-level (syntax-local-context))
                                   (list #'quote #'id)
                                   (list #'submod "." #'id))
                               #'id
                               #'id)
                #'tail)]))))

(define-module-path-syntax rhombus-self
  (make-module-path-submod-same-operator module-path-prefix-operator))

(define-for-syntax (make-module-path-submod-up-operator prefix-operator)
  (prefix-operator
   #'rhombus-parent
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       #:datum-literals ()
       [(form-id name::! ...+ id:identifier . tail)
        (values (datum->syntax #'id
                               (append (list #'submod)
                                       (for/list ([name (in-list (syntax->list #'(name ...)))])
                                         "..")
                                       (list #'id))
                               #'id
                               #'id)
                #'tail)]
       [(form-id name::! ...+)
        (values (datum->syntax #'form-id
                               (append (list #'submod)
                                       (for/list ([name (in-list (syntax->list #'(name ...)))])
                                         ".."))
                               #'form-id
                               #'form-id)
                #'())]
       [(form-id  . tail)
        (values (datum->syntax #'form-id
                               (list #'submod "..")
                               #'form-id
                               #'form-id)
                #'tail)]))))

(define-module-path-syntax rhombus-parent
  (make-module-path-submod-up-operator module-path-prefix-operator))

;; Defines a fake meta namespace that would be exposed if we allowed
;; new module-path forms, needed to document the built-in ones
(define-name-root modpath
  #:fields ([macro modpath-macro]))
(define-syntax modpath-macro 'placeholder)

(define-module-path-syntax rhombus.
  (module-path-prefix-operator
   (in-module-path-space #'rhombus.)
   '((default . stronger))
   'macro
   (lambda (stx)
     (syntax-parse stx
       [(_ id:identifier . tail)
        (values #'(quote id)
                #'tail)]))))
