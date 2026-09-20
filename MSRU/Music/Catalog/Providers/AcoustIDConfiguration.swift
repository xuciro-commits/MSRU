//
//  AcoustIDConfiguration.swift
//  MSRU
//
//  Created for Acoustic Metadata Pipeline Architecture.
//

import Foundation

/// Persistent configuration and credential management for the AcoustID web service.
public actor AcoustIDConfiguration {

    public static let shared = AcoustIDConfiguration()

    private let defaults: UserDefaults
    private let keyName = "MSRU_AcoustID_API_Key"
    /// Default verified Application Client Key (AcoustID requires an Application API key for /v2/lookup)
    public static let defaultClientKey = "cSpUJKpD"

    private var cachedKey: String?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The active AcoustID client API key used for fingerprint lookups.
    public var apiKey: String {
        get {
            if let cached = cachedKey {
                return cached
            }
            let key = defaults.string(forKey: keyName) ?? Self.defaultClientKey
            cachedKey = key
            return key
        }
    }

    /// Updates the AcoustID API key.
    public func setApiKey(_ newKey: String) {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalVal = trimmed.isEmpty ? Self.defaultClientKey : trimmed
        defaults.set(finalVal, forKey: keyName)
        cachedKey = finalVal
    }

    /// Resets the API key back to the built-in verified default client key.
    public func resetToDefault() {
        defaults.removeObject(forKey: keyName)
        cachedKey = Self.defaultClientKey
    }

    /// Tests the connectivity of the current API key against the official AcoustID lookup endpoint.
    public func verifyConnectivity() async -> (success: Bool, message: String) {
        let currentKey = apiKey
        // AcoustID /v2/lookup accepts trackid or (duration + fingerprint).
        // Using a standard reference trackid verifies the Application API Key validity and network connectivity cleanly.
        let referenceTrackId = "9ff43b6a-4f16-427c-93c2-92307ca505e0"
        let endpoint = "https://api.acoustid.org/v2/lookup?client=\(currentKey)&trackid=\(referenceTrackId)"
        guard let url = URL(string: endpoint) else {
            return (false, "无效的 API 请求地址")
        }

        var req = URLRequest(url: url, timeoutInterval: 8.0)
        req.setValue("MSRU/1.0 (contact@msru.local)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return (false, "未收到服务器响应")
            }

            if http.statusCode == 200 {
                return (true, "连接成功 (Status 200 OK)")
            } else if http.statusCode == 401 || http.statusCode == 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let code = error["code"] as? Int,
                   let msg = error["message"] as? String {
                    if code == 4 {
                        return (false, "AcoustID 报错: API Key 无效。提示：个人用户 User Key (用于上传声纹) 无法用于查询，请使用应用 Client Key (前往 acoustid.org/new-application 获取)")
                    }
                    return (false, "AcoustID 报错: \(msg) (代码 \(code))")
                }
                return (false, "AcoustID 响应异常 (HTTP \(http.statusCode))")
            } else {
                return (false, "HTTP 状态码 \(http.statusCode)")
            }
        } catch {
            return (false, "网络请求失败: \(error.localizedDescription)")
        }
    }
}
