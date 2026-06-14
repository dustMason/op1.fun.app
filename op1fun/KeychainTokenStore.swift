import Foundation

final class CredentialStore {
    private let emailKey = "op1fun.email"
    private let tokenKey = "op1fun.apiToken"

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
            UserDefaults.standard.string(forKey: tokenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: tokenKey)
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
    }
}
