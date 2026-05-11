import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case unprocessable(String)
    case serverError(Int, String?)
    case networkError(Error)
    case decodingError(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unauthorized: return String(localized: "error_unauthorized")
        case .forbidden: return String(localized: "error_forbidden")
        case .notFound: return String(localized: "error_not_found")
        case .conflict(let msg): return msg
        case .unprocessable(let msg): return msg
        case .serverError(let code, let msg): return msg ?? "Server error \(code)"
        case .networkError(let e): return e.localizedDescription
        case .decodingError: return String(localized: "error_decoding")
        case .cancelled: return nil
        }
    }
}
