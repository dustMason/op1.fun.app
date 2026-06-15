import Foundation
import Security

final class CredentialStore {
    private let emailKey = "op1fun.email"
    private let tokenService = "com.fiftyfootfoghorn.op1fun"
    private let tokenAccount = "apiToken"
    private let userIDKey = "op1fun.userID"
    private let usernameKey = "op1fun.username"

    var email: String? {
        get {
            UserDefaults.standard.string(forKey: emailKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: emailKey)
        }
    }

    var token: String? {
        get {
            keychainToken
        }
        set {
            if let newValue, !newValue.isEmpty {
                saveToken(newValue)
            } else {
                deleteToken()
            }
        }
    }

    var userID: String? {
        get {
            UserDefaults.standard.string(forKey: userIDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userIDKey)
        }
    }

    var username: String? {
        get {
            UserDefaults.standard.string(forKey: usernameKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: usernameKey)
        }
    }

    var isLoggedIn: Bool {
        guard let email, !email.isEmpty, let token, !token.isEmpty else {
            return false
        }

        return true
    }

    func clear() {
        email = nil
        token = nil
        userID = nil
        username = nil
    }

    private var keychainToken: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else {
            return
        }

        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }

    private func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]

        SecItemDelete(query as CFDictionary)
    }
}
