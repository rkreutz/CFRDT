import Foundation
import Collections

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

    fileprivate struct Tombstone: Hashable {

        var value: Value
        var position: LWWOROrderedSet<Value, Timestamp>.Index
    }

    private var tombstones = LWWORSet<Tombstone, Timestamp>()
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

        let (inserted, originalIndex) = values.insert(InternalElement(value: value), at: index)
        guard inserted else { return (false, originalIndex) }

        for index in (index + 1) ..< values.count {

            var mutableValue = values.remove(at: index)
            mutableValue.timestamp.tick()
            tombstones.insert(Tombstone(value: mutableValue.value, position: index))
            values.insert(mutableValue, at: index)
        }

        tombstones.remove(Tombstone(value: value, position: index))
        return (true, index)
    }

    @discardableResult
    public mutating func updateOrInsert(
        _ item: Value,
        at index: Int
    ) -> (originalMember: Value?, index: Int) {

        let (original, index) = values.updateOrInsert(InternalElement(value: item), at: index)

        if original == nil {

            for index in (index + 1) ..< values.count {

                var mutableValue = values.remove(at: index)
                mutableValue.timestamp.tick()
                tombstones.insert(Tombstone(value: mutableValue.value, position: (index - 1)))
                values.insert(mutableValue, at: index)
            }
        }

        tombstones.remove(Tombstone(value: item, position: index))
        return (original?.value, index)
    }

    @discardableResult
    public mutating func remove(_ value: Value) -> Value? {

        let internalElement = InternalElement(value: value)

        guard
            let index = values.firstIndex(of: internalElement),
            let removedValue = values.remove(internalElement)?.value
        else { return nil }

        tombstones.insert(Tombstone(value: value, position: index))
        for index in index ..< values.count {

            var mutableValue = values.remove(at: index)
            mutableValue.timestamp.tick()
            tombstones.insert(Tombstone(value: mutableValue.value, position: (index + 1)))
            values.insert(mutableValue, at: index)
        }

        return removedValue
    }

    @discardableResult
    public mutating func move(_ value: Value, to destinationIndex: Index) -> Bool {

        let element = InternalElement(value: value)
        guard let sourceIndex = values.firstIndex(of: element) else { return false }

        for index in Swift.min(sourceIndex, destinationIndex) ... Swift.max(sourceIndex, destinationIndex) {

            tombstones.insert(Tombstone(value: values[index].value, position: index))
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

extension LWWOROrderedSet.Tombstone: Codable where Value: Codable {}
extension LWWOROrderedSet.InternalElement: Codable where Value: Codable {}
extension LWWOROrderedSet: Codable where Value: Codable {}

extension LWWOROrderedSet: Replicable {

    public func merged(with other: LWWOROrderedSet) -> LWWOROrderedSet {

        var result = self
        result.tombstones = tombstones.merged(with: other.tombstones)
        result.values = []
        var dequeToAdd = Deque<InternalElement>()

        func mostUpToDate(_ lhs: InternalElement?, _ rhs: InternalElement?, index: Int) -> InternalElement? {

            switch (lhs, rhs) {

            case (.none, .none):
                return nil

            case let (.none, .some(element)),
                 let (.some(element), .none):
                guard let tombstone = result.tombstones.timestamp(for: Tombstone(value: element.value, position: index)) else { return rhs }
                return element.timestamp > tombstone ? element : nil

            case let (.some(lhs), .some(rhs)):
                let lhsTombstone = result.tombstones.timestamp(for: Tombstone(value: lhs.value, position: index))
                let rhsTombstone = result.tombstones.timestamp(for: Tombstone(value: rhs.value, position: index))
                switch (lhsTombstone, rhsTombstone) {

                case let (.some(lhsTombstone), .some(rhsTombstone)) where lhs.timestamp <= lhsTombstone && rhs.timestamp <= rhsTombstone:
                    return nil

                case let (.some(lhsTombstone), .none) where lhs.timestamp <= lhsTombstone:
                    return rhs

                case let (.none, .some(rhsTombstone)) where rhs.timestamp <= rhsTombstone:
                    return lhs

                case (_, _) where lhs.value == rhs.value:
                    return lhs.timestamp > rhs.timestamp ? lhs : rhs

                case (_, _) where lhs.timestamp > rhs.timestamp:
                    return lhs

                default:
                    return rhs
                }
            }
        }

        var index = 0
        while index < values.count || index < other.values.count || !dequeToAdd.isEmpty {

            let lhs: InternalElement? = index < values.count ? values[index] : nil
            let rhs: InternalElement? = index < other.values.count ? other.values[index] : nil
            let deque: InternalElement? = dequeToAdd.popFirst()

            let mostUpToDate = mostUpToDate(mostUpToDate(lhs, rhs, index: index), deque, index: index)
            if let toAdd = mostUpToDate {

                result.values.append(toAdd)
                result.tombstones.remove(Tombstone(value: toAdd.value, position: index))
            }

            if mostUpToDate == deque {

                lhs.map { dequeToAdd.append($0) }
                rhs.map { dequeToAdd.append($0) }
                dequeToAdd.sort(by: { $0.timestamp > $1.timestamp })
            } else if mostUpToDate == lhs {

                rhs.map { dequeToAdd.append($0) }
                dequeToAdd.sort(by: { $0.timestamp > $1.timestamp })
                deque.map { dequeToAdd.prepend($0) }
            } else if mostUpToDate == rhs {

                lhs.map { dequeToAdd.append($0) }
                dequeToAdd.sort(by: { $0.timestamp > $1.timestamp })
                deque.map { dequeToAdd.prepend($0) }
            } else {

                lhs.map { dequeToAdd.append($0) }
                rhs.map { dequeToAdd.append($0) }
                dequeToAdd.sort(by: { $0.timestamp > $1.timestamp })
                deque.map { dequeToAdd.prepend($0) }
            }

            index += 1
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

        insert(value: newValue, at: index)
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

        remove(values[index].value).unsafelyUnwrapped
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
