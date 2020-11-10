import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(LWWRegisterTests.allTests),
        testCase(LWWORSetTests.allTests),
    ]
}
#endif
