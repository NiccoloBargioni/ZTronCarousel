import UIKit

public extension UIImage {
    static func exists(_ assetName: String) -> Bool {
        return UIImage(named: assetName) != nil
    }
}

