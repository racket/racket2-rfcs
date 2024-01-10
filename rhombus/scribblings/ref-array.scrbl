#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@(def dots = @rhombus(..., ~bind))

@title{Arrays}

An array is @tech{indexable} using @brackets to access an array element
by position (in constant time) via @rhombus(#%index). An array also
works with the @rhombus(++) operator to append arrays. An array can be
used as @tech{sequence}, in which case it supplies its elements in
order.

An array is normally mutable, but immutable arrays can originate from
Racket. The @rhombus(Array, ~annot) annotation is satisfied by both
mutable and immutable arrays, while @rhombus(MutableArray, ~annot) and
@rhombus(ImmutableArray, ~annot) require one or the other.

@dispatch_table(
  "array",
  @rhombus(Array),
  [arr.length(), Array.length(arr)]
  [arr.copy(arg, ...), Array.copy(arr, arg, ...)]
  [arr.copy_from(arg, ...), Array.copy_from(arr, arg, ...)]
  [arr.take_left(n), Array.take_left(arr, n)]
  [arr.take_right(n), Array.take_right(arr, n)]
  [arr.drop_left(n), Array.drop_left(arr, n)]
  [arr.drop_right(n), Array.drop_right(arr, n)]
  [arr.set_in_copy(i, v), Array.set_in_copy(arr, i, v)]
)

@doc(
  annot.macro 'Array'
  annot.macro 'Array.of_length($expr)'
  annot.macro 'Array.now_of($annot)'
  annot.macro 'Array.later_of($annot)'
  annot.macro 'MutableArray'
  annot.macro 'ImmutableArray'
){

 The @rhombus(Array, ~annot) annotation (without
 @rhombus(of_length, ~datum), @rhombus(now_of, ~datum), or
 @rhombus(later_of, ~datum)) matches any array. The
 @rhombus(Array.of_length, ~annot) annotation matches arrays of a
 given length.

 The @rhombus(Array.now_of, ~annot) form constructs a @tech{predicate
  annotation} that matches an array whose elements all currently satisfy
 @rhombus(annot), but it does not ensure in any way that future
 values installed into the array will satisfy @rhombus(annot). The given
 @rhombus(annot) must not be a converting annotation. Static
 information from @rhombus(annot) is not propagated to accesses of
 the array, since there's no gauarantee that the value will still satisfy
 the annotation.

 The @rhombus(Array.later_of, ~annot) form constructs a @tech{converter
  annotation} that immediately matches an array without checking
  that its elements currently satisfy @rhombus(annot). The conversion
 result of the annotation is a view of the original array, but one where
 @rhombus(annot) is checked against a value that would be returned by
 accessing an element of the array or a value to be installed into the
 array. (A different view of the array might changes an element to one that
 does not astisfy @rhombus(annot).) Static information from
 @rhombus(annot) is propagated to accesses of the array. Note that a
 converter @rhombus(annot) is applied for each access or update.

 @rhombus(MutableArray, ~annot) matches only mutable arrays, and
 @rhombus(ImmutableArray, ~annot) matches only immutable arrays (that may
 originate from Racket).

 Static information associated by @rhombus(Array, ~annot), etc., makes
 an expression acceptable as a sequence to @rhombus(for) in static mode.

@examples(
  ~repl:
    Array(1, 2, 3) :: Array
    Array(1, 2, 3) :: Array.of_length(3)
    ~error:
      Array(1, 2, 3) :: Array.of_length(5)
    Array(1, 2, 3) :: Array.now_of(Number)
    ~error:
      Array(1, "b", 3) :: Array.now_of(Number)
  ~defn:
    def a :: Array.later_of(Number) = Array(1, "b", 3)
  ~repl:
    a[0]
    ~error:
      a[1]
    ~error:
      a[2] := "c"
)

}

@doc(
  fun Array(v :: Any, ...) :: MutableArray
){

 Constructs a mutable array containing given arguments.

@examples(
  def a = Array(1, 2, 3)
  a
  a[0]
  a[0] := 0
  a
)

}

@doc(
  ~nonterminal:
    repet_bind: def bind ~defn
  bind.macro 'Array($bind, ...)'
  bind.macro 'Array($bind, ..., $repet_bind #,(@litchar{,}) $ellipsis)'

  grammar ellipsis:
    #,(dots)
){

 Matches an array with as many elements as @rhombus(bind)s, where
 each element matches its corresponding @rhombus(bind), or at least
 as may elements as @rhombus(bind)s when a @rhombus(repet_bind) is
 provided.  When @rhombus(repet_bind) is provided, each additional element
 must match @rhombus(repet_bind).

 Elements are extracted from a matching array eagerly, so mutations of
 the array afterward do no change the matched values. When
 @rhombus(repet_bind) is provided, the extracted matching elements are
 combined into an internal list to implement the repetition.

@examples(
  def Array(1, x, y) = Array(1, 2, 3)
  y
  def Array(1, z, ...) = Array(1, 2, 3)
  [z, ...]
)

}

@doc(
  ~nonterminal:
    len_expr: block expr
    fill_expr: block expr
  reducer.macro 'Array'
  reducer.macro 'Array.of_length($len_expr, $maybe_fill)'

  grammar maybe_fill:
    ~fill: $fill_expr
    #,(@epsilon)
){

 @tech{Reducers} used with @rhombus(for), accumulates each result of a
 @rhombus(for) body into a result array.

 The @rhombus(Array.of_length, ~reducer) reducer, like the
 corresponding annotation, produces an array of a given length.
 Specifically, an array of the specified
 length is created and mutated by iterations of the @rhombus(for) body.
 Iterations more than the specified length will trigger an exception,
 while iterations fewer than the length will leave the value of
 @rhombus(fill_expr) (or @rhombus(0)) in the array.

}

@doc(
  fun Array.make(length :: NonnegInt, val :: Any = 0)
    :: MutableArray
){

  Creates a fresh array with @rhombus(length) slots, where each slot
  is initialized to @rhombus(val).

@examples(
  Array.make(3, "x")
)

}

@doc(
  fun Array.length(arr :: Array) :: Int
){

 Returns the length of @rhombus(arr).

@examples(
  Array.make(3, "x").length()
)

}


@doc(
  fun Array.copy(arr :: Array,
                 start :: NonnegInt = 0,
                 end :: NonnegInt = Array.length(arr)) :: MutableArray
){

 Returns a fresh array string with the same initial content as in
 @rhombus(arr) from position @rhombus(start) (inclusive) through
 @rhombus(end) (exclusive).

@examples(
  Array("a", "b", "c").copy()
  Array("a", "b", "c").copy(1)
  Array("a", "b", "c").copy(1, 2)
)

}

@doc(
  fun Array.copy_from(dest_arr :: MutableArray,
                      dest_start :: NonnegInt,
                      src_arr :: Array,
                      src_start :: NonnegInt = 0,
                      src_end :: NonnegInt = Array.length(src_arr))
    :: Void
){

 Copies bytes from @rhombus(src_arr) at @rhombus(src_start) (inclusive) to
 @rhombus(src_end) (exclusive) into @rhombus(dest_arr) starting at
 @rhombus(dest_start). The length of @rhombus(dest_arr) must be at least
 @rhombus(dest_start + (src_end - src_start)).

}

@doc(
  fun Array.take_left(arr :: Array, n :: NonnegInt) :: MutableArray
  fun Array.take_right(arr :: Array, n :: NonnegInt) :: MutableArray
  fun Array.drop_left(arr :: Array, n :: NonnegInt) :: MutableArray
  fun Array.drop_right(arr :: Array, n :: NonnegInt) :: MutableArray
){

 Like @rhombus(Array.copy) with a range that selects a prefix or suffix
 of @rhombus(arr).

@examples(
  Array("a", "b", "c").take_left(2)
  Array("a", "b", "c").take_right(2)
  Array("a", "b", "c").drop_left(2)
  Array("a", "b", "c").drop_right(2)
)

}


@doc(
  fun Array.set_in_copy(arr :: Array, i :: NonnegInt, v :: Any) :: MutableArray
){

 Returns an array like @rhombus(arr), but with @rhombus(v) as the
 @rhombus(i)th element.

@examples(
  Array("a", "b", "c").set_in_copy(1, "x")
)

}

