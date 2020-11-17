import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(LTArrayTests.allTests),
        testCase(LWWORDictionaryTests.allTests),
        testCase(LWWORSetTests.allTests),
        testCase(LWWRegisterTests.allTests),
    ]
}
#endif
