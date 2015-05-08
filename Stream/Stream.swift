//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// An iterable stream.
public enum Stream<T>: NilLiteralConvertible {
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
