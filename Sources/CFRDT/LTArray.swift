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

    public mutating func insert(_ newValue: Element, at index: Int) {

        let new = makeEntry(withValue: newValue, forInsertingAtIndex: index)
        entries.insert(new, at: index)
    }

    public mutating func append(_ newValue: Element) { insert(newValue, at: entries.count) }

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

extension LTArray.Entry: Codable where Element: Codable {}
extension LTArray: Codable where Element: Codable {}

extension LTArray: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Element...) {

        elements.forEach { self.append($0) }
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
