import Foundation

/// Time based Linked Tree Array
public typealias ReplicatingArray<Element> = LTArray<Element, DisambiguousTimeInterval>

/// Linked Tree Array
public struct LTArray<Element, Timestamp: Timestampable> {

    fileprivate struct Entry: Identifiable {

        var anchor: ID?
        var value: Element?
        var timestamp: Timestamp = .tick()
        var id = UUID()

        var isDeleted: Bool { value == nil }

        mutating func tick() {

            timestamp.tick()
        }

        func ordered(beforeSibling other: Entry) -> Bool { timestamp > other.timestamp }
    }

    private var entries: [Entry] = []
    private var tombstones: [Entry] = []

    public var values: [Element] { entries.compactMap { $0.value } }
    public var count: Int { entries.count }

    public init() {}

    public subscript(bounds: ClosedRange<Int>) -> LTArray<Element, Timestamp> {

        get { self[Range(bounds)] }
        set { self[Range(bounds)] = newValue }
    }

    public subscript(bounds: PartialRangeFrom<Int>) -> LTArray<Element, Timestamp> {

        get { self[Range(uncheckedBounds: (bounds.lowerBound, count))] }
        set { self[Range(uncheckedBounds: (bounds.lowerBound, count))] = newValue }
    }

    public subscript(bounds: PartialRangeUpTo<Int>) -> LTArray<Element, Timestamp> {

        get { self[Range(uncheckedBounds: (0, bounds.upperBound))] }
        set { self[Range(uncheckedBounds: (0, bounds.upperBound))] = newValue }
    }

    public subscript(bounds: PartialRangeThrough<Int>) -> LTArray<Element, Timestamp> {

        get { self[ClosedRange(uncheckedBounds: (0, bounds.upperBound))] }
        set { self[ClosedRange(uncheckedBounds: (0, bounds.upperBound))] = newValue }
    }
}

extension LTArray: Replicable {

    public func merged(with other: Self) -> Self {

        let resultTombstones = (tombstones + other.tombstones)
            .sorted(by: { $0.ordered(beforeSibling: $1) })
            .filterDuplicates { $0.id }

        let tombstoneIds = resultTombstones.map { $0.id }

        var encounteredIds: Set<Entry.ID> = []
        let orderedEntries = (entries + other.entries)
            .sorted(by: { $0.ordered(beforeSibling: $1) })
            .filter { !tombstoneIds.contains($0.id) && encounteredIds.insert($0.id).inserted }

        let resultEntriesWithTombstones = Self.ordered(fromEntries: orderedEntries, tombstones: resultTombstones)
        let resultEntries = resultEntriesWithTombstones.filter { !$0.isDeleted }

        var result = self
        result.entries = resultEntries
        result.tombstones = resultTombstones
        return result
    }

    private static func ordered(fromEntries entries: [Entry], tombstones: [Entry]) -> [Entry] {

        let anchoredByAnchorId = [Entry.ID?: [Entry]](
            grouping: (entries + tombstones).sorted(by: { $0.ordered(beforeSibling: $1) }),
            by: { $0.anchor }
        )

        var result: [Entry] = []

        func addDecendants(of containers: [Entry]) {

            for container in containers {

                result.append(container)
                guard let anchoredToValueContainer = anchoredByAnchorId[container.id] else { continue }
                addDecendants(of: anchoredToValueContainer)
            }
        }

        let roots = anchoredByAnchorId[nil] ?? []
        addDecendants(of: roots)
        return result
    }
}

extension LTArray: Equatable where Element: Equatable {

    public static func == (lhs: LTArray<Element, Timestamp>, rhs: LTArray<Element, Timestamp>) -> Bool {

        lhs.values == rhs.values
    }
}

extension LTArray.Entry: Codable where Element: Codable {}
extension LTArray: Codable where Element: Codable {}

extension LTArray: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Element...) {

        elements.forEach { append($0) }
    }
}

extension LTArray: Collection, RandomAccessCollection {

    public var startIndex: Int { entries.startIndex }
    public var endIndex: Int { entries.endIndex }
    public func index(after index: Int) -> Int { entries.index(after: index) }

    public subscript(_ index: Int) -> Element {

        get { entries[index].value! } //swiftlint:disable:this force_unwrapping
        set {

            remove(at: index)
            let newEntry = makeEntry(withValue: newValue, forInsertingAtIndex: index)
            entries.insert(newEntry, at: index)
        }
    }

    public subscript(bounds: Range<Int>) -> LTArray<Element, Timestamp> {

        get { LTArray(Slice(base: self, bounds: bounds)) }

        set {

            bounds.reversed().forEach { remove(at: $0) }
            insert(contentsOf: newValue, at: bounds.lowerBound)
        }
    }
}

extension LTArray: RangeReplaceableCollection {

    public init<Sequence: Swift.Sequence>(_ sequence: Sequence) where Sequence.Element == Element {

        sequence.forEach { append($0) }
    }

    public mutating func insert(_ newValue: Element, at index: Int) {

        let new = makeEntry(withValue: newValue, forInsertingAtIndex: index)
        entries.insert(new, at: index)
    }

    public mutating func insert<Sequence: Swift.Sequence>(contentsOf sequence: Sequence, at index: Int) where Sequence.Element == Element {

        sequence.reversed().forEach { insert($0, at: index) }
    }

    public mutating func append(_ newValue: Element) { insert(newValue, at: entries.count) }

    public mutating func append<Sequence: Swift.Sequence>(contentsOf sequence: Sequence) where Sequence.Element == Element {

        sequence.forEach { append($0) }
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Element {

        var entry = entries[index]
        let value = entry.value! //swiftlint:disable:this force_unwrapping
        entry.value = nil
        entry.tick()
        tombstones.append(entry)
        entries.remove(at: index)
        return value
    }

    public mutating func removeSubrange(_ bounds: Range<Int>) {

        bounds.reversed().forEach { remove(at: $0) }
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
    ) where Element == Collection.Element {

        self[subrange] = LTArray(newElements)
    }
}

private extension LTArray {

    func makeEntry(withValue value: Element, forInsertingAtIndex index: Int) -> Entry {

        let anchor = index > 0 ? entries[index - 1].id : nil
        return Entry(anchor: anchor, value: value)
    }
}

private extension Array {

    func filterDuplicates(identifyingWith block: (Element) -> AnyHashable) -> Self {

        var encountered: Set<AnyHashable> = []
        return filter { encountered.insert(block($0)).inserted }
    }
}
