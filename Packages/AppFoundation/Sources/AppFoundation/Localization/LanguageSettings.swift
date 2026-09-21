//
//  LanguageSettings.swift
//  AppFoundation
//

import Foundation
import Observation

// MARK: - Supported Language

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

// MARK: - Language Settings

/*
 Language override for the application.

 When `selectedLanguage` is `.system`, the app follows
 the system locale. Otherwise the resolved locale
 is injected into the SwiftUI environment.
 */

@MainActor
@Observable
public final class LanguageSettings:
    Sendable {

    // MARK: - Storage Key

    private static let storageKey =
        "AppFoundation.LanguageSettings.selectedLanguage"


    // MARK: - Selected Language

    public var selectedLanguage:
        SupportedLanguage {

        didSet {

            UserDefaults.standard.set(
                selectedLanguage.rawValue,
                forKey:
                    Self.storageKey
            )
        }
    }


    // MARK: - Resolved Locale

    /*
     The locale to inject into the SwiftUI environment.

     Returns nil when following the system,
     meaning no `.environment(\.locale, ...)` override is needed.
     */

    public var resolvedLocale:
        Locale? {

        selectedLanguage.locale
    }


    // MARK: - Init

    public init() {

        let stored =
            UserDefaults.standard.string(
                forKey:
                    Self.storageKey
            )


        let language =
            stored.flatMap {
                SupportedLanguage(
                    rawValue:
                        $0
                )
            }
            ?? .system


        self.selectedLanguage =
            language
    }
}
