//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// An iterable stream.
public enum Stream<T>: ArrayLiteralConvertible, NilLiteralConvertible {

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
		return Cons(Box(first), Memo(unevaluated: rest))
	}

	/// Constructs a `Stream` from `first` and its `Memo`ized continuation.
	public static func cons(first: T, _ rest: Memo<Stream>) -> Stream {
		return Cons(Box(first), rest)
	}

	/// Constructs a unary `Stream` of `x`.
	public static func pure(x: T) -> Stream {
		return Cons(Box(x), Memo { nil })
	}


	// MARK: Destructors

	/// Unpacks the receiver into an optional tuple of its first element and the memoized remainder.
	///
	/// Returns `nil` if the receiver is the empty stream.
	public func uncons() -> (T, Memo<Stream>)? {
		switch self {
		case let Cons(x, rest):
			return (x.value, rest)
		case Nil:
			return nil
		}
	}


	/// The first element of the receiver, or `nil` if the receiver is the empty stream.
	public var first: T? {
		return uncons()?.0
	}

	/// The remainder of the receiver after its first element. If the receiver is the empty stream, this will return the empty stream.
	public var rest: Stream {
		return uncons()?.1.value ?? nil
	}

	/// Is this the empty stream?
	public var isEmpty: Bool {
		return uncons() == nil
	}


	// MARK: Combinators

	/// Returns a `Stream` of the first `n` elements of the receiver.
	///
	/// If `n` <= 0, returns the empty `Stream`.
	public func take(n: Int) -> Stream {
		if n <= 0 { return nil }

		return uncons().map { .cons($0, $1.value.take(n - 1)) } ?? nil
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


	// MARK: ArrayLiteralConvertible

	public init(arrayLiteral elements: T...) {
		self.init(elements)
	}


	// MARK: NilLiteralConvertible

	/// Constructs a `Nil` `Stream`.
	public init(nilLiteral: ()) {
		self = Nil
	}


	// MARK: Cases

	/// A `Stream` of a `T` and the lazily memoized rest of the `Stream`.
	///
	/// Avoid using this directly; instead, use `Stream.cons()` or `Stream.pure()` to construct streams, and `stream.first`, `stream.rest`, and `stream.uncons()` to deconstruct them: they don’t require you to `Box` or unbox, `Stream.cons()` comes in `@autoclosure` and `Memo` varieties, and `Stream.pure()`, `Stream.cons()`, and `stream.uncons()` are all usable as first-class functions.
	case Cons(Box<T>, Memo<Stream>)

	/// The empty `Stream`.
	///
	/// Avoid using this directly; instead, use `nil`: `Stream` conforms to `NilLiteralConvertible`, and `nil` has better properties with respect to type inferencing.
	case Nil
}


// MARK: Concatenation

infix operator ++ {
	associativity right
	precedence 145
}

/// Produces the concatenation of `left` and `right`.
public func ++ <T> (left: Stream<T>, right: Stream<T>) -> Stream<T> {
	return left.uncons().map { first, rest in
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


import Box
import Memo
import Prelude
