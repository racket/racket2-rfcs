#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@(def dots = @rhombus(..., ~bind))
@(def dots_expr = @rhombus(...))

@title{Maps}

A @deftech{map} associates a value with each of a set of keys.
Immutable maps can be constructed using the syntax
@rhombus({#,(@rhombus(key_expr, ~var)): #,(@rhombus(val_expr, ~var)), ...}),
which creates a map from the values of the @rhombus(key_expr, ~var)s to
the corresponding values of the @rhombus(val_expr, ~var)s. Note
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
  Map
  mp.length()
  mp.keys(try_sort, ...)
  mp.values()
  mp.get(k)
  mp.has_key(k)
  mp.copy()
  mp.snapshot()
  mp.to_sequence()
)

@dispatch_table(
  "map (immutable only)"
  Map
  mp.append(mp2, ...)
  mp.remove(k)
)

@dispatch_table(
  "mutable map"
  MutableMap
  mp.set(k, v)
  mp.delete(k)
)

@doc(
  ~nonterminal:
    val_annot: :: annot
    key_annot: :: annot
  annot.macro 'Map'
  annot.macro 'Map.of($key_annot, $val_annot)'
  annot.macro 'Map.later_of($key_annot, $val_annot)'
  annot.macro 'ReadableMap'
  annot.macro 'MutableMap'
  annot.macro 'MutableMap.now_of($key_annot, $val_annot)'
  annot.macro 'MutableMap.later_of($key_annot, $val_annot)'
  annot.macro 'WeakMutableMap'
  annot.macro 'Map.by($key_comp)'
  annot.macro 'Map.by($key_comp).of($key_annot, $val_annot)'
  annot.macro 'MutableMap.by($key_comp)'
  annot.macro 'WeakMutableMap.by($key_comp)'
){

 The @rhombus(Map, ~annot) annotation matches any immutable map.
 @rhombus(ReadableMap, ~annot) matches both mutable and immutable maps,
 while @rhombus(MutableMap, ~annot) matches mutable maps (created with,
 for example, the @rhombus(MutableMap) constructor).
 @rhombus(WeakMutableMap, ~annot) matches weak mutable maps (created with,
 for example, the @rhombus(WeakMutableMap) constructor).

 The @rhombus(of) and @rhombus(now_of) annotation variants match a map
 whose keys satisfy @rhombus(key_annot) and whose values satisfy
 @rhombus(val_annot), where satisfaction of the annotation is confirmed
 by immediately checking all keys and values. No future obligation is
 attached to a map satisfying the annotation, so in the case of
 @rhombus(MutableMap.now_of), no static information is associated with
 value access using @brackets.

 The @rhombus(later_of) annotation variants create a @tech{converter
  annotation} given annotations for keys and values; satisfaction of those
 annotations is confirmed only on demand, both for keys and values that
 are extracted from the map and for keys and values added or appended to
 the map. For @rhombus(Map.later_of), the key and value annotations must
 be @tech{predicate annotations}. Since a value annotation is checked on
 every access, its static information is associated with access using
 @brackets.

 The @rhombus(Map.by, ~annot), @rhombus(MutableMap.by, ~annot), and
 @rhombus(WeakMutableMap.by, ~annot) annotation variants match only maps
 that use the hash and equality procedures specified by
 @rhombus(key_comp).

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
  expr.macro '#%braces {$expr_or_splice, ...}'
  grammar expr_or_splice:
    $elem_expr
    $elem_repet #,(@litchar{,}) $ellipses
    & $set_expr
  grammar ellipses:
    $ellipsis
    $ellipses #,(@litchar{,}) $ellipsis
  grammar ellipsis:
    #,(dots_expr)
  repet.macro '#%braces {$key_repet_or_splice, ...}'
  repet.macro '#%braces {$repet_or_splice, ...}'
){

 Constructs either an immutable map or immutable set, depending on whether
 @rhombus(key_expr) and @rhombus(val_expr) are provided or
 @rhombus(elem_expr) is provided. If no elements are provided directly,
 the result is a map (not a set). Map/set constructions can also serve as
 repetitions, where @rhombus(key_repet_or_splice) and
 @rhombus(repet_or_splice) are like
 @rhombus(key_val_or_splice) and @rhombus(expr_or_splice),
 but with repetitions in place of expressions.

 When @dots_expr is used among the content with two repetitions (for a
 map) or one repetition (for a set), the paired key and value elements
 (for a map) or value elements (for a set) are included in the result map
 or set. When @rhombus(& map_expr) or @rhombus(& set_expr) appears among
 the content, the immutable map or immutable set produced by @rhombus(map_expr) or
 @rhombus(set_expr) is included in the result map or set. This
 inclusion respects the @tech{map configuration} specified by the
 construction.

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
  repet.macro 'Map{$key_repet_or_splice, ...}'
  grammar key_val_or_splice:
    $key_expr: $val_expr
    $key_repet: $val_repet #,(@litchar{,}) $ellipsis
    #,(@rhombus(&)) $map_expr
  grammar ellipsis:
    #,(dots),
  fun Map([key :: Any, val :: Any] :: Listable.to_list, ...)
    :: Map
  expr.macro 'Map.by($key_comp){$key_val_or_splice, ...}'
  expr.macro 'Map.by($key_comp)'
  repet.macro 'Map.by($key_comp){$key_repet_or_splice, ...}'
){

 Constructs an immutable map containing given keys mapped to the given
 values, equivalent to using @rhombus({key_val_or_splice, ...}) for the
 @braces form, or @rhombus({key: val, ...}) for the function form.
 The @braces form works as a repetition, where @rhombus(key_repet_or_splice)
 is like @rhombus(key_val_or_splice) with repetitions in place of expressions.

 The @rhombus(Map.by) variants create a map that uses the equality and
 hashing functions specified by @rhombus(key_comp) for keys.

@examples(
  def m = Map{"x": 1, "y": 2}
  m
  m["x"]
  Map(["x", 1], ["y", 2])
  Map{"a": 4, "b": 4, & m}
  Map.by(===){"x" +& "": 1, "" +& "x": 2}
)

}

@doc(
  ~nonterminal:
    key_expr: block expr
    default_expr: block expr
    default_body: block body
    val_bind: def bind ~defn
    map_bind: def bind ~defn
    set_bind: def bind ~defn
    rest_key_bind: def bind ~defn
    rest_val_bind: def bind ~defn
    rest_bind: def bind ~defn
  bind.macro '#%braces {$key_val, ...}'
  bind.macro '#%braces {$key_val, ..., $map_rest}'
  grammar key_val:
    $key_expr: $val_bind = $default_expr
    $key_expr: $val_bind: $default_body; ...
    $key_expr: $val_bind
  grammar map_rest:
    & $map_bind
    $rest_key_bind: $rest_val_bind #,(@litchar{,}) $ellipsis
  bind.macro '#%braces {$expr, ...}'
  bind.macro '#%braces {$expr, ..., $set_rest}'
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
  def {"x": x, "y": y} = Map{"x": 1, "y": 2}
  y
  def Map{"a": a, "z": z = 0} = {"a": 1, "b": 2, "c": 3}
  [a, z]
  def {"b", more, ...} = Set{"a", "b", "c"}
  [more, ...]
)

}

@doc(
  ~nonterminal:
    key_expr: block expr
    default_expr: block expr
    default_body: block body
    val_bind: def bind ~defn
    map_bind: def bind ~defn
    rest_key_bind: def bind ~defn
    rest_val_bind: def bind ~defn
  bind.macro 'Map{$key_val, ...}'
  bind.macro 'Map{$key_val, ..., $rest}'
  bind.macro 'Map([$key_expr, $val_bind], ...)'
  bind.macro 'ReadableMap{$key_val, ...}'
  bind.macro 'ReadableMap{$key_val, ..., $rest}'
  bind.macro 'ReadableMap([$key_expr, $val_bind], ...)'
  bind.macro 'Map.by($key_comp){$key_val, ...}'
  bind.macro 'Map.by($key_comp){$key_val, ..., $rest}'
  bind.macro 'Map.by($key_comp)([$key_expr, $val_bind], ...)'
  grammar key_val:
    $key_expr: $val_bind = $default_expr
    $key_expr: $val_bind: $default_body; ...
    $key_expr: $val_bind
  grammar rest:
    & $map_bind
    $rest_key_bind: $rest_val_bind #,(@litchar{,}) $ellipsis
  grammar ellipsis:
    #,(dots)
){

 Matches a map of the keys computed by @rhombus(key_expr) to values
 that match the corresponding @rhombus(val_bind)s.
 The matched map may have additional keys and values.
 If @rhombus(default_expr) or @rhombus(default_body) is supplied, the
 key is optional, and the @rhombus(default_expr) or
 @rhombus(default_body) is used to produce a ``default'' value to
 further match in case the key is missing in the matched map.
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
 For @rhombus(ReadableMap, ~bind), the @rhombus(& map_bind) will match
 a snapshot (in the sense of @rhombus(Map.snapshot)) of the rest of the map.
 The @rhombus(Map.by, ~bind) binding forms match only immutable maps
 constructed using @rhombus(key_comp).

@examples(
  def Map{"x": x, "y": y} = {"x": 1, "y": 2}
  y
  def Map{"a": a, "z": z = 0} = {"a": 1, "b": 2, "c": 3}
  [a, z]
  def Map{"a": _, & rst} = {"a": 1, "b": 2, "c": 3}
  rst
  def Map{"a": _, key: val, ...} = {"a": 1, "b": 2, "c": 3}
  [key, ...]
  [val, ...]
  match Map.by(===){}
  | Map.by(==){}: "by equal"
  | Map.by(===){}: "by object identity"
)

}


@doc(
  reducer.macro 'Map'
  reducer.macro 'Map.by($key_comp)'
){

 A @tech{reducer} used with @rhombus(for), expects two results from a
 @rhombus(for) body, and accumulates them into a map using the first
 result as a key and the second result as a value.

 The @rhombus(Map.by, ~reducer) reducer creates a map that uses the
 equality and hashing functions specified by @rhombus(key_comp).

}

@doc(
  ~nonterminal:
    key_expr: block expr
    val_expr: block expr
  expr.macro 'MutableMap{$key_expr: $val_expr, ...}'
  fun MutableMap([key :: Any, val :: Any] :: Listable.to_list, ...)
    :: MutableMap
  expr.macro 'MutableMap.by($key_comp){$key_expr: $val_expr, ...}'
  expr.macro 'MutableMap.by($key_comp)'
){

 Similar to @rhombus(Map) as a constructor, but creates a mutable map
 that can be updated using an @tech{assignment operator} like @rhombus(:=).

 Note that @dots_expr and @rhombus(&) are not supported for constructing
 mutable maps, only immutable maps.

@examples(
  def m = MutableMap{"x": 1, "y": 2}
  m
  m["x"]
  m["x"] := 0
  m
)

}


@doc(
  ~nonterminal:
    key_expr: block expr
    val_expr: block expr
  expr.macro 'WeakMutableMap{$key_expr: $val_expr, ...}'
  fun WeakMutableMap([key :: Any, val :: Any] :: Listable.to_list, ...)
    :: WeakMutableMap
  expr.macro 'WeakMutableMap.by($key_comp){$key_expr: $val_expr, ...}'
  expr.macro 'WeakMutableMap.by($key_comp)'
){

 Like @rhombus(MutableMap), but creates a map where a key is removed
 from the map by a garbage collection when the key is reachable only by
 enumerating the map's keys. A key is not considered reachable merely
 because it is reachable through the value mapped from the key.

}


@doc(
  def Map.empty :: Map = {}
  bind.macro 'Map.empty'
  def ReadableMap.empty :: ReadableMap = {}
  bind.macro 'ReadableMap.empty'
){

 An empty map. The @rhombus(Map.empty, ~bind) binding form differs from
 from @rhombus({}) or @rhombus(Map()), because @rhombus(Map.empty, ~bind)
 matches only an empty immutable map, while @rhombus({}) or
 @rhombus(Map()) matches any immutable map.

 The @rhombus(ReadableMap.empty, ~bind) binding form matches an empty map
 whether it is mutable or immutable.

 Corresponding to the binding forms, @rhombus(Map.empty) and
 @rhombus(ReadableMap.empty) are bound to @rhombus({}) with
 appropriate static information.

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
  fun Map.length(mp :: ReadableMap) :: Int
){

 Returns the number of key--value mappings in @rhombus(mp).

@examples(
  Map.length({"a": 1, "b": 2})
  Map.length({})
  {"a": 1, "b": 2}.length()
  {}.length()
)

}


@doc(
  fun Map.append(mp0 :: Map, mp :: Map, ...) :: Map
){

 Functionally appends @rhombus(mp)s (including @rhombus(mp0)), like the @rhombus(++) operator
 (but without the special optimization). When a key has a value in
 multiple given @rhombus(mp)s, the rightmost value is used.

 When @rhombus(mp)s use different @tech{map configurations}, that of
 @rhombus(mp0) is respected. Conceptually, in the binary case, each
 key--value mapping from the right @rhombus(mp) is added to the left
 @rhombus(mp).

@examples(
  {1: "a", 2: "b"}.append({1: "c"}, {1: "d"})
  {1: "a", 2: "b"} ++ {1: "c"} ++ {1: "d"}
  {1: "a", 2: "b"}.append(
    Map.by(is_same_number_or_object){1: "d"},
    Map.by(is_now){1: "c"},
  )
  {1: "a", 2: "b"}
    ++ Map.by(is_same_number_or_object){1: "d"}
    ++ Map.by(is_now){1: "c"}
)

}


@doc(
  fun Map.keys(mp :: ReadableMap,
               try_sort :: Any = #false)
    :: List
){

 Returns the keys of @rhombus(mp) in a list. If @rhombus(try_sort)
 is true, then the elements are sorted to the degree that a built-in
 comparison can sort them.

@examples(
  Map.keys({"a": 1, "b": 2}, #true)
)

}


@doc(
  fun Map.values(mp :: ReadableMap) :: List
){

 Returns the values of @rhombus(mp) in a list.

@examples(
  Map.values({"a": 1, "b": 2})
)

}


@doc(
  fun Map.get(mp :: ReadableMap,
              key :: Any,
              default :: Any:
                fun (): throw Exn.Fail.Contract(....))
    :: Any
){

 Equivalent @rhombus(mp[key]) (with the default implicit
 @rhombus(#%index) form) when @rhombus(default) is not provided,
 otherwise @rhombus(default) is used when @rhombus(mp) does
 not contain a mapping for @rhombus(key). In that case, if
 @rhombus(default) is a function, then the function is called with zero
 arguments to get a result, otherwise @rhombus(default) is returned as
 the result.

@examples(
  Map.get({"a": 1, "b": 2}, "a")
  {"a": 1, "b": 2}["a"]
  Map.get({"a": 1, "b": 2}, "c", #inf)
  ~error:
    Map.get({"a": 1, "b": 2}, "c", fun (): error("no value"))
)

}


@doc(
  fun Map.remove(mp :: Map, key :: Any) :: Map
){

 Returns a map like @rhombus(mp), but without a mapping for
 @rhombus(key) is @rhombus(mp) has one.

@examples(
  Map.remove({"a": 1, "b": 2}, "a")
  Map.remove({"a": 1, "b": 2}, "c")
)

}


@doc(
  fun MutableMap.set(mp :: MutableMap,
                     key :: Any, val :: Any)
    :: Void
){

 Equivalent to @rhombus(mp[key] := val) (with the default implicit
 @rhombus(#%index) form). Changes @rhombus(mp) to map @rhombus(key)
 to @rhombus(val).

@examples(
  def m = MutableMap{"a": 1, "b": 2}
  m.set("a", 3)
  m
  m["a"] := 4
  m
)

}


@doc(
  fun MutableMap.delete(mp :: MutableMap, key :: Any) :: Void
){

 Changes @rhombus(mp) to remove a mapping for @rhombus(key), if any.

@examples(
  def m = MutableMap{"a": 1, "b": 2}
  m.delete("c")
  m
  m.delete("a")
  m
)

}


@doc(
  fun Map.has_key(mp :: ReadableMap, key :: Any) :: Boolean
){

 Returns @rhombus(#true) if @rhombus(key) is mapped to a value in
 @rhombus(mp), @rhombus(#false) otherwise.

@examples(
  Map.has_key({"a": 1, "b": 2}, "a")
  Map.has_key({"a": 1, "b": 2}, "c")
)

}


@doc(
  fun Map.copy(mp :: ReadableMap) :: MutableMap
){

 Creates a mutable map whose initial content matches @rhombus(mp).

}



@doc(
  fun Map.snapshot(mp :: ReadableMap) :: Map
){

 Returns an immutable map whose content matches @rhombus(mp). If
 @rhombus(mp) is immutable, then it is the result.

}


@doc(
  fun Map.to_sequence(mp :: ReadableMap) :: Sequence
){

 Implements @rhombus(Sequenceable, ~class) by returning a
 @tech{sequence} of @rhombus(mp)'s keys and values (as two result
 values) in an unspecified order.

}
