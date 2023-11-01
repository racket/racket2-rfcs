#lang scribble/rhombus/manual
@(import: "common.rhm" open)

@title{Numbers}

@doc(
  annot.macro 'Number'
){

  Matches any number.

@examples(
  5 is_a Number
  5/2 is_a Number
  #inf is_a Number
  math.sqrt(-1) is_a Number
)

}

@doc(
  annot.macro 'Exact'
  annot.macro 'Inexact'
){

 Matches exact and inexcat numbers, respectively. An inexact number is
 one that is represented as a floating-point number or a complex number
 with an inexact real or imaginary part. These two annotations are
 mutually exclusive.

@examples(
  ~check:
    5 is_a Exact
    ~is #true
  ~check:
    5.0 is_a Inexact
    ~is #true
  ~check:
    5.0 is_a Exact
    ~is #false
  ~check:
    5 is_a Inexact
    ~is #false
)

}

@doc(
  annot.macro 'Int'
  annot.macro 'PosInt'
  annot.macro 'NegInt'
  annot.macro 'NonnegInt'

  annot.macro 'Int.in($lo $inclusivity, $hi $inclusivity)'
  
  grammar inclusivity:
    #,(epsilon)
    ~inclusive
    ~exclusive  
){

 Matches exact integers: all of them, positive integers, negative
 integers, nonnegative integers, or integers in a given range.

 The @rhombus(Int.in, ~annot) annotation constraints a integers to be
 within the given range, where each end of the range is inclusive by
 default, but @rhombus(~inclusive) or @rhombus(~exclusive) can be
 specified.

@examples(
  5 is_a Int
  5 is_a PosInt
  -5 is_a NegInt
  0 is_a NonnegInt
  0 is_a Int.in(0, 1 ~exclusive)
  1 is_a Int.in(0, 1 ~exclusive)
)

}

@doc(
  annot.macro 'Real'
  annot.macro 'PosReal'
  annot.macro 'NegReal'
  annot.macro 'NonnegReal'
  annot.macro 'Real.at_least($lo)'
  annot.macro 'Real.above($lo)'
  annot.macro 'Real.below($hi)'
  annot.macro 'Real.at_most($hi)'
  annot.macro 'Real.in($lo $inclusivity, $hi $inclusivity)'

  grammar inclusivity:
    #,(epsilon)
    ~inclusive
    ~exclusive  
){

 The @rhombus(Real, ~annot) annotation matches real numbers (as opposed
 to imaginary numbers like the result of @rhombus(math.sqrt(-1))). The
 @rhombus(PosReal, ~annot), @rhombus(NegReal, ~annot), and
 @rhombus(NonnegReal, ~annot) annotatiosn match positive, negative, and
 non-negative real numbers, respectively.

 The @rhombus(Real.at_least, ~annot), @rhombus(Real.above, ~annot),
 @rhombus(Real.below, ~annot), and @rhombus(Real.at_most, ~annot)
 annotations furher constrain the number to be equal to or greater than,
 greater than, less then, or equal to or less than the given number,
 respectively.

 The @rhombus(Real.in, ~annot) annotation constraints a real number to
 be within the given range, where each end of the range is inclusive by
 default, but @rhombus(~inclusive) or @rhombus(~exclusive) can be
 specified.

@examples(
  5 is_a Real
  5.0 is_a Real
  5.1 is_a Real
  #inf is_a Real
  math.sqrt(-1) is_a Real

  1 is_a Real.at_least(1)
  1 is_a Real.above(1)
  0 is_a Real.in(0, 1 ~exclusive)
  1 is_a Real.in(0, 1 ~exclusive)
)

}

@doc(
  annot.macro 'Rational'
){

 Matches the same numbers as @rhombus(Real) except for @rhombus(#inf),
 @rhombus(#neginf), and @rhombus(#nan).

@examples(
  5 is_a Rational
  #inf is_a Rational
)

}

@doc(
  annot.macro 'Integral'
){

 Matches the same numbers as @rhombus(Int) plus real numbers that have
 no fractional component.

@examples(
  5 is_a Integral
  5.0 is_a Integral
  5.1 is_a Integral
)

}

@doc(
  annot.macro 'Flonum'
){

 Matches real numbers that are represented as floating-point numbers.

@examples(
  5.0 is_a Flonum
  #inf is_a Flonum
  5 is_a Flonum
  5/2 is_a Flonum
)

}


@doc(
  annot.macro 'Byte'
){

 Matches integers in the range @rhombus(0) ro @rhombus(255) (inclusive).

@examples(
  5 is_a Byte
  256 is_a Byte
)

}


@doc(
  operator ((x :: Number) + (y :: Number)) :: Number
  operator ((x :: Number) - (y :: Number)) :: Number
  operator ((x :: Number) * (y :: Number)) :: Number
  operator ((x :: Number) / (y :: Number)) :: Number
  operator ((x :: Number) ** (y :: Number)) :: Number
){

 The usual arithmetic operators with the usual precedence, except that
 @rhombus(/) does not have the same precedence as @rhombus(*) when it
 appears to the left of @rhombus(*).

@examples(
  1+2
  3-4
  5*6
  8/2
  1+2*3
  2**10
  ~error:
    6/2*3
)

}


@doc(
  operator ((x :: Integral) div (y :: Integral)) :: Integral
  operator ((x :: Integral) rem (y :: Integral)) :: Integral
  operator ((x :: Integral) mod (y :: Integral)) :: Integral
){

 Integer division (truncating), remainder, and modulo operations.

@examples(
  7 div 5
  7 rem 5
  7 mod 5
  7 mod -5
)

}


@doc(
  operator ((x :: Number) > (y :: Number)) :: Boolean
  operator ((x :: Number) >= (y :: Number)) :: Boolean
  operator ((x :: Number) < (y :: Number)) :: Boolean
  operator ((x :: Number) <= (y :: Number)) :: Boolean
){

 The usual comparsion operators on numbers. See also @rhombus(.=).

@examples(
  1 < 2
  3 >= 3.0
)

}

@doc(
  fun math.abs(x :: Real) :: Real
  fun math.max(x :: Real) :: Real
  fun math.min(x :: Real) :: Real
  fun math.floor(x :: Real) :: Real
  fun math.ceiling(x :: Real) :: Real
  fun math.round(x :: Real) :: Real
  fun math.sqrt(x :: Number) :: Number
  fun math.log(x :: Number) :: Number
  fun math.exp(x :: Number) :: Number
  fun math.expt(base :: Number, power :: Number) :: Number
  fun math.cos(x :: Number) :: Number
  fun math.sin(x :: Number) :: Number
  fun math.tan(x :: Number) :: Number
  fun math.acos(x :: Number) :: Number
  fun math.asin(x :: Number) :: Number
  fun math.atan(x :: Number) :: Number
  fun math.atan(y :: Number, x :: Number) :: Number
){

 The usual functions on numbers.

@examples(
  math.abs(-1.5)
  math.min(1, 2)
  math.max(1, 2)
  math.floor(1.5)
  math.ceiling(1.5)
  math.round(1.5)
  math.sqrt(4)
  math.cos(3.14)
  math.sin(3.14)
  math.tan(3.14 / 4)
  math.acos(1)
  math.asin(1)
  math.atan(0.5)
  math.atan(1, 2)
  math.log(2.718)
  math.exp(1)
)

}


@doc(
  fun math.exact(x :: Number) :: Exact
  fun math.inexact(x :: Number) :: Inexact
){

 Converts a number to ensure that it is exact or inexact, respectively.
 Some real numbers, such as @rhombus(#inf), cannot be made exact.

@examples(
  math.exact(5.0)
  math.inexact(5)
)

}


@doc(
  fun math.real_part(x :: Number) :: Real
  fun math.imag_part(x :: Number) :: Real
  fun math.magnitude(x :: Number) :: Real
  fun math.angle(x :: Number) :: Real
){

 Operations on complex numbers.

@examples(
  math.real_part(5)
  math.real_part(math.sqrt(-1))
  math.imag_part(math.sqrt(-1))
  math.magnitude(1 + math.sqrt(-1))
  math.angle(1 + math.sqrt(-1))  
)

}



@doc(
  fun math.numerator(q :: Rational) :: Integral
  fun math.denominator(q :: Rational) :: Integral
){

 Coerces @rhombus(q) to an exact number, finds the numerator of the
 number expressed in its simplest fractional form, and returns this
 number coerced to the exactness of @rhombus(q).

@examples(
  math.numerator(256/6)
  math.denominator(256/6)
  math.denominator(0.125)
)

}

@doc(
  fun math.random() :: Real
  fun math.random(n :: PosInt) :: NonnegInt
){

 Returns a random number between @rhombus(0.0) (inclusive) and
 @rhombus(1.0) (exclusive) when called with 0 arguments, and returns an
 integer between 0 (inclusive) and @rhombus(n) (exclusive) when called
 with @rhombus(n).

@examples(
  ~fake:
    math.random()
    0.5348255534758128
  ~fake:
    math.random(17)
    13
)

}

@doc(
  fun math.sum(n :: Number, ...) :: Number
  fun math.product(n :: Number, ...) :: Number
){

 Generalizations of @rhombus(+) and @rhombus(*) to any number of
 arguments.

@examples(
  math.sum()
  math.sum(1, 2, 3, 4)
  math.product(1, 2, 3, 4)
)

}

@doc(
  fun math.equal(n :: Number, ...) :: Boolean
  fun math.less(n :: Real, ...) :: Boolean
  fun math.less_or_equal(n :: Real, ...) :: Boolean
  fun math.greater(n :: Real, ...) :: Boolean
  fun math.greater_or_equal(n :: Real, ...) :: Boolean
){

 Generalizations of @rhombus(.=), @rhombus(<), @rhombus(<=),
 @rhombus(>), and @rhombus(>=) to any number of arguments. The result is
 always @rhombus(#true) for zero or one arguments.

@examples(
  math.less()
  math.less(1)
  math.less(2, 1)
  math.less(1, 2, 3, 4)
  math.less(1, 2, 3, 0)
)

}

@doc(
  def math.pi :: Flonum
){

 An appromation of @italic{π}, the ratio of a circle's circumference to its diameter.

@examples(
  math.pi
)

}

@doc(
  operator ((n :: Int) bits.and (m :: Int)) :: Int
  operator ((n :: Int) bits.or (m :: Int)) :: Int
  operator ((n :: Int) bits.xor (m :: Int)) :: Int
  operator (bits.not (n :: Int)) :: Int
  operator ((n :: Int) bits.(<<) (m :: NonnegInt)) :: Int
  operator ((n :: Int) bits.(>>) (m :: NonnegInt)) :: Int
  operator ((n :: Int) bits.(?) (m :: NonnegInt)) :: Boolean
  fun bits.length(n :: Int) :: Int
  fun bits.field(n :: Int, start :: NonnegInt, end :: NonnegInt) :: Int
){

 Bitwise operations on integers interpreted as a semi-infinite two's
 complement representation:

@itemlist(

  @item{@rhombus(bits.and), @rhombus(bits.or) (inclusive),
   @rhombus(bits.xor), work on pairs of bits from @rhombus(n) and
   @rhombus(m);}

  @item{@rhombus(bits.not) inverts every bit in @rhombus(n);}

  @item{@rhombus(bits.(<<)) and @rhombus(bits.(>>)) perform a left shift
   or arithmetic right shift of @rhombus(n) by @rhombus(m) bits;}

  @item{@rhombus(bits.(?)) reports whether the bit at position
   @rhombus(m) (counting from 0 as the least-significant bit) is set within
   @rhombus(n);}

  @item{@rhombus(bits.length) reports the number of bits that remain in
   @rhombus(n) if all identical leading bits (@rhombus(0)s for a position
   @rhombus(n) or @rhombus(1)s for a negative @rhombus(n)) are removed;
   and}

  @item{@rhombus(bits.field) produces the integer represented by bits
   @rhombus(start) (inclusive) through @rhombus(end) (exclusive) of
   @rhombus(n).}

)

@examples(
  5 bits.and 3
  5 bits.or 3
  5 bits.xor 3
  bits.not 3
  5 bits.(<<) 2
  5 bits.(>>) 2
  bits.length(2)
  bits.length(-2)
  bits.field(255, 1, 4)
)

}
