import Foundation

/// Time based Last-Writer-Wins Observed-Remove Dictionary
public typealias ReplicatingDictionary<Key: Hashable, Value> = LWWORDictionary<Key, Value, DisambiguousTimeInterval>

/// Last-Writer-Wins Observed-Remove Dictionary
public struct LWWORDictionary<Key: Hashable, Value, Timestamp: Timestampable> {

    fileprivate struct ValueContainer {

        var value: Value?
        var timestamp: Timestamp

        var isDeleted: Bool { value == nil }

        init(value: Value?, timestamp: Timestamp) {

            self.value = value
            self.timestamp = timestamp
        }
    }

    private var valueContainersByKey: [Key: ValueContainer]

    public var values: [Value] {

        valueContainersByKey.compactMap({ $0.value.value })
    }

    public var keys: [Key] {

        valueContainersByKey
            .filter({ !$0.value.isDeleted })
            .map({ $0.key })
    }

    public var dictionary: [Key: Value] {

        valueContainersByKey.compactMapValues({ $0.value })
    }

    public var count: Int {

        valueContainersByKey.reduce(0) { result, pair in

            result + (pair.value.isDeleted ? 0 : 1)
        }
    }

    public init() {
        
        valueContainersByKey = [:]
    }

    public subscript(key: Key) -> Value? {

        get {

            valueContainersByKey[key]?.value
        }

        set {

            if valueContainersByKey[key] != nil {

                valueContainersByKey[key]?.value = newValue
                valueContainersByKey[key]?.timestamp.tick()
            } else {

                valueContainersByKey[key] = ValueContainer(value: newValue, timestamp: .tick())
            }
        }
    }
}

extension LWWORDictionary: Replicable {

    public func merged(with other: LWWORDictionary) -> LWWORDictionary {

        var result = self

        result.valueContainersByKey = other.valueContainersByKey.reduce(into: valueContainersByKey) { result, keyValuePair in

            let firstValueContainer = result[keyValuePair.key]
            let secondValueContainer = keyValuePair.value

            if let firstValueContainer = firstValueContainer {

                result[keyValuePair.key] = firstValueContainer.timestamp > secondValueContainer.timestamp ?
                    firstValueContainer :
                    secondValueContainer
            } else {

                result[keyValuePair.key] = secondValueContainer
            }
        }

        return result
    }
}

public extension LWWORDictionary where Value: Replicable {

    func merged(with other: LWWORDictionary) -> LWWORDictionary {

        var resultDictionary = self

        resultDictionary.valueContainersByKey = other.valueContainersByKey.reduce(into: valueContainersByKey) { result, keyValuePair in

            let first = result[keyValuePair.key]
            let second = keyValuePair.value

            if let first = first {

                if let firstValue = first.value,
                   let secondValue = second.value {

                    var timestamp = Swift.max(first.timestamp, second.timestamp)
                    timestamp.tick()

                    let newValue = firstValue.merged(with: secondValue)
                    result[keyValuePair.key] = ValueContainer(value: newValue, timestamp: timestamp)
                } else {

                    result[keyValuePair.key] = first.timestamp > second.timestamp ? first : second
                }
            } else {

                result[keyValuePair.key] = second
            }
        }
        return resultDictionary
    }
}

extension LWWORDictionary.ValueContainer: Codable where Value: Codable, Key: Codable {}
extension LWWORDictionary: Codable where Value: Codable, Key: Codable {

    public init(from decoder: Decoder) throws {

        let container = try decoder.singleValueContainer()
        valueContainersByKey = try container.decode([Key: ValueContainer].self)
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.singleValueContainer()
        try container.encode(valueContainersByKey)
    }
}

extension LWWORDictionary: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (Key, Value)...) {

        self.valueContainersByKey = Dictionary(
            uniqueKeysWithValues: elements
                .map { ($0, ValueContainer(value: $1, timestamp: .tick())) }
        )
    }
}

extension LWWORDictionary: Sequence {

    @inlinable
    public func makeIterator() -> Dictionary<Key, Value>.Iterator {

        dictionary.makeIterator()
    }
}
