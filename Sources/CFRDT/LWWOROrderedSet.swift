import Foundation
import OrderedCollections

/// Time based Last-Writer-Wins Observed-Remove Ordered Set
public typealias ReplicatingOrderedSet<Value: Hashable> = LWWOROrderedSet<Value, DisambiguousTimeInterval>

/// Last-Writer-Wins Observed-Remove Ordered Set
public struct LWWOROrderedSet<Value: Hashable, Timestamp: Timestampable> {

    fileprivate struct InternalElement: Hashable {

        var value: Value
        var timestamp: Timestamp = .tick()

        func hash(into hasher: inout Hasher) {

            hasher.combine(value)
        }

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.value == rhs.value }
    }

    private var tombstones = LWWORSet<Value, Timestamp>()
    private var values: OrderedSet<InternalElement> = []

    public init() {}

    public init(array values: [Value]) {

        self.init()
        self.values = OrderedSet(values.map { InternalElement(value: $0) })
    }

    @discardableResult
    public mutating func insert(
        value: Value,
        at index: Int
    ) -> (inserted: Bool, index: Int) {

        tombstones.remove(value)
        return values.insert(InternalElement(value: value), at: index)
    }

    @discardableResult
    public mutating func updateOrInsert(
        _ item: Value,
        at index: Int
    ) -> (originalMember: Value?, index: Int) {

        let (original, index) = values.updateOrInsert(InternalElement(value: item), at: index)
        tombstones.remove(item)
        return (original?.value, index)
    }

    @discardableResult
    public mutating func remove(_ value: Value) -> Value? {

        let internalElement = InternalElement(value: value)
        guard let removedValue = values.remove(internalElement)?.value else { return nil }
        tombstones.insert(value)
        return removedValue
    }

    @discardableResult
    public mutating func move(_ value: Value, to destinationIndex: Index) -> Bool {

        let element = InternalElement(value: value)
        guard let sourceIndex = values.firstIndex(of: element) else { return false }
        for index in Swift.min(sourceIndex, destinationIndex) ... Swift.max(sourceIndex, destinationIndex) {

            if index == sourceIndex { continue }
            var mutatedElement = values.remove(at: index)
            mutatedElement.timestamp.tick()
            values.insert(mutatedElement, at: index)
        }
        values.remove(at: sourceIndex)
        return values.insert(element, at: destinationIndex).inserted
    }

    public func contains(_ value: Value) -> Bool {

        values.contains(InternalElement(value: value))
    }
}

extension LWWOROrderedSet: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Value...) {

        self.init(array: elements)
    }
}

extension LWWOROrderedSet: CustomStringConvertible where Value: CustomStringConvertible {

    public var description: String { "[" + values.map(\.value.description).joined(separator: ", ") + "]" }
}

extension LWWOROrderedSet: Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.values == rhs.values }
}

extension LWWOROrderedSet.InternalElement: Codable where Value: Codable {}
extension LWWOROrderedSet: Codable where Value: Codable {}

extension LWWOROrderedSet: Replicable {

    public func merged(with other: LWWOROrderedSet) -> LWWOROrderedSet {

        var result = self
        result.tombstones = tombstones.merged(with: other.tombstones)
        result.values = []

        for index in 0 ..< Swift.max(values.count, other.values.count) {

            let lhs: InternalElement? = index < values.count ? values[index] : nil
            let rhs: InternalElement? = index < other.values.count ? other.values[index] : nil

            switch (lhs, rhs) {

            // We have the same index-value pair on both sets
            case let (.some(lhs), .some(rhs)) where lhs == rhs:
                // Use the latest
                result.values.append(lhs.timestamp > rhs.timestamp ? lhs : rhs)

            // Each index-value pair were removed on the alternate set
            case let (.some(lhs), .some(rhs)) where result.tombstones.contains(lhs.value) && result.tombstones.contains(rhs.value):
                let lhsTombstoneTimestamp = result.tombstones.timestamp(for: lhs.value).unsafelyUnwrapped
                let rhsTombstoneTimestamp = result.tombstones.timestamp(for: rhs.value).unsafelyUnwrapped
                let shouldRemoveLhs = lhsTombstoneTimestamp > lhs.timestamp
                let shouldRemoveRhs = rhsTombstoneTimestamp > rhs.timestamp
                switch (shouldRemoveLhs, shouldRemoveRhs) {

                // If both should be maintained and lhs is the latest we add it first
                case (false, false) where lhs.timestamp >= rhs.timestamp:
                    result.tombstones.remove(lhs.value)
                    result.tombstones.remove(rhs.value)
                    result.values.append(lhs)
                    result.values.append(rhs)

                // If both should be maintained and lhs is the oldest, we add rhs first
                case (false, false):
                    result.tombstones.remove(rhs.value)
                    result.tombstones.remove(lhs.value)
                    result.values.append(rhs)
                    result.values.append(lhs)

                // If rhs should be removed, we'll only add lhs
                case (false, true):
                    result.tombstones.remove(lhs.value)
                    result.values.append(lhs)

                // If lhs should be removed, we'll only add rhs
                case (true, false):
                    result.tombstones.remove(rhs.value)
                    result.values.append(rhs)

                // If both should be removed we won't add them to the set
                case (true, true):
                    break
                }

            // If lhs was removed in the alternate set, and rhs was moved in the alternate set
            case let (.some(lhs), .some(rhs)) where result.tombstones.contains(lhs.value) && values.contains(rhs):
                let lhsTombstoneTimestamp = result.tombstones.timestamp(for: lhs.value).unsafelyUnwrapped
                let shouldRemoveLhs = lhsTombstoneTimestamp > lhs.timestamp
                let rhsInLhsTimestamp = values[values.firstIndex(of: rhs).unsafelyUnwrapped].timestamp
                let shouldMoveRhs = rhsInLhsTimestamp < rhs.timestamp
                switch (shouldRemoveLhs, shouldMoveRhs) {

                // If we should remove lhs and move rhs, we'll simply append rhs to the set
                case (true, true):
                    result.values.append(rhs)

                // If we should maintain lhs and move rhs, we'll add both but the latest one will be first
                case (false, true):
                    result.tombstones.remove(lhs.value)
                    if lhs.timestamp < rhs.timestamp {

                        result.values.append(rhs)
                        result.values.append(lhs)
                    } else {

                        result.values.append(lhs)
                        result.values.append(rhs)
                    }

                // If we should remove lhs and NOT move rhs, we don't add any of them to the set
                case (true, false):
                    break

                // If we should maintain lhs and NOT move rhs, we just add lhs to the set
                case (false, false):
                    result.tombstones.remove(lhs.value)
                    result.values.append(lhs)
                }

            // If lhs was removed in the alternate set, and rhs was added
            case let (.some(lhs), .some(rhs)) where result.tombstones.contains(lhs.value):
                let lhsTombstoneTimestamp = result.tombstones.timestamp(for: lhs.value).unsafelyUnwrapped
                let shouldRemoveLhs = lhsTombstoneTimestamp > lhs.timestamp
                if shouldRemoveLhs {

                    // If we should remove lhs we only add rhs
                    result.values.append(rhs)
                } else {

                    // If we should keep both
                    result.tombstones.remove(lhs.value)
                    // We'll add first the latest one
                    if lhs.timestamp < rhs.timestamp {

                        result.values.append(rhs)
                        result.values.append(lhs)
                    } else {

                        result.values.append(lhs)
                        result.values.append(rhs)
                    }
                }

            // If rhs was removed in the alternate set, and lhs was moved in the alternate set
            case let (.some(lhs), .some(rhs)) where result.tombstones.contains(rhs.value) && other.values.contains(lhs):
                let rhsTombstoneTimestamp = result.tombstones.timestamp(for: rhs.value).unsafelyUnwrapped
                let shouldRemoveRhs = rhsTombstoneTimestamp > rhs.timestamp
                let lhsInRhsTimestamp = other.values[other.values.firstIndex(of: lhs).unsafelyUnwrapped].timestamp
                let shouldMoveLhs = lhsInRhsTimestamp < lhs.timestamp
                switch (shouldRemoveRhs, shouldMoveLhs) {

                // If we should remove rhs and move lhs, we'll simply append lhs to the set
                case (true, true):
                    result.values.append(lhs)

                // If we should maintain rhs and move lhs, we'll add both but the latest one will be first
                case (false, true):
                    result.tombstones.remove(rhs.value)
                    if lhs.timestamp < rhs.timestamp {

                        result.values.append(rhs)
                        result.values.append(lhs)
                    } else {

                        result.values.append(lhs)
                        result.values.append(rhs)
                    }

                // If we should remove rhs and NOT move lhs, we don't add any of them to the set
                case (true, false):
                    break

                // If we should maintain rhs and NOT move lhs, we just add rhs to the set
                case (false, false):
                    result.tombstones.remove(rhs.value)
                    result.values.append(rhs)
                }

            // If rhs was removed in the alternate set, and lhs was added
            case let (.some(lhs), .some(rhs)) where result.tombstones.contains(rhs.value):
                let rhsTombstoneTimestamp = result.tombstones.timestamp(for: rhs.value).unsafelyUnwrapped
                let shouldRemoveRhs = rhsTombstoneTimestamp > rhs.timestamp
                if shouldRemoveRhs {

                    // If we should remove rhs we only add lhs
                    result.values.append(lhs)
                } else {

                    // If we should keep both
                    result.tombstones.remove(rhs.value)
                    // We'll add first the latest one
                    if lhs.timestamp < rhs.timestamp {

                        result.values.append(rhs)
                        result.values.append(lhs)
                    } else {

                        result.values.append(lhs)
                        result.values.append(rhs)
                    }
                }

            // In case both values were moved in the alternate set
            case let (.some(lhs), .some(rhs)) where other.values.contains(lhs) && values.contains(rhs):
                let lhsInRhsTimestamp = other.values[other.values.firstIndex(of: lhs).unsafelyUnwrapped].timestamp
                let shouldMoveLhs = lhsInRhsTimestamp < lhs.timestamp
                let rhsInLhsTimestamp = values[values.firstIndex(of: rhs).unsafelyUnwrapped].timestamp
                let shouldMoveRhs = rhsInLhsTimestamp < rhs.timestamp
                switch (shouldMoveLhs, shouldMoveRhs) {

                // Case both must be moved in the new set
                case (true, true):
                    // We add the latest first
                    if lhs.timestamp < rhs.timestamp {

                        result.values.append(rhs)
                        result.values.append(lhs)
                    } else {

                        result.values.append(lhs)
                        result.values.append(rhs)
                    }

                // In case rhs is the only one to be moved
                case (false, true):
                    result.values.append(rhs)

                // In case lhs is the only one to be moved
                case (true, false):
                    result.values.append(lhs)

                // In case none should be moved
                case (false, false):
                    break
                }

            // In case lhs was moved in the alternate set and rhs was added.
            case let (.some(lhs), .some(rhs)) where other.values.contains(lhs):
                let lhsInRhsTimestamp = other.values[other.values.firstIndex(of: lhs).unsafelyUnwrapped].timestamp
                let shouldMoveLhs = lhsInRhsTimestamp < lhs.timestamp
                if shouldMoveLhs {

                    if lhs.timestamp < rhs.timestamp {

                        result.values.append(rhs)
                        result.values.append(lhs)
                    } else {

                        result.values.append(lhs)
                        result.values.append(rhs)
                    }
                } else {

                    result.values.append(rhs)
                }

            // In case rhs was moved in the alternate set and lhs was added
            case let (.some(lhs), .some(rhs)) where values.contains(rhs):
                let rhsInLhsTimestamp = values[values.firstIndex(of: rhs).unsafelyUnwrapped].timestamp
                let shouldMoveRhs = rhsInLhsTimestamp < rhs.timestamp
                if shouldMoveRhs {

                    if lhs.timestamp < rhs.timestamp {

                        result.values.append(rhs)
                        result.values.append(lhs)
                    } else {

                        result.values.append(lhs)
                        result.values.append(rhs)
                    }
                } else {

                    result.values.append(lhs)
                }

            // If both were added
            case let (.some(lhs), .some(rhs)):
                // We'll add first the latest one
                if lhs.timestamp < rhs.timestamp {

                    result.values.append(rhs)
                    result.values.append(lhs)
                } else {

                    result.values.append(lhs)
                    result.values.append(rhs)
                }

            // If the element being added was deleted in the alternate set
            case let (.none, .some(element)) where result.tombstones.contains(element.value),
                 let (.some(element), .none) where result.tombstones.contains(element.value):
                let tombstoneTimestamp = result.tombstones.timestamp(for: element.value).unsafelyUnwrapped
                // We'll add it to the new set if the tombstone is older than the new value
                if tombstoneTimestamp <= element.timestamp {

                    result.tombstones.remove(element.value)
                    result.values.append(element)
                }

            // If rhs was moved
            case let (.none, .some(rhs))  where values.contains(rhs):
                let rhsInLhsTimestamp = values[values.firstIndex(of: rhs).unsafelyUnwrapped].timestamp
                let shouldMoveRhs = rhsInLhsTimestamp < rhs.timestamp
                if shouldMoveRhs {

                    result.values.append(rhs)
                }

            // If lhs was moved
            case let (.some(lhs), .none) where other.values.contains(lhs):
                let lhsInRhsTimestamp = other.values[other.values.firstIndex(of: lhs).unsafelyUnwrapped].timestamp
                let shouldMoveLhs = lhsInRhsTimestamp < lhs.timestamp
                if shouldMoveLhs {

                    result.values.append(lhs)
                }

            // If the element was added we simply append it to the set
            case let (.none, .some(element)),
                 let (.some(element), .none):
                result.values.append(element)

            case (.none, .none):
                // This should never happen
                fatalError("Reached an index (\(index)) which is out of bounds of both replicating sets...")
            }
        }

        return result
    }
}

extension LWWOROrderedSet: Collection, RandomAccessCollection {

    public var startIndex: Int { values.startIndex }
    public var endIndex: Int { values.endIndex }
    public func index(after index: Int) -> Int { values.index(after: index) }

    public subscript(_ index: Int) -> Value {

        get { values[index].value }
        set { insert(newValue, at: index) }
    }

    public subscript(bounds: Range<Int>) -> LWWOROrderedSet<Value, Timestamp> {

        get { LWWOROrderedSet(Slice(base: self, bounds: bounds)) }

        set {

            bounds.reversed().forEach { remove(at: $0) }
            insert(contentsOf: newValue, at: bounds.lowerBound)
        }
    }

    public subscript(bounds: ClosedRange<Int>) -> LWWOROrderedSet<Value, Timestamp> {

        get { self[Range(bounds)] }
        set { self[Range(bounds)] = newValue }
    }

    public subscript(bounds: PartialRangeFrom<Int>) -> LWWOROrderedSet<Value, Timestamp> {

        get { self[Range(uncheckedBounds: (bounds.lowerBound, count))] }
        set { self[Range(uncheckedBounds: (bounds.lowerBound, count))] = newValue }
    }

    public subscript(bounds: PartialRangeUpTo<Int>) -> LWWOROrderedSet<Value, Timestamp> {

        get { self[Range(uncheckedBounds: (0, bounds.upperBound))] }
        set { self[Range(uncheckedBounds: (0, bounds.upperBound))] = newValue }
    }

    public subscript(bounds: PartialRangeThrough<Int>) -> LWWOROrderedSet<Value, Timestamp> {

        get { self[ClosedRange(uncheckedBounds: (0, bounds.upperBound))] }
        set { self[ClosedRange(uncheckedBounds: (0, bounds.upperBound))] = newValue }
    }
}

extension LWWOROrderedSet: RangeReplaceableCollection {

    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Element == Value {

        values = OrderedSet(sequence.map { InternalElement(value: $0) })
    }

    public mutating func insert(_ newValue: Value, at index: Int) {

        tombstones.remove(newValue)
        values.insert(InternalElement(value: newValue), at: index)
    }

    public mutating func insert<Sequence: Swift.Sequence>(contentsOf sequence: Sequence, at index: Int) where Sequence.Element == Value {

        sequence.reversed().forEach { insert($0, at: index) }
    }

    public mutating func append(_ newValue: Value) { insert(newValue, at: values.count) }

    public mutating func append<Sequence: Swift.Sequence>(contentsOf sequence: Sequence) where Sequence.Element == Value {

        sequence.forEach { append($0) }
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Value {

        let value = values.remove(at: index).value
        tombstones.insert(value)
        return value
    }

    public mutating func removeSubrange(_ bounds: Range<Int>) {

        bounds.reversed()
            .filter { $0 < values.count }
            .forEach { remove(at: $0) }
    }

    @discardableResult
    public mutating func removeFirst() -> Element {

        remove(at: 0)
    }

    public mutating func removeFirst(_ k: Int) {

        removeSubrange(0 ..< k)
    }

    public mutating func replaceSubrange<Collection: Swift.Collection>(
        _ subrange: Range<Int>,
        with newElements: Collection
    ) where Value == Collection.Element {

        self[subrange] = LWWOROrderedSet(newElements)
    }
}
