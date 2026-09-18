import Foundation

enum SpeechLanguage: String, CaseIterable, Identifiable, Sendable {
    case dutch = "nl", english = "en", automatic = "auto"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dutch: return "Nederlands"
        case .english: return "English"
        case .automatic: return "Automatic"
        }
    }
    var defaultModelID: String { self == .english ? "small.en" : "small-q5_1" }
    var defaultPrompt: String {
        switch self {
        case .english: return AppSettings.defaultVocabularyPrompt
        case .dutch: return "Vandaag bespreken we het project en de planning. Kun je het Grafana dashboard aanpassen en daarna een Slack bericht sturen? AI, API, JSON, GitHub, OpenAI, ChatGPT, Python, PostgreSQL, macOS."
        case .automatic: return "AI, API, JSON, GitHub, OpenAI, ChatGPT, Slack, Grafana, Python, PostgreSQL, macOS."
        }
    }
}

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case dutch = "nl", english = "en"
    var id: String { rawValue }
    var title: String { self == .dutch ? "Nederlands" : "English" }
}

enum DutchNumberStyle: String, CaseIterable, Sendable {
    case plain, grouped
}

/// Captured at recording start, never read from mutable settings during decode.
struct DictationOptions: Sendable {
    let language: SpeechLanguage
    let modelID: String
    let prompt: String
    let customTerms: [String]
    let grammar: Bool
    let numbers: Bool
    let spokenCommands: Bool
    let numberStyle: DutchNumberStyle

    init(settings: AppSettings) {
        language = settings.speechLanguage
        modelID = settings.selectedModel
        prompt = settings.vocabularyPrompt
        customTerms = settings.customTerms
        grammar = settings.grammarCorrectionEnabled
        numbers = settings.numberConversionEnabled
        spokenCommands = settings.spokenCommandsEnabled
        numberStyle = settings.dutchNumberStyle
    }

    func correct(_ text: String, detectedLanguage: String?, context: CorrectionContext) -> String {
        let code = language == .automatic ? detectedLanguage : language.rawValue
        if code == "nl" {
            return DutchTextCorrector.correct(text, grammar: grammar, numbers: numbers,
                commands: spokenCommands, style: numberStyle, customTerms: customTerms, context: context)
        }
        if code == "en" {
            return TextCorrector.shared.correct(text, context: context, grammar: grammar,
                                                numbers: numbers, customTerms: customTerms)
        }
        // Unknown languages: don't apply Dutch/English rules to someone else's language.
        return text
    }
}
