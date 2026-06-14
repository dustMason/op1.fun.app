import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case server(String)
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The op1.fun API returned an unexpected response."
        case .server(let message):
            return message
        case .missingCredentials:
            return "Please log in before downloading."
        }
    }
}

final class APIClient {
    private let baseURL = URL(string: "https://api.op1.fun/v1/")!

    func logIn(email: String, password: String) async throws -> String {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        let data = try await post(path: "api_token", body: body, email: nil, token: nil)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIClientError.invalidResponse
        }

        if let token = object["api_token"] as? String, !token.isEmpty {
            return token
        }

        if let error = object["error"] as? String {
            throw APIClientError.server(error)
        }

        throw APIClientError.invalidResponse
    }

    func enableAppFeatureFlag(email: String, token: String) async throws {
        _ = try await post(
            path: "feature_flags",
            body: ["flags": ["app": true]],
            email: email,
            token: token
        )
    }

    func fetchPatch(path: String, email: String, token: String) async throws -> RemotePatch {
        let data = try await get(path: path, email: email, token: token)
        return try JSONAPI.parsePatchRoot(data)
    }

    func fetchPack(path: String, email: String, token: String) async throws -> RemotePack {
        let data = try await get(path: path, email: email, token: token)
        return try JSONAPI.parsePackRoot(data)
    }

    private func get(path: String, email: String, token: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(email, forHTTPHeaderField: "X-User-Email")
        request.setValue(token, forHTTPHeaderField: "X-User-Token")

        return try await data(for: request)
    }

    private func post(path: String, body: [String: Any], email: String?, token: String?) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let email, let token {
            request.setValue(email, forHTTPHeaderField: "X-User-Email")
            request.setValue(token, forHTTPHeaderField: "X-User-Token")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await data(for: request)
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let error = object["error"] as? String
            {
                throw APIClientError.server(error)
            }

            throw APIClientError.server("op1.fun returned HTTP \(httpResponse.statusCode).")
        }

        return data
    }
}

