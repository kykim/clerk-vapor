import Vapor

// MARK: - ClerkAuth

/// The resolved authentication state attached to every request after middleware runs.
/// Always present on the request after `ClerkMiddleware` — check `isAuthenticated` before using other fields.
public struct ClerkAuth: Sendable {
    /// Whether the request carries a valid, verified session token.
    public let isAuthenticated: Bool

    /// The verified Clerk user ID (`user_xxx`), or nil if unauthenticated.
    public let userId: String?

    /// The verified session ID (`sess_xxx`), or nil if unauthenticated.
    public let sessionId: String?

    /// The active organisation ID (`org_xxx`), if present in the JWT.
    public let orgId: String?

    /// The active organisation role (e.g. `org:admin`), if present.
    public let orgRole: String?

    /// The active organisation slug, if present.
    public let orgSlug: String?

    /// Granted organisation permissions, if present.
    public let orgPermissions: [String]

    /// Whether this session is an impersonation session (`act` claim present).
    public let isImpersonating: Bool

    /// The raw JWT string that was verified.
    public let token: String?

    /// The full verified payload, if available.
    public let payload: ClerkSessionPayload?

    // MARK: - Authenticated init (from verified payload)
    public init(payload: ClerkSessionPayload, token: String) {
        self.isAuthenticated = true
        self.userId          = payload.sub.value
        self.sessionId       = payload.sid
        self.orgId           = payload.org?.id
        self.orgRole         = payload.org?.rol
        self.orgSlug         = payload.org?.slg
        self.orgPermissions  = payload.org?.per ?? []
        self.isImpersonating = payload.act != nil
        self.token           = token
        self.payload         = payload
    }

    // MARK: - Unauthenticated sentinel
    static let unauthenticated = ClerkAuth(
        isAuthenticated: false, userId: nil, sessionId: nil,
        orgId: nil, orgRole: nil, orgSlug: nil,
        orgPermissions: [], isImpersonating: false,
        token: nil, payload: nil
    )

    private init(
        isAuthenticated: Bool, userId: String?, sessionId: String?,
        orgId: String?, orgRole: String?, orgSlug: String?,
        orgPermissions: [String], isImpersonating: Bool,
        token: String?, payload: ClerkSessionPayload?
    ) {
        self.isAuthenticated = isAuthenticated
        self.userId = userId; self.sessionId = sessionId
        self.orgId = orgId; self.orgRole = orgRole; self.orgSlug = orgSlug
        self.orgPermissions = orgPermissions; self.isImpersonating = isImpersonating
        self.token = token; self.payload = payload
    }

    // MARK: - Permission / Role helpers

    /// Returns `true` if the active organisation grants `permission`.
    public func has(permission: String) -> Bool { orgPermissions.contains(permission) }

    /// Returns `true` if the active organisation role matches `role`.
    public func has(role: String) -> Bool { orgRole == role }
}

// MARK: - Request Storage

private struct ClerkAuthKey: StorageKey { typealias Value = ClerkAuth }

// Sendable wrapper for optional ClerkAuth storage
private struct OptionalClerkAuthWrapper: Sendable { let auth: ClerkAuth? }
private struct OptionalClerkAuthKey: StorageKey { typealias Value = OptionalClerkAuthWrapper }

extension Request {
    /// The Clerk auth state — always present after `ClerkMiddleware`.
    /// Check `clerkAuth.isAuthenticated` before using `userId` etc.
    /// Non-throwing: returns `.unauthenticated` sentinel if middleware hasn't run.
    public var clerkAuth: ClerkAuth {
        storage[ClerkAuthKey.self] ?? .unauthenticated
    }

    /// The verified Clerk auth if present, or `nil` (for optional/public routes).
    public var optionalClerkAuth: ClerkAuth? {
        storage[OptionalClerkAuthKey.self]?.auth
    }

    /// Require authentication or throw `ClerkError.unauthenticated` (HTTP 401).
    @discardableResult
    public func requireClerkAuth() throws -> ClerkAuth {
        let auth = clerkAuth
        guard auth.isAuthenticated else { throw ClerkError.unauthenticated }
        return auth
    }

    internal func setClerkAuth(_ auth: ClerkAuth) {
        storage[ClerkAuthKey.self] = auth
        storage[OptionalClerkAuthKey.self] = OptionalClerkAuthWrapper(auth: auth)
    }

    internal func clearClerkAuth() {
        storage[ClerkAuthKey.self] = .unauthenticated
        storage[OptionalClerkAuthKey.self] = OptionalClerkAuthWrapper(auth: nil)
    }
}
