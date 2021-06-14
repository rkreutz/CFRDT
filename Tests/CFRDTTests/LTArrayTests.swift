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
        XCTAssertEqual(a, [1,2,3])
    }

    func testInserting() {
        a.insert(1, at: 0)
        a.insert(2, at: 0)
        a.insert(3, at: 0)
        XCTAssertEqual(a, [3,2,1])
    }

    func testRemoving() {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)
        XCTAssertEqual(a, [1,3])
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
        XCTAssertEqual(a, [3,2,3])
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
        XCTAssertEqual(c, [7,8,9,1,2,3])
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
        XCTAssertEqual(d, [7,9,1,3])
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

        XCTAssertEqual(a.merged(with: b), [1,1,2,3,6,5])
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
        XCTAssertEqual(c, d)
        XCTAssertEqual(c, e)
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
        XCTAssertEqual(d, [7,9,1,3])
        XCTAssertEqual(d, c)
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

        let d = a.merged(with: b).merged(with: c)
        let e = a.merged(with: b.merged(with: c))
        let f = b.merged(with: a.merged(with: c))
        XCTAssertEqual(d, f)
        XCTAssertEqual(e, f)
        XCTAssertEqual(f, [11, 12, 5, 6, 7, 1, 3])
    }

    func testCodable() {
        a.append(1)
        a.append(2)
        a.remove(at: 1)
        a.append(3)

        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(LTArray<Int, DisambiguousTimeInterval>.self, from: data)
        XCTAssertEqual(d, a)
    }

    func testAppendSequence() {

        a.append(contentsOf: [3,2,1])
        a.append(contentsOf: [4,5,6])
        XCTAssertEqual(a, [3,2,1,4,5,6])
    }

    func testInsertSequence() {

        a.append(contentsOf: [1,2,3])
        a.insert(contentsOf: [4,5,6], at: 1)
        XCTAssertEqual(a, [1,4,5,6,2,3])
    }

    func testRangedSubscript() {
        a.append(contentsOf: [1,2,3,4,5,6])
        XCTAssertEqual(a[2..<4], [3,4])

        a[1..<4] = LTArray(a[1..<4].reversed())
        XCTAssertEqual(a, [1,4,3,2,5,6])

        a[0..<3] = [1,2,3,4,5,6]
        XCTAssertEqual(a, [1,2,3,4,5,6,2,5,6])
    }

    func testClosedRangeSubscript() {

        a.append(contentsOf: [1,2,3,4,5,6])
        XCTAssertEqual(a[2...4], [3,4,5])

        a[1...4] = LTArray(a[1...4].reversed())
        XCTAssertEqual(a, [1,5,4,3,2,6])

        a[0...3] = [1,2,3,4,5,6]
        XCTAssertEqual(a, [1,2,3,4,5,6,2,6])
    }

    func testPartialRangeSubscript() {

        a.append(contentsOf: [1,2,3,4,5,6])
        XCTAssertEqual(a[...3], [1,2,3,4])
        XCTAssertEqual(a[..<3], [1,2,3])
        XCTAssertEqual(a[3...], [4,5,6])
        var a1 = a!, a2 = a!, a3 = a!

        a1[1...] = LTArray<Int, DisambiguousTimeInterval>(a[1...].reversed())
        a2[...3] = LTArray<Int, DisambiguousTimeInterval>(a[...3].reversed())
        a3[..<3] = LTArray<Int, DisambiguousTimeInterval>(a[..<3].reversed())
        XCTAssertEqual(a1, [1,6,5,4,3,2])
        XCTAssertEqual(a2, [4,3,2,1,5,6])
        XCTAssertEqual(a3, [3,2,1,4,5,6])

        a1[3...] = [1,2,3,4,5,6]
        print(a1.values)
        a2[...3] = [1,2,3,4,5,6]
        print(a1.values)
        a3[..<3] = [1,2,3,4,5,6]
        print(a1.values)
        XCTAssertEqual(a1, [1,6,5,1,2,3,4,5,6])
        XCTAssertEqual(a2, [1,2,3,4,5,6,5,6])
        XCTAssertEqual(a3, [1,2,3,4,5,6,4,5,6])
    }

    func testRangeReplaceableConformance() {

        var a1: LTArray<Int, DisambiguousTimeInterval> = [1,2,3,4,5]
        a1.removeSubrange(1...3)
        XCTAssertEqual(a1, [1,5])

        var a2: LTArray<Int, DisambiguousTimeInterval> = [1,2,3,4,5]
        a2.removeFirst(3)
        XCTAssertEqual(a2, [4,5])

        var a3: LTArray<Int, DisambiguousTimeInterval> = [1,2,3,4,5]
        XCTAssertEqual(a3.removeFirst(), 1)
        XCTAssertEqual(a3, [2,3,4,5])

        var a4: LTArray<Int, DisambiguousTimeInterval> = [1,2,3,4,5]
        a4.removeAll()
        XCTAssertEqual(a4, [])

        var a5: LTArray<Int, DisambiguousTimeInterval> = [1,2,3,4,5]
        a5.removeAll(where: { $0 % 2 == 0 })
        XCTAssertEqual(a5, [1,3,5])

        var a6: LTArray<Int, DisambiguousTimeInterval> = [1,2,3,4,5]
        a6.replaceSubrange(1...4, with: [6,7,8,9,10])
        XCTAssertEqual(a6, [1,6,7,8,9,10])
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
        ("testAppendSequence", testAppendSequence),
        ("testInsertSequence", testInsertSequence),
        ("testRangedSubscript", testRangedSubscript),
        ("testClosedRangeSubscript", testClosedRangeSubscript),
        ("testPartialRangeSubscript", testPartialRangeSubscript),
        ("testRangeReplaceableConformance", testRangeReplaceableConformance),
    ]
}
