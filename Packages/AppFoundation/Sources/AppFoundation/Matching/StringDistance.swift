//
//  StringDistance.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 3.
//

import Foundation

/// String similarity and fuzzy matching metrics for entity resolution and deduplication.
public enum StringDistance {

    /// Normalizes text by lowercasing, folding diacritics, removing punctuation, and collapsing whitespace.
    public static func normalize(_ string: String?) -> String {
        guard let string, !string.isEmpty else { return "" }
        let folded = string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = folded.unicodeScalars.filter { allowed.contains($0) }
        let trimmed = String(cleaned).components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return trimmed
    }

    /// Computes classic Levenshtein edit distance between two strings.
    public static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = min(prev[j], curr[j - 1], prev[j - 1]) + 1
                }
            }
            prev = curr
        }

        return prev[n]
    }

    /// Computes normalized Levenshtein similarity within range `[0.0, 1.0]`.
    public static func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        let maxLen = max(s1.count, s2.count)
        guard maxLen > 0 else { return 1.0 }
        let dist = levenshteinDistance(s1, s2)
        return max(0.0, 1.0 - (Double(dist) / Double(maxLen)))
    }

    /// Computes token-level Jaccard similarity (word-order invariant).
    public static func tokenJaccardSimilarity(_ s1: String, _ s2: String) -> Double {
        let tokens1 = Set(s1.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        let tokens2 = Set(s2.components(separatedBy: .whitespaces).filter { !$0.isEmpty })

        if tokens1.isEmpty && tokens2.isEmpty { return 1.0 }
        if tokens1.isEmpty || tokens2.isEmpty { return 0.0 }

        let intersection = tokens1.intersection(tokens2)
        let union = tokens1.union(tokens2)

        return Double(intersection.count) / Double(union.count)
    }

    /// Computes a composite normalized similarity score combining token-based and Levenshtein metrics.
    public static func similarity(_ s1: String?, _ s2: String?) -> Double {
        let norm1 = normalize(s1)
        let norm2 = normalize(s2)

        if norm1.isEmpty && norm2.isEmpty { return 1.0 }
        if norm1.isEmpty || norm2.isEmpty { return 0.0 }
        if norm1 == norm2 { return 1.0 }

        let lev = levenshteinSimilarity(norm1, norm2)
        let jaccard = tokenJaccardSimilarity(norm1, norm2)

        // Give weight to both character edit distance and token reordering
        return (lev * 0.6) + (jaccard * 0.4)
    }
}
