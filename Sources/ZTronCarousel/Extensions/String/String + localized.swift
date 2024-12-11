import Foundation

extension String {
    func localized(in bundle: Bundle?) -> Self {
        return String(localized: String.LocalizationValue(stringLiteral: self), bundle: bundle)
    }
}
