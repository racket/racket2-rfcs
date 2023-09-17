#lang scribble/rhombus/manual
@(import: "common.rhm" open
          "nonterminal.rhm" open)

@(def dots: @rhombus(..., ~bind))
@(def dots_expr: @rhombus(...))

@title{Lists}

@deftech{Lists} can be constructed using the syntax
@rhombus([#,(@rhombus(expr, ~var)), ...]), which creates list containing the values of the
@rhombus(expr, ~var)s as elements. More precisely, a use of square
brackets without a preceding expression implicitly uses the
@rhombus(#%brackets) form, which (despite its name) is normally bound to
construct a list.

A list is @tech{indexable} using @brackets to access a list
element by position (in time proportional to the position) via
@rhombus(#%index). A list also works with the @rhombus(++) operator
to append lists. A list can be used as @tech{sequence}, in which case
it supplies its elements in order.

@dispatch_table(
  "list"
  @rhombus(List)
  [lst.length(), List.length(lst)]
  [lst.first, List.first(lst)]
  [lst.rest, List.rest(lst)]
  [lst.reverse(), List.reverse(lst)]
  [lst.append(lst2, ...), List.append(lst, lst2, ...)]
  [list.drop_left(lst, n), List.drop_left(lst, n)]
  [list.drop_right(lst, n), List.drop_right(lst, n)]
  [list.has_element(lst, v), List.has_element(lst, v)]
  [list.remove(lst, v), List.remove(lst, v)]
  [lst.map(func), List.map(lst, func)]
  [lst.for_each(func), List.for_each(lst, func)]
  [lst.sort(arg, ...), List.sort(lst, arg, ...)]
)

@doc(
  annot.macro 'List'
  annot.macro 'List.of($annot)'
){

 Matches any list in the form without @rhombus(of). The @rhombus(of)
 variant matches a list whose elements satisfy @rhombus(annot).

 Static information associated by @rhombus(List, ~annot) or
 @rhombus(List.of, ~annot) makes an expression acceptable as a sequence
 to @rhombus(for) in static mode.

}

@doc(
  ~nonterminal:
    list_expr: block expr
  fun List(v :: Any, ...) :: List
  expr.macro '#%brackets [$expr_or_splice, ...]'
  repet.macro '#%brackets [$repet_or_splice, ...]'

  grammar expr_or_splice:
    $expr
    $repet #,(@litchar{,}) $ellipses
    & $list_expr

  grammar ellipses:
    $ellipsis
    $ellipses #,(@litchar{,}) ellipsis

  grammar ellipsis:
    #,(dots_expr)

){

 Constructs a list of the given @rhombus(v)s values or results of the
 @rhombus(expr_or_splice)s. A @rhombus(&) or @dots_expr form
 can appear within @brackets to splice a @tech{repetition} or existing list
 into the constructed list, the same as in a function call (see
 @rhombus(#%call)). List constructions can also serve as
 repetitions, where @rhombus(repet_or_splice) is like
 @rhombus(expr_or_splice), but with repetitions in place of expressions.

 @see_implicit(@rhombus(#%brackets), @brackets, "expression")

@examples(
  def lst = List(1, 2, 3)
  lst
  lst[0]
  lst ++ [4, 5]
  #%brackets [1, 2, 3]
)

}

@doc(
  ~nonterminal:
    list_bind: def bind ~defn
    repet_bind: def bind ~defn
  bind.macro 'List($bind, ...)'
  bind.macro 'List($bind, ..., $rest)'
  bind.macro '#%brackets [$bind, ...]'
  bind.macro '#%brackets [$bind, ..., $rest]'
  grammar rest:
    $repet_bind #,(@litchar{,}) $ellipsis
    & $list_bind
  grammar ellipsis:
    #,(dots)
){

 Matches a list with as many elements as @rhombus(bind)s, or if
 @rhombus(rest) is included, at least as many elements as
 @rhombus(bind)s, where the @rhombus(rest) (if present) matches the
 rest of the list.

 When @rhombus(& list_bind) is used, the rest of the list must match
 the @rhombus(list_bind). Static information associated by
 @rhombus(List) is propagated to @rhombus(list_bind).

 When @rhombus(repet_bind) is used and does not impose a predicate or
 conversion on a matching value (e.g., @rhombus(repet_bind) is an
 identifier), then the corresponding elements of a matching value are not
 traversed, which means that matching can be constant-time. Using this
 repetition for the tail a new list similarly avoids traversing the
 elements.

 @see_implicit(@rhombus(#%brackets, ~bind), @brackets, "binding")

@examples(
  def List(1, x, y): [1, 2, 3]
  y
  def [1, also_x, also_y]: [1, 2, 3]
  also_y
  def List(1, & xs): [1, 2, 3]
  xs
  def List(1, x, ...): [1, 2, 3]
  [x, ...]
)

}

@doc(
  annot.macro 'NonemptyList'
  annot.macro 'NonemptyList.of($annot)'
){

 Like @rhombus(List, ~annot) as an annotation, but matches only non-empty
 lists.

@examples(
  [1] :: NonemptyList
  ~error: [] :: NonemptyList
)

}

@doc(
  reducer.macro 'List'
){

 A @tech{reducer} used with @rhombus(for), accumulates each result of a
 @rhombus(for) body into a result list.

}

@doc(
  fun List.cons(elem :: Any, lst :: List) :: List
){

 Creates a list like @rhombus(lst), but with @rhombus(elem) added to
 the front.

@examples(
  List.cons(1, [2, 3])
)

}

@doc(
  ~nonterminal:
    list_bind: def bind ~defn
    elem_bind: def bind ~defn
  bind.macro 'List.cons($elem_bind, $list_bind)'
){

 Matches a non-empty list where @rhombus(elem_bind) matches the
 first element of the list and @rhombus(list_bind) matches the
 rest of the list. Static information associated by @rhombus(List) is
 propagated to @rhombus(list_bind).

@examples(
  def List.cons(x, y): [1, 2, 3]
  x
  y
)

}


@doc(
  def List.empty :: []
  bind.macro 'List.empty'
){

  A name and pattern for the empty list.

}


@doc(
  fun List.first(lst :: NonemptyList)
){

 Returns the first element of @rhombus(lst).

@examples(
  List.first(["a", "b", "c"])
)

}

@doc(
  fun List.rest(lst :: NonemptyList) :: List
){

 Returns a list like @rhombus(lst), but without its first element.

@examples(
  List.rest(["a", "b", "c"])
)

}

@doc(
  fun List.length(lst :: List) :: NonnegInt
){

 Returns the number of items in @rhombus(lst).

@examples(
  List.length([1, 4, 8])
  List.length([])
  [1, 4, 8].length
)

}


@doc(
  fun List.reverse(lst :: List) :: List
){

 Returns a list with the same items as @rhombus(lst). but in reversed
 order.

@examples(
  List.reverse([1, 4, 8])
  [1, 4, 8].reverse
)

}


@doc(
  fun List.append(lst :: List, ...) :: List
){

 Appends the @rhombus(lst)s in order. See also @rhombus(++).

@examples(
  List.append([1, 2, 3], [4, 5], [6])
  [1, 2, 3].append([4, 5], [6])
)

}


@doc(
  fun List.drop_left(lst :: List, n :: NonnegInt) :: List
  fun List.drop_right(lst :: List, n :: NonnegInt) :: List
){

 Returns a list like @rhombus(lst), but without the first @rhombus(n)
 elements in the case of @rhombus(List.drop_left), or without the last
 @rhombus(n) elements in the case of @rhombus(List.drop_right). The given
 @rhombus(lst) must have at least @rhombus(n) elements, otherwise an
 @rhombus(Exn.Fail.Contract, ~class) exception is raised.

@examples(
  [1, 2, 3, 4, 5].drop_left(2)
  [1, 2, 3, 4, 5].drop_right(2)
  ~error:
    [1].drop_left(2)
)

}


@doc(
  fun List.has_element(lst :: List, v) :: List
){

 Returns @rhombus(#true) if @rhombus(lst) has an element equal to
 @rhombus(v), @rhombus(#false) otherwise.

@examples(
  [1, 2, 3].has_element(2)
  [1, 2, 3].has_element(200)
)

}


@doc(
  fun List.remove(lst :: List, v) :: List
){

 Returns a list like @rhombus(lst), but with the first element equal to
 @rhombus(v) (if any) removed.

@examples(
  [1, 2, 3, 2].remove(2)
)

}

@doc(
  fun List.map(lst :: List, f :: Function.of_arity(1)) :: List,
  fun List.for_each(lst :: List, f :: Function.of_arity(1)) :: List,
){

 Like @rhombus(Function.map) and @rhombus(Function.for_each), but with a
 single list of arguments first, with the function supplied second.

@examples(
  List.map([1, 2, 3], fun (x): x + 1)
  [1, 2, 3].map(fun (x): x + 1)
  [1, 2, 3].for_each(println)
)

}


@doc(
  fun List.sort(lst :: List, less :: Function.of_arity(2) = math.less) :: List,
){

 Sorts @rhombus(lst) using @rhombus(less) to compare elements.

@examples(
  List.sort([1, 3, 2])
  List.sort([1, 3, 2], math.greater)
)

}


@doc(
  fun List.iota(n :: NonnegInt) :: List.of(NonnegInt)
){

 Returns a list containing the integers 0 to @rhombus(n) (exclusive) in
 order.

@examples(
  List.iota(3)
  List.iota(0)
)

}
