//
//  SupportedLanguage.swift
//  AppFoundation
//

import Foundation

public enum SupportedLanguage:
    String,
    CaseIterable,
    Identifiable,
    Sendable,
    Codable {

    case system =
        "system"

    case english =
        "en"

    case chinese =
        "zh-Hans"

    case tibetan =
        "bo"

    public var id:
        String {

        rawValue
    }

    public var displayName:
        String {

        switch self {

        case .system:
            return String(
                localized:
                    "language.system",
                bundle:
                    .module
            )

        case .english:
            return String(
                localized:
                    "language.english",
                bundle:
                    .module
            )

        case .chinese:
            return String(
                localized:
                    "language.chinese",
                bundle:
                    .module
            )

        case .tibetan:
            return String(
                localized:
                    "language.tibetan",
                bundle:
                    .module
            )
        }
    }

    public var locale:
        Locale? {

        switch self {

        case .system:
            return nil

        default:
            return Locale(
                identifier:
                    rawValue
            )
        }
    }
}
