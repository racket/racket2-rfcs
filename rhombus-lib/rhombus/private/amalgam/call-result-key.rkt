#lang racket/base
(require (for-syntax racket/base)
         "static-info.rkt")

(define-static-info-key-syntax/provide #%call-result
  (static-info-key static-infos-result-or
                   static-infos-result-and))
