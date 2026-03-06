import Vapor

// MARK: - ClerkError (primary error type — used by middleware and API client)

/// All errors produced by the ClerkVapor SDK.
/// Conforms to `AbortError` so Vapor renders them as proper HTTP responses.
public enum ClerkError: AbortError, LocalizedError, Sendable {

    // Auth errors
    case missingToken
    case unauthenticated
    case tokenExpired
    case tokenNotYetValid
    case invalidToken(String)

    // Config errors
    case configuration(String)

    // API / network errors
    case apiError(status: HTTPStatus, message: String)
    case networkError(String)
    case decodingError(String)

    // MARK: AbortError

    public var status: HTTPStatus {
        switch self {
        case .missingToken, .unauthenticated, .tokenExpired,
             .tokenNotYetValid, .invalidToken:
            return .unauthorized
        case .configuration:
            return .internalServerError
        case .apiError(let s, _):
            return s
        case .networkError, .decodingError:
            return .internalServerError
        }
    }

    public var reason: String { errorDescription ?? "Unknown Clerk error" }

    // MARK: LocalizedError

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No session token found. Provide a Bearer token or __session cookie."
        case .unauthenticated:
            return "Request is not authenticated."
        case .tokenExpired:
            return "Session token has expired."
        case .tokenNotYetValid:
            return "Session token is not yet valid (nbf claim is in the future)."
        case .invalidToken(let r):
            return "Invalid session token: \(r)"
        case .configuration(let msg):
            return "Clerk configuration error: \(msg)"
        case .apiError(_, let msg):
            return "Clerk API error: \(msg)"
        case .networkError(let msg):
            return "Network error communicating with Clerk: \(msg)"
        case .decodingError(let msg):
            return "Failed to decode Clerk response: \(msg)"
        }
    }
}

// MARK: - ClerkSDKError (legacy / alias type used by ClerkMiddlewareTests)

/// Legacy error type — mirrors `ClerkError` but with the original naming from ClerkMiddlewareTests.
/// Kept as a distinct type so existing tests compile without modification.
public enum ClerkSDKError: Error, LocalizedError, Sendable {
    case notConfigured
    case missingToken
    case tokenExpired
    case tokenNotYetValid
    case invalidSignature
    case unauthorizedParty(String)
    case jwksFetchFailed(String)
    case jwksParsingFailed
    case apiError(status: UInt, message: String, code: String?)
    case networkError(String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ClerkVapor is not configured. Call app.useClerk(_:) in configure.swift."
        case .missingToken:
            return "No session token found in __session cookie or Authorization header."
        case .tokenExpired:
            return "The session token has expired."
        case .tokenNotYetValid:
            return "The session token is not yet valid (nbf claim in the future)."
        case .invalidSignature:
            return "The session token signature could not be verified."
        case .unauthorizedParty(let p):
            return "Unauthorized party: \(p)."
        case .jwksFetchFailed(let m):
            return "Failed to fetch JWKS from Clerk: \(m)"
        case .jwksParsingFailed:
            return "Failed to parse JWKS response from Clerk."
        case .apiError(let s, let m, _):
            return "Clerk API error \(s): \(m)"
        case .networkError(let m):
            return "Network error communicating with Clerk: \(m)"
        case .decodingError(let m):
            return "Failed to decode Clerk response: \(m)"
        }
    }

    /// Maps to a Vapor `Abort` for HTTP responses.
    public var abort: Abort {
        switch self {
        case .missingToken, .tokenExpired, .tokenNotYetValid,
             .invalidSignature, .unauthorizedParty:
            return Abort(.unauthorized, reason: errorDescription ?? "Unauthorized")
        case .notConfigured:
            return Abort(.internalServerError, reason: errorDescription ?? "Server misconfiguration")
        default:
            return Abort(.internalServerError, reason: errorDescription ?? "Internal error")
        }
    }
}
