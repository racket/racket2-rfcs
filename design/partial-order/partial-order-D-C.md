Partial Order
==========================

### Option D-C: Comparison with key, with false and short-circuiting

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
 * `fun compare_hash_code(a) :: Integer`
   Follows type-specific `compare_hash_code` method
   implementations, behaves compatibly with `.=` on  real
   numbers, and on other types, follows hash code methods
   from their equality implementations.
 * Racket's `equal?` and `equal-hash-code` can use these
   methods as well.

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
