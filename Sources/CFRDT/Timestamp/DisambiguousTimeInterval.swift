import Foundation

public struct DisambiguousTimeInterval: Timestampable, Identifiable {

    public static func tick() -> DisambiguousTimeInterval { DisambiguousTimeInterval() }

    public var id: UUID = UUID()
    public var timeInterval: TimeInterval = Date().timeIntervalSince1970

    public mutating func tick() {

        id = UUID()
        timeInterval = Date().timeIntervalSince1970
    }
}

extension DisambiguousTimeInterval: Codable {

    public enum CodingKeys: CodingKey {

        case id
        case timeInterval
    }

    public init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        guard let timeInterval = TimeInterval(try container.decode(String.self, forKey: .timeInterval)) else {

            throw DecodingError.dataCorruptedError(forKey: .timeInterval, in: container, debugDescription: "Failed to parse TimeInterval")
        }
        self.timeInterval = timeInterval
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode("\(timeInterval)", forKey: .timeInterval)
    }
}

extension DisambiguousTimeInterval: Comparable {

    public static func < (lhs: DisambiguousTimeInterval, rhs: DisambiguousTimeInterval) -> Bool {

        (lhs.timeInterval, lhs.id.uuidString) < (rhs.timeInterval, rhs.id.uuidString)
    }
}
