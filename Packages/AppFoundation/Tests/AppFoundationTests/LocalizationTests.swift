//
//  LocalizationTests.swift
//  AppFoundationTests
//

import Testing
import Foundation

@testable import AppFoundation


// MARK: - Localization Tests

@MainActor
struct LocalizationTests {

    @Test
    func supportedLanguagesHaveCorrectProperties() {

        #expect(
            SupportedLanguage.system.rawValue
            ==
            "system"
        )

        #expect(
            SupportedLanguage.english.rawValue
            ==
            "en"
        )

        #expect(
            SupportedLanguage.chinese.rawValue
            ==
            "zh-Hans"
        )

        #expect(
            SupportedLanguage.tibetan.rawValue
            ==
            "bo"
        )

        #expect(
            SupportedLanguage.system.locale
            ==
            nil
        )

        #expect(
            SupportedLanguage.english.locale?.identifier
            ==
            "en"
        )

        #expect(
            SupportedLanguage.chinese.locale?.identifier
            ==
            "zh-Hans"
        )

        #expect(
            SupportedLanguage.tibetan.locale?.identifier
            ==
            "bo"
        )
    }


    @Test
    func languageSettingsInitializesAndResolvesLocale() {

        let settings =
            LanguageSettings()

        #expect(
            settings.selectedLanguage
            ==
            .system
        )

        #expect(
            settings.resolvedLocale
            ==
            nil
        )

        settings.selectedLanguage =
            .english

        #expect(
            settings.resolvedLocale?.identifier
            ==
            "en"
        )

        settings.selectedLanguage =
            .chinese

        #expect(
            settings.resolvedLocale?.identifier
            ==
            "zh-Hans"
        )

        settings.selectedLanguage =
            .tibetan

        #expect(
            settings.resolvedLocale?.identifier
            ==
            "bo"
        )

        // Reset to system
        settings.selectedLanguage =
            .system

        #expect(
            settings.resolvedLocale
            ==
            nil
        )
    }


    @Test
    func languageSettingsCodableRoundtrip() throws {

        let original =
            SupportedLanguage.tibetan

        let data =
            try JSONEncoder().encode(original)

        let decoded =
            try JSONDecoder().decode(SupportedLanguage.self, from: data)

        #expect(
            decoded
            ==
            original
        )
    }
}
