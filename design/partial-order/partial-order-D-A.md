Partial Order
==========================

### Option D-A: Comparison only, with false and short-circuiting

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
 * `operator (a <~ b) :: Boolean` produces true when `partial_compare` produces negative, false on anything else (including NaN)
 * `operator (a >~ b) :: Boolean` produces true when `partial_compare` produces positive, false on anything else (including NaN)
 * `operator (a <=~ b) :: Boolean` produces true when `partial_compare` produces negative or zero, false on anything else (including NaN)
 * `operator (a >=~ b) :: Boolean` produces true when `partial_compare` produces positive or zero, false on anything else (including NaN)

These operators have short-circuiting behavior, such as:

```
[2, Baddie(1)] <=~ [1, Baddie(2)]
[2, Baddie(1)] <~ [1, Baddie(2)]
```

These should return false immeditately after comparing `2`
and `1`, without comparing `Baddie1()` and `Baddie2()`.
Where option A, B, or C would try to compare `Baddie1()`
and `Baddie2()` to see whether they're comparable or not.
