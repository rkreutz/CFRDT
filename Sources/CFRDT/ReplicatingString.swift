import Foundation

public typealias ReplicatingString = ReplicatingArray<String.Element>

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

        value.forEach { self.append($0) }
    }
}
