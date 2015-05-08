//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// An iterable stream.
public enum Stream<T> {
	// MARK: Cases

	/// A `Stream` of a `T` and the lazily memoized rest of the `Stream`.
	case Cons(Box<T>, Memo<Stream<T>>)

	/// The empty `Stream`.
	case Nil
}


import Box
import Memo
