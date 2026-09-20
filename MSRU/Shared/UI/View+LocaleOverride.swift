//
//  View+LocaleOverride.swift
//  MSRU
//

import SwiftUI
import AppFoundation


// MARK: - Locale Override

/*
 Conditionally overrides the SwiftUI locale environment
 when the user has chosen a non-system language.

 When `locale` is nil (system mode), no override is applied
 and the view inherits the system's natural locale.
 */

extension View {

    @ViewBuilder
    func applyLocaleOverride(
        _ locale:
            Locale?
    ) -> some View {

        if let locale {

            self.environment(
                \.locale,
                locale
            )

        } else {

            self
        }
    }
}
