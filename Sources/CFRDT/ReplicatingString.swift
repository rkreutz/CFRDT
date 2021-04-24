import Foundation

public typealias ReplicatingString = ReplicatingArray<ReplicatingCharacter>

extension ReplicatingString: ExpressibleByExtendedGraphemeClusterLiteral {

    public init(extendedGraphemeClusterLiteral value: String.ExtendedGraphemeClusterLiteralType) {

        self.init(stringLiteral: String(extendedGraphemeClusterLiteral: value))
    }
}

extension ReplicatingString: ExpressibleByUnicodeScalarLiteral {

    public init(unicodeScalarLiteral value: String.UnicodeScalarLiteralType) {

        self.init(stringLiteral: String(unicodeScalarLiteral: value))
    }
}

extension ReplicatingString: ExpressibleByStringLiteral {

    public init(stringLiteral value: String.StringLiteralType) {

        value.forEach { self.append(ReplicatingCharacter($0)) }
    }
}

extension ReplicatingString: CustomStringConvertible {

    public var description: String {

        values.map(String.init).joined(separator: "")
    }
}

public struct ReplicatingCharacter: Hashable, CustomStringConvertible {

    fileprivate var character: Character

    public var description: String { character.description }
}

public extension ReplicatingCharacter {

    init(_ character: Character) {

        self.character = character
    }

    init?(_ string: String) {

        guard let character = string.first else { return nil }
        self.character = character
    }
}

extension ReplicatingCharacter: Codable {

    public init(from decoder: Decoder) throws {

        var container = try decoder.unkeyedContainer()
        let string = try container.decode(String.self)
        guard let character = string.first else {

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "No character found")
        }
        self.character = character
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.unkeyedContainer()
        try container.encode(String(character))
    }
}

public extension String {

    init(_ replicatingCharacter: ReplicatingCharacter) {

        self.init(replicatingCharacter.character)
    }
}
