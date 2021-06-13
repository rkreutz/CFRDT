import XCTest
@testable import CFRDT

final class ReplicatingStringTests: XCTestCase {

    func testStringInterpolation() {

        let replicatingString: ReplicatingString = "Some string"
        XCTAssertEqual("\(replicatingString)", "Some string")
    }

    static var allTests = [
        ("testStringInterpolation", testStringInterpolation)
    ]
}
