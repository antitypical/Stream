//  Copyright (c) 2015 Rob Rix. All rights reserved.

/// An iterable stream.
public enum Stream<T>: ArrayLiteralConvertible, CollectionType, NilLiteralConvertible, Printable {

	// MARK: Constructors

	/// Initializes with a generating function.
	public init(_ f: () -> T?) {
		self = Stream.construct(f)()
	}

	/// Initializes with a `SequenceType`.
	public init<S: SequenceType where S.Generator.Element == T>(_ sequence: S) {
		var generator = sequence.generate()
		self.init({ generator.next() })
	}


	/// Maps a generator of `T?` into a generator of `Stream`.
	public static func construct(generate: () -> T?) -> () -> Stream {
		return fix { recur in
			{ generate().map { self.cons($0, recur()) } ?? nil }
		}
	}

	/// Constructs a `Stream` from `first` and its `@autoclosure`’d continuation.
	public static func cons(first: T, @autoclosure(escaping) _ rest: () -> Stream) -> Stream {
		return Cons(first, Memo(unevaluated: rest))
	}

	/// Constructs a `Stream` from `first` and its `Memo`ized continuation.
	public static func cons(first: T, _ rest: Memo<Stream>) -> Stream {
		return Cons(first, rest)
	}

	/// Constructs a unary `Stream` of `x`.
	public static func pure(x: T) -> Stream {
		return Cons(x, Memo { nil })
	}


	// MARK: Destructors

	/// Unpacks the receiver into an optional tuple of its first element and the memoized remainder.
	///
	/// Returns `nil` if the receiver is the empty stream.
	public var uncons: (T, Memo<Stream>)? {
		switch self {
		case let Cons(x, rest):
			return (x, rest)
		case Nil:
			return nil
		}
	}


	/// The first element of the receiver, or `nil` if the receiver is the empty stream.
	public var first: T? {
		return uncons?.0
	}

	/// The remainder of the receiver after its first element. If the receiver is the empty stream, this will return the empty stream.
	public var rest: Stream {
		return uncons?.1.value ?? nil
	}

	/// Is this the empty stream?
	public var isEmpty: Bool {
		return uncons == nil
	}


	// MARK: Combinators

	/// Returns a `Stream` of the first `n` elements of the receiver.
	///
	/// If `n` <= 0, returns the empty `Stream`.
	public func take(n: Int) -> Stream {
		if n <= 0 { return nil }

		return uncons.map { .cons($0, $1.value.take(n - 1)) } ?? nil
	}

	/// Returns a `Stream` without the first `n` elements of `stream`.
	///
	/// If `n` <= 0, returns the receiver.
	///
	/// If `n` <= the length of the receiver, returns the empty `Stream`.
	public func drop(n: Int) -> Stream {
		if n <= 0 { return self }

		return rest.drop(n - 1)
	}


	/// Returns a `Stream` produced by mapping the elements of the receiver with `f`.
	public func map<U>(f: T -> U) -> Stream<U> {
		return uncons.map { .cons(f($0), $1.value.map(f)) } ?? nil
	}


	/// Folds the receiver starting from a given `seed` using the left-associative function `combine`.
	public func foldLeft<Result>(seed: Result, _ combine: (Result, T) -> Result) -> Result {
		return foldLeft(seed, combine >>> Either.right)
	}

	/// Folds the receiver starting from a given `seed` using the left-associative function `combine`.
	///
	/// `combine` should return `.Left(x)` to terminate the fold with `x`, or `.Right(x)` to continue the fold.
	public func foldLeft<Result>(seed: Result, _ combine: (Result, T) -> Either<Result, Result>) -> Result {
		return uncons.map { first, rest in
			combine(seed, first).either(
				ifLeft: id,
				ifRight: { rest.value.foldLeft($0, combine) })
		} ?? seed
	}

	/// Folds the receiver ending with a given `seed` using the right-associative function `combine`.
	public func foldRight<Result>(seed: Result, _ combine: (T, Result) -> Result) -> Result {
		return uncons.map { combine($0, $1.value.foldRight(seed, combine)) } ?? seed
	}

	/// Folds the receiver ending with a given `seed` using the right-associative function `combine`.
	///
	/// `combine` receives the accumulator as a lazily memoized value. Thus, `combine` may terminate the fold simply by not evaluating the memoized accumulator.
	public func foldRight<Result>(seed: Result, _ combine: (T, Memo<Result>) -> Result) -> Result {
		return uncons.map { combine($0, $1.map { $0.foldRight(seed, combine) }) } ?? seed
	}


	/// Unfolds a new `Stream` starting from the initial state `state` and producing pairs of new states and values with `unspool`.
	///
	/// This is dual to `foldRight`. Where `foldRight` takes a right-associative combine function which takes the current value and the current accumulator and returns the next accumulator, `unfoldRight` takes the current state and returns the current value and the next state.
	public static func unfoldRight<State>(state: State, _ unspool: State -> (T, State)?) -> Stream {
		return unspool(state).map { value, next in self.cons(value, self.unfoldRight(next, unspool)) } ?? nil
	}

	/// Unfolds a new `Stream` starting from the initial state `state` and producing pairs of new states and values with `unspool`.
	///
	/// Since this unfolds to the left, it produces an eager `Stream` and thus is unsuitable for infinite `Stream`s.
	///
	/// This is dual to `foldLeft`. Where `foldLeft` takes a right-associative combine function which takes the current value and the current accumulator and returns the next accumulator, `unfoldLeft` takes the current state and returns the current value and the next state.
	public static func unfoldLeft<State>(state: State, _ unspool: State -> (State, T)?) -> Stream {
		// An alternative implementation replaced the cons in `unfoldRight`’s definition with the concatenation of recurrence and the value. While quite elegant, it ended up being a third slower.
		//
		// This would be a recursive function definition, except that local functions are disallowed from recurring.
		return fix { prepend in
			{ state, stream in
				unspool(state).map { next, value in prepend(next, self.cons(value, stream)) } ?? stream
			}
		} (state, nil)
	}


	// MARK: ArrayLiteralConvertible

	public init(arrayLiteral elements: T...) {
		self.init(elements)
	}


	// MARK: CollectionType

	public var startIndex: StreamIndex<T> {
		return StreamIndex(stream: self, index: isEmpty ? -1 : 0)
	}

	public var endIndex: StreamIndex<T> {
		return StreamIndex(stream: nil, index: -1)
	}

	public subscript (index: StreamIndex<T>) -> T {
		return index.stream.first!
	}


	// MARK: NilLiteralConvertible

	/// Constructs a `Nil` `Stream`.
	public init(nilLiteral: ()) {
		self = Nil
	}


	// MARK: Printable

	public var description: String {
		let describe: Stream -> [String] = fix { internalDescription in {
				switch $0 {
				case let Cons(x, rest):
					return [toString(x.value)] + internalDescription(rest.value)
				default:
					return []
				}
			}
		}
		return "(" + join(" ", describe(self)) + ")"
	}


	// MARK: SequenceType

	public func generate() -> IndexingGenerator<Stream> {
		return IndexingGenerator(self)
	}


	// MARK: Cases

	/// A `Stream` of a `T` and the lazily memoized rest of the `Stream`.
	///
	/// Avoid using this directly; instead, use `Stream.cons()` or `Stream.pure()` to construct streams, and `stream.first`, `stream.rest`, and `stream.uncons` to deconstruct them: they don’t require you to `Box` or unbox, `Stream.cons()` comes in `@autoclosure` and `Memo` varieties, and `Stream.pure()`, `Stream.cons()`, and `stream.uncons` are all usable as first-class functions.
	case Cons(T, Memo<Stream>)

	/// The empty `Stream`.
	///
	/// Avoid using this directly; instead, use `nil`: `Stream` conforms to `NilLiteralConvertible`, and `nil` has better properties with respect to type inferencing.
	case Nil
}

public struct StreamIndex<T>: ForwardIndexType {
	let stream: Stream<T>
	let index: Int


	// MARK: ForwardIndexType

	public func successor() -> StreamIndex {
		return StreamIndex(stream: stream.rest, index: stream.rest.isEmpty ? -1 : index + 1)
	}
}

public func == <T> (left: StreamIndex<T>, right: StreamIndex<T>) -> Bool {
	return left.index == right.index
}


// MARK: Concatenation

infix operator ++ {
	associativity right
	precedence 145
}

/// Produces the concatenation of `left` and `right`.
public func ++ <T> (left: Stream<T>, right: Stream<T>) -> Stream<T> {
	return left.uncons.map { first, rest in
		.cons(first, Memo { rest.value ++ right })
	} ?? right
}


// MARK: Equality.

/// Equality of `Stream`s of `Equatable` types.
///
/// We cannot declare that `Stream<T: Equatable>` conforms to `Equatable`, so this is defined ad hoc.
public func == <T: Equatable> (lhs: Stream<T>, rhs: Stream<T>) -> Bool {
	switch (lhs, rhs) {
	case let (.Cons(x, xs), .Cons(y, ys)) where x == y:
		return xs.value == ys.value
	case (.Nil, .Nil):
		return true
	default:
		return false
	}
}


/// Inequality of `Stream`s of `Equatable` types.
///
/// We cannot declare that `Stream<T: Equatable>` conforms to `Equatable`, so this is defined ad hoc.
public func != <T: Equatable> (lhs: Stream<T>, rhs: Stream<T>) -> Bool {
	switch (lhs, rhs) {
	case let (.Cons(x, xs), .Cons(y, ys)) where x == y:
		return xs.value != ys.value
	case (.Nil, .Nil):
		return false
	default:
		return true
	}
}


import Either
import Memo
import Prelude
