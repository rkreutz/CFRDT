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

    func testInserting() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = []
        a.insert(1, at: 0)
        a.insert(2, at: 0)
        a.insert(3, at: 0)
        XCTAssertEqual(a, [3, 2, 1])
    }

    func testSingleInsert() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        XCTAssertFalse(a.insert(value: 1, at: 2).inserted)
        XCTAssertEqual(a.insert(value: 1, at: 2).index, 0)
    }

    func testUpdateOrInsert() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        let (updatedMember, updatedIndex) = a.updateOrInsert(1, at: 3)
        XCTAssertEqual(updatedMember, 1)
        XCTAssertEqual(updatedIndex, 0)
        let (insertedMember, insertedIndex) = a.updateOrInsert(4, at: 1)
        XCTAssertNil(insertedMember)
        XCTAssertEqual(insertedIndex, 1)
    }

    func testRemove() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        XCTAssertEqual(a.remove(1), 1)
        XCTAssertNil(a.remove(1))
        XCTAssertEqual(a, [2, 3])
    }

    func testMove() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]

        XCTAssertTrue(a.move(2, to: 2))
        XCTAssertEqual(a, [1, 3, 2])
    }

    func testContains() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        XCTAssertTrue(a.contains(1))
        XCTAssertFalse(a.contains(4))
        a.remove(1)
        XCTAssertFalse(a.contains(1))
    }

    func testCodable() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]

        a.remove(1)
        a.move(2, to: 1)
        a.append(4)
        a.insert(1, at: 2)

        XCTAssertNoThrow(String(data: try JSONEncoder().encode(a), encoding: .utf8))
        let json = "{\"tombstones\":{\"metadata\":{\"1\":{\"timestamp\":{\"id\":\"B4EF2D35-61BE-40E3-B6BD-0585B666CA93\",\"timeInterval\":\"1623710300.946465\"},\"isDeleted\":true}}},\"values\":[{\"value\":3,\"timestamp\":{\"id\":\"14D0C5FE-D0AD-4754-B015-2C0ED35F6E07\",\"timeInterval\":\"1623710300.9464068\"}},{\"value\":2,\"timestamp\":{\"id\":\"B055935C-0105-4229-B6F3-65B379A602DF\",\"timeInterval\":\"1623710300.946346\"}},{\"value\":1,\"timestamp\":{\"id\":\"37FC1D53-4E72-4E70-AE18-17B29267A7A2\",\"timeInterval\":\"1623710300.946466\"}},{\"value\":4,\"timestamp\":{\"id\":\"E4E3EAB8-672B-4011-BB5D-5A75021307B4\",\"timeInterval\":\"1623710300.946463\"}}]}"
        XCTAssertEqual(try JSONDecoder().decode(LWWOROrderedSet<Int, DisambiguousTimeInterval>.self, from: json.data(using: .utf8) ?? Data()), [3, 2, 1, 4])
    }

    func testSubscript() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]

        XCTAssertEqual(a[2], 3)
        XCTAssertEqual(a[1...2], [2, 3])

        a[2] = 4
        XCTAssertEqual(a, [1, 2, 4, 3])

        a[0] = 2
        XCTAssertEqual(a, [1, 2, 4, 3])

        a[0...2] = [5, 6]
        XCTAssertEqual(a, [5, 6, 3])

        a[1...2] = [6, 4]
        XCTAssertEqual(a, [5, 6, 4])
    }

    func testRemoveFirst() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]

        XCTAssertEqual(a.removeFirst(), 1)
        XCTAssertEqual(a, [2, 3])
        a.removeFirst(2)
        XCTAssertEqual(a, [])
        a.removeFirst(4)
        XCTAssertEqual(a, [])
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

    func testDeleteThenMerge() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        var copy = a
        copy.remove(2)

        XCTAssertEqual(a.merged(with: copy), [1, 3])
    }

    func testMoveThenMerge() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        var copy = a
        copy.move(2, to: 2)

        XCTAssertEqual(a.merged(with: copy), [1, 3, 2])
    }

    func testInsertThenMerge() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        var copy = a
        copy.insert(4, at: 1)

        XCTAssertEqual(a.merged(with: copy), [1, 4, 2, 3])
    }

    func testMergeOfInitiallyUnrelated() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        let b: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [4, 5, 6, 1, 2]
        let c = a.merged(with: b)
        XCTAssertEqual(c, [4, 5, 6, 3, 1, 2])
    }

    func testMultipleMerges() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        let b: LWWOROrderedSet<Int, DisambiguousTimeInterval> = []

        var c = b.merged(with: a)
        XCTAssertEqual(c, [1, 2, 3])

        c.append(4)
        c.append(5)
        c.append(6)

        let d = a.merged(with: c)
        XCTAssertEqual(d, [1, 2, 3, 4, 5, 6])
    }

    func testIdempotency() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        let b: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [4, 6]

        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        XCTAssertEqual(c, d)
        XCTAssertEqual(c, e)
    }

    func testCommutivity() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        let b: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [4, 6]

        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(c, d)
        XCTAssertEqual(c, [4, 1, 6, 2, 3])
    }

    func testAssociativity() {

        let a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        let b: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [4, 6]
        let c: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 5, 6]

        let d = a.merged(with: b).merged(with: c)
        let e = a.merged(with: b.merged(with: c))
        let f = b.merged(with: a.merged(with: c))
        XCTAssertEqual(d, f)
        XCTAssertEqual(e, f)
        XCTAssertEqual(f, [1, 4, 5, 2, 6, 3])
    }

    func testConvolutedMerge() {

        var a: LWWOROrderedSet<Int, DisambiguousTimeInterval> = [1, 2, 3]
        var copy = a

        a.append(5)
        a.remove(1)
        copy.move(1, to: 2)
        a.insert(contentsOf: [4, 6, 1], at: 1)
        copy.append(contentsOf: [4, 5, 6])

        XCTAssertEqual(a, [2, 4, 6, 1, 3, 5])
        XCTAssertEqual(copy, [2, 3, 1, 4, 5, 6])
        let merge = a.merged(with: copy)
        XCTAssertEqual(merge, [2, 3, 4, 1, 5, 6])
    }

    static var allTests = [
        ("testEquatable", testEquatable),
        ("testInserting", testInserting),
        ("testSingleInsert", testSingleInsert),
        ("testUpdateOrInsert", testUpdateOrInsert),
        ("testRemove", testRemove),
        ("testMove", testMove),
        ("testContains", testContains),
        ("testCodable", testCodable),
        ("testSubscript", testSubscript),
        ("testRemoveFirst", testRemoveFirst),
        ("testConcurrentMoves", testConcurrentMoves),
        ("testMergeOfInitiallyUnrelated", testMergeOfInitiallyUnrelated),
        ("testMultipleMerges", testMultipleMerges),
        ("testIdempotency", testIdempotency),
        ("testCommutivity", testCommutivity),
        ("testAssociativity", testAssociativity),
        ("testConvolutedMerge", testConvolutedMerge)
    ]
}
