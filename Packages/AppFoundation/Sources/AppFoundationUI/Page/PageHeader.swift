//
//  PageHeader.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Page Header

/*
 PageHeader 表达一个 Application Page
 的标题区域。

 它不是 Card。

 它表达：

 - page identity
 - supporting description
 - page-level actions
 */

public struct PageHeader<Actions>:
    View
where
    Actions:
        View {

    private let title:
        LocalizedStringResource


    private let subtitle:
        LocalizedStringResource?


    private let actions:
        Actions


    public init(
        _ title:
            LocalizedStringResource,
        subtitle:
            LocalizedStringResource? = nil,
        @ViewBuilder actions:
            () -> Actions
    ) {

        self.title =
            title

        self.subtitle =
            subtitle

        self.actions =
            actions()
    }


    public var body:
        some View {

        HStack(
            alignment:
                .center,
            spacing:
                16
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                Text(
                    title
                )
                .font(
                    .largeTitle
                )
                .fontWeight(
                    .bold
                )


                if let subtitle {

                    Text(
                        subtitle
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            Spacer(
                minLength:
                    20
            )


            actions
        }
    }
}


// MARK: - No Actions

public extension PageHeader
where
    Actions == EmptyView {

    init(
        _ title:
            LocalizedStringResource,
        subtitle:
            LocalizedStringResource? = nil
    ) {

        self.init(
            title,
            subtitle:
                subtitle
        ) {

            EmptyView()
        }
    }
}
