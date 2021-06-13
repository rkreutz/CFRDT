import XCTest
@testable import CFRDT

final class LWWOROrderedSetTests: XCTestCase {

    func testEquatable() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        let b: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [2, 3, 1]

        XCTAssertEqual(a, [1, 2, 3])
        XCTAssertEqual(b, [2, 3, 1])
        XCTAssertNotEqual(a, b)
    }

    func testMove() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]

        XCTAssertTrue(a.move(2, to: 2))
        XCTAssertEqual(a, [1, 3, 2])
    }

    func testConcurrentMoves() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        var aCopy = a

        aCopy.move(1, to: 1)
        XCTAssertEqual(aCopy, [2, 1, 3])

        a.move(1, to: 2)
        XCTAssertEqual(a, [2, 3, 1])

        XCTAssertEqual(a.merged(with: aCopy), [2, 3, 1])
        XCTAssertEqual(aCopy.merged(with: a), [2, 3, 1])

        var b: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        var bCopy = b

        b.move(1, to: 2)
        XCTAssertEqual(b, [2, 3, 1])

        bCopy.move(1, to: 1)
        XCTAssertEqual(bCopy, [2, 1, 3])

        XCTAssertEqual(b.merged(with: bCopy), [2, 1, 3])
        XCTAssertEqual(bCopy.merged(with: b), [2, 1, 3])
    }

    static var allTests = [
        ("testMove", testMove),
        ("testConcurrentMoves", testConcurrentMoves)
    ]
}
