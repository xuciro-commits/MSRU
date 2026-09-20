//
//  QueueHeaderView.swift
//  MSRU
//

import SwiftUI


struct QueueHeaderView: View {

    let onClear:
        () -> Void


    var body: some View {

        HStack {

            Text(
                "Next"
            )
            .font(
                .headline
            )


            Spacer()


            Button {

                onClear()

            } label: {

                Text(
                    "Clear"
                )
            }
            .buttonStyle(
                .plain
            )
            .foregroundStyle(
                .secondary
            )
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
}


#Preview {

    QueueHeaderView(
        onClear: {}
    )
    .frame(
        width: 320
    )
}
