Generic Immutable Lists
=======================

This document proposes a design for generic immutable lists in Rhombus, as well as a plan for implementing them.

Motivation
----------

Lists come in many flavors, with many different performance characteristics. Forces programmers to interact with each of these flavors with different APIs leads to complexity, confusion, and inconsistencies. It hampers expressive power, as algorithms that operate on lists must tie themselves to specific implementations. Performance also suffers, as a lack of support for the most optimal list implementation for a task can lead programmers to choose suboptimal implementations instead. A generic interface for list processing can solve some of these problems.

Out of scope
------------

This design document focuses solely on immutable lists, and leaves open the design of mutable lists as well as other collections. Discussion on these topics can be found in #201 and #221.

Summary
-------

A `List` interface is provided from a `rhombus/list` module alongside various implementations of it. The basic structure of the interface is this:

```
interface List:
    method get(index)
    method set(index, element)
    method add(element) # Adds to the end of the list
    method insert(index, element)
    method remove(element) # Removes first occurrence of element from list
    method removeAt(index)
    method sublist(start, end) # Returns a view
    property size
```

Various other methods that can be derived from these may be included, but this is the core interface that list implementations must supply. The following implementations will be provided:

- `ConsList`, which is what the current Rhombus `List` implementation is. This is primarily intended for use in the Rhombus implementation itself, to avoid dependencies on collection implementations. The existing `List` implementation will be renamed to `ConsList`.
- `PersistentList`, an immutable list backed by an RRB-tree that supports efficient reads and (functional) writes.
- `ArrayList`, an immutable list backed by a Racket vector. This is also roughly what the current Rhombus `Array` implementation is, with the exception that a Rhombus `Array` can be mutable or immutable. The `ArrayList` `List` implementation is solely for lists backed by immutable arrays.
- `EmptyList` and `SingletonList`, specialized implementations for empty lists and single-element lists that avoid the overheads of trees and arrays.

Rather than ask users to carefully consider their use case and select the appropriate implementation every time a list is needed, the `List` interface will provide mechanisms to intelligently select a desirable implementation:

- A `List.builder()` function for creating a *list builder*, a write-only object which allows mutably constructing a list with its `add()` method. Calling `build()` on a builder produces an immutable list backed by an `ArrayList`. Using builders avoids the overhead of the tree structures in `PersistentList` entirely. Insertion into the builder can avoid allocation too by using the standard approach of maintaining an internal mutable array that is doubled in size as elements are inserted. The builder can also decide whether to use `EmptyList` or `SingletonList` based on the number of inserted elements at the time `build()` is called.
- Whenever the update methods on an `ArrayList`, `EmptyList`, or `SingletonList` are called, the underlying list will be copied into a `PersistentList`. This allows efficient functional updates on the lists created by a list builder with an amortized constant cost.
- The bracketed list construction notation `[a, b, c]` will be equivalent to `List(a, b, c)`, which will construct an array-backed list.

These choices are based on the following assumptions:

- Most lists are created, then read and iterated. Interleaved reads and updates to a list are rare.
- When interleaved reads and writes *are* necessary, the initial starting list is usually small, frequently the empty list or a singleton list.
- Iterating and accessing flat arrays is faster than cons lists and RRB trees.

RRB Trees
---------

The `PersistentList` implementation will be backed by relaxed radix-balanced trees as described in the paper ["RRB-Trees: Efficient Immutable Vectors"](https://citeseerx.ist.psu.edu/viewdoc/download;jsessionid=F16EC1235F2CFF0ED612C3C1ADC87EAF?doi=10.1.1.592.5377&rep=rep1&type=pdf). Stencil vectors will be used internally to improve the performance of some of the vector operations performed by the tree.

Equality
--------

Two lists are equal if they contain the same elements in the same order. **This should be true even if the lists use different implementation classes!** An `EmptyList` and a `PersistentList` with zero elements must be equal, and an `ArrayList` and a `PersistentList` must be equal if they have the same contents. This can be achieved by making `List` supply a default implementation of `Equatable` for all lists.

Sublist Views
-------------

The `List.sublist()` method returns a _view_. A view is an object that is an adapator over some other object. The sublist view will hold a pointer to the entire original list and use the start and end indices to do some index math when retrieving elements from the underlying list. This runs in constant time and works for any immutable list, at the expense of holding on to the whole list in memory unless an explicit copy is created.

Indexing Notation
-----------------

The `List` interface will implement the `Indexable` interface, allowing `list[i]` to access the `i`th element of the list. An exception is thrown if the index is out of bounds. The `List` interface will **not** implement `MutableIndexable`, as `List` is not mutable.

Module Organization
-------------------

The `List` interface will be exported from a `rhombus/list` module and require explicit imports to use. However, the `[]` notation for list literals won't require you import `rhombus/list` to construct lists.

Because several different implementations of the `List` interface need to refer to each other (for example, `ArrayList` needs to switch to a `PersistentList` when updated) and because it would be unwieldy to define all the implementations in the same file, internally within Rhombus things will be a bit more split up. The core `List` interface will be defined on its own in an internal module, then re-exported from `rhombus/list` along with the other list implementations. This allows each implementation to be in a separate module and for the implementations to import each other as needed. To avoid circular dependencies, `PersistentList` will be self-contained and will _not_ switch back to `EmptyList` if all elements are removed from it.

Batch Processing Methods
------------------------

This design does not yet include features for batch operations on list  such as adding or removing multiple elements at once or concatenating two lists. Likely this will be addressed in future work by `List.addAll()` and `List.removeAll()` methods that accept arbitrary sequences, with fast paths based on the type of sequence provided (such as efficiently concatenating two `PersistentList`s). A similar `ListBuilder.addAll()` method would allow batch insertion into a builder, making `List.builder().addAll(bigList.sublist(start, end)).build()` one possible way to create a sublist that does not keep a reference to the original list.

Sequence Interface
------------------

For now we're going to continue to use Racket's `sequence?` type and make `List` function as a sequence. This allows lists to cooperate with `for` in both Racket and Rhombus.

Examples
--------

```
> [1, 2, 3]
[1, 2, 3]

> List(1, 2, 3)
[1, 2, 3]

> [1, 2, 3].add(4)
[1, 2, 3, 4]

> [1, 2, 3].remove(2)
[1, 3]

> [1, 2, 3].size
3

> [1, 2, 3][0]
1

> [1, 2, 3].set(1, 200)
[1, 200, 3]

> [1, 2, 3].insert(1, 100)
[1, 100, 2, 3]

> [1, 2, 3].removeAt(1)
[1, 3]

> [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].sublist(3, 8)
[4, 5, 6, 7, 8]

> [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].sublist(3, 8).size
5

> [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].sublist(3, 8)[0]
4
```

Implementation Plan
-------------------

The implementation has a few parts:

1. Making room in the existing Rhombus implementation by renaming `List` to `ConsList`
2. Adding the actual `List` interface
3. Making `ConsList` implement `List`
4. Implementing empty lists, singleton lists, and `ArrayList`
5. Implementing a `ListBuilder`
6. Implementing RRB trees
7. Adding `PersistentList` backed by RRB trees

Everything except implementing RRB trees depends on the first two steps. Additionally, implementing `ListBuilder` depends on `EmptyList`, `SingletonList`, and `ArrayList` being implemented since that's what it will build. Those lists also technically depend on `PersistentList` so they can switch to it on update, but a first step to `EmptyList`, `SingletonList`, and `ArrayList` can simply throw an exception on update instead so we can fill in that part later.
