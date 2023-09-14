#lang scribble/rhombus/manual
@(import: "common.rhm" open
          "nonterminal.rhm" open)

@(def dots: @rhombus(..., ~bind))
@(def dots_expr: @rhombus(...))

@title{Maps}

Immutable maps can be constructed using the syntax
@rhombus({#,(@rhombus(key_expr, ~var)): #,(@rhombus(value_expr, ~var)), ...}),
which creates a map from the values of the @rhombus(key_expr, ~var)s to
the corresponding values of the @rhombus(value_expr, ~var)s. Note
that using @litchar{,} in place of @litchar{:} creates a set with
separate values, instead of a key--value mapping. More precisely, a
use of curly braces with no preceding expression is parsed as an
implicit use of the @rhombus(#%braces) form.

A map is @tech{indexable} using @brackets after a map expression with an
expression for the key within @brackets. Mutable maps can be
updated with a combination of @brackets and @tech{assignment operators}
such as @rhombus(:=) (but use @rhombus(++) to functionally update an
immutable map). These uses of square brackets are implemented by
@rhombus(#%index).  A map can be used as @tech{sequence}, in which case
it supplies a key and its associated value (as two result values)
in an unspecified order.

@dispatch_table(
  "readbale map (immutable or mutable)"
  @rhombus(Map)
  [map.length(), Map.length(map)]
  [map.keys(try_sort, ...), Map.keys(map, try_sort, ...)]
  [map.values(), Map.values(map)]
  [map.get(k), Map.get(map, k)]
  [map.has_key(k), Map.has_key(map, k)]
  [map.copy(), Map.copy(map)]
  [map.snapshot(), Map.snapshot(map)]
)

@dispatch_table(
  "map (immutable only)"
  @rhombus(Map)
  [map.remove(k), Map.remove(map, k)]
)

@dispatch_table(
  "mutable map"
  @rhombus(MutableMap)
  [map.delete(k), MutableMap.delete(map, k)]
)

@doc(
  ~nonterminal:
    value_annot: :: annot
    key_annot: :: annot
  annot.macro 'Map'
  annot.macro 'Map.of($key_annot, $value_annot)'
  annot.macro 'ReadableMap'
  annot.macro 'MutableMap'
){

 Matches any immutable map in the form without @rhombus(of). The @rhombus(of)
 variant matches a map whose keys satisfy @rhombus(key_annot)
 and whose values satisfy @rhombus(value_annot).

 @rhombus(ReadableMap, ~annot) matches both mutable and immutable maps,
 while @rhombus(MutableMap, ~annot) matches mutable maps (created with,
 for example, the @rhombus(MutableMap) constructor).

 Static information associated by @rhombus(Map, ~annot), etc., makes an
 expression acceptable as a sequence to @rhombus(for) in static mode.

}

@doc(
  ~nonterminal:
    key_expr: block expr
    val_expr: block expr
    elem_expr: block expr
    map_expr: block expr
    set_expr: block expr
    key_repet: block repet
    val_repet: block repet
    elem_repet: block repet
  expr.macro '#%braces {$key_val_or_splice, ...}'
  grammar key_val_or_splice:
    $key_expr: $val_expr
    $key_repet: $val_repet #,(@litchar{,}) $ellipses
    & $map_expr
  expr.macro '#%braces {$expr_or_splice, ...+}'
  grammar expr_or_splice:
    $elem_expr
    $elem_repet #,(@litchar{,}) $ellipses
    & $set_expr
  grammar ellipses:
    $ellipsis
    $ellipses #,(@litchar{,}) $ellipsis
  grammar ellipsis:
    #,(dots_expr)
  repet.macro '#%braces {$key_val_or_splice_repet, ...}'
  repet.macro '#%braces {$repet_or_splice, ...+}'
){

 Constructs either a map or a set, depending on whether
 @rhombus(key_expr) and @rhombus(val_expr) are provided or
 @rhombus(elem_expr) is provided. If no elements are provided directly,
 the result is a map (not a set). Map/set constructions can also serve as
 repetitions, where @rhombus(key_val_or_splice_repet) and
 @rhombus(repet_or_splice) are like
 @rhombus(key_val_or_splice) and @rhombus(expr_or_splice),
 but with repetitions in place of expressions.

 When @dots_expr is used among the content with two repetitions (for a
 map) or one repetition (for a set), the paired key and value elements
 (for a map) or value elements (for a set) are included in the result map
 or set. When @rhombus(& map_expr) or @rhombus(& set_expr) appears among
 the content, the map or set produced by @rhombus(map_expr) or
 @rhombus(set_expr) is included in the result map or set.

 Mappings or elements are added to the result map or set left-to-right,
 which means that a later @rhombus(key_expr) or @rhombus(elem_expr) may
 replace one earlier in the sequence. This ordering applies to mappings
 or elements spliced via @dots_expr and @rhombus(&), too.
 
 @see_implicit(@rhombus(#%braces), @braces, "expression or repetition")

@examples(
  {1, 2, 3}
  {"a": 1, "b": 2}
  #%braces {1, 2, 3}
  #%braces {"a": 1, "b": 2}
  {1, 2, & {3, 4}}
  {"a": 1, "b": 2, & {"c": 3, "d": 4}}
)

}


@doc(
  ~nonterminal:
    key_expr: block expr
    val_expr: block expr
    map_expr: block expr
    key_repet: block repet
    val_repet: block repet
  expr.macro 'Map{$key_val_or_splice, ...}'
  repet.macro 'Map{$key_val_or_splice_repet, ...}'
  grammar key_val_or_splice:
    $key_expr: $val_expr
    $key_repet: $val_repet #,(@litchar{,}) $ellipsis
    #,(@rhombus(&)) $map_expr
  grammar ellipsis:
    #,(dots),
  fun Map([key :: Any, value :: Any], ...) :: Map
){

 Constructs an immutable map containing given keys mapped to the given
 values, equivalent to using @rhombus({key_val_or_splice, ...}) for the
 @braces form, or @rhombus({key: value, ...}) for the function form.
 The @braces form works as a repetition, where @rhombus(key_val_or_splice_repet)
 is like @rhombus(key_val_or_splice) with repetitions in place of expressions.

@examples(
  def m: Map{"x": 1, "y": 2}
  m
  m["x"]
  Map(["x", 1], ["y", 2])
  Map{"a": 4, "b": 4, & m}
)

}

@doc(
  ~nonterminal:
    key_expr: block expr
    val_bind: def bind ~defn
    map_bind: def bind ~defn
    set_bind: def bind ~defn
    rest_key_bind:  def bind ~defn
    rest_val_bind:  def bind ~defn
    rest_bind:  def bind ~defn
  bind.macro '#%braces {$key_expr: $val_bind, ...}'
  bind.macro '#%braces {$key_expr: $val_bind, ..., map_rest}'
  grammar map_rest:
    & $map_bind
    $rest_key_bind: $rest_val_bind #,(@litchar{,}) $ellipsis
  bind.macro '#%braces {$expr, ...}'
  bind.macro '#%braces {$expr, ..., set_rest}'
  grammar set_rest:
    & $set_bind
    $rest_bind #,(@litchar{,}) $ellipsis
  grammar ellipsis:
    #,(dots)
){

 Matches either an immutable map or immutable set, depending on whether
 @rhombus(key_expr) and @rhombus(val_bind) are provided or
 @rhombus(expr) is provided. If no @rhombus(key_expr) or
 @rhombus(expr) are provided, the binding matches a map (not a set).

 See @rhombus(Map, ~bind) and @rhombus(Set, ~bind) for more information.

 @see_implicit(@rhombus(#%braces, ~bind), @braces, "binding")

@examples(
  def {"x": x, "y": y}: Map{"x": 1, "y": 2}
  y
  def {"b", rest, ...}: Set{"a", "b", "c"}
  [rest, ...]
)

}

@doc(
  ~nonterminal:
    key_expr: block expr
    val_bind: def bind ~defn
    map_bind: def bind ~defn
    rest_key_bind:  def bind ~defn
    rest_val_bind:  def bind ~defn
  bind.macro 'Map{$key_expr: $val_bind, ...}'
  bind.macro 'Map{$key_expr: $val_bind, ..., $rest}'
  bind.macro 'Map([$key_expr, $val_bind], ...)'
  bind.macro 'ReadableMap{$key_expr: $val_bind, ...}'
  bind.macro 'ReadableMap{$key_expr: $val_bind, ..., $rest}'
  bind.macro 'ReadableMap([$key_expr, $val_bind], ...)'
  grammar rest:
    & $map_bind
    $rest_key_bind: $rest_val_bind #,(@litchar{,}) $ellipsis
  grammar ellipsis:
    #,(dots)
){

 Matches a map of the keys computed by @rhombus(key_expr) to values
 that match the corresponding @rhombus(val_bind)s.
 The matched map may have additional keys and values.
 If @rhombus(& map_bind) is supplied, the rest of the map excluding
 the given @rhombus(key_expr)s must match the @rhombus(map_bind).
 Static information associated by @rhombus(Map) is propagated to @rhombus(map_bind).
 If @rhombus(rest_key_bind: rest_val_bind) followed by @dots is
 supplied, the rest of the map excluding the given @rhombus(key_expr)s
 must have individual keys that match @rhombus(rest_key_bind) and
 values that match @rhombus(rest_val_bind), and identifiers in
 @rhombus(rest_key_bind) and @rhombus(rest_val_bind) are bound
 as repetitions. Values matching @rhombus(rest_key_bind) and @rhombus(rest_val_bind)
 are extracted eagerly and preserved in internal lists to implement
 the repetitions.

 The @rhombus(Map, ~bind) binding forms match only immutable maps, while
 @rhombus(ReadableMap, ~bind) forms match both immutable and mutable maps.

@examples(
  def Map{"x": x, "y": y}: {"x": 1, "y": 2}
  y
  def Map{"a": a}: {"a": 1, "b": 2, "c": 3}
  a
  def Map{"a": _, & rst}: {"a": 1, "b": 2, "c": 3}
  rst
  def Map{"a": _, key: val, ...}: {"a": 1, "b": 2, "c": 3}
  [key, ...]
  [val, ...]
)

}


@doc(
  reducer.macro 'Map'
){

 A @tech{reducer} used with @rhombus(for), expects two results from a
 @rhombus(for) body, and accumulates them into a map using the first
 result as a key and the second result as a value.

}

@doc(
  ~nonterminal:
    key_expr: block expr
    val_expr: block expr
  expr.macro 'MutableMap{key_expr: val_expr, ...}'
  fun MutableMap(key :: Any, value:: Any, ...) :: MutableMap
){

 Similar to @rhombus(Map) as a constructor, but creates a mutable map
 that can be updated using and @tech{assignment operator} lik @rhombus(:=).

 Note that @dots_expr and @rhombus(&) are not supported for constructing
 mutable maps, only immutable maps.

@examples(
  def m: MutableMap{"x": 1, "y": 2}
  m
  m["x"]
  m["x"] := 0
  m
)

}


@doc(
  bind.macro 'Map.empty'
  expr.macro 'Map.empty'
  bind.macro 'ReadableMap.empty'
  expr.macro 'ReadableMap.empty'
){

 An empty map. The @rhombus(Map.empty, ~bind) binding form differs from
 from @rhombus({}) or @rhombus(Map()), because @rhombus(Map.empty, ~bind)
 matches only an empty immutable map, while @rhombus({}) or
 @rhombus(Map()) matches any immutable map.

 The @rhombus(ReadableMap.empty, ~bind) binding form matches an empty map
 whether it is mutable or immutable. The @rhombus(ReadableMap.empty)
 expression form is equivalent to @rhombus(Map.empty).

@examples(
  Map.empty
  match {}
  | Map.empty: "empty map"
  | _: #false
  match {"x": 1, "y": 2}
  | Map.empty: "empty map"
  | _: #false
  match {"x": 1, "y": 2}
  | {}: "curly braces allow extra"
  | _: #false
  match {"x": 1, "y": 2}
  | Map(): "Map binding allows extra"
  | _: #false
  match MutableMap{}
  | Map.empty: "empty immutable map"
  | _: #false
  match MutableMap{}
  | ReadableMap.empty: "empty map for now"
  | _: #false
)

}

@doc(
  fun Map.length(map :: ReadableMap) :: Int
){

 Returns the number of key--value mappings in @rhombus(map).

@examples(
  Map.length({"a": 1, "b": 2})
  Map.length({})
  {"a": 1, "b": 2}.length()
)

}


@doc(
  fun Map.keys(map :: ReadableMap, try_sort = #false) :: List
){

 Returns the keys of @rhombus(map) in a list.  If @rhombus(try_order)
 is true, then the elements are sorted to the degree that a built-in
 comparison can sort them.

@examples(
  Map.keys({"a": 1, "b": 2}, #true)
)

}


@doc(
  fun Map.values(map :: ReadableMap) :: List
){

 Returns the values of @rhombus(map) in a list.

@examples(
  Map.values({"a": 1, "b": 2})
)

}


@doc(
  fun Map.get(map :: ReadableMap, key, default = #,(@rhombus(raise_error, ~var)))
){

 Equivalent to @rhombus(map[key]) when @rhombus(default) is not
 provided, otherwise @rhombus(default) is used when @rhombus(map) does
 not contain a mapping for @rhombus(key). In that case, if
 @rhombus(default) is a function, then the function is called with zero
 arguments to get a result, otherwise @rhombus(default) is returned as
 the result.

@examples(
  Map.get({"a": 1, "b": 2}, "a")
  Map.get({"a": 1, "b": 2}, "c", #inf)
  ~error:
    Map.get({"a": 1, "b": 2}, "c", fun(): error("no value"))
)

}


@doc(
  fun Map.remove(map :: Map, key) :: Map
){

 Returns a map like @rhombus(map), but without a mapping for
 @rhombus(key) is @rhombus(map) has one.

@examples(
  Map.remove({"a": 1, "b": 2}, "a")
  Map.remove({"a": 1, "b": 2}, "c")
)

}


@doc(
  fun MutableMap.delete(map :: MutableMap, key) :: Void
){

 Changes @rhombus(map) to remove a mapping for @rhombus(key), if any.

@examples(
  def m = MutableMap{"a": 1, "b": 2}
  m.delete("c")
  m
  m.delete("a")
  m
)

}


@doc(
  fun Map.has_key(map :: ReadableMap, key) :: Boolean
){

 Returns @rhombus(#true) if @rhombus(key) is mapped to a value in
 @rhombus(map), @rhombus(#false) otherwise.

@examples(
  Map.has_key({"a": 1, "b": 2}, "a")
  Map.has_key({"a": 1, "b": 2}, "c")
)

}


@doc(
  fun Map.copy(map :: ReadableMap) :: MutableMap
){

 Creates a mutable map whose initial content matches @rhombus(map).

}



@doc(
  fun Map.snapshot(set :: ReadableMap) :: Map
){

 Returns an immutable map whose content matches @rhombus(map). If
 @rhombus(map) is immutable, then it is the result.

}
