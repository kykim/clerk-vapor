# ClerkVapor

A Swift SDK for integrating [Clerk](https://clerk.com) authentication into [Vapor 4](https://vapor.codes) applications.

## Features

- 🔐 **JWT Verification** — RS256 token verification via JWKS (with in-memory caching) or a static PEM key (networkless)
- 🛡️ **Middleware** — `ClerkMiddleware` (passive) and `ClerkAuthMiddleware` (enforcing) for protecting routes
- 🏢 **Organisation Support** — `ClerkOrgMiddleware` for org-scoped access control
- 📦 **Backend API Client** — Type-safe wrappers for Users, Sessions, and Organizations
- 🪝 **Webhook Handling** — Svix signature verification + event routing
- ✅ **Fully async/await** — Built for Swift concurrency

## Requirements

- Swift 5.9+
- macOS 13+ / Linux (Ubuntu 20.04+)
- Vapor 4.99+

## Installation

Add ClerkVapor to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/clerk-vapor.git", from: "1.0.0"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "ClerkVapor", package: "clerk-vapor"),
    ]),
]
```

## Quick Start

### 1. Configure

```swift
// Sources/App/configure.swift
import ClerkVapor

public func configure(_ app: Application) async throws {
    app.useClerk(ClerkConfiguration(
        secretKey: Environment.get("CLERK_SECRET_KEY")!,
        publishableKey: Environment.get("CLERK_PUBLISHABLE_KEY"),
        // Optional: PEM key for networkless JWT verification
        // jwtKey: Environment.get("CLERK_JWT_KEY"),
        authorizedParties: ["https://yourapp.com", "http://localhost:3000"]
    ))
}
```

### 2. Protect Routes

```swift
// Sources/App/routes.swift
import ClerkVapor

public func routes(_ app: Application) throws {

    // Public route — clerkAuth is populated but not required
    app.grouped(ClerkMiddleware()).get("public") { req -> String in
        if req.clerkAuth.isAuthenticated {
            return "Hello, \(req.clerkAuth.userId!)"
        }
        return "Hello, stranger"
    }

    // Protected routes — returns 401 if no valid session
    let auth = app.grouped(ClerkMiddleware(), ClerkAuthMiddleware())

    auth.get("me") { req async throws -> ClerkUser in
        let userId = req.clerkAuth.userId!
        return try await req.clerk.users.getUser(userId: userId)
    }

    // Organisation-scoped route
    let adminOnly = auth.grouped(ClerkOrgMiddleware(role: "org:admin"))
    adminOnly.delete("users", ":userId") { req async throws -> HTTPStatus in
        let targetId = try req.parameters.require("userId")
        _ = try await req.clerk.users.deleteUser(userId: targetId)
        return .noContent
    }
}
```

### 3. Webhooks

```swift
app.clerkWebhook(
    at: "webhooks", "clerk",
    secret: Environment.get("CLERK_WEBHOOK_SECRET")!
) { event, req in
    switch event.type {
    case .userCreated:
        let user = try event.data.decode(as: ClerkUser.self)
        req.logger.info("New user: \(user.id)")
        // sync to your database…
    case .userDeleted:
        req.logger.info("User deleted: \(event.data.id ?? "unknown")")
    default:
        req.logger.debug("Unhandled event: \(event.type.rawValue)")
    }
    return .ok
}
```

## Configuration Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `secretKey` | `String` | required | `sk_live_...` or `sk_test_...` from Clerk Dashboard |
| `publishableKey` | `String?` | nil | `pk_live_...` for frontend identification |
| `jwtKey` | `String?` | nil | PEM public key for networkless JWT verification |
| `apiURL` | `String` | `https://api.clerk.com` | Clerk Backend API base URL |
| `apiVersion` | `String` | `v1` | API version |
| `authorizedParties` | `[String]` | `[]` | Allowed origins for the `azp` JWT claim |
| `clockSkewSeconds` | `Int` | `5` | Tolerance for JWT `exp`/`nbf` validation |

## Middleware Reference

| Middleware | Behaviour |
|------------|-----------|
| `ClerkMiddleware` | Verifies token if present; sets `req.clerkAuth`. Never blocks. |
| `ClerkAuthMiddleware` | Requires `req.clerkAuth.isAuthenticated == true`; returns 401 otherwise. Must follow `ClerkMiddleware`. |
| `ClerkOrgMiddleware(orgId:role:)` | Requires an active organisation claim matching `orgId` and/or `role`. |

## Backend API Reference

```swift
// Users
let user  = try await req.clerk.users.getUser(userId: "user_xxx")
let users = try await req.clerk.users.listUsers(limit: 20, query: "alice")
let count = try await req.clerk.users.count()
try await req.clerk.users.banUser(userId: "user_xxx")

// Sessions
let session = try await req.clerk.sessions.getSession(sessionId: "sess_xxx")
try await req.clerk.sessions.revokeSession(sessionId: "sess_xxx")

// Organizations
let org  = try await req.clerk.organizations.getOrganization(orgId: "org_xxx")
let orgs = try await req.clerk.organizations.listOrganizations()
```

## Environment Variables

```bash
CLERK_SECRET_KEY=sk_live_...
CLERK_PUBLISHABLE_KEY=pk_live_...
CLERK_JWT_KEY="-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
CLERK_WEBHOOK_SECRET=whsec_...
```

## JWT Verification Strategy

ClerkVapor supports two verification modes:

**Network mode (default):** Fetches Clerk's JWKS on first use and caches the keys for 1 hour. Requires outbound HTTPS to `https://api.clerk.com`.

**Networkless mode:** Set `jwtKey` to your instance's PEM public key (from Clerk Dashboard → API Keys → Show JWT public key). All verification happens in-process with no network calls.

## License

MIT
