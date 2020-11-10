import Foundation

/// Time based Last-Writer-Wins Observed-Remove Set
public typealias ReplicatingSet<Value: Hashable> = LWWORSet<Value, DisambiguousTimeInterval>

/// Last-Writer-Wins Observed-Remove Set
public struct LWWORSet<Value: Hashable, Timestamp: Timestampable> {

    fileprivate struct Metadata {

        var isDeleted: Bool = false
        var timestamp: Timestamp = .tick()
    }

    public var values: Set<Value> { internalSet }
    public var count: Int { internalSet.count }

    private var metadata: Dictionary<Int, Metadata> = [:]
    private var internalSet: Set<Value> = []

    public init() {

        metadata = [:]
        internalSet = []
    }

    public init(array elements: [Value]) {

        self.init()
        elements.forEach { self.insert($0) }
    }

    @discardableResult public mutating func insert(_ value: Value) -> Bool {

        var isNewInsert = false
        let hashValue = value.hashValue

        if var oldMetadata = metadata[hashValue] {

            isNewInsert = oldMetadata.isDeleted
            oldMetadata.isDeleted = false
            oldMetadata.timestamp.tick()
            metadata[hashValue] = oldMetadata
        } else {

            isNewInsert = true
            metadata[hashValue] = Metadata()
        }

        internalSet.insert(value)

        return isNewInsert
    }

    @discardableResult public mutating func remove(_ value: Value) -> Value? {

        let hashValue = value.hashValue

        if  var oldMetadata = metadata[hashValue],
            !oldMetadata.isDeleted {

            oldMetadata.isDeleted = true
            oldMetadata.timestamp.tick()
            metadata[hashValue] = oldMetadata
        }

        return internalSet.remove(value)
    }

    public func contains(_ value: Value) -> Bool { internalSet.contains(value) }
}

extension LWWORSet: Replicable {

    public func merged(with other: LWWORSet) -> LWWORSet {

        var result = self

        result.metadata = other.metadata.reduce(into: metadata) { (result, keyValuePair) in

            let firstMetadata = result[keyValuePair.key]
            let secondMetadata = keyValuePair.value
            if let firstMetadata = firstMetadata {

                result[keyValuePair.key] = firstMetadata.timestamp > secondMetadata.timestamp ? firstMetadata : secondMetadata
            } else {

                result[keyValuePair.key] = secondMetadata
            }
        }

        result.internalSet = result.internalSet
            .union(other.internalSet)
            .filter { result.metadata[$0.hashValue]?.isDeleted == false }

        return result
    }

}

extension LWWORSet.Metadata: Codable where Value: Codable {}
extension LWWORSet: Codable where Value: Codable {}


extension LWWORSet: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Value...) {

        self.init(array: elements)
    }
}
