import Foundation

/// For errors outside SwiftUI; views use their explicitly selected locale.
enum L10n {
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let language = AppSettings.shared.interfaceLanguage.rawValue
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: Locale(identifier: language), arguments: arguments)
    }
}
