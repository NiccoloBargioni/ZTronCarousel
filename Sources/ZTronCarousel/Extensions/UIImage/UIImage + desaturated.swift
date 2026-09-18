import UIKit
import CoreImage

public extension UIImage {
    /// A grayscale copy of this image, used to convey that a routing element is not selectable
    /// under the currently active filters. Returns `self` unmodified when the conversion fails.
    func desaturated() -> UIImage {
        guard let ciImage = CIImage(image: self) else { return self }
        
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.0, forKey: kCIInputSaturationKey)
        
        guard let output = filter?.outputImage else { return self }
        
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return self }
        
        return UIImage(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
