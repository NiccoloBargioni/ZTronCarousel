import Foundation

public extension String {
    func fromLocalized() -> String {
        return String(
            localized: String.LocalizationValue(self),
            bundle: .main,
            locale: Locale(
                identifier: Locale.preferredLanguages.first ?? "en-US"
            )
        )
    }
}
