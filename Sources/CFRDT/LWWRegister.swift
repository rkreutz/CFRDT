import Foundation

/// Time based Last-Writter-Wins Register
public typealias TLWWRegister<Value> = LWWRegister<Value, DisambiguousTimeInterval>

/// Last-Writer-Wins Register
public struct LWWRegister<Value, Timestamp: Timestampable> {

    internal struct Entry {

        var value: Value
        var timestamp: Timestamp = .tick()

        func isOrdered(after other: Entry) -> Bool { timestamp > other.timestamp }
    }

    internal var entry: Entry

    public var value: Value {

        get { entry.value }
        set { entry = Entry(value: newValue) }
    }

    public init(_ value: Value) {

        entry = Entry(value: value)
    }
}

extension LWWRegister: Replicable {

    public func merged(with other: LWWRegister) -> LWWRegister {

        entry.isOrdered(after: other.entry) ? self : other
    }
}

extension LWWRegister.Entry: Codable where Value: Codable {}
extension LWWRegister: Codable where Value: Codable {

    public init(from decoder: Decoder) throws {

        let container = try decoder.singleValueContainer()
        self.entry = try container.decode(Entry.self)
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.singleValueContainer()
        try container.encode(entry)
    }
}

@available(iOS 13, tvOS 13, watchOS 6, OSX 10.15, *)
extension LWWRegister.Entry: Identifiable where Value: Identifiable {

    var id: Value.ID { value.id }
}

@available(iOS 13, tvOS 13, watchOS 6, OSX 10.15, *)
extension LWWRegister: Identifiable where Value: Identifiable {

    public var id: Value.ID { entry.id }
}

extension LWWRegister: ExpressibleByIntegerLiteral where Value: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: Value.IntegerLiteralType) {

        self.init(Value(integerLiteral: value))
    }
}

extension LWWRegister: ExpressibleByFloatLiteral where Value: ExpressibleByFloatLiteral {

    public init(floatLiteral value: Value.FloatLiteralType) {

        self.init(Value(floatLiteral: value))
    }
}

extension LWWRegister: ExpressibleByNilLiteral where Value: ExpressibleByNilLiteral {

    public init(nilLiteral: ()) {

        self.init(Value(nilLiteral: nilLiteral))
    }
}

extension LWWRegister: ExpressibleByBooleanLiteral where Value: ExpressibleByBooleanLiteral {

    public init(booleanLiteral value: Value.BooleanLiteralType) {

        self.init(Value(booleanLiteral: value))
    }
}

extension LWWRegister: ExpressibleByUnicodeScalarLiteral where Value: ExpressibleByUnicodeScalarLiteral {

    public init(unicodeScalarLiteral value: Value.UnicodeScalarLiteralType) {

        self.init(Value(unicodeScalarLiteral: value))
    }
}

extension LWWRegister: ExpressibleByExtendedGraphemeClusterLiteral where Value: ExpressibleByExtendedGraphemeClusterLiteral {

    public init(extendedGraphemeClusterLiteral value: Value.ExtendedGraphemeClusterLiteralType) {

        self.init(Value(extendedGraphemeClusterLiteral: value))
    }
}

extension LWWRegister: ExpressibleByStringLiteral where Value: ExpressibleByStringLiteral {

    public init(stringLiteral value: Value.StringLiteralType) {

        self.init(Value(stringLiteral: value))
    }
}

extension LWWRegister: ExpressibleByStringInterpolation where Value: ExpressibleByStringInterpolation {

    public init(stringInterpolation: Value.StringInterpolation) {

        self.init(Value(stringInterpolation: stringInterpolation))
    }
}
