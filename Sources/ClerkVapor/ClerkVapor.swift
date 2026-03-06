/// ClerkVapor – Clerk.com authentication SDK for Vapor 4
///
/// Quick Start
/// -----------
/// 1. Register the configuration in `configure.swift`:
///
/// ```swift
/// import ClerkVapor
///
/// public func configure(_ app: Application) async throws {
///     app.useClerk(ClerkConfiguration(
///         secretKey: Environment.get("CLERK_SECRET_KEY")!,
///         publishableKey: Environment.get("CLERK_PUBLISHABLE_KEY"),
///         // Optional: supply your PEM public key for networkless JWT verification
///         // jwtKey: Environment.get("CLERK_JWT_KEY"),
///         authorizedParties: ["https://yourapp.com"]
///     ))
/// }
/// ```
///
/// 2. Add middleware in `routes.swift`:
///
/// ```swift
/// // Passive — populates req.clerkAuth but does not enforce
/// app.middleware.use(ClerkMiddleware())
///
/// // Enforcing — returns 401 if no valid session
/// let protected = app.grouped(ClerkMiddleware(), ClerkAuthMiddleware())
/// protected.get("me") { req async throws -> ClerkUser in
///     let auth = try req.requireClerkAuth()
///     return try await req.clerk.users.getUser(userId: auth.userId!)
/// }
/// ```
///
/// 3. Webhook handling:
///
/// ```swift
/// app.clerkWebhook(at: "webhooks", "clerk", secret: Environment.get("CLERK_WEBHOOK_SECRET")!) { event, req in
///     req.logger.info("Received event: \(event.type.rawValue)")
///     return .ok
/// }
/// ```

@_exported import Vapor
