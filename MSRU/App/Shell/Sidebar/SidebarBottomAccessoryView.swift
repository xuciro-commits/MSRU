import SwiftUI


struct SidebarBottomAccessoryView:
    View {

    let onOpenSettings:
        () -> Void


    var body: some View {

        HStack(
            spacing: 10
        ) {

            accountSection


            Spacer(
                minLength: 12
            )


            settingsButton
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            10
        )
    }


    // MARK: - Account

    private var accountSection:
        some View {

        HStack(
            spacing: 9
        ) {

            Image(
                systemName:
                    "person.crop.circle.fill"
            )
            .font(
                .system(
                    size: 20
                )
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                "许强"
            )
            .font(
                .system(
                    size: 13,
                    weight: .medium
                )
            )
            .lineLimit(1)
        }
    }


    // MARK: - Settings

    private var settingsButton:
        some View {

        Button(
            action:
                onOpenSettings
        ) {

            Image(
                systemName:
                    "gearshape"
            )
            .font(
                .system(
                    size: 14,
                    weight: .medium
                )
            )
            .frame(
                width: 24,
                height: 24
            )
        }
        .buttonStyle(
            .plain
        )
        .help(
            "Settings"
        )
    }
}


#Preview {

    SidebarBottomAccessoryView(
        onOpenSettings: {}
    )
    .frame(
        width: 240
    )
}
