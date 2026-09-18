import Foundation

/// Deliberately not a grammar rewriter. Preserve articles, accents and word order.
/// Spoken commands are opt-in; they can also be ordinary words in Dutch.
enum DutchTextCorrector {
    private static let units = ["nul", "een", "twee", "drie", "vier", "vijf", "zes", "zeven", "acht", "negen",
                                "tien", "elf", "twaalf", "dertien", "veertien", "vijftien", "zestien", "zeventien", "achttien", "negentien"]
    private static let tens = ["twintig", "dertig", "veertig", "vijftig", "zestig", "zeventig", "tachtig", "negentig"]
    static let technicalTerms = ["AI", "API", "JSON", "GitHub", "OpenAI", "ChatGPT", "Slack", "Grafana", "Python", "PostgreSQL", "macOS", "Swift", "Whisper", "JavaScript", "TypeScript"]

    /// Parse unambiguous compound Dutch integers up to 999,999.
    static func integer(_ input: String) -> Int? {
        let word = input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "nl_NL"))
        if let index = units.firstIndex(of: word) { return index }
        if let index = tens.firstIndex(of: word) { return (index + 2) * 10 }
        for (index, ten) in tens.enumerated() where word.hasSuffix(ten) {
            let prefix = String(word.dropLast(ten.count))
            if prefix.hasSuffix("en"), let unit = units.firstIndex(of: String(prefix.dropLast(2))), (1...9).contains(unit) {
                return (index + 2) * 10 + unit
            }
        }
        for (scaleWord, scale) in [("duizend", 1000), ("honderd", 100)] {
            guard let range = word.range(of: scaleWord) else { continue }
            let left = String(word[..<range.lowerBound])
            let right = String(word[range.upperBound...])
            // Recursion strictly shortens input. Restrict each part to avoid malformed compounds.
            guard let multiplier = left.isEmpty ? 1 : integer(left), multiplier > 0,
                  multiplier < (scale == 1000 ? 1000 : 10),
                  let remainder = right.isEmpty ? 0 : integer(right), remainder < scale else { return nil }
            return multiplier * scale + remainder
        }
        return nil
    }

    static func correct(_ text: String, grammar: Bool = true, numbers: Bool = true,
                        commands: Bool = false, style: DutchNumberStyle = .plain,
                        customTerms: [String] = [], context: CorrectionContext = .standalone) -> String {
        guard grammar || commands else { return text }
        var result = text
        if grammar && numbers {
            result = replace(result, pattern: #"\b[\p{L}]+\b"#) { word in
                // An unaccented "een" is usually the article, not a numeric instruction.
                guard word.lowercased() != "een", let value = integer(word) else { return word }
                return String(value)
            }
            // Decimal comma before spoken punctuation; never convert a literal "komma" alone.
            result = replace(result, pattern: #"(?<![\p{L}\p{N}_.,])\d+\h+komma\h+\d+(?![\p{L}\p{N}_])"#) {
                $0.replacingOccurrences(of: #"\h+komma\h+"#, with: ",", options: [.regularExpression, .caseInsensitive])
            }
            if style == .grouped {
                result = replace(result, pattern: #"(?<![\p{L}\p{N}_.,])\d{4,}(?![\p{L}\p{N}_.,])"#) { digits in
                    guard !digits.hasPrefix("0") else { return digits }
                    return digits.reversed().enumerated().map { index, digit in
                        (index > 0 && index % 3 == 0 ? "." : "") + String(digit)
                    }.joined().reversed().map(String.init).joined()
                }
            }
        }
        if commands {
            for (spoken, symbol) in [("nieuwe alinea", "\n\n"), ("nieuwe regel", "\n"), ("dubbele punt", ":"),
                                      ("vraagteken", "?"), ("uitroepteken", "!"), ("punt", "."), ("komma", ",")] {
                result = replace(result, pattern: "\\b" + spoken.replacingOccurrences(of: " ", with: "\\h+") + "\\b[.,]?") { _ in symbol }
            }
        }
        // Horizontal space only: never collapse spoken line/paragraph boundaries.
        result = replace(result, pattern: #"\h+([,.;:!?])"#) { $0.trimmingCharacters(in: .whitespaces) }
        result = replace(result, pattern: #"[,;:!?](?=\p{L})"#) { $0 + " " }
        result = result.replacingOccurrences(of: #"\h*\n\h*"#, with: "\n", options: .regularExpression)
        result = replace(result, pattern: #"\h{2,}"#) { _ in " " }
        result = result.trimmingCharacters(in: .whitespaces)
        if grammar {
            // Only genuine sentence boundaries, not periods within URLs/acronyms/decimals.
            if context.atSentenceStart {
                result = replace(result, pattern: #"^[\s\"'‘“(]*\p{L}"#) { capitalize($0) }
            }
            result = replace(result, pattern: #"(?:[.!?]\h+|\n)[\"'‘“(]*\p{L}"#) { capitalize($0) }
            // Restore product and user casing after capitalization (e.g. macOS).
            for term in technicalTerms + customTerms where !term.isEmpty {
                let pattern = "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: term) + "(?![\\p{L}\\p{N}_])"
                result = replace(result, pattern: pattern) { _ in term }
            }
            if context.appendPeriod, let last = result.last, last.isLetter,
               !result.contains("://"), !result.contains("@"), !result.hasSuffix("`") {
                result += "."
            }
        }
        return result
    }

    private static func capitalize(_ value: String) -> String {
        guard let index = value.firstIndex(where: { $0.isLetter }) else { return value }
        return String(value[..<index]) + value[index].uppercased() + value[value.index(after: index)...]
    }

    /// Protect literal code, URLs and mail addresses from number/casing/spacing changes.
    private static func replace(_ text: String, pattern: String, transform: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let literal = try? NSRegularExpression(pattern: #"`[^`]*`|https?://[^\s]+|[\w.+-]+@[\w.-]+\.[\p{L}]+"#) else { return text }
        let fullRange = NSRange(text.startIndex..., in: text)
        let protected = literal.matches(in: text, range: fullRange).map(\.range)
        var result = text
        for match in regex.matches(in: text, range: fullRange).reversed() {
            guard !protected.contains(where: { NSIntersectionRange($0, match.range).length > 0 }),
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: transform(String(result[range])))
        }
        return result
    }
}
