import Foundation

public protocol Replicable {

    func merged(with other: Self) -> Self
}
