#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@title{Block}

@doc(
  expr.macro 'block:
                $body
                ...'
){

 Returns the result of the @rhombus(body) block, which may include local
 definitions.

@examples(
  block:
    1
    2

  block:
    let one = 1
    one + one
)

}
