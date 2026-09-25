//
//  AddSubsonicServerSheet.swift
//  MSRU
//
//  Sheet for connecting a Subsonic / OpenSubsonic server (a NAS, Navidrome, …).
//  Nothing is saved until the server accepts the credentials.
//

import SwiftUI
import SubsonicKit

struct AddSubsonicServerSheet: View {
    @Bindable var store: SubsonicServerStore
    let onDismiss: () -> Void

    @State private var selectedPreset: SubsonicServerPreset = .navidrome
    @State private var serverName = ""
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""

    @State private var isTesting = false
    @State private var isAdding = false
    @State private var testResult: TestResult?

    private enum TestResult {
        case success(info: SubsonicServerInfo)
        case failure(message: String)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                presetPicker
                helperBanner
                formFields

                if let testResult {
                    testStatusView(testResult)
                }

                Spacer()

                HStack {
                    Button("Cancel", role: .cancel, action: onDismiss)
                        .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(action: runTest) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 8)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTesting || isAdding || !isFormValid)

                    Button(action: runAdd) {
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
            .navigationTitle(Text("Connect a Server"))
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server Type")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Server Type", selection: $selectedPreset) {
                ForEach(SubsonicServerPreset.allCases) { preset in
                    Label {
                        Text(preset.title)
                    } icon: {
                        Image(systemName: preset.iconName)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: selectedPreset) {
                testResult = nil
            }
        }
    }

    private var helperBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)

            Text(selectedPreset.instructions)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Name") {
                TextField("Name", text: $serverName, prompt: Text(selectedPreset.title))
            }
            field("Server Address") {
                TextField(
                    "Server Address",
                    text: $serverAddress,
                    prompt: Text(verbatim: "http://nas.local:\(selectedPreset.defaultPort)")
                )
            }
            HStack(spacing: 14) {
                field("Username") {
                    TextField("Username", text: $username)
                }
                field("Password") {
                    SecureField("Password", text: $password)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
    }

    private func field(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
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
                    Text("Connected · API \(info.apiVersion)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                    if info.isOpenSubsonic {
                        Text("OpenSubsonic extensions: \(info.openSubsonicExtensions.map(\.name).joined(separator: ", "))")
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

    private var resolvedName: String {
        let name = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? String(localized: selectedPreset.title) : name
    }

    private var isFormValid: Bool {
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    private func normalizedURL() -> URL? {
        var address = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.hasPrefix("http://") && !address.hasPrefix("https://") {
            address = "http://\(address)"
        }
        return URL(string: address)
    }

    private func runTest() {
        guard let url = normalizedURL() else {
            testResult = .failure(message: String(localized: "The server address is not valid."))
            return
        }
        isTesting = true
        testResult = nil
        Task {
            do {
                let (info, _) = try await store.testConnection(url: url, username: username, password: password)
                testResult = .success(info: info)
            } catch {
                testResult = .failure(message: error.localizedDescription)
            }
            isTesting = false
        }
    }

    private func runAdd() {
        guard let url = normalizedURL() else {
            testResult = .failure(message: String(localized: "The server address is not valid."))
            return
        }
        isAdding = true
        Task {
            do {
                try await store.addServer(name: resolvedName, url: url, username: username, password: password)
                onDismiss()
            } catch {
                testResult = .failure(message: error.localizedDescription)
                isAdding = false
            }
        }
    }
}

// MARK: - Preset Copy

private extension SubsonicServerPreset {
    var title: LocalizedStringResource {
        switch self {
        case .zspace: "ZSpace"
        case .navidrome: "Navidrome"
        case .generic: "Subsonic / OpenSubsonic"
        }
    }

    var instructions: LocalizedStringKey {
        switch self {
        case .zspace:
            "Turn on the Subsonic media service in ZSpace, then sign in with the account you set for it."
        case .navidrome:
            "Navidrome speaks OpenSubsonic natively. Use its address and your usual sign-in."
        case .generic:
            "Works with any server compatible with Subsonic 1.16.1 or OpenSubsonic, such as Gonic, LMS or Airsonic."
        }
    }
}

#Preview {
    AddSubsonicServerSheet(
        store: SubsonicServerStore(coordinator: .preview()),
        onDismiss: {}
    )
}
