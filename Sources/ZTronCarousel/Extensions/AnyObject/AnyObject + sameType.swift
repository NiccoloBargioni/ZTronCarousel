import Foundation

/// Successfully considers two objects of different subclasses of the same class as distinct
internal func sameType<T: AnyObject, U: AnyObject>(_ lhs: T, _ rhs: U) -> Bool {
    return object_getClassName(lhs) == object_getClassName(rhs)
}
