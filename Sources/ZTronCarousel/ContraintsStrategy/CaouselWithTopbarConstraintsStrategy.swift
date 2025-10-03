import UIKit

public protocol CarouselWithTopbarConstraintsStrategy: ConstraintsStrategy {
    func makeTopbarConstraints(for: UIDeviceOrientation, nestingLevel: Int, maxDepth: Int)
}
