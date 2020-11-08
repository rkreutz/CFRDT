import XCTest
@testable import CFRDT

final class LWWRegisterTests: XCTestCase {

    var a: LWWRegister<Int, DisambiguousTimeInterval>!
    var b: LWWRegister<Int, DisambiguousTimeInterval>!

    override func setUp() {

        super.setUp()
        a = 1
        b = 2
    }

    func testInitialCreation() {

        XCTAssertEqual(a.value, 1)
    }

    func testSettingValue() {

        a.value = 2
        XCTAssertEqual(a.value, 2)
        a.value = 3
        XCTAssertEqual(a.value, 3)
    }

    func testMergeOfInitiallyUnrelated() {

        let c = a.merged(with: b)
        XCTAssertEqual(c.value, b.value)
    }

    func testLastChangeWins() {

        a.value = 3
        let c = a.merged(with: b)
        XCTAssertEqual(c.value, a.value)
    }

    func testIdempotency() {

        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        XCTAssertEqual(c.value, d.value)
        XCTAssertEqual(c.value, e.value)
    }

    func testCommutativity() {

        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(d.value, c.value)
    }

    func testAssociativity() {

        let c: LWWRegister<Int, DisambiguousTimeInterval> = 3
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.value, f.value)
    }

    func testCodable() {

        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(LWWRegister<Int, DisambiguousTimeInterval>.self, from: data)
        XCTAssertEqual(a.entry.value, d.entry.value)
        XCTAssertEqual(a.entry.timestamp, d.entry.timestamp)
    }

    static var allTests = [
        ("testInitialCreation", testInitialCreation),
        ("testSettingValue", testSettingValue),
        ("testMergeOfInitiallyUnrelated", testMergeOfInitiallyUnrelated),
        ("testLastChangeWins", testLastChangeWins),
        ("testIdempotency", testIdempotency),
        ("testCommutativity", testCommutativity),
        ("testAssociativity", testAssociativity),
        ("testCodable", testCodable),
    ]
}
