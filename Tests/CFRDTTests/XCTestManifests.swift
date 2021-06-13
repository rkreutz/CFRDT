import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(LTArrayTests.allTests),
        testCase(LWWORDictionaryTests.allTests),
        testCase(LWWOROrderedSetTests.allTests),
        testCase(LWWORSetTests.allTests),
        testCase(LWWRegisterTests.allTests),
        testCase(ReplicatingStringTests.allTests),
    ]
}
#endif
