public enum TopbarItemStrategy: Hashable, Sendable {
    case leaf
    case passthrough(depth: Int)
}


