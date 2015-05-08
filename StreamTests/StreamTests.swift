//  Copyright (c) 2015 Rob Rix. All rights reserved.

class StreamTests: XCTestCase {
	func testStreams() {
		let seq = [1, 2, 3, 4, 5, 6, 7, 8, 9]
		let stream = Stream(seq)

		XCTAssertEqual(stream.first ?? -1, 1)
		XCTAssertEqual(stream.first ?? -1, 1)
		XCTAssertEqual(stream.rest.first ?? -1, 2)
		XCTAssertEqual(stream.rest.first ?? -1, 2)
		XCTAssertEqual(stream.rest.rest.rest.first ?? -1, 4)

		var n = 0
		for (a, b) in Zip2(stream, seq) {
			n++
			XCTAssertEqual(a, b)
			XCTAssertEqual(n, a)
		}
		XCTAssertEqual(Array(stream), seq)
		XCTAssertEqual(n, seq.count)
	}

	func testEffectfulStreams() {
		var effects = 0
		let seq = SequenceOf<Int> {
			GeneratorOf {
				if effects < 5 {
					effects++
					return effects
				}
				return nil
			}
		}

		XCTAssertEqual(effects, 0)

		let stream = Stream(seq)
		XCTAssertEqual(effects, 1)

		let _ = stream.first
		XCTAssertEqual(effects, 1)

		let _ = stream.rest.first
		XCTAssertEqual(effects, 2)

		for each in stream {}
		XCTAssertEqual(effects, 5)

		XCTAssertEqual(stream.first ?? -1, 1)
		XCTAssertEqual(stream.rest.rest.rest.rest.first ?? -1, 5)
		XCTAssertNil(stream.rest.rest.rest.rest.rest.first)
		XCTAssertEqual(effects, 5)
	}

	func testStreamReduction() {
		XCTAssertEqual(reduce(Stream([1, 2, 3, 4]), 0, +), 10)
	}

	func testStreamReductionIsLeftReduce() {
		XCTAssertEqual(reduce(Stream(["1", "2", "3"]), "0", +), "0123")
		XCTAssertEqual(reduce(Stream.cons("1", Stream.cons("2", Stream.pure("3"))), "0", +), "0123")
	}

	func testConstructsNilFromGeneratorOfConstantNil() {
		XCTAssertTrue(Stream<Int> { nil } == nil)
	}

	func testConstructsConsFromGeneratorOfConstantNonNil() {
		let x: Int? = 1
		let stream = Stream { x }
		XCTAssertEqual(stream.first ?? -1, 1)
	}

	func testConstructsFiniteStreamFromGeneratorOfFiniteSequence() {
		let seq = [1, 2, 3]
		var generator = seq.generate()
		let stream = Stream { generator.next() }
		XCTAssertEqual(Array(stream), seq)
		XCTAssertEqual(reduce(stream, 0, +), 6)
		XCTAssertEqual(reduce(map(stream, toString), "0", +), "0123")
	}

	func testMapping() {
		let mapped = map(Stream([1, 2, 3]), { $0 * 2 })
		XCTAssertEqual(reduce(mapped, 0, +), 12)
	}

	func testCons() {
		let stream = Stream.pure(0)
		XCTAssertEqual(stream.first ?? -1, 0)
		XCTAssert(stream.rest == nil)
	}

	let fibonacci: Stream<Int> = fix { fib in
		{ x, y in Stream.cons(x + y, fib(y, x + y)) }
		}(0, 1)

	func testTake() {
		let stream = fibonacci.take(3)
		XCTAssertTrue(stream == Stream([1, 2, 3]))
	}

	func testTakeOfZeroIsNil() {
		let stream = fibonacci.take(0)
		XCTAssertTrue(stream == nil)
	}

	func testTakeOfNegativeIsNil() {
		let stream = fibonacci.take(-1)
		XCTAssertTrue(stream == nil)
	}

	func testDrop() {
		let stream = fibonacci.drop(3)
		XCTAssertEqual(stream.first ?? -1, 5)
	}

	func testDropOfZeroIsSelf() {
		let stream = Stream([1, 2, 3])
		XCTAssertTrue(stream.drop(0) == stream)
	}

	func testDropOfNegativeIsSelf() {
		let stream = Stream([1, 2, 3])
		XCTAssertTrue(stream.drop(-1) == stream)
	}

	func testMap() {
		XCTAssertEqual(Array(fibonacci.map { $0 * $0 }.take(3)), [1, 4, 9])
	}

	func testConcatenationOfNilAndNilIsNil() {
		XCTAssertEqual([Int]() + (nil ++ nil), [])
	}

	func testConcatenationOfNilAndXIsX() {
		XCTAssertEqual([Int]() + (nil ++ Stream.pure(0)), [0])
	}

	func testConcatenationOfXAndNilIsX() {
		XCTAssertEqual([Int]() + (Stream.pure(0) ++ nil), [0])
	}

	func testConcatenationOfXAndYIsXY() {
		XCTAssertEqual([Int]() + (Stream.pure(0) ++ Stream.pure(1)), [0, 1])
	}

	func testConcatenation() {
		let concatenated = Stream([1, 2, 3]) ++ Stream([4, 5, 6])
		XCTAssertEqual(reduce(concatenated, "0", { $0 + toString($1) }), "0123456")
	}

	func testFoldLeft() {
		XCTAssertEqual(Stream([1, 2, 3]).foldLeft("0", { $0 + toString($1) }), "0123")
	}

	func testFoldLeftWithEarlyTermination() {
		XCTAssertEqual(Stream([1, 2, 3]).foldLeft("0", { $0 + toString($1) } >>> Either.left), "01")
	}

	func testFoldRight() {
		XCTAssertEqual(Stream([1, 2, 3]).foldRight("4", { toString($0) + $1 }), "1234")
	}

	func testFoldRightWithEarlyTermination() {
		XCTAssertEqual(Stream([1, 2, 3]).foldRight("4", { (each: Int, rest: Memo<String>) in toString(each) }), "1")
	}

	func testUnfoldRight() {
		let fib = Stream.unfoldRight((0, 1)) { x, y in
			(x + y, (y, x + y))
		}
		XCTAssertEqual([Int]() + fib.take(5), [1, 2, 3, 5, 8])
	}

	func testUnfoldLeft() {
		let stream = Stream.unfoldLeft(5) { n in n >= 0 ? (n - 1, n) : nil }
		XCTAssertEqual([Int]() + stream, [0, 1, 2, 3, 4, 5])
	}

	func testArrayLiteralConvertible() {
		let stream: Stream<Int> = [1, 2, 3, 4, 5]
		XCTAssertEqual([Int]() + stream, [1, 2, 3, 4, 5])
	}
}


import Either
import Memo
import Prelude
import Stream
import XCTest
