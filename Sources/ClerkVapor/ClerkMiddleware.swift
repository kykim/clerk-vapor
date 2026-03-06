import Vapor

// MARK: - ClerkMiddleware

/// Passive middleware — attempts token verification but never blocks the request.
/// Sets `req.clerkAuth` on every request. Check `req.clerkAuth.isAuthenticated` downstream.
///
/// Use `ClerkAuthMiddleware` (or `req.requireClerkAuth()`) to enforce authentication.
public struct ClerkMiddleware: AsyncMiddleware {

    private static let verifier = ClerkJWTVerifier()

    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let config = request.application.clerkConfig else {
            throw Abort(.internalServerError,
                        reason: "Clerk is not configured. Call app.useClerk(_:) in configure.swift.")
        }

        if let token = extractToken(from: request) {
            do {
                let payload = try await Self.verifier.verify(
                    token: token, config: config, client: request.client)
                request.setClerkAuth(ClerkAuth(payload: payload, token: token))
            } catch {
                request.clearClerkAuth()
                request.logger.debug("ClerkMiddleware: token verification failed — \(error)")
            }
        } else {
            request.clearClerkAuth()
        }

        return try await next.respond(to: request)
    }

    private func extractToken(from request: Request) -> String? {
        if let bearer = request.headers.bearerAuthorization { return bearer.token }
        if let cookie = request.cookies["__session"]        { return cookie.string }
        return nil
    }
}

// MARK: - ClerkAuthMiddleware (enforcing)

/// Enforcing middleware — returns HTTP 401 if the request is not authenticated.
/// Must be placed **after** `ClerkMiddleware` in the middleware chain.
///
/// ```swift
/// let protected = app.grouped(ClerkMiddleware(), ClerkAuthMiddleware())
/// protected.get("me") { req in ... }
/// ```
public struct ClerkAuthMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard request.clerkAuth.isAuthenticated else {
            throw ClerkError.unauthenticated
        }
        return try await next.respond(to: request)
    }
}

// MARK: - ClerkOrgMiddleware

/// Requires an active organisation claim matching the specified `orgId` and/or `role`.
public struct ClerkOrgMiddleware: AsyncMiddleware {
    private let requiredOrgId: String?
    private let requiredRole: String?

    public init(orgId: String? = nil, role: String? = nil) {
        self.requiredOrgId = orgId
        self.requiredRole  = role
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let auth = request.clerkAuth
        guard auth.isAuthenticated else { throw ClerkError.unauthenticated }
        if let required = requiredOrgId, auth.orgId != required {
            throw Abort(.forbidden, reason: "Not a member of the required organisation.")
        }
        if let required = requiredRole, auth.orgRole != required {
            throw Abort(.forbidden, reason: "Insufficient organisation role.")
        }
        return try await next.respond(to: request)
    }
}

// MARK: - RoutesBuilder helpers

extension RoutesBuilder {
    /// Route group protected by `ClerkMiddleware` + `ClerkAuthMiddleware` — returns 401 if unauthenticated.
    public func clerkProtected() -> RoutesBuilder {
        grouped(ClerkMiddleware(), ClerkAuthMiddleware())
    }

    /// Route group with optional Clerk auth — never blocks unauthenticated requests.
    public func clerkOptional() -> RoutesBuilder {
        grouped(ClerkMiddleware())
    }
}
