import XCTest
@testable import CFRDT

final class LWWORSetTests: XCTestCase {

    var a: LWWORSet<Int, DisambiguousTimeInterval>!
    var b: LWWORSet<Int, DisambiguousTimeInterval>!

    override func setUp() {
        super.setUp()
        a = []
        b = []
    }

    func testInitialCreation() {
        XCTAssertEqual(a.count, 0)
    }

    func testAppending() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        XCTAssertEqual(a.values, [1,2,3])
    }

    func testInserting() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        XCTAssertEqual(a.values, Set([3,2,1]))
    }

    func testRemoving() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(2)
        XCTAssertEqual(a.contains(1), true)
        XCTAssertEqual(a.contains(2), false)
        XCTAssertEqual(a.contains(4), false)
        XCTAssertEqual(a.values, Set([1,3]))
        XCTAssertEqual(a.count, 2)
    }

    func testInterleavedInsertAndRemove() {
        a.insert(1)
        a.insert(2)
        a.remove(1) // 2
        a.insert(3)
        a.remove(2) // 3
        a.insert(1)
        a.insert(2) // 1,2,3
        a.remove(1) // 2,3
        a.insert(3) // 2,3
        XCTAssertEqual(a.values, Set([2,3]))
    }

    func testMergeOfInitiallyUnrelated() {
        a.insert(1)
        a.insert(2)
        a.insert(3)

        b.insert(10)
        b.remove(10)
        b.insert(7)
        b.insert(8)
        b.insert(9)

        let c = a.merged(with: b)
        XCTAssertEqual(c.values, Set([7,8,9,1,2,3]))
    }

    func testMergeWithRemoves() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(1) // 2,3

        b.insert(1)
        b.remove(0)
        b.insert(7)
        b.insert(8)
        b.insert(9)
        b.remove(1) // 7,8,9

        let d = b.merged(with: a)
        XCTAssertEqual(d.values, Set([2,3,7,8,9]))
    }

    func testMultipleMerges() {
        a.insert(1)
        a.insert(2)
        a.insert(3)

        b = b.merged(with: a)

        b.insert(10)
        b.remove(10)

        b.insert(1)
        b.insert(5) // [1,2,3,5]

        a.insert(6) // [1,2,3,6]

        XCTAssertEqual(a.merged(with: b).values, Set([1,2,3,5,6]))
    }

    func testIdempotency() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(1)

        b.insert(1)
        b.remove(1)
        b.insert(7)
        b.insert(8)
        b.insert(9)
        b.remove(8)

        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        XCTAssertEqual(c.values, d.values)
        XCTAssertEqual(c.values, e.values)
    }

    func testCommutivity() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(2)

        b.insert(10)
        b.remove(10)
        b.insert(7)
        b.insert(8)
        b.insert(9)
        b.remove(8)

        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(d.values, Set([7,9,1,3]))
        XCTAssertEqual(d.values, c.values)
    }

    func testAssociativity() {
        a.insert(1)
        a.insert(2)
        a.remove(2)
        a.insert(3)

        b.insert(5)
        b.insert(6)
        b.insert(7)

        var c: LWWORSet<Int, DisambiguousTimeInterval> = [10,11,12]
        c.remove(10)

        let d = a.merged(with: b).merged(with: c)
        let e = a.merged(with: b.merged(with: c))
        let f = b.merged(with: a.merged(with: c))
        XCTAssertEqual(d.values, f.values)
        XCTAssertEqual(e.values, f.values)
    }

    func testCodable() {
        a.insert(1)
        a.insert(2)
        a.remove(2)
        a.insert(3)

        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(LWWORSet<Int, DisambiguousTimeInterval>.self, from: data)
        XCTAssertEqual(d.values, a.values)
    }

    static var allTests = [
        ("testInitialCreation", testInitialCreation),
        ("testAppending", testAppending),
        ("testInserting", testInserting),
        ("testRemoving", testRemoving),
        ("testInterleavedInsertAndRemove", testInterleavedInsertAndRemove),
        ("testMergeOfInitiallyUnrelated", testMergeOfInitiallyUnrelated),
        ("testMergeWithRemoves", testMergeWithRemoves),
        ("testMultipleMerges", testMultipleMerges),
        ("testIdempotency", testIdempotency),
        ("testCommutivity", testCommutivity),
        ("testAssociativity", testAssociativity),
        ("testCodable", testCodable),
    ]
}
