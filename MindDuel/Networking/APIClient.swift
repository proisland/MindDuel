import Foundation

/// Centralised HTTP client. Injects the access token, auto-refreshes on 401,
/// and decodes JSON responses into the expected type.
actor APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = URL(string: "http://localhost:3000/v1")!
    #else
    private let baseURL = URL(string: "https://api.mindduel.no/v1")!
    #endif

    private let session: URLSession
    private let tokenStore = AuthTokenStore.shared
    private var isRefreshing = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: – Public interface

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await request(method: "GET", path: path, query: query, body: nil as Empty?)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "POST", path: path, query: [:], body: body)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "PATCH", path: path, query: [:], body: body)
    }

    func delete(_ path: String) async throws {
        let _: Empty = try await request(method: "DELETE", path: path, query: [:], body: nil as Empty?)
    }

    // MARK: – Core

    private func request<B: Encodable, T: Decodable>(
        method: String, path: String, query: [String: String], body: B?
    ) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            urlComponents.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var req = URLRequest(url: urlComponents.url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        if let token = tokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await perform(req, retryOnUnauthorized: true)
    }

    private func perform<T: Decodable>(_ req: URLRequest, retryOnUnauthorized: Bool) async throws -> T {
        let (data, response) = try await executeRequest(req)
        let http = response as! HTTPURLResponse

        if http.statusCode == 401 && retryOnUnauthorized {
            try await refreshIfNeeded()
            var retried = req
            if let token = tokenStore.accessToken {
                retried.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data2, response2) = try await executeRequest(retried)
            let http2 = response2 as! HTTPURLResponse
            return try decode(data: data2, status: http2.statusCode)
        }

        return try decode(data: data, status: http.statusCode)
    }

    private func executeRequest(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch let e as URLError where e.code == .cancelled {
            throw APIError.cancelled
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func decode<T: Decodable>(data: Data, status: Int) throws -> T {
        switch status {
        case 200...299:
            if T.self == Empty.self { return Empty() as! T }
            do {
                return try JSONDecoder.api.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 404: throw APIError.notFound
        case 409:
            let msg = (try? JSONDecoder.api.decode(ErrorBody.self, from: data))?.message ?? "Conflict"
            throw APIError.conflict(msg)
        case 422:
            let msg = (try? JSONDecoder.api.decode(ErrorBody.self, from: data))?.message ?? "Invalid request"
            throw APIError.unprocessable(msg)
        default:
            let msg = (try? JSONDecoder.api.decode(ErrorBody.self, from: data))?.message
            throw APIError.serverError(status, msg)
        }
    }

    // MARK: – Token refresh

    private func refreshIfNeeded() async throws {
        guard !isRefreshing else { return }
        guard let refresh = tokenStore.refreshToken else { throw APIError.unauthorized }
        isRefreshing = true
        defer { isRefreshing = false }

        struct RefreshBody: Encodable { let refreshToken: String }
        struct TokenPair: Decodable { let accessToken: String; let refreshToken: String }

        var req = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RefreshBody(refreshToken: refresh))

        do {
            let (data, response) = try await executeRequest(req)
            let status = (response as! HTTPURLResponse).statusCode
            if status == 200, let pair = try? JSONDecoder.api.decode(TokenPair.self, from: data) {
                tokenStore.save(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
            } else {
                tokenStore.clear()
                throw APIError.unauthorized
            }
        } catch is APIError {
            tokenStore.clear()
            throw APIError.unauthorized
        }
    }
}

// MARK: – Helpers

struct Empty: Codable {}

private struct ErrorBody: Decodable { let message: String }

extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
