import XCTest
@testable import WhisperDictation

final class DutchLanguageTests: XCTestCase {
    private func isolatedSettings(_ configure: (UserDefaults) -> Void = { _ in },
                                  test: (AppSettings) -> Void) {
        let name = "WhisperDictationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        configure(defaults)
        test(AppSettings(defaults: defaults))
    }

    func testFreshInstallDefaultsToDutchWithoutCommands() {
        isolatedSettings { settings in
            XCTAssertEqual(settings.speechLanguage, .dutch)
            XCTAssertEqual(settings.interfaceLanguage, .dutch)
            XCTAssertEqual(settings.selectedModel, "small-q5_1")
            XCTAssertFalse(settings.spokenCommandsEnabled)
            XCTAssertEqual(settings.dutchNumberStyle, .plain)
        }
    }

    func testUpgradePreservesEnglishModelVocabularyAndTerms() {
        isolatedSettings({ defaults in
            defaults.set("base.en-q5_1", forKey: "selectedModel")
            defaults.set("My vocabulary", forKey: "vocabularyPrompt")
            defaults.set(["Plant Activity"], forKey: "customTerms")
        }) { settings in
            XCTAssertEqual(settings.speechLanguage, .english)
            XCTAssertEqual(settings.selectedModel, "base.en-q5_1")
            XCTAssertEqual(settings.vocabularyPrompt, "My vocabulary")
            settings.speechLanguage = .dutch
            XCTAssertEqual(settings.selectedModel, "small-q5_1")
            XCTAssertNotEqual(settings.vocabularyPrompt, "My vocabulary")
            settings.vocabularyPrompt = "Mijn woordenlijst"
            settings.speechLanguage = .english
            XCTAssertEqual(settings.vocabularyPrompt, "My vocabulary")
            XCTAssertEqual(settings.customTerms, ["Plant Activity"])
            settings.speechLanguage = .dutch
            XCTAssertEqual(settings.vocabularyPrompt, "Mijn woordenlijst")
        }
    }

    func testCompatibilityMatrixAndHashes() {
        for model in ModelManager.ModelInfo.all {
            XCTAssertTrue(model.supports(.english))
            XCTAssertEqual(model.supports(.dutch), model.isMultilingual)
            XCTAssertEqual(model.supports(.automatic), model.isMultilingual)
            XCTAssertEqual(model.sha256.count, 64)
            XCTAssertTrue(model.sha256.allSatisfy(\.isHexDigit))
            XCTAssertEqual(model.url.scheme, "https")
        }
        XCTAssertEqual(Set(ModelManager.ModelInfo.all.map(\.settingsId)).count, 9)
    }

    func testSnapshotIsIndependentOfLaterSettings() {
        isolatedSettings { settings in
            settings.customTerms = ["Plant Activity"]
            let snapshot = DictationOptions(settings: settings)
            settings.speechLanguage = .english
            settings.grammarCorrectionEnabled = false
            settings.customTerms = []
            XCTAssertEqual(snapshot.language, .dutch)
            XCTAssertEqual(snapshot.modelID, "small-q5_1")
            XCTAssertTrue(snapshot.grammar)
            XCTAssertEqual(snapshot.correct("plant activity", detectedLanguage: nil, context: .standalone), "Plant Activity.")
        }
    }

    func testAutoUsesDetectedLanguageNotDutchByDefault() {
        isolatedSettings { settings in
            settings.speechLanguage = .automatic
            let snapshot = DictationOptions(settings: settings)
            XCTAssertEqual(snapshot.correct("tweeënveertig", detectedLanguage: "nl", context: .standalone), "42")
            XCTAssertEqual(snapshot.correct("forty two", detectedLanguage: "en", context: .standalone), "42")
            XCTAssertEqual(snapshot.correct("bonjour le monde", detectedLanguage: "fr", context: .standalone), "bonjour le monde")
            XCTAssertEqual(snapshot.correct("twee", detectedLanguage: nil, context: .standalone), "twee")
        }
    }

    func testCompoundNumbersAndDecimalComma() {
        for (word, value) in [("tweeënveertig", 42), ("drieënzeventig", 73), ("vijfduizend", 5000),
                              ("honderdtwee", 102), ("tweeduizendvierhonderdzes", 2406), ("één", 1)] {
            XCTAssertEqual(DutchTextCorrector.integer(word), value)
        }
        XCTAssertEqual(DutchTextCorrector.correct("drie komma vijf"), "3,5")
        XCTAssertEqual(DutchTextCorrector.correct("vijfduizend euro", style: .grouped), "5.000 euro.")
        XCTAssertEqual(DutchTextCorrector.correct("vijfduizend euro"), "5000 euro.")
        XCTAssertNil(DutchTextCorrector.integer("honderdhonderd"))
    }

    func testConservativeWordsAccentsAndLiteralText() {
        XCTAssertEqual(DutchTextCorrector.correct("een café in België"), "Een café in België.")
        XCTAssertEqual(DutchTextCorrector.correct("eenentwintig ideeën"), "21 ideeën.")
        XCTAssertEqual(DutchTextCorrector.correct("code 007", style: .grouped), "Code 007")
        XCTAssertEqual(DutchTextCorrector.correct("https://voorbeeld.nl/drie"), "https://voorbeeld.nl/drie")
        XCTAssertEqual(DutchTextCorrector.correct("drie@example.nl"), "drie@example.nl")
        XCTAssertEqual(DutchTextCorrector.correct("`drie komma vijf`"), "`drie komma vijf`")
        XCTAssertEqual(DutchTextCorrector.correct("een punt maken"), "Een punt maken.")
    }

    func testTechnicalCasingAndSpacing() {
        XCTAssertEqual(DutchTextCorrector.correct("macos gebruikt de api van openai , en github"), "macOS gebruikt de API van OpenAI, en GitHub.")
        XCTAssertEqual(DutchTextCorrector.correct("hallo,wereld! volgende zin"), "Hallo, wereld! Volgende zin.")
    }

    func testCommandsOffByDefaultAndOptionalWithoutGrammar() {
        XCTAssertEqual(DutchTextCorrector.correct("hallo punt"), "Hallo punt.")
        XCTAssertEqual(DutchTextCorrector.correct("hallo punt. nieuwe regel. volgende zin", commands: true), "Hallo.\nVolgende zin.")
        XCTAssertEqual(DutchTextCorrector.correct("titel dubbele punt nieuwe alinea tekst", commands: true), "Titel:\n\nTekst.")
        XCTAssertEqual(DutchTextCorrector.correct("hallo vraagteken", grammar: false, commands: true), "hallo?")
        XCTAssertEqual(DutchTextCorrector.correct("twee , drie", grammar: false, numbers: false), "twee , drie")
        XCTAssertEqual(DutchTextCorrector.correct("twee dingen", grammar: false, numbers: true), "2 dingen")
        XCTAssertEqual(DutchTextCorrector.correct("twee dingen", numbers: false), "Twee dingen.")
    }

    func testLiveContextAndNewlineJoining() {
        let context = CorrectionContext(atSentenceStart: false, appendPeriod: false)
        XCTAssertEqual(DutchTextCorrector.correct("en dan verder", context: context), "en dan verder")
        let collector = TranscriptCollector()
        XCTAssertEqual(collector.joinAndAppend("Hallo."), "Hallo.")
        XCTAssertEqual(collector.joinAndAppend("\n\n"), "\n\n")
        XCTAssertTrue(collector.atSentenceStart)
        XCTAssertEqual(collector.joinAndAppend("Volgende zin."), "Volgende zin.")
        XCTAssertEqual(collector.joinAndAppend(""), "")
        XCTAssertEqual(collector.text, "Hallo.\n\nVolgende zin.")
    }

    func testMultiwordCustomTermsRespectPromptBudget() {
        let base = Array(repeating: "woord", count: 698).joined(separator: " ")
        let result = DictationEngine.buildPrompt(base: base, customTerms: ["Plant Activity", "Nog een term"], transcriptTail: "oude tekst")
        XCTAssertEqual(result.split(whereSeparator: \.isWhitespace).count, 700)
        XCTAssertTrue(result.hasSuffix("Plant Activity"))
        XCTAssertFalse(result.contains("Nog een term"))
    }
}
