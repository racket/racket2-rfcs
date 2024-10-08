#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre
                     shrubbery/property
                     racket/syntax-srcloc)
         (only-in rhombus/private/name-root
                  portal-syntax->lookup
                  in-name-root-space))

(provide (for-syntax
          resolve-name-ref
          append-consecutive-syntax-objects))

(define-for-syntax (append-consecutive-syntax-objects datum pre t)
  (define pre-loc (syntax-srcloc pre))
  (define t-loc (syntax-srcloc t))
  (define t/s (if (and pre-loc
                       t-loc
                       (equal? (srcloc-source pre-loc)
                               (srcloc-source t-loc))
                       (srcloc-position t-loc)
                       (srcloc-span t-loc)
                       (srcloc-position pre-loc)
                       ((srcloc-position pre-loc) . < . (srcloc-position t-loc)))
                  (datum->syntax t
                                 datum
                                 (struct-copy srcloc pre-loc
                                              [span (- (+ (srcloc-position t-loc)
                                                          (srcloc-span t-loc))
                                                       (srcloc-position pre-loc))])
                                 t
                                 t)
                  t))
  (let* ([t/s (syntax-raw-prefix-property t/s (syntax-raw-prefix-property pre))]
         [t/s (syntax-raw-inner-prefix-property t/s (syntax-raw-inner-prefix-property pre))])
    t/s))

;; returns #f or (hash 'target target 'remains rest 'space space-name 'raw default-raw 'raw-prefix prefix-part-of-raw)
(define-for-syntax (resolve-name-ref space-names root fields
                                     #:parens [ptag #f]
                                     #:raw [given-raw #f])
  (let loop ([root root] [ns-root #f] [fields fields] [root-raw #f] [ns-raw-prefix #f])
    (cond
      [(null? fields) #f]
      [else
       (define field (car fields))
       (define p (identifier-binding-portal-syntax (in-name-root-space root) #f))
       (define is-import? (and p (syntax-parse p
                                   #:datum-literals (import)
                                   [([import . _] _ ctx) #t]
                                   [_ #f])))
       (define lookup (and p (portal-syntax->lookup p (lambda (self-id lookup) lookup) #f)))
       (define (make-intro space-name)
         (if space-name
             (make-interned-syntax-introducer space-name)
             (lambda (x) x)))
       (define dest+space-name
         (cond
           [(and (pair? space-names) (null? (cdr space-names)))
            (define space-name (car space-names))
            (define intro (make-intro space-name))
            (define dest (and lookup
                              (or (lookup #f "identifier" field intro)
                                  (and (pair? (cdr fields))
                                       (lookup #f "identifier" field in-name-root-space)))))
            (and dest (cons dest space-name))]
           [else
            (or
             (for/or ([space-name (in-list space-names)])
               (define intro (make-intro space-name))
               (define dest (and lookup (lookup #f "identifier" field intro)))
               (and dest
                    (or (not space-name)
                        (identifier-distinct-binding (intro dest) dest #f)
                        (identifier-distinct-binding (in-name-root-space dest) dest #f))
                    (cons dest space-name)))
             (and lookup
                  (pair? (cdr fields))
                  (let ([dest (lookup #f "identifier" field in-name-root-space)])
                    (and dest (cons dest 'rhombus/namespace)))))]))
       (define dest (and dest+space-name (car dest+space-name)))
       (define space-name (and dest+space-name (cdr dest+space-name)))
       (define parens? (and ptag (null? (cdr fields))))
       (define raw-prefix (format "~a."
                                  (or root-raw
                                      (syntax-raw-property root)
                                      (syntax-e root))))
       (define raw (format "~a~a~a~a"
                           (if is-import?
                               ""
                               raw-prefix)
                           (if parens? "(" "")
                           (syntax-e field)
                           (if parens? ")" "")))
       (define (transfer-parens-suffix p)
         (if parens?
             (syntax-raw-suffix-property p (cons
                                            (or (syntax-raw-suffix-property p) '())
                                            (syntax-raw-suffix-property ptag)))
             p))
       (define (add-rest p)
         (and p (hash 'target p
                      'remains (cdr fields)
                      'space space-name
                      'root (or ns-root
                                (and (not is-import?)
                                     root))
                      'raw raw
                      'raw-prefix (and (not given-raw)
                                       (or ns-raw-prefix
                                           (and is-import? raw-prefix))))))
       (define (next named-dest)
         (loop named-dest (or ns-root (and (not is-import?) root)) (cdr fields)
               raw (or (and is-import? raw-prefix) ns-raw-prefix)))
       (cond
         [dest
          (define loc-stx
            (append-consecutive-syntax-objects
             'loc-stx
             root
             field))
          (define named-dest
            (transfer-parens-suffix
             (syntax-raw-property (datum->syntax dest (syntax-e dest) loc-stx loc-stx)
                                  (or given-raw raw))))
          (or (next named-dest)
              (add-rest named-dest))]
         [else
          (define id ((make-intro space-name) (datum->syntax root (string->symbol raw))))
          (and (identifier-binding id #f)
               (let ([named-id (transfer-parens-suffix
                                (syntax-raw-property
                                 (datum->syntax id (syntax-e id)
                                                (append-consecutive-syntax-objects
                                                 'loc-stx
                                                 root
                                                 field))
                                 (or given-raw raw)))])
                 (or (next named-id)
                     (add-rest named-id))))])])))
