import Combine
import Foundation
import Security
import UIKit

// MARK: - CryptoricAuth LicenseManager
// Direct 1-Step License Key Verification for CryptoricAuth API 1.0
// Docs: https://cryptoricauth.alwaysdata.net/docs/index.html#/

@MainActor
final class LicenseManager: ObservableObject {

    // ─── CryptoricAuth Credentials ──────────────────────────────────────────
    private static let appName    = "ios external"
    private static let ownerID    = "47" // Dashboard Owner ID from panel
    private static let appSecret  = "d31644ba37ed77b7793504f77106f220e9c4b01440781988a202d10275a60105"
    private static let apiBaseURL = "https://cryptoricauth.alwaysdata.net/api.php"
    private static let appVersion = "1.0"
    // ────────────────────────────────────────────────────────────────────────

    @Published private(set) var expirationDate: Date?
    @Published private(set) var isActive  = false
    @Published private(set) var isBusy    = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String? = "https://discord.gg/j4RydbkY8b"
    @Published var rememberKey = true

    private let service          = "com.Cryptoric.external-ios.activation"
    private let keyAccount       = "license-key"
    private let activatedAccount = "license-activated"
    private let hwidAccount      = "device-hwid"

    init() {
        let key = string(for: keyAccount) ?? UserDefaults.standard.string(forKey: "cryptoric_key")
        let isActivated = (string(for: activatedAccount) == "true") || UserDefaults.standard.bool(forKey: "cryptoric_activated")

        if let key, !key.isEmpty, isActivated {
            isActive = true
        } else {
            isActive = false
        }
    }

    var hasRememberedKey: Bool {
        guard let stored = string(for: keyAccount) ?? UserDefaults.standard.string(forKey: "cryptoric_key") else { return false }
        return !stored.isEmpty
    }

    // Stable hardware identifier persisted in Keychain + UserDefaults
    private var persistentHWID: String {
        if let stored = string(for: hwidAccount), !stored.isEmpty {
            return stored
        }
        if let userDefaultsHwid = UserDefaults.standard.string(forKey: "cryptoric_hwid"), !userDefaultsHwid.isEmpty {
            save(userDefaultsHwid, for: hwidAccount)
            return userDefaultsHwid
        }
        let vendorId = UIDevice.current.identifierForVendor?.uuidString
        let newHwid = (vendorId != nil && !vendorId!.isEmpty) ? vendorId! : UUID().uuidString
        save(newHwid, for: hwidAccount)
        UserDefaults.standard.set(newHwid, forKey: "cryptoric_hwid")
        return newHwid
    }

    func beginLaunchSession() {
        guard let savedKey = rememberedKey(), !savedKey.isEmpty else {
            if isActive {
                deactivate()
            }
            return
        }

        // Re-verify remembered key with the CryptoricAuth server on launch
        isBusy = true
        Task {
            do {
                let result = try await verifyLicense(key: savedKey)
                if result.success {
                    // Check expiration date if present
                    if let expStr = result.expires, let expTs = Double(expStr), expTs > 0 {
                        let expDate = Date(timeIntervalSince1970: expTs)
                        expirationDate = expDate
                        if Date() > expDate {
                            deactivate()
                            message = "License has expired"
                            isBusy = false
                            return
                        }
                    }
                    isActive = true
                    message  = result.message ?? "Activated successfully!"
                    persistActivation(key: savedKey)
                } else {
                    // Key was deleted or invalidated on the server
                    deactivate()
                    message = result.message ?? "License key is invalid or has been revoked/deleted"
                }
            } catch {
                // If there is a network error, keep current state or notify
                message = "License check error: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).filter { !$0.isNewline }
        guard !trimmed.isEmpty, !isBusy else { return }

        isBusy  = true
        message = "Verifying with CryptoricAuth..."

        Task {
            do {
                let result = try await verifyLicense(key: trimmed)

                if result.success {
                    // Check expiry if present
                    if let expStr = result.expires, let expTs = Double(expStr), expTs > 0 {
                        let expDate = Date(timeIntervalSince1970: expTs)
                        expirationDate = expDate
                        if Date() > expDate {
                            deactivate()
                            message = "License has expired"
                            isBusy = false
                            return
                        }
                    }
                    isActive = true
                    message  = result.message ?? "Activated successfully!"
                    persistActivation(key: trimmed)
                } else {
                    deactivate()
                    message  = result.message ?? "Invalid license key"
                }
            } catch {
                isActive = false
                message  = "Connection error: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    private func persistActivation(key: String) {
        if rememberKey {
            save(key, for: keyAccount)
            save("true", for: activatedAccount)
            UserDefaults.standard.set(key, forKey: "cryptoric_key")
            UserDefaults.standard.set(true, forKey: "cryptoric_activated")
        }
    }

    func rememberedKey() -> String? {
        string(for: keyAccount) ?? UserDefaults.standard.string(forKey: "cryptoric_key")
    }

    func refresh() {
        if let savedKey = rememberedKey(), !savedKey.isEmpty {
            activate(key: savedKey)
        } else {
            deactivate()
        }
    }

    func deactivate() {
        delete(keyAccount)
        delete(activatedAccount)
        UserDefaults.standard.removeObject(forKey: "cryptoric_key")
        UserDefaults.standard.set(false, forKey: "cryptoric_activated")
        isActive  = false
        expirationDate = nil
        message   = "Activation removed from this device"
    }

    // MARK: - CryptoricAuth API Verification (GET action=verify)

    private func verifyLicense(key: String) async throws -> CryptoricLicenseResponse {
        guard var components = URLComponents(string: Self.apiBaseURL) else {
            throw CryptoricError("Invalid API URL configuration")
        }

        let hwid = persistentHWID

        components.queryItems = [
            URLQueryItem(name: "action",  value: "verify"),
            URLQueryItem(name: "key",     value: key),
            URLQueryItem(name: "hwid",    value: hwid),
            URLQueryItem(name: "ownerid", value: Self.ownerID),
            URLQueryItem(name: "name",    value: Self.appName),
            URLQueryItem(name: "secret",  value: Self.appSecret),
            URLQueryItem(name: "version", value: Self.appVersion)
        ]

        guard let requestURL = components.url else {
            throw CryptoricError("Could not build authentication request URL")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CryptoricError("Server returned an invalid response")
        }

        guard (200...299).contains(http.statusCode) else {
            throw CryptoricError("Server HTTP Error: \(http.statusCode)")
        }

        let rawString = String(data: data, encoding: .utf8) ?? ""

        // Extract clean JSON payload between the first '{' and last '}' to strip PHP deprecation warnings / HTML headers
        var jsonData = data
        if let firstBrace = rawString.firstIndex(of: "{"),
           let lastBrace = rawString.lastIndex(of: "}") {
            let jsonString = String(rawString[firstBrace...lastBrace])
            if let extractedData = jsonString.data(using: .utf8) {
                jsonData = extractedData
            }
        }

        // Try resilient JSON dictionary parsing
        if let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let successVal: Bool
            if let boolVal = json["success"] as? Bool {
                successVal = boolVal
            } else if let intVal = json["success"] as? Int {
                successVal = (intVal == 1)
            } else if let strVal = json["success"] as? String {
                let s = strVal.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                successVal = (s == "true" || s == "1")
            } else {
                successVal = false
            }

            let messageVal = json["message"] as? String

            var expiresVal: String? = nil
            if let exp = json["expires"] {
                expiresVal = "\(exp)"
            } else if let exp = json["expiry"] {
                expiresVal = "\(exp)"
            } else if let dataObj = json["data"] as? [String: Any] {
                if let expTs = dataObj["expires_timestamp"], !(expTs is NSNull) {
                    if let expBool = expTs as? Bool, !expBool {
                        expiresVal = nil // Lifetime / no expiry
                    } else {
                        expiresVal = "\(expTs)"
                    }
                } else if let expAt = dataObj["expires_at"], !(expAt is NSNull) {
                    expiresVal = "\(expAt)"
                }
            }

            return CryptoricLicenseResponse(success: successVal, message: messageVal, expires: expiresVal)
        }

        // Fallback Codable decoding
        if let decoded = try? JSONDecoder().decode(CryptoricLicenseResponse.self, from: jsonData) {
            return decoded
        }

        throw CryptoricError("Invalid response from auth server: \(rawString)")
    }

    // MARK: - Keychain Storage

    private func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String, for account: String) {
        let base: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String]     = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - CryptoricAuth Response Model

private struct CryptoricLicenseResponse: Decodable {
    let success: Bool
    let message: String?
    let expires: String?

    init(success: Bool, message: String?, expires: String?) {
        self.success = success
        self.message = message
        self.expires = expires
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Flexible success parsing (handles Bool, Int, String)
        if let boolVal = try? container.decode(Bool.self, forKey: .success) {
            self.success = boolVal
        } else if let intVal = try? container.decode(Int.self, forKey: .success) {
            self.success = (intVal == 1)
        } else if let strVal = try? container.decode(String.self, forKey: .success) {
            let s = strVal.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            self.success = (s == "true" || s == "1")
        } else {
            self.success = false
        }

        self.message = try? container.decode(String.self, forKey: .message)

        if let expStr = try? container.decode(String.self, forKey: .expires) {
            self.expires = expStr
        } else if let expInt = try? container.decode(Int.self, forKey: .expires) {
            self.expires = String(expInt)
        } else if let expDouble = try? container.decode(Double.self, forKey: .expires) {
            self.expires = String(Int64(expDouble))
        } else if let expAlt = try? container.decode(String.self, forKey: .expiry) {
            self.expires = expAlt
        } else if let expAltInt = try? container.decode(Int.self, forKey: .expiry) {
            self.expires = String(expAltInt)
        } else {
            self.expires = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case success, message, expires, expiry
    }
}

// MARK: - Helper Error

private struct CryptoricError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { self.errorDescription = message }
}
