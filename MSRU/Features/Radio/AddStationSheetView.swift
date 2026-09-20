//
//  AddStationSheetView.swift
//  MSRU
//

import SwiftUI

struct AddStationSheetView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var streamURLString: String = ""
    @State private var genre: RadioGenre = .classical
    @State private var country: String = "Global"
    @State private var descriptionText: String = ""
    @State private var errorMessage: String? = nil

    let onSave: (RadioStation) -> Void

    private var isValidURL: Bool {
        guard let url = URL(string: streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isValidURL
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("电台详情") {
                    TextField("电台名称", text: $name, prompt: Text("例如：我喜欢的电台"))

                    TextField("流媒体 URL", text: $streamURLString, prompt: Text("https://example.com/stream.mp3"))
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        #endif

                    if !streamURLString.isEmpty && !isValidURL {
                        Text("请输入有效的 HTTP 或 HTTPS 流媒体 URL。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Picker("类型", selection: $genre) {
                        ForEach(RadioGenre.allCases.filter { $0 != .all }) { item in
                            Text(item.displayTitle).tag(item)
                        }
                    }

                    TextField("国家/地区", text: $country, prompt: Text("例如：全球、中国、美国"))
                    TextField("描述（可选）", text: $descriptionText, prompt: Text("可选备注或标语"))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("添加自定义电台")
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 340)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave,
              let url = URL(string: streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "流媒体 URL 无效或缺少电台名称。"
            return
        }

        let newStation = RadioStation(
            id: "custom-\(UUID().uuidString.prefix(8).lowercased())",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "用户添加的自定义流媒体。"
                : descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            genre: genre,
            streamURL: url,
            country: country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Global"
                : country.trimmingCharacters(in: .whitespacesAndNewlines),
            isFeatured: false,
            isCustom: true
        )

        onSave(newStation)
        dismiss()
    }
}

#Preview("Add Station Sheet") {
    AddStationSheetView(onSave: { _ in })
}
