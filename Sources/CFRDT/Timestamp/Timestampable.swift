import Foundation

public protocol Timestampable: Hashable, Codable, Comparable {

    static func tick() -> Self
    mutating func tick()
}
