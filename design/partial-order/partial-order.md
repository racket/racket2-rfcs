Partial Order
==========================

Summary
-------

A generic interface for partial orders.

Motivation
----------

I have 3 main motivations:
 - Ordering for sorted data structures.
 - Customizable equal-now-like behavior within Rhombus.
 - Equality within tolerance for testing `check-within`.

Note that most sorted data structures expect a total order,
not a partial order.
But a key type that implements a partial order can still be
useful if only a subset of keys are allowed which are all
comparable to each other: for example `Real` numbers only
have a partial order because NaN exists, but if they're
free to accept that and just error when they see NaN is
incomparable, they can still be very useful.

Design Options
--------------

### Option A: Comparison only, any resemblance to equality is entirely coincedental

Data definitions that want to implement partial orders only
need to implement one method: `partial_compare`.
Implementations of `partial_compare` are not expected to be
compatible with with `Equatable`, `==`, or Racket's `equal?`
in any way, and there is no hash code associated with this.

#### Interface to be implemented by data definitions privately

A `PartialOrdering` is a `Real` number:
 - Negative represents `<` less than
 - Zero represents `=` equal to
 - Positive represents `>` greater than
 - NaN represents incomparable

The interface `PartialOrder` is intended to be implemented
privately with the `partial_compare` method:

```
// Self is implicit
method partial_compare(other :: Imp, recur :: (Any, Any) -> PartialOrdering) :: PartialOrdering
```

The method implementation may assume that `other`'s method
implementation comes from the same type.

It is expected that mutable data structures can implement
`partial_compare` in a way that depends on mutable state,
and so ordering might change after mutation.

#### Operations to be used publicly

An `Ordering` is a comparable real number, excluding NaN:
 - Negative represents `<` less than
 - Zero represents `=` equal to
 - Positive represents `>` greater than

Functions:
 * `fun partial_compare(a, b) :: PartialOrdering`
   Follows type-specific `partial_compare` method implementations
   when the method implementations come from the same type.
   Produces NaN when they come from different types.
   When the types don't implement `PartialOrder`, it can
   use `equal?/recur` for a product order.
 * `fun compare(a, b) :: Ordering`
   Errors when `partial_compare` would produce NaN,
   otherwise produces the `Ordering` it would produce.
 * `fun within(a, b, epsilon :: Real) :: Boolean`
   Produces true when they compare equal, while allowing
   numbers within them to be different by at most epsilon
   from one another, false otherwise.

Operators:
 * `operator (a =~ b) :: Boolean` produces true when `partial_compare` produces zero, false when it produces something else (including NaN)
 * `operator (a !=~ b) :: Boolean` produces true when `partial_compare` produces something other than zero (including NaN), false on zero
 * `operator (a <~ b) :: Boolean` produces true when `compare` produces negative, false on positive or zero, and errors on errors (including errors when `partial_compare` produces NaN)
 * `operator (a >~ b) :: Boolean` produces true when `compare` produces positive, false on negative or zero, and errors on errors (including errors when `partial_compare` produces NaN)
 * `operator (a <=~ b) :: Boolean` produces true when `compare` produces negative or zero, false on positive, and errors on errors (including errors when `partial_compare` produces NaN)
 * `operator (a >=~ b) :: Boolean` produces true when `compare` produces positive or zero, false on negative, and errors on errors (including errors when `partial_compare` produces NaN)

### Option B: Comparison with hash, connected with equal-now

Data definitions that want to implement partial orders need
two methods: `partial_compare` and `compare_hash_code`.
Partial orders interact with Racket's `equal?/recur`
through product orders (not lexicographic orders).

#### Interface to be implemented by data definitions privately

The interface `PartialOrder` is intended to be implemented
privately with these methods:

```
// Self is implicit
method partial_compare(other :: Imp, recur :: (Any, Any) -> PartialOrdering) :: PartialOrdering

// Self is implicit
method compare_hash_code(recur :: (Any) -> Integer) :: Integer
```

The `partial_compare` method may assume that `other`'s
method implementation comes from the same type.

It is expected that mutable data structures can implement
partial orders in a way that depends on their mutable state,
and so ordering might change after mutation.

The `compare_hash_code` method can error when an element
isn't comparable to anything, not even itself (such as NaN).

#### Operations to be used publicly

Functions:
 * All the same functions from Option A: Comparison only
 * `fun compare_hash_code(a) :: Integer`
   Follows type-specific `compare_hash_code` method
   implementations, behaves compatibly with `.=` on  real
   numbers, and on other types, follows hash code methods
   from their equality implementations.
 * Racket's `equal?` and `equal-hash-code` can use these
   methods as well.

Operators:
 * All the same operators from Option A: Comparison only

### Option C: Comparison with key, connected with equal-now via hash-proc recur

Data definitions that want to implement partial orders can
either just implement the `compare_key` method, or
implement both `compare_key` and `partial_compare`.
Partial orders interact with Racket's `equal?/recur`
through product orders (not lexicographic orders).

#### Interface to be implemented by data definitions privately

The interface `PartialOrder` is intended to be implemented
privately with these methods:

```
// Self is implicit
method compare_key() :: Any

// Self is implicit
method partial_compare(other :: Imp, recur :: (Any, Any) -> PartialOrdering) :: PartialOrdering
```

With the `partial_compare` method optional.

The `partial_compare` method may assume that `other`'s
method implementation comes from the same type.

It is expected that mutable data structures can implement
partial orders in a way that depends on their mutable state,
and so ordering might change after mutation.

The `compare_key` method can error when an element isn't
comparable to anything, not even itself (such as NaN).

#### Operations to be used publicly

Functions:
 * All the same functions from Option B: Comparison with hash

Operators:
 * All the same operators from Option B: Comparison with hash

### Option D: Comparators produce false on incomparable values

The same as either option A, B, or C, except that when
values are incomparable, `<~`, `<=~`, `>~`, and `>=~` each
produce false instead of an error.

This allows some short-circuiting behavior, such as:

```
[2, Baddie1()] <=~ [1, Baddie2()]
[2, Baddie1()] <~ [1, Baddie2()]
```

These should return false immeditately after comparing `2`
and `1`, without comparing `Baddie1()` and `Baddie2()`.
Where option A, B, or C would try to compare `Baddie1()`
and `Baddie2()` to see whether they're comparable or not.

Option D-A provides the same interfaces and operations as
option A, but with the false results on incomparable values
and better short-circuiting.

Option D-B provides the same as option B, but with false
and short-circuiting.

Option D-C provides the same as option C, but with false
and short-circuiting.

Evaluation and Tradeoffs
------------------------

Option A is relatively simple and easier to implement than
Option B or C.

Option B and C provide more functionality with hash codes
and support for Racket's `equal?`.
But options B and C would probably require building this
into the core of Racket so that they can access `hash-proc`
methods with their recur arguments.

Between B and C, B is simpler to implement but slightly
harder for users.
While C is slightly trickier to implement but easier for
users.

Options A, B, and C can provide error messages where users
might expect values to be comparable when they're not.
This can help those users find errors more quickly if they
either have warped expectations from total orders, or when
they accidentally mix types that they didn't mean to mix.
Option D expects users of `<~`, `<=~`, etc. to know that
it's a partial order where values can be incomparable.
But option D's short-circuiting is very desirable, and
producing false results on incomparable values also makes
it more consistent overall, bringing `<~`, `<=~`, etc. more
in line with the behavior of `=~` and `!=~`.

Prior art and References
------------------------

The `compare_key` method in Option C is inspired by
[countvajhula's proposal](https://github.com/racket/rhombus-prototype/tree/master/design/equality)
to use a `key` method to define equality.

The use of negative/zero/positive numbers for less/equal/greater is inspired by 2 sources:
 * Gerbil Scheme's
   [Red-Black Trees](https://cons.io/reference/misc.html#red-black-trees)
   and their `cmp` argument.
 * Alexis King's
   [`alexis/util/comparator`](https://docs.racket-lang.org/alexis-util/Untyped_Utilities.html#%28part._.Comparison_.Predicate_.Generation%29)
   module, `define-comparison-predicates` macro.

The operater name `=~` is inspired by [Pyret's equal-now](https://www.pyret.org/docs/latest/equality.html).

Drawbacks and Unresolved questions
----------------------------------

Yet another equality predicate `=~`?
When there are already several of them, adding another
might be considered confusing.

Contributors
------------

Alex Knauth
Rocketnia
