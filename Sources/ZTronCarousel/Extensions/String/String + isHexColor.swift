import Foundation

internal extension String {
    var isHexColor: Bool {
        return first == "#" && (count == 4 || count == 7) && filter(\.isHexDigit).count == count - 1
    }
}

