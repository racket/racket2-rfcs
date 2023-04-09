#lang scribble/rhombus/manual
@(import: "common.rhm" open)

@title{Static and Dynamic Lookup}

@doc(
  defn.macro 'use_static'
){

 (Re-)defines @rhombus(.), @rhombus(#%ref), and @rhombus(#%parens)
 to require certain static information and consistency with static
 information:

@itemlist(

 @item{A static @rhombus(.) accesses a component of a target only when
  the access can be resolved statically, otherwise the @rhombus(.) form is
  a syntax error.}

 @item{A static @rhombus(#%ref) looks up a value only when
  the lookup operator can be specialized statically (e.g., to a
  @tech{list} or @tech{map} lookup), otherwise the lookup form is an
  error.}

 @item{A static @rhombus(#%parens) does not require static
  information about functions and methods for calls, but it reports an
  error when the number of supplied arguments is inconsistent with static
  information that is available for the called function or method.
  Similarly, @rhombus(:=) assignment to a property is rejected if static
  information does not declare the property as supporting assignment.}
)

 See also @secref("static-lib").

@examples(
  class Posn(x, y)
  fun ok_lookup(ps :~ List.of(Posn)):
    use_static
    ps[0].x
  ~error:
    fun bad_lookup(ps):
      use_static
      ps[0].x
  ~error:
    fun still_bad_lookup(ps :~ List):
      use_static
      ps[0].x
  ~error:
    block:
      use_static
      Posn(1, 2, 3)
)

}

@doc(
  defn.macro 'use_dynamic'
){

 (Re-)defines @rhombus(.), @rhombus(#%ref), and @rhombus(#%parens)
 to their default bindings, which allow either static or dynamic
 resolution of a component access or lookup specialization with no
 complaints about argument mismatches.

@examples(
  class Posn(x, y)
  fun (ps):
    use_dynamic
    ps[0].x
)

}

@doc(
  fun dynamic(v)
){

 The identity function.

 A call to @rhombus(dynamic) has no static information, even if its
 argument has static information, so wrapping a call to
 @rhombus(dynamic) around an expression has the effect of discarding
 any static information available for the expression.

@examples(
  class Posn(x, y)
  ~error:
    fun bad_lookup(ps :~ List.of(Posn)):
      use_static
      dynamic(ps)[0].x
  ~error:
    fun still_bad_lookup(ps :~ List.of(Posn)):
      use_static
      dynamic(ps[0]).x
  fun (ps :~ List.of(Posn)):
    dynamic(dynamic(ps)[0]).x
)

}
