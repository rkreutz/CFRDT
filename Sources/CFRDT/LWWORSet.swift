import Foundation

/// Time based Last-Writer-Wins Observed-Remove Set
public typealias ReplicatingSet<Value: Hashable> = LWWORSet<Value, DisambiguousTimeInterval>

/// Last-Writer-Wins Observed-Remove Set
public struct LWWORSet<Value: Hashable, Timestamp: Timestampable> {

    fileprivate struct Metadata {

        var isDeleted: Bool = false
        var timestamp: Timestamp = .tick()
    }

    private var metadata = [Value: Metadata]()

    public var values: Set<Value> {

        let values = metadata.filter({ !$1.isDeleted }).map({ $0.key })
        return Set(values)

    }

    public var count: Int {

        metadata.reduce(0) { result, pair in
            result + (pair.value.isDeleted ? 0 : 1)
        }
    }

    public init() {}

    public init(array elements: [Value]) {

        self.init()
        elements.forEach { self.insert($0) }
    }

    @discardableResult
    public mutating func insert(_ value: Value) -> Bool {

        var isNewInsert = false

        if var oldMetadata = metadata[value] {

            isNewInsert = oldMetadata.isDeleted
            oldMetadata.isDeleted = false
            oldMetadata.timestamp.tick()
            metadata[value] = oldMetadata
        } else {

            isNewInsert = true
            metadata[value] = Metadata()
        }

        return isNewInsert
    }

    @discardableResult
    public mutating func remove(_ value: Value) -> Value? {

        guard
            var oldMetadata = metadata[value],
            !oldMetadata.isDeleted
        else { return nil }

        oldMetadata.isDeleted = true
        oldMetadata.timestamp.tick()
        metadata[value] = oldMetadata

        return value
    }

    public func contains(_ value: Value) -> Bool {

        metadata[value]?.isDeleted == false
    }
}

extension LWWORSet: Replicable {

    public func merged(with other: LWWORSet) -> LWWORSet {

        var result = self

        result.metadata = other.metadata.reduce(into: metadata) { result, keyValuePair in

            let firstMetadata = result[keyValuePair.key]
            let secondMetadata = keyValuePair.value
            if let firstMetadata = firstMetadata {

                result[keyValuePair.key] = firstMetadata.timestamp > secondMetadata.timestamp ? firstMetadata : secondMetadata
            } else {

                result[keyValuePair.key] = secondMetadata
            }
        }

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

extension LWWORSet {

    func timestamp(for value: Value) -> Timestamp? {

        metadata[value]?.timestamp
    }
}
