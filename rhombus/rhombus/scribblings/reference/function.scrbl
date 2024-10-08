#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open
    meta_label:
      rhombus/doc.DocSpec)

@(def dots = @rhombus(..., ~bind))
@(def dots_expr = @rhombus(...))

@title(~tag: "ref-function"){Functions}

An expression followed by a parenthesized sequence of expressions is
parsed as an implicit use of the @rhombus(#%call) form, which is
normally bound to implement function calls.

@dispatch_table(
  "function"
  Function
  f.map(args, ...)
  f.for_each(args, ...)
)

@doc(
  annot.macro 'Function'
  annot.macro 'Function.of_arity($expr_or_keyword, $expr_or_keyword, ...)'
  grammar expr_or_keyword:
    $expr
    $keyword
){

 The @rhombus(Function, ~annot) annotation matches any function.

 The @rhombus(Function.of_arity, ~annot) variant requires that each
 @rhombus(expr) produces a nonnegative integer, and then function must
 accept that many by-position arguments. The function must require only
 keywords that are provided as @rhombus(keyword)s, and it must accept all
 @rhombus(keyword)s that are listed. Each @rhombus(keyword) must be
 distinct.

@margin_note_block{Due to the current limitation in the function arity
 protocol, a function must require an exact set of keywords across all
 arities, even though Rhombus multi-case @rhombus(fun)s allow
 non-uniform keyword arguments in different cases. In a Rhombus
 multi-case @rhombus(fun), the required set of keywords is the
 ``intersection'' of required keywords in all cases.}

@examples(
  math.cos is_a Function
  math.cos is_a Function.of_arity(1)
  math.atan is_a Function.of_arity(1, 2)
  (fun (x, ~y): #void) is_a Function.of_arity(1, ~y)
  (fun (x, ~y): #void) is_a Function.of_arity(1)
  (fun (x, ~y = 0): #void) is_a Function.of_arity(1)
  (fun (x, ~y = 0): #void) is_a Function.of_arity(1, ~y, ~z)
)

}


@doc(
  ~nonterminal:
    id: block
    fun_expr: block expr
    arg_expr: block expr
    repet_arg: #%call arg
    list_expr: block expr
    map_expr: block expr

  expr.macro '$fun_expr #%call ($arg, ...)'
  repet.macro '$fun_expr #%call ($repet_arg, ...)'
  expr.macro '$fun_expr #%call ($arg, ..., _, $arg, ...)'

  grammar arg:
    $arg_expr
    $keyword
    $keyword: $arg_expr
    $keyword: $body; ...
    $repet #,(@litchar{,}) $ellipses
    & $list_expr
    ~& $map_expr
  grammar ellipses:
    $ellipsis
    $ellipses #,(@litchar{,}) $ellipsis
  grammar ellipsis:
    #,(dots_expr)
){

  A function call. Each @rhombus(arg_expr) alone is a by-position
  argument, and each @rhombus(keyword: arg_expr) combination is a
  by-keyword argument. Function calls can serve as repetitions,
  where @rhombus(repet_arg) is like @rhombus(arg), but with repetitions
  in place of expressions.

  If the @rhombus(arg) sequence contains @rhombus(& list_expr) or
  @rhombus(repet #,(@litchar{,}) ellipses), then the
  elements of the list or @tech{repetition} are spliced into the
  call as separate by-position arguments.

  If the @rhombus(arg) sequence contains @rhombus(~& map_expr), then all
  the keys in the immutable map produced by @rhombus(map_expr) must be keywords, and
  they must not overlap with the directly supplied @rhombus(keyword)s or
  keywords in maps from other @rhombus(~& map_expr) arguments. The
  keyword-value pairs are passed into the function as additional keyword
  arguments.

 Parallel to @rhombus(fun), a single @rhombus(keyword) as an
 @rhombus(arg) is equivalent to the form @rhombus(keyword: id)
 @margin_note{This kind of double duty of a single @rhombus(keyword)
 is sometimes referred to as ``punning.''}
 where @rhombus(id) is composed from @rhombus(keyword) by taking its
 string form and lexical context.

 The case with an immediate @rhombus(_) group among other
 @rhombus(arg)s is a special case for a function shorthand, and it takes
 precedence over parsing the @rhombus(_) as an @rhombus(arg). See
 @rhombus(_) for more information.

 See also @rhombus(use_static).

 @see_implicit(@rhombus(#%call), @parens, "expression", ~is_infix: #true)

@examples(
  List.length([1, 2, 3])
  List.length #%call ([1, 2, 3])
)

}


@doc(
  ~nonterminal:
    arg_expr: block expr
    fun_expr: block expr
  expr.macro '$arg_expr |> $immediate_callee'
  expr.macro '$arg_expr |> $fun_expr'
){

 The @rhombus(|>) operator applies its second argument as a function to
 its first argument. That is, @rhombus(arg_expr |> fun_expr) is
 equivalent to @rhombus(fun_expr(arg_expr)), except that
 @rhombus(arg_expr) is evaluated before @rhombus(fun_expr), following
 the textual order.
 @margin_note{This form is known as a ``pipeline.'' Accordingly,
 @rhombus(|>) is the ``pipe-forward'' operator.}
 The conversion is performed syntactically so that
 static checking and propagation of static information may apply, but
 @rhombus(arg_expr) and @rhombus(fun_expr) are parsed as expressions before the
 conversion. The @rhombus(|>) operator declares weaker precedence than
 all other operators.

 Alternatively, the right-hand side can be an @tech{immediate callee},
 in which case the static information for @rhombus(arg_expr) is
 supplied to it.

 A @rhombus(_) function shorthand can be especially useful with
 @rhombus(|>).

@examples(
  [1, 2, 3] |> List.length
  [3, 1, 2]
    |> List.sort(_)
    |> ([0] ++ _ ++ [100])
    |> to_string.map(_)
)

}

@doc(
  ~nonterminal:
    id: block
    default_expr: block expr
    default_body: block body
    list_expr: block expr
    map_expr: block expr
    list_bind: def bind ~defn
    map_bind: def bind ~defn
    repet_bind: def bind ~defn

  defn.macro 'fun $id_name($bind, ...):
                $body
                ...'
  defn.macro 'fun $id_name $case_maybe_kw_opt:
                $maybe_doc
                $body
                ...'
  defn.macro 'fun
              | $id_name $case_maybe_kw:
                  $body
                  ...
              | ...'
  defn.macro 'fun $id_name $maybe_res_annot
              | $id_name $case_maybe_kw:
                  $body
                  ...
              | ...'
  defn.macro 'fun $id_name $maybe_res_annot:
                $maybe_doc
              | $id_name $case_maybe_kw:
                  $body
                  ...
              | ...'

  expr.macro 'fun ($bind, ...):
                $body
                ...'
  expr.macro 'fun $case_maybe_kw_opt:
                $body
                ...'

  expr.macro 'fun $maybe_res_annot
              | $case_maybe_kw:
                  $body
                  ...
              | ...'

  grammar case_maybe_kw_opt:
    ($bind_maybe_kw_opt, ..., $rest, ...) $maybe_res_annot

  grammar case_maybe_kw:
    ($bind_maybe_kw, ..., $rest, ...) $maybe_res_annot

  grammar maybe_doc:
    ~doc
    ~doc:
      $desc_body
      ...
    #,(epsilon)

  grammar bind_maybe_kw_opt:
    $bind
    $keyword: $bind
    $bind = $default_expr
    $bind: $default_body; ...
    $keyword: $bind = $default_expr
    $keyword: $bind: $default_body; ...
    $keyword
    $keyword = $default_expr

  grammar bind_maybe_kw:
    $bind
    $keyword: $bind
    $keyword

  grammar maybe_res_annot:
    #,(@rhombus(::, ~bind)) $annot
    #,(@rhombus(:~, ~bind)) $annot
    #,(@rhombus(::, ~bind)) #,(@rhombus(values, ~annot))($annot, ...)
    #,(@rhombus(:~, ~bind)) #,(@rhombus(values, ~annot))($annot, ...)
    #,(@rhombus(::, ~bind)) ($annot, ...)
    #,(@rhombus(:~, ~bind)) ($annot, ...)
    #,(epsilon)

  grammar rest:
    $repet_bind #,(@litchar{,}) $ellipsis
    & $list_bind
    ~& $map_bind

  grammar ellipsis:
    #,(dots)

){

 Binds @rhombus(id_name) as a function in the @rhombus(expr, ~space)
 @tech{space}, or when
 @rhombus(id_name) is not supplied, serves as an expression that
 produces a function value.

 The first case shown for the definition and expression forms shown
 above are subsumed by the second case, but they describe the most common
 forms of function definitions and expressions.

@examples(
  ~defn:
    fun f(x):
      x+1
  ~repl:
    f(0)
  ~defn:
    fun List.number_of_items(l):
      List.length(l)
  ~repl:
    List.number_of_items(["a", "b", "c"])
  ~defn:
    def identity = fun (x): x
  ~repl:
    identity(1)
  ~defn:
    fun curried_add(x):
      fun (y):
        x + y
  ~repl:
    curried_add(1)(2)
)

 When @vbar is not used, then arguments can have default values
 as specified after a @rhombus(=) or in a block after the argument name.
 Bindings for earlier arguments are visible in each
 @rhombus(default_expr) or @rhombus(default_body), but not bindings for later arguments;
 accordingly, matching actions are interleaved with binding effects (such
 as rejecting a non-matching argument) left-to-right, except that the
 result of a @rhombus(default_expr) is subject to the same constraints
 imposed by annotations and patterns for its argument as an explicitly
 supplied argument would be. An argument form @rhombus(keyword) or
 @rhombus(keyword = default_expr) is equivalent to the form
 @rhombus(keyword: id) or @rhombus(keyword: id = default_expr) where
 @rhombus(id) is composed from @rhombus(keyword) by taking its
 string form and lexical context.
 A @rhombus(::) or @rhombus(:~) is not allowed in @rhombus(default_expr),
 unless it is nested in another term, since that might be misread or
 confused as an annotation in @rhombus(bind) for an identifier; for similar
 reasons, @rhombus(bind) and @rhombus(default_expr) cannot contain an
 immediate @rhombus(=).

 A constraint not reflected in the grammar is that all optional
 by-position arguments must follow all required by-position arguments.
 To define a function that works otherwise, use the @vbar form.

@examples(
  ~defn:
    fun f(x, y = x+1):
      [x, y]
  ~repl:
    f(0)
    f(0, 2)
  ~defn:
    fun transform([x, y],
                  ~scale: factor = 1,
                  ~dx: dx = 0,
                  ~dy: dy = 0):
      [factor*x + dx, factor*y + dy]
  ~repl:
    transform([1, 2])
    transform([1, 2], ~dx: 7)
    transform([1, 2], ~dx: 7, ~scale: 2)
  ~defn:
    ~error:
      fun invalid(x = 1, y):
        x+y
  ~defn:
    fun
    | valid(y): valid(1, y)
    | valid(x, y): x+y
  ~repl:
    valid(2)
    valid(3, 2)
)

 When alternatives are specified with multiple @vbar clauses, the
 clauses can be provided immediately after @rhombus(fun) or after the
 name and a @rhombus(maybe_res_annot) as described further below.

@examples(
  ~defn:
    fun
    | hello(name):
        "Hello, " +& name
    | hello(first, last):
        hello(first +& " " +& last)
  ~repl:
    hello("World")
    hello("Inigo", "Montoya")
  ~defn:
    fun
    | is_passing(n :: Number): n >= 70
    | is_passing(pf :: Boolean): pf
  ~repl:
    is_passing(80) && is_passing(#true)
)

When a @rhombus(rest) sequence contains @rhombus(& list_bind) or
@rhombus(repet_bind #,(@litchar{,}) #,(dots)), then the
function or function alternative accepts any number of additional
by-position arguments.
For @rhombus(& list_bind), the additional arguments are collected
into a list value, and that list value is bound to the
@rhombus(list_bind). Static information associated by @rhombus(List)
is propagated to @rhombus(list_bind).
For @rhombus(repet_bind #,(@litchar{,}) #,(dots)), each
variable in @rhombus(repet_bind) is bound to a repetition that
repeats access to that piece of each additional argument.
Only one by-position rest binding, @rhombus(& list_bind) or
@rhombus(repet_bind #,(@litchar{,}) #,(dots_expr)), can appear
in a @rhombus(rest) sequence.

When a @rhombus(rest) sequence contains @rhombus(~& map_bind), then
the function or function alternative accepts any number of additional
keyword arguments. The additional keywords and associated argument
values are collected into an immutable map value to be bound to
@rhombus(map_bind). Static information associated by @rhombus(Map) is
propagated to @rhombus(map_bind).
Only one @rhombus(~& map_bind) can appear in a @rhombus(rest) sequence.

@examples(
  ~defn:
    fun
    | is_sorted([] || [_]):
        #true
    | is_sorted([head, next, & tail]):
        head <= next && is_sorted([next, & tail])
  ~repl:
    is_sorted([1, 2, 3, 3, 5])
    is_sorted([1, 2, 9, 3, 5])
  ~defn:
    fun
    | is_sorted([] || [_]):
        #true
    | is_sorted([head, next, tail, ...]):
        head <= next && is_sorted([next, tail, ...])
  ~repl:
    is_sorted([1, 2, 3, 3, 5])
    is_sorted([1, 2, 9, 3, 5])
)

 When @rhombus(maybe_res_annot) is present, it provides an annotation for
 the function's result, but only for the corresponding case if a
 @rhombus(maybe_res_annot) is present in a multi-case function written with
 @(vbar). In the case of a checked annotation using @rhombus(::), the
 function's body is @emph{not} in tail position with respect to a call to
 the function, since a check will be applied to the function's result.
 When @rhombus(maybe_res_annot) is present for a function declared with
 cases afterward, a @rhombus(maybe_res_annot) applies to all cases, in addition to any
 @rhombus(maybe_res_annot) supplied for a specific case. A
 @rhombus(maybe_res_annot) that has a parenthesized sequence of
 @rhombus(annot)s (with our without @rhombus(values)) describes
 multiple result values with an annotation for each individual result.

@examples(
  ~defn:
    fun hello :: String
    | hello(name):
        "Hello, " +& name
    | hello():
        #false
  ~repl:
    hello("World")
    ~error:
      hello()
  ~defn:
    fun things_to_say :: (String, String)
    | things_to_say():
        values("Hi", "Bye")
    | things_to_say(more):
        values("Hi", "Bye", more)
  ~repl:
    things_to_say()
    ~error:
      things_to_say("Nachos")
)

 When @rhombus(~doc) is present and @rhombus(fun) is used in a
 declaration context, then a @rhombus(doc, ~datum) submodule splice is
 generated with @rhombusmodname(rhombus/doc) as the submodule's language.
 In the submodule, @rhombus(id_name) is defined as a
 @rhombus(DocSpec, ~annot) value to record the function's arguments and
 result annotation (if any). If a @rhombus(maybe_res_annot) is present
 with @rhombus(:~, ~bind), it is converted to @rhombus(::, ~bind) in the
 recorded function shape. Tools such as Rhombus Scribble can implort
 the submodule to extract the recorded information.

 See also @rhombus(_) for information about function shorthands using
 @rhombus(_). For example, @rhombus((_ div _)) is a shorthand for
 @rhombus(fun (x, y): x div y).

}


@doc(
  ~nonterminal:
    case_maybe_kw_opt: fun ~defn
    case_maybe_kw: fun ~defn
    maybe_res_annot: fun ~defn

  entry_point.macro 'fun ($bind, ...):
                       $body
                       ...'
  entry_point.macro 'fun $case_maybe_kw_opt'
  entry_point.macro 'fun $maybe_res_annot
                     | $case_maybe_kw
                     | ...'

  immediate_callee.macro 'fun ($bind, ...):
                            $body
                            ...'
  immediate_callee.macro 'fun $case_maybe_kw_opt'
  immediate_callee.macro 'fun $maybe_res_annot
                          | $case_maybe_kw
                          | ...'
){

 The @tech{entry point} and @tech{immediate callee} forms of
 @rhombus(fun, ~entry_point) are the same as the expression form of
 @rhombus(fun).

 A binding as an @deftech{entry point} allows a form to work and cooperate
 with contexts such as @rhombus(constructor, ~class_clause) that
 syntactically require a function. That is, an entry point is a syntactic
 concept. Its corresponding run-time representation is normally a function,
 but an entry point may need to be manipulated statically, such as adding
 an extra argument to make it serve as a method.
 Besides @rhombus(fun, ~entry_point), the @rhombus(macro, ~entry_point) form is
 also bound as entry point.

 A binding as an @tech{immediate callee} allows a form to work and
 cooperate with contexts such as the right-hand side of the @rhombus(|>)
 operator to improve static-information propagation.

}


@doc(
  fun Function.map(f :: Function,
                   args0 :: List, args :: List, ...)
    :: List,
  fun Function.for_each(f :: Function,
                        args0 :: List, args :: List, ...)
    :: Void,
){

 Applies @rhombus(f) to each element of each @rhombus(args) (including @rhombus(args0)), iterating
 through the @rhombus(args) lists together, so @rhombus(f) must take as
 many arguments as the number of given @rhombus(args) lists. For
 @rhombus(Function.map), the result is a list containing the result of
 each call to @rhombus(f) in order. For @rhombus(Function.for_each), the
 result is @rhombus(#void), and the result of each call to @rhombus(f) is
 ignored.

@examples(
  Function.map((_ + _), [1, 2, 3], [4, 5, 6])
  (_ + _).map([1, 2, 3], [4, 5, 6])
  println.for_each([1, 2, 3])
)

}

@doc(
  fun Function.pass(& _, ~& _) :: Void
){

 Accepts any arguments and returns @rhombus(#void).

}


@doc(
  interface Callable
){

@provided_interface_only()

 An interface that a class can implement (publicly or privately) to make
 instances of the class callable as functions. The interface has one
 abstract method, which must be overridden to implement the behavior of
 function calls:

@itemlist(

 @item{@rhombus(call) --- receives the arguments that are passed to the
  instance that is called as a function, and the method's result is the
  result of the function call.}

)

@examples(
  ~defn:
    class Posn(x, y):
      private implements Callable
      private override method call(dx, dy):
        Posn(x + dx, y + dy)
  ~repl:
    def p = Posn(1, 2)
    p
    p(3, 4)
)

}
