//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// An iterable stream.
public enum Stream<T>: NilLiteralConvertible {

	// MARK: Constructors

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


	// MARK: NilLiteralConvertible

	/// Constructs a `Nil` `Stream`.
	public init(nilLiteral: ()) {
		self = Nil
	}


	// MARK: Cases

	/// A `Stream` of a `T` and the lazily memoized rest of the `Stream`.
	case Cons(Box<T>, Memo<Stream<T>>)

	/// The empty `Stream`.
	///
	/// Avoid using this directly; instead, use `nil`: `Stream` conforms to `NilLiteralConvertible`, and `nil` has better properties with respect to type inferencing.
	case Nil
}


import Box
import Memo
