import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(LWWORDictionaryTests.allTests),
        testCase(LWWORSetTests.allTests),
        testCase(LWWRegisterTests.allTests),
    ]
}
#endif
