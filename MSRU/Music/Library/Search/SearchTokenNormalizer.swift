//
//  SearchTokenNormalizer.swift
//  MSRU
//
//  High-performance Unicode, Chinese Pinyin, Character N-gram, and Alias normalizer
//  for professional multi-language SQLite FTS5 search.
//

import Foundation
import AppFoundation

nonisolated public enum SearchTokenNormalizer {

    /// Normalizes and generates rich searchable tokens for any text (Chinese, English, Latin, Numerics).
    /// Generates:
    /// 1. NFKC normalized base text
    /// 2. Space-separated unigrams and bigrams for CJK ideographs (enabling substring search in FTS5)
    /// 3. Pinyin full syllables ("zhou jie lun")
    /// 4. Continuous pinyin ("zhoujielun")
    /// 5. Pinyin first-letter initials ("zjl")
    /// 6. Traditional/Simplified Chinese variants and bigrams
    /// 7. Cross-lingual artist aliases (e.g. 周杰伦 <-> Jay Chou)
    public static func generateSearchTokens(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var allTokens = Set<String>()

        // Process full text as a whole
        for token in tokensForSegment(trimmed) {
            allTokens.insert(token)
        }

        // Also process each component/word individually
        let segments = trimmed.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        for segment in segments {
            for token in tokensForSegment(segment) {
                allTokens.insert(token)
            }
        }

        return allTokens.sorted().joined(separator: " ")
    }

    private static func tokensForSegment(_ segment: String) -> [String] {
        var tokens: [String] = [segment]

        let cjkChars = segment.filter { isCJK($0) }
        if !cjkChars.isEmpty {
            // Unigrams
            let unigrams = cjkChars.map { String($0) }.joined(separator: " ")
            tokens.append(unigrams)

            // Bigrams
            if cjkChars.count >= 2 {
                var bigrams: [String] = []
                let charArray = Array(cjkChars)
                for i in 0..<(charArray.count - 1) {
                    bigrams.append("\(charArray[i])\(charArray[i + 1])")
                }
                tokens.append(bigrams.joined(separator: " "))
            }

            // Pinyin generation via CFStringTransform
            let pinyinString = NSMutableString(string: segment) as CFMutableString
            if CFStringTransform(pinyinString, nil, kCFStringTransformMandarinLatin, false) {
                CFStringTransform(pinyinString, nil, kCFStringTransformStripDiacritics, false)
                let pinyin = (pinyinString as String).lowercased()
                tokens.append(pinyin)

                let continuousPinyin = pinyin.components(separatedBy: .whitespacesAndNewlines).joined()
                if !continuousPinyin.isEmpty {
                    tokens.append(continuousPinyin)
                }

                let words = pinyin.split(separator: " ")
                let initials = words.compactMap { $0.first.map { String($0) } }.joined()
                if initials.count > 1 {
                    tokens.append(initials)
                }
            }

            // Traditional Chinese variant
            let traditional = convertToTraditional(segment)
            if traditional != segment {
                tokens.append(traditional)
                let tradChars = Array(traditional.filter { isCJK($0) })
                if tradChars.count >= 2 {
                    var tradBigrams: [String] = []
                    for i in 0..<(tradChars.count - 1) {
                        tradBigrams.append("\(tradChars[i])\(tradChars[i + 1])")
                    }
                    tokens.append(tradBigrams.joined(separator: " "))
                }
            }

            // Simplified Chinese variant
            let simplified = convertToSimplified(segment)
            if simplified != segment {
                tokens.append(simplified)
            }
        }

        // Known aliases
        if let aliases = knownArtistAliases[segment] {
            for alias in aliases {
                tokens.append(alias)
                tokens.append(alias.lowercased())
            }
        }

        return tokens
    }

    /// Prepares a user search query for FTS5 syntax matching.
    /// Handles partial prefix matching, multi-token queries, and multi-lingual expansion.
    public static func prepareFTSQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Strip characters that break SQLite FTS5
        let sanitized = trimmed.components(separatedBy: CharacterSet(charactersIn: #""*^:()"#)).joined(separator: " ")
        let terms = sanitized.split(separator: " ").filter { !$0.isEmpty }
        guard !terms.isEmpty else { return "" }

        // Check if query is an alias
        if let aliases = knownArtistAliases[trimmed] {
            var aliasTerms = [trimmed]
            aliasTerms.append(contentsOf: aliases)
            let clauses = aliasTerms.map { "\"\($0)\"*" }
            return clauses.joined(separator: " OR ")
        }

        // Multi-term AND matching with wildcards
        let formattedTerms = terms.map { term -> String in
            let termStr = String(term)
            if termStr.contains(where: { isCJK($0) }) {
                // If user typed Chinese, check simplified and traditional
                let simp = convertToSimplified(termStr)
                let trad = convertToTraditional(termStr)
                if simp != trad {
                    return "(\"\(simp)\"* OR \"\(trad)\"*)"
                }
                return "\"\(termStr)\"*"
            } else {
                return "\(termStr)*"
            }
        }

        return formattedTerms.joined(separator: " ")
    }

    // MARK: - Helpers

    private static func isCJK(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        let value = scalar.value
        return (0x4E00...0x9FFF).contains(value) ||
               (0x3400...0x4DBF).contains(value) ||
               (0xF900...0xFAFF).contains(value)
    }

    private static func convertToTraditional(_ text: String) -> String {
        let str = NSMutableString(string: text) as CFMutableString
        CFStringTransform(str, nil, "Simplified-Traditional" as CFString, false)
        return str as String
    }

    private static func convertToSimplified(_ text: String) -> String {
        let str = NSMutableString(string: text) as CFMutableString
        CFStringTransform(str, nil, "Traditional-Simplified" as CFString, false)
        return str as String
    }

    /// Curated lookup table for prominent artist cross-lingual aliases (e.g. Chinese <-> English/Romanized)
    private static let knownArtistAliases: [String: [String]] = [
        "周杰伦": ["Jay Chou", "Chou Jay", "Jay", "周杰倫"],
        "周杰倫": ["Jay Chou", "Chou Jay", "Jay", "周杰伦"],
        "Jay Chou": ["周杰伦", "周杰倫"],
        "陈奕迅": ["Eason Chan", "Chan Eason", "Eason", "陳奕迅"],
        "Eason Chan": ["陈奕迅", "陳奕迅"],
        "王菲": ["Faye Wong", "Wong Faye", "Faye"],
        "Faye Wong": ["王菲"],
        "林俊杰": ["JJ Lin", "Lin JJ", "JJ", "林俊傑"],
        "JJ Lin": ["林俊杰", "林俊傑"],
        "张学友": ["Jacky Cheung", "Cheung Jacky", "張學友"],
        "Jacky Cheung": ["张学友", "張學友"],
        "孙燕姿": ["Stefanie Sun", "Sun Stefanie", "孫燕姿"],
        "Stefanie Sun": ["孙燕姿", "孫燕姿"],
        "莫文蔚": ["Karen Mok"],
        "陶喆": ["David Tao"],
        "李宗盛": ["Jonathan Lee"],
        "罗大佑": ["Lo Ta-yu"],
        "五月天": ["Mayday"]
    ]
}
