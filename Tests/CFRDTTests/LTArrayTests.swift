import XCTest
@testable import CFRDT

final class LTArrayTests: XCTestCase {

    var a: LTArray<Int, DisambiguousTimeInterval>!
    var b: LTArray<Int, DisambiguousTimeInterval>!

    override func setUp() {
        super.setUp()
        a = []
        b = []
    }

    func testInitialCreation() {
        XCTAssertEqual(a.count, 0)
    }

    func testAppending() {
        a.append(1)
        a.append(2)
        a.append(3)
        XCTAssertEqual(a.values, [1,2,3])
    }

    func testInserting() {
        a.insert(1, at: 0)
        a.insert(2, at: 0)
        a.insert(3, at: 0)
        XCTAssertEqual(a.values, [3,2,1])
    }

    func testRemoving() {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)
        XCTAssertEqual(a.values, [1,3])
        XCTAssertEqual(a.count, 2)
    }

    func testInterleavedInsertAndRemove() {
        a.append(1)
        a.append(2)
        a.remove(at: 1) // [1]
        a.append(3)
        a.remove(at: 0) // [3]
        a.append(1)
        a.append(2)
        a.remove(at: 1) // [3,2]
        a.append(3)
        XCTAssertEqual(a.values, [3,2,3])
    }

    func testMergeOfInitiallyUnrelated() {
        a.append(1)
        a.append(2)
        a.append(3)

        // Force the lamport of b higher, so it comes first
        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)

        let c = a.merged(with: b)
        XCTAssertEqual(c.values, [7,8,9,1,2,3])
    }

    func testMergeWithRemoves() {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)

        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        b.remove(at: 1)

        let d = b.merged(with: a)
        XCTAssertEqual(d.values, [7,9,1,3])
    }

    func testMultipleMerges() {
        a.append(1)
        a.append(2)
        a.append(3)

        b = b.merged(with: a)

        b.insert(1, at: 0)
        b.remove(at: 0)

        b.insert(1, at: 0)
        b.append(5)

        a.append(6)

        XCTAssertEqual(a.merged(with: b).values, [1,1,2,3,6,5])
    }

    func testIdempotency() {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)

        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        b.remove(at: 1)

        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        XCTAssertEqual(c.values, d.values)
        XCTAssertEqual(c.values, e.values)
    }

    func testCommutivity() {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)

        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        b.remove(at: 1)

        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(d.values, [7,9,1,3])
        XCTAssertEqual(d.values, c.values)
    }

    func testAssociativity() {
        a.append(1)
        a.append(2)
        a.remove(at: 1)
        a.append(3)

        b.append(5)
        b.append(6)
        b.append(7)

        var c: LTArray<Int, DisambiguousTimeInterval> = [10,11,12]
        c.remove(at: 0)

        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.values, f.values)
    }

    func testCodable() {
        a.append(1)
        a.append(2)
        a.remove(at: 1)
        a.append(3)

        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(LTArray<Int, DisambiguousTimeInterval>.self, from: data)
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
