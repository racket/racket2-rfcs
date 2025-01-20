#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@title{Booleans}

@doc(
  annot.macro 'Boolean'
){

  Matches @rhombus(#true) or @rhombus(#false).

}

@doc(
  annot.macro 'False'
  annot.macro 'True'
){

  Matches only @rhombus(#false) and values other than @rhombus(#false), respectively.

@examples(
  #false is_a False
  #false is_a True
  42 is_a True
)

}


@doc(
  ~nonterminal:
    left_expr: block expr
    right_expr: block expr
    left_repet: block repet
    right_repet: block repet
  expr.macro '$left_expr || $right_expr'
  repet.macro '$left_repet || $right_repet'
  operator_order:
    ~order: logical_disjunction
){

 Produces the value of @rhombus(left_expr) if it is
 non-@rhombus(#false), otherwise produces the value(s) of
 @rhombus(right_expr). The @rhombus(right_expr) is evaluated in tail
 position with respect to the @rhombus(||) form, if evaluated at all.

 The @rhombus(||) form can also serve as @tech{repetitions}.

}

@doc(
  ~nonterminal:
    left_bind: def bind ~defn
    right_bind: def bind ~defn
  bind.macro '$left_bind || $right_bind'
  operator_order:
    ~order: logical_disjunction
){

 Matches if either @rhombus(left_bind) or @rhombus(right_bind) matches.
 No identifiers are bound after a successful match, however. In other
 words, @rhombus(left_bind) and @rhombus(right_bind) are used only in
 matching mode, and implied conversions might be skipped.

@examples(
  fun check_shape(v):
    match v
    | [x] || [x, y, z]: #true
    | ~else: #false
  check_shape([1])
  check_shape([1, 2, 3])
  check_shape([1, 2])
)

}

@doc(
  ~nonterminal:
    left_annot: :: annot
    right_annot: :: annot
  annot.macro '$left_annot || $right_annot'
  operator_order:
    ~order: logical_disjunction
){

 Creates an annotation that accepts a value satisfying either
 @rhombus(left_annot) or @rhombus(right_annot). The static information
 implied by the annotation is the intersection of information for
 @rhombus(left_annot) and @rhombus(right_annot).

 The annotations are checked in other. Either or both of
 @rhombus(left_annot) and @rhombus(right_annot) can be a @tech(~doc: guide_doc){converter
  annotation}, in which case the conversion result of the first satisfied
 annotation is used.

@examples(
  1 is_a (String || Int)
  1 is_a (Boolean || Int)
)

}

@doc(
  ~nonterminal:
    ellipses: List
  reducer.macro 'any'
  expr.macro 'any($expr_or_splice, ...)'
  grammar expr_or_splice:
    $expr
    $repet #,(@litchar{,}) $ellipses
){

 The @rhombus(any, ~reducer) form as a @tech(~doc: guide_doc){reducer} is like
 @rhombus(||): it stops an iteration as soon as a non-@rhombus(#false)
 value is produced for an element and it returns that value, otherwise it
 returns @rhombus(#false).

@examples(
  for any (i in 0..10):
    i == 5 && to_string(i)
  for any (i in 0..10):
    i == 10
)

 The @rhombus(any) expression form is like @rhombus(||), but
 @rhombus(any) supports repetition arguments, and it stops iterating
 through a repetition as soon as a non-@rhombus(#false) result is found.
 When the last @rhombus(expr_or_splice) is an @nontermref(expr), it is in
 tail position.

@examples(
  def [x, ...] = [1, 2, 3, 4]
  any(x > 2 && x, ...)
)

}


@doc(
  ~nonterminal:
    left_expr: block expr
    right_expr: block expr
    left_repet: block repet
    right_repet: block repet
  expr.macro '$left_expr && $right_expr'
  repet.macro '$left_repet && $right_repet'
  operator_order:
    ~order: logical_conjunction
){

 Produces @rhombus(#false) if the value of @rhombus(left_expr) is
 @rhombus(#false), otherwise produces the value(s) of
 @rhombus(right_expr). The @rhombus(right_expr) is evaluated in tail
 position with respect to the @rhombus(&&) form, if evaluated at all.

 The @rhombus(&&) form can also serve as @tech{repetitions}.

}

@doc(
  ~nonterminal:
    left_bind: def bind ~defn
    right_bind: def bind ~defn
  bind.macro '$left_bind && $right_bind'
  operator_order:
    ~order: logical_conjunction
){

 Matches when both @rhombus(left_bind) and @rhombus(right_bind) match.
 All identifiers from bindings are available after the match, and
 static information from @rhombus(left_bind) is propagated to
 @rhombus(right_bind) (but not the other way around).

 See @rhombus(where, ~bind) for a different kind of ``and'' binding that
 allows the right-hand side to refer to bindings from the left-hand side.

@examples(
  class Posn(x, y)
  fun three_xs(v):
    match v
    | [_, _, _] && [Posn(x, _), ...]: [x, ...]
    | ~else: #false
  three_xs([Posn(1, 2), Posn(3, 4), Posn(5, 6)])
  three_xs([Posn(1, 2), Posn(3, 4)])
  three_xs([Posn(1, 2), Posn(3, 4), "no"])
)

}


@doc(
  ~nonterminal:
    left_annot: :: annot
    right_annot: :: annot
  annot.macro '$left_annot && $right_annot'
  operator_order:
    ~order: logical_conjunction
){

 Creates an annotation that accepts a value satisfying both
 @rhombus(left_annot) and @rhombus(right_annot).

 When @rhombus(left_annot) and @rhombus(right_annot) are
 @tech(~doc: guide_doc){predicate annotations}, the static information
 implied by the annotation is the union of information for
 @rhombus(left_annot) and @rhombus(right_annot), where information
 from @rhombus(right_annot) takes precedence in cases where both
 supply values for the same static-information key.

 If @rhombus(left_annot) or @rhombus(right_annot) is a
 @tech(~doc: guide_doc){converter annotation}, the @rhombus(left_annot) conversion
 is applied first, and its result is the input to @rhombus(right_annot),
 and the result of @rhombus(right_annot) is the result for the
 for the overall annotation created by @rhombus(&&, ~annot).
 When the overall annotation is used only for matching, the conversion
 part of @rhombus(right_annot) is skipped, but the conversion part of
 @rhombus(left_annot) must be performed.

@examples(
  1 is_a (String && Int)
  Pair(1, "hello") is_a (Pair.of(Int, Any) && Pair.of(Any, String))
  1 :: (converting(fun (n): n+1) && converting(fun (n): -n))
)

}


@doc(
  ~nonterminal:
    expr_or_splice: any ~reducer
  reducer.macro 'all'
  expr.macro 'all($expr_or_splice, ...)'
){

 The @rhombus(all, ~reducer) form as a @tech(~doc: guide_doc){reducer} is like
 @rhombus(&&): it stops an iteration as soon as a @rhombus(#false) value
 is produced for an element, and it otherwise returns the result of the
 last iteration.

@examples(
  for all (i in 0..10):
    i == 5
  for all (i in 0..10):
    i < 10 && to_string(i)
)

 The @rhombus(all) expression form is like @rhombus(&&), but
 @rhombus(all) supports repetition arguments, and it stops iterating
 through a repetition as soon as a @rhombus(#false) result is found. When
 the last @rhombus(expr_or_splice) is a @nontermref(expr), it is in tail
 position.

@examples(
  def [x, ...] = [1, 2, 3, 4]
  all(x < 2, ...)
)

}


@doc(
  operator (! (v :: Any)) :: Boolean
  operator_order:
    ~order: logical_negation
  expr.macro '$expr !in $expr'
  expr.macro '$expr !is_now $expr'
  expr.macro '$expr !is_a $annot'
  operator_order:
    ~order: equivalence
){

 The prefix @rhombus(!) operator produces @rhombus(#true) if @rhombus(v)
 is @rhombus(#false), @rhombus(#false) otherwise.

 As an infix operator, @rhombus(!) modifies @rhombus(in),
 @rhombus(is_now), or @rhombus(is_a). Any other infix use of @rhombus(!)
 is an error.

@examples(
  !#false
  !#true
  !"false"
  1 !in [0, 2, 4]
)

}

@doc(
  bind.macro '! $bind'
  operator_order:
    ~order: logical_negation
){

 Matches if @rhombus(bind) does not match. Because @rhombus(bind) does
 not match, no identifiers are bound.

@examples(
  fun
  | is_two_list(![x, y]): #false
  | is_two_list(_): #true
  is_two_list([1])
  is_two_list([1, 2])
  is_two_list([1, 2, 3])
)

}

@doc(
  annot.macro '! $annot'
  operator_order:
    ~order: logical_negation
){

 Creates an annotation that accepts a value not satisfying
 @rhombus(annot). Because @rhombus(annot) is not satisfied, no
 conversion is performed.

@examples(
  [1, 2, 3] is_a !List
  PairList[1, 2, 3] is_a !List
)

}
