#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@title{Ranges}

A @deftech{range}, or an @deftech{interval}, represents a contiguous
set of integers between two points. When the starting point is
included, the range can be used as a @tech{sequence}; in addition,
when the ending point is not @rhombus(#inf), the range is
@tech{listable}.

@dispatch_table(
  "range"
  Range
  rge.start()
  rge.end()
  rge.includes_start()
  rge.includes_end()
  rge.has_element(int)
  rge.encloses(rge2, ...)
  rge.is_connected(rge2)
  rge.overlaps(rge2)
  rge.span(rge2, ...)
  rge.gap(rge2)
  rge.intersect(rge2, ...)
)

@dispatch_table(
  "range (sequenceable)"
  Range
  rge.to_sequence()
  rge.step_by(step)
)

@dispatch_table(
  "range (listable)"
  Range
  rge.to_list()
)

@doc(
  annot.macro 'Range'
  annot.macro 'SequenceRange'
  annot.macro 'ListRange'
){

 The @rhombus(Range, ~annot) annotation matches any range.

 The @rhombus(SequenceRange, ~annot) annotation matches a range that
 can be used as a @tech{sequence}, for which
 @rhombus(Range.includes_start) returns true.

 The @rhombus(ListRange, ~annot) annotation matches a range that is
 @tech{listable}, for which @rhombus(Range.includes_start) returns
 true, and @rhombus(Range.end) returns non-@rhombus(#inf).

 Static information associated by @rhombus(SequenceRange, ~annot) or
 @rhombus(ListRange, ~annot) makes an expression acceptable as a
 sequence to @rhombus(for) in static mode.

}


@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  expr.macro '$start_expr .. $end_expr'
  bind.macro '$start_bind .. $end_bind'
  expr.macro '$start_expr ..'
  bind.macro '$start_bind ..'
  expr.macro '.. $end_expr'
  bind.macro '.. $end_bind'
  expr.macro '..'
  bind.macro '..'
){

 The same as @rhombus(Range.from_to, ~expr),
 @rhombus(Range.from, ~expr), @rhombus(Range.to, ~expr), and
 @rhombus(Range.full, ~expr), respectively.

 When @rhombus(start_expr .. end_expr) or @rhombus(start_expr ..) is
 used in an @rhombus(each, ~for_clause) clause of @rhombus(for), the
 optimization is more aggressive in that no intermediate range is
 created.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  expr.macro '$start_expr ..= $end_expr'
  bind.macro '$start_bind ..= $end_bind'
  expr.macro '..= $end_expr'
  bind.macro '..= $end_bind'
){

 The same as @rhombus(Range.from_to_inclusive, ~expr) and
 @rhombus(Range.to_inclusive, ~expr), respectively.

 When @rhombus(start_expr ..= end_expr) is used in an
 @rhombus(each, ~for_clause) clause of @rhombus(for), the optimization
 is more aggressive in that no intermediate range is created.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  expr.macro '$start_expr <..< $end_expr'
  bind.macro '$start_bind <..< $end_bind'
  expr.macro '$start_expr <..<'
  bind.macro '$start_bind <..<'
){

 The same as @rhombus(Range.from_exclusive_to, ~expr) and
 @rhombus(Range.from_exclusive, ~expr), respectively.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  expr.macro '$start_expr <..= $end_expr'
  bind.macro '$start_bind <..= $end_bind'
){

 The same as @rhombus(Range.from_exclusive_to_inclusive, ~expr).

}


@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  fun Range.from_to(start :: Int, end :: Int) :: ListRange
  bind.macro 'Range.from_to($start_bind, $end_bind)'
){

 Constructs a range that includes @rhombus(start), but does not
 include @rhombus(end). The corresponding binding matches the
 constructed range.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  fun Range.from_to_inclusive(start :: Int, end :: Int)
    :: ListRange
  bind.macro 'Range.from_to_inclusive($start_bind, $end_bind)'
){

 Constructs a range that includes both @rhombus(start) and
 @rhombus(end). The corresponding binding matches the constructed
 range.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    start_bind: def bind ~defn
  fun Range.from(start :: Int) :: SequenceRange
  bind.macro 'Range.from($start_bind)'
){

 Constructs a range that includes @rhombus(start), and with
 @rhombus(#inf) as the ending point. The corresponding binding matches
 the constructed range.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  fun Range.from_exclusive_to(start :: Int, end :: Int)
    :: Range
  bind.macro 'Range.from_exclusive_to($start_bind, $end_bind)'
){

 Constructs a range that does not include either @rhombus(start) or
 @rhombus(end). The corresponding binding matches the constructed
 range.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    end_expr: block expr
    start_bind: def bind ~defn
    end_bind: def bind ~defn
  fun Range.from_exclusive_to_inclusive(start :: Int,
                                        end :: Int)
    :: Range
  bind.macro 'Range.from_exclusive_to_inclusive($start_bind,
                                                $end_bind)'
){

 Constructs a range that does not include @rhombus(start), but
 includes @rhombus(end). The corresponding binding matches the
 constructed range.

}

@doc(
  ~nonterminal:
    start_expr: block expr
    start_bind: def bind ~defn
  fun Range.from_exclusive(start :: Int) :: Range
  bind.macro 'Range.from_exclusive($start_bind)'
){

 Constructs a range that does not include @rhombus(start), and with
 @rhombus(#inf) as the ending point. The corresponding binding matches
 the constructed range.

}

@doc(
  ~nonterminal:
    end_expr: block expr
    end_bind: def bind ~defn
  fun Range.to(end :: Int) :: Range
  bind.macro 'Range.to($end_bind)'
){

 Constructs a range with @rhombus(#neginf) as the starting point, and
 does not include @rhombus(end). The corresponding binding matches the
 constructed range.

}

@doc(
  ~nonterminal:
    end_expr: block expr
    end_bind: def bind ~defn
  fun Range.to_inclusive(end :: Int) :: Range
  bind.macro 'Range.to_inclusive($end_bind)'
){

 Constructs a range with @rhombus(#neginf) as the starting point, and
 includes @rhombus(end). The corresponding binding matches the
 constructed range.

}

@doc(
  fun Range.full() :: Range
  bind.macro 'Range.full()'
){

 Constructs a range with @rhombus(#neginf) as the starting point and
 @rhombus(#inf) as the ending point. The corresponding binding matches
 the constructed range.

}


@doc(
  fun Range.start(rge :: Range) :: Int || matching(#neginf)
  fun Range.end(rge :: Range) :: Int || matching(#inf)
){

 Returns the starting point and ending point of @rhombus(rge),
 respectively. The starting point can be @rhombus(#neginf), and the
 ending point can be @rhombus(#inf), indicating the lack of a starting
 point or ending point.

}

@doc(
  fun Range.includes_start(rge :: Range) :: Boolean
  fun Range.includes_end(rge :: Range) :: Boolean
){

 Returns @rhombus(#true) if @rhombus(rge) includes the starting point
 and the ending point, respectively, @rhombus(#false) otherwise. A
 @rhombus(#neginf) starting point or @rhombus(#inf) ending point
 cannot be included.

}


@doc(
  fun Range.has_element(rge :: Range, int :: Int) :: Boolean
){

 Checks whether @rhombus(rge) has @rhombus(int) in the range that it
 represents.

@examples(
  (3..=7).has_element(5)
  (3..=7).has_element(7)
  (3..=7).has_element(10)
)

}


@doc(
  fun Range.encloses(rge :: Range, ...) :: Boolean
){

 Checks whether @rhombus(rge)s are in enclosing order. A range
 @rhombus(rge, ~var) encloses another range @rhombus(rge2, ~var) when
 @rhombus(rge, ~var) has every integer in @rhombus(rge2, ~var). Every
 range encloses itself, and empty ranges never enclose non-empty
 ranges.

@examples(
  Range.encloses()
  (2 <..< 8).encloses()
  (2 <..< 8).encloses(4..=6)
  (2 <..< 8).encloses(2..=6, 4..=6)
  (2 <..< 8).encloses(5..)
  (2 <..<).encloses(5..)
)

}

@doc(
  fun Range.is_connected(rge :: Range, rge2 :: Range) :: Boolean
){

 Checks whether @rhombus(rge) is connected with @rhombus(rge2), that
 is, whether there exists a range (possibly empty) that is enclosed by
 both @rhombus(rge) and @rhombus(rge2).

@examples(
  (2..=7).is_connected(3 <..< 8)
  (2..=5).is_connected(5 <..< 8)
  (2 <..< 5).is_connected(5 <..< 8)
)

}

@doc(
  fun Range.overlaps(rge :: Range, rge2 :: Range) :: Boolean
){

 Checks whether @rhombus(rge) overlaps with @rhombus(rge2), that is,
 whether there exists a non-empty range that is enclosed by both
 @rhombus(rge) and @rhombus(rge2).

@examples(
  (2..=7).overlaps(3 <..< 8)
  (2..=5).overlaps(5..=8)
  (2..=5).overlaps(5 <..< 8)
)

}


@doc(
  fun Range.span(rge0 :: Range, rge :: Range, ...) :: Range
){

 Returns the smallest range that encloses all @rhombus(rge)s
 (including @rhombus(rge0)).

@examples(
  (2..=5).span()
  (2..=5).span(8 <..< 9)
  (..4).span(6..=6)
  (2 <..< 8).span(..=5, 8 <..< 9)
)

}

@doc(
  fun Range.gap(rge :: Range, rge2 :: Range) :: maybe(Range)
){

 Returns the largest range that lies between @rhombus(rge) and
 @rhombus(rge2), or @rhombus(#false) if no such range exists
 (precisely when @rhombus(rge) overlaps with @rhombus(rge2)).

@examples(
  (2..=5).gap(8..=9)
  (..4).gap(6..=6)
  (2 <..< 8).gap(8..=10)
  (2..=8).gap(8..=10)
)

}

@doc(
  fun Range.intersect(rge :: Range, ...) :: maybe(Range)
){

 Returns the intersection of all @rhombus(rge)s, or @rhombus(#false)
 if no such range exists. The intersection of a range
 @rhombus(rge, ~var) and another range @rhombus(rge2, ~var) is the
 largest range that is enclosed by both @rhombus(rge, ~var) and
 @rhombus(rge2, ~var), which only exists when @rhombus(rge, ~var) is
 connected with @rhombus(rge2, ~var).

@examples(
  Range.intersect()
  (2..=8).intersect()
  (2..=8).intersect(4 <..< 16)
  (4 <..<).intersect(..6, 2..=8)
  (2 <..< 8).intersect(..=5)
  (2 <..< 8).intersect(8 <..< 10)
)

}


@doc(
  fun Range.to_list(rge :: ListRange) :: List
){

 Implements @rhombus(Listable, ~class) by returning a @tech{list} of
 integers in @rhombus(rge) in order.

}


@doc(
  fun Range.to_sequence(rge :: SequenceRange) :: Sequence
){

 Implements @rhombus(Sequenceable, ~class) by returning a
 @tech{sequence} of integers in @rhombus(rge) in order. The sequence
 is infinite when the ending point is @rhombus(#inf).

}

@doc(
  fun Range.step_by(rge :: SequenceRange, step :: PosInt)
    :: Sequence
){

 Returns a @tech{sequence} of integers in @rhombus(rge) in order,
 stepping by the given @rhombus(step) size.

 When invoked as @rhombus(rge.step_by(step)) in an
 @rhombus(each, ~for_clause) clause of @rhombus(for), the sequence is
 optimized, in addition to the optimization in @rhombus(..) or
 @rhombus(..=).

}
