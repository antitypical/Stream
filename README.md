# Stream

This is a Swift microframework providing a lazy `Stream<T>` type with generic implementations of `==`/`!=` where `T`: `Equatable`.

`Stream`s are lazily-populated as well as lazily-evaluated, making them convenient for procrastinating tasks you don’t want to do yet, like performing an expensive computation in successive stages.

You can construct `Stream`s with `SequenceType`s, use them as `SequenceType`s, and `map` and `fold` to your heart’s content.


## Use

Constructing a `Stream`:

```swift
let empty: Stream<Int> = nil
let unary = Stream.pure(4)
let binary = Stream.cons(4, nil)
let fibonacci: Stream<Int> = fix { fib in // fix is from Prelude.framework
	{ x, y in Stream.cons(x + y, fib(y, x + y)) }
}(0, 1)
```

Note that `fibonacci` is infinite! Don’t worry about it, just don’t evaluate it all in one go (like with a `for` loop that never `break`s).

It’s safe to extract values from any `Stream`, whether infinite or not:

```swift
let (first, rest) = fibonacci.uncons
let first = fibonacci.first
let rest = fibonacci.rest
let isEmpty = fibonacci.isEmpty
```

Better yet, use `take` and `drop` to do the heavy lifting for you, or `map` to compute whatever you need to in a new infinite `Stream`:

```swift
// Bad, infinite loops:
for each in fibonacci {}

// Okay, stops:
for each in fibonacci { break }

// Good, doesn’t compute anything til you iterate the result:
let firstFive = fibonacci.take(5)

// Best, doesn’t compute anything til you iterate, and it’s infinite too:
let fibonacciSquares = fibonacci.map { x in x * x }
```

You can combine `Stream`s together by concatenating them using the `++` operator—even infinite ones:

```swift
let aleph = fibonacci ++ fibonacci
```

This is more useful for prepending elements onto an infinite stream, though:

```swift
let fibonacciSquaresForABit = firstFive.map { x in x * x } ++ fibonacci.drop(5)
```

Full API documentation is in the source.


## Integration

1. Add this repository as a submodule and check out its dependencies, and/or [add it to your Cartfile](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile) if you’re using [carthage](https://github.com/Carthage/Carthage/) to manage your dependencies.
2. Drag `Stream.xcodeproj` into your project or workspace, and do the same with its dependencies (i.e. the other `.xcodeproj` files included in `Stream.xcworkspace`). NB: `Stream.xcworkspace` is for standalone development of Stream, while `Stream.xcodeproj` is for targets using Stream as a dependency.
3. Link your target against `Stream.framework` and each of the dependency frameworks.
4. Application targets should ensure that the framework gets copied into their application bundle. (Framework targets should instead require the application linking them to include Stream and its dependencies.)
