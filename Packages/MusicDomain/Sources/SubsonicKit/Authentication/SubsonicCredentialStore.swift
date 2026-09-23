//
//  SubsonicCredentialStore.swift
//  SubsonicKit
//
//  Secure credential storage interface and Keychain implementation.
//

import Foundation
import Security

public protocol SubsonicCredentialStore: Sendable {
    func savePassword(_ password: String, for serverID: LibrarySourceID) throws
    func password(for serverID: LibrarySourceID) throws -> String?
    func deletePassword(for serverID: LibrarySourceID) throws
}

public final class KeychainSubsonicCredentialStore: SubsonicCredentialStore, Sendable {
    public let service: String

    public init(service: String = "com.msru.subsonic.credentials") {
        self.service = service
    }

    public func savePassword(_ password: String, for serverID: LibrarySourceID) throws {
        guard let data = password.data(using: .utf8) else {
            throw RemoteLibraryError.malformedResponse(details: "Invalid password encoding")
        }

        // Delete existing item first
        try? deletePassword(for: serverID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw RemoteLibraryError.serverError(code: Int(status), message: "Failed to save password to Keychain: \(status)")
        }
    }

    public func password(for serverID: LibrarySourceID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            throw RemoteLibraryError.serverError(code: Int(status), message: "Failed to read password from Keychain: \(status)")
        }

        return password
    }

    public func deletePassword(for serverID: LibrarySourceID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw RemoteLibraryError.serverError(code: Int(status), message: "Failed to delete password from Keychain: \(status)")
        }
    }
}

public final class InMemorySubsonicCredentialStore: SubsonicCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var passwords: [LibrarySourceID: String] = [:]

    public init() {}

    public func savePassword(_ password: String, for serverID: LibrarySourceID) throws {
        lock.lock()
        defer { lock.unlock() }
        passwords[serverID] = password
    }

    public func password(for serverID: LibrarySourceID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return passwords[serverID]
    }

    public func deletePassword(for serverID: LibrarySourceID) throws {
        lock.lock()
        defer { lock.unlock() }
        passwords.removeValue(forKey: serverID)
    }
}
