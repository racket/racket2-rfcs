#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open
    "macro.rhm")

@(def macro_eval = macro.make_macro_eval())

@(def dollar = @rhombus($))

@title{Annotation Macros}

@doc(
  space.enforest annot
){

 The @tech{space} for bindings of identifiers and operators that can be
 used in annotation, such as after @rhombus(::).

}


@doc(
  ~meta
  def annot_meta.space :: SpaceMeta
){

 A compile-time value that identifies the same space as
 @rhombus(annot, ~space). See also @rhombus(SpaceMeta, ~annot).

}


@doc(
  ~nonterminal:
    macro_patterns: expr.macro ~defn

  defn.macro 'annot.macro $macro_patterns'
){

 Like @rhombus(expr.macro), but defines an identifier or operator as an
 annotation form in the @rhombus(annot, ~space) @tech{space}.
 The result of the macro expansion can be a result
 created with @rhombus(annot_meta.pack_predicate).

@examples(
  ~eval: macro_eval
  annot.macro 'two_of($ann)':
    'matching(List(_ :: $ann, _ :: $ann))'
  [1, 2] :: two_of(Number)
  ~error:
    [1, 2, 3] :: two_of(Number)
  ~error:
    [1, "x"] :: two_of(Number)
)

}


@doc(
  ~meta
  fun annot_meta.is_predicate(stx :: Syntax) :: Boolean
  fun annot_meta.pack_predicate(fun_stx :: Syntax,
                                statinfo_stx :: Syntax = '()')
    :: Syntax
  fun annot_meta.unpack_predicate(stx :: Syntax)
    :: (Syntax, Syntax)
){

 The @rhombus(annot_meta.is_predicate) function determines whether a
 syntax object represents a parsed @tech(~doc: guide_doc){predicate annotation}.  This
 function and @rhombus(annot_meta.unpack_predicate) are potentially
 useful on the result of matching @rhombus(annot_meta.Parsed, ~stxclass).


 The @rhombus(annot_meta.pack_predicate) function packs an expression
 for a predicate with static information into an
 annotation form as a syntax object. When the resulting annotation is
 applied to a value, it checks the value using the predicate, and it
 also associates the static information in @rhombus(statinfo_stx) with
 the value. The given @rhombus(statinfo_stx) is in unpacked form
 (i.e., @rhombus(statinfo_meta.pack) is applied automatically).

 The @rhombus(annot_meta.unpack_predicate) function is
 the inverse of @rhombus(annot_meta.pack_predicate), returning two
 values: an expression and unpacked static information.

 See @secref(~doc: guide_doc, "annotation-macro") for more explanation and for
 examples.

}

@doc(
  ~meta
  fun annot_meta.is_converter(stx :: Syntax) :: Boolean
  fun annot_meta.pack_converter(bind_stx :: Syntax,
                                body_stx :: Syntax,
                                statinfo_stx :: Syntax = '()')
    :: Syntax
  fun annot_meta.unpack_converter(stx :: Syntax)
    :: (Syntax, Syntax, Syntax)
){

 The @rhombus(annot_meta.is_predicate) function determines whether a
 syntax object represents a parsed @tech(~doc: guide_doc){converter annotation}. This
 function and @rhombus(annot_meta.unpack_converter) are potentially
 useful on the result of matching @rhombus(annot_meta.Parsed, ~stxclass).

 The @rhombus(annot_meta.pack_converter) function packs
 a binding, a body expression (that can refer to
 bindings), and static information into a @tech(~doc: guide_doc){converter annotation}
 form as a syntax object. When the resulting annotation is applied to a
 value, it uses the binding to determine whether the value satisfies the
 predicate, and if so (and if the converted result is needed), the
 body expression is evaluated to obtain the converted value.
 It also associates the static information in @rhombus(statinfo_stx) with
 the converted value. The given @rhombus(statinfo_stx) is in unpacked
 form (i.e., @rhombus(statinfo_meta.pack) is applied automatically).

 The @rhombus(annot_meta.unpack_converter) function is
 the inverse of @rhombus(annot_meta.pack_converter), returning three
 values: a binding, an expression, and unpacked static information.
 The @rhombus(annot_meta.unpack_converter) function will also unpack
 a @tech(~doc: guide_doc){predicate annotation}, automatically generalizing it to
 a converter annotation.

 See @secref(~doc: guide_doc, "annotation-macro-protocol") for more explanation.

}

@doc(
  ~meta
  fun annot_meta.parse_to_packed_statinfo(stx :: Group)
    :: Syntax
){

 A convenience function that parses @rhombus(stx) as an annotation and
 returns just its static-information component in packed form.

}


@doc(
  ~nonterminal:
    as_annot: :: annot
  defn.macro 'annot.delayed_declare $id'
  defn.macro 'annot.delayed_complete $id_name: $as_annot'
){

 Last-resort forms for solving mutual-dependency problems among
 annotations. The @rhombus(annot.delayed_declare) form declares an
 annotation, and the @rhombus(annot.delayed_complete) form mutates a
 declaration to make it equivalent to @rhombus(as_annot).

 A completed delayed annotation need not be declared in the same module
 or definition context, which is why @rhombus(annot.delayed_complete)
 allows an @rhombus(id_name). See @secref("namespaces") form more
 information on @rhombus(id_name).

 If a value is tested against a delayed annotation @rhombus(id) before
 it is completed via @rhombus(annot.delayed_complete) at run time, then
 an exception is reported. At compile time, attempting to use the static information
 associated @rhombus(id) throws a syntax error until it is completed via
 @rhombus(annot.delayed_complete).

 These forms should be used as last resort, because they inherently
 involve a side effect, and because that effect is potentially across module boundaries. When a
 module uses an imported delayed annotation, the run-time component of
 that delayed annotation might be initialized as a side effect of
 requiring some other module, which potentially makes the reference
 fragile. Delayed annotations are suitable for use inside a library that
 is implemented by multiple private modules that are aggregated into a
 single library as the public interface.

@examples(
  ~eval: macro_eval
  annot.delayed_declare Forward
  class Posn(x, y)
  ~error:
    Posn(1, 2) :: Forward
  ~error:
    block:
      use_static
      fun (p :: Forward): p.x
  annot.delayed_complete Forward: Posn
  Posn(1, 2) :: Forward
  block:
    use_static
    fun (p :: Forward): p.x
)

}


@doc(
  ~meta
  syntax_class annot_meta.Parsed:
    kind: ~group
    fields:
      group
  syntax_class annot_meta.AfterPrefixParsed(op_name):
    kind: ~group
    fields:
      group
      [tail, ...]
  syntax_class annot_meta.AfterInfixParsed(op_name):
    kind: ~group
    fields:
      group
      [tail, ...]
){

 Analogous to @rhombus(expr_meta.Parsed, ~stxclass), etc., but for annotations.

}


@doc(
  fun annot_meta.relative_precedence(left_mode :: matching(#'prefix || #'infix),
                                     left_op :: Name,
                                     right_infix_op :: Name)
    :: matching(#'weaker || #'stronger || #false)
  fun annot_meta.ends_parse(left_mode :: matching(#'prefix || #'infix),
                            left_op :: Name,
                            tail :: Group) :: Boolean
){

 Like @rhombus(expr_meta.relative_precedence) and
 @rhombus(expr_meta.ends_parse), but for annotation operators.

}



@(macro.close_eval(macro_eval))
