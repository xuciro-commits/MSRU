//
//  AddSubsonicServerSheet.swift
//  MSRU
//
//  Sheet modal for adding and testing a new Subsonic/OpenSubsonic server.
//

import SwiftUI
import SubsonicKit

struct AddSubsonicServerSheet: View {
    @Bindable var store: SubsonicServerStore
    let onDismiss: () -> Void

    @State private var selectedPreset: SubsonicServerPreset = .zspace
    @State private var serverName: String = "极空间 NAS"
    @State private var serverAddress: String = "http://192.168.31.200:8025"
    @State private var username: String = "msru"
    @State private var password: String = "msruz4pro"

    @State private var isTesting: Bool = false
    @State private var isAdding: Bool = false
    @State private var testResult: TestResult? = nil

    private enum TestResult {
        case success(info: SubsonicServerInfo)
        case failure(message: String)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Preset Picker
                presetPicker

                // Helper instructions banner
                helperBanner

                // Form Fields
                formFields

                // Test Status Indicator
                if let result = testResult {
                    testStatusView(result)
                }

                Spacer()

                // Bottom Action Bar
                HStack {
                    Button("Cancel", role: .cancel) {
                        onDismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button {
                        runTest()
                    } label: {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 8)
                        } else {
                            Text("测试连接")
                        }
                    }
                    .disabled(isTesting || isAdding || !isFormValid)

                    Button {
                        runAdd()
                    } label: {
                        if isAdding {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 12)
                        } else {
                            Text("Add")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTesting || isAdding || !isFormValid)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 520, height: 500)
            .navigationTitle(String(localized: "添加媒体库来源"))
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("服务器类型")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("服务器类型", selection: $selectedPreset) {
                ForEach(SubsonicServerPreset.allCases) { preset in
                    Label(preset.displayName, systemImage: preset.iconName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPreset) { _, newPreset in
                switch newPreset {
                case .zspace:
                    serverName = "极空间 NAS"
                    if serverAddress.isEmpty || serverAddress.contains(":4533") || serverAddress.contains(":4040") {
                        serverAddress = "http://192.168.31.200:8025"
                    }
                case .navidrome:
                    serverName = "Navidrome"
                    if serverAddress.isEmpty || serverAddress.contains(":8025") || serverAddress.contains(":4040") {
                        serverAddress = "http://localhost:4533"
                    }
                case .generic:
                    serverName = "Subsonic Server"
                    if serverAddress.isEmpty || serverAddress.contains(":8025") || serverAddress.contains(":4533") {
                        serverAddress = "http://localhost:4040"
                    }
                }
                testResult = nil
            }
        }
    }

    private var helperBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)

            Text(selectedPreset.helperInstructions)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("来源名称")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("如：我的极空间", text: $serverName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("服务地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    String(localized: "服务地址"),
                    text: $serverAddress,
                    prompt: Text(verbatim: "http://192.168.31.200:8025")
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("用户名")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("用户名", text: $username)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("密码")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    @ViewBuilder
    private func testStatusView(_ result: TestResult) -> some View {
        switch result {
        case .success(let info):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("连接成功！协议版本 \(info.apiVersion)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                    if info.isOpenSubsonic {
                        Text("已识别 OpenSubsonic 标准扩展 (\(info.openSubsonicExtensions.map(\.name).joined(separator: ", ")))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .failure(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            .padding(10)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var isFormValid: Bool {
        !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    private func normalizedURL() -> URL? {
        var addr = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.starts(with: "http://") && !addr.starts(with: "https://") {
            addr = "http://\(addr)"
        }
        return URL(string: addr)
    }

    private func runTest() {
        guard let url = normalizedURL() else {
            testResult = .failure(message: "服务器地址格式无效")
            return
        }

        isTesting = true
        testResult = nil

        Task {
            do {
                let (info, _) = try await store.testConnection(
                    url: url,
                    username: username,
                    password: password
                )
                testResult = .success(info: info)
            } catch let err as RemoteLibraryError {
                testResult = .failure(message: err.localizedDescription)
            } catch {
                testResult = .failure(message: error.localizedDescription)
            }
            isTesting = false
        }
    }

    private func runAdd() {
        guard let url = normalizedURL() else {
            testResult = .failure(message: "服务器地址格式无效")
            return
        }

        isAdding = true

        Task {
            do {
                try await store.addServer(
                    name: serverName,
                    url: url,
                    username: username,
                    password: password
                )
                onDismiss()
            } catch let err as RemoteLibraryError {
                testResult = .failure(message: err.localizedDescription)
                isAdding = false
            } catch {
                testResult = .failure(message: error.localizedDescription)
                isAdding = false
            }
        }
    }
}

#Preview {
    AddSubsonicServerSheet(
        store: SubsonicServerStore(coordinator: .preview()),
        onDismiss: {}
    )
}
