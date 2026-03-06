import Vapor
import Leaf
import ClerkVapor

// MARK: - ClerkLeaf

/// Entry point for the ClerkLeaf integration module.
///
/// In `configure.swift`:
/// ```swift
/// app.useClerk(ClerkConfiguration(secretKey: ..., publishableKey: ...))
/// app.useClerkLeaf()   // registers all Clerk Leaf tags + enables Leaf renderer
/// ```
public struct ClerkLeaf {

    /// Registers all built-in Clerk Leaf tags on the application.
    public static func register(on app: Application) {
        app.leaf.tags["clerkScript"]               = ClerkScriptTag()
        app.leaf.tags["clerkSignIn"]               = ClerkSignInTag()
        app.leaf.tags["clerkSignUp"]               = ClerkSignUpTag()
        app.leaf.tags["clerkUserButton"]           = ClerkUserButtonTag()
        app.leaf.tags["clerkUserProfile"]          = ClerkUserProfileTag()
        app.leaf.tags["clerkOrganizationProfile"]  = ClerkOrganizationProfileTag()
        app.leaf.tags["clerkOrganizationSwitcher"] = ClerkOrganizationSwitcherTag()
    }
}

// MARK: - Application extension

extension Application {

    /// Register Clerk Leaf tags and enable the Leaf view renderer.
    /// Call this after `app.useClerk(_:)` in `configure.swift`.
    public func useClerkLeaf() {
        ClerkLeaf.register(on: self)
        views.use(.leaf)
    }
}

// MARK: - ClerkViewContext

/// An `Encodable` context bag for rendering Clerk Leaf templates.
/// Keys and values are passed straight through to Leaf.
public struct ClerkViewContext: Encodable {
    private let storage: [String: AnyEncodable]

    public init(_ dict: [String: any Encodable]) {
        self.storage = dict.mapValues(AnyEncodable.init)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        for (key, value) in storage {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }
}

// Helpers for ClerkViewContext
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: any Encodable) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

// MARK: - ClerkLeafContext

/// Builds the Clerk-specific context from the current request.
public enum ClerkLeafContext {

    /// Returns base Clerk context values:
    /// `clerkPublishableKey`, `clerkFrontendAPIURL`, `clerkJSVersion`,
    /// `clerkIsSignedIn`, and (when signed in) `clerkUserId`, `clerkOrgId`, `clerkOrgRole`.
    public static func base(for req: Request) -> [String: any Encodable] {
        guard let config = req.application.clerkConfig else { return [:] }
        var ctx: [String: any Encodable] = [
            "clerkPublishableKey": config.publishableKey ?? "",
            "clerkFrontendAPIURL": config.frontendAPIURL?.absoluteString ?? "",
            "clerkJSVersion":      "latest",
        ]
        let auth = req.clerkAuth
        ctx["clerkIsSignedIn"] = auth.isAuthenticated
        if auth.isAuthenticated {
            ctx["clerkUserId"]  = auth.userId  ?? ""
            ctx["clerkOrgId"]   = auth.orgId   ?? ""
            ctx["clerkOrgRole"] = auth.orgRole ?? ""
        }
        return ctx
    }
}

// MARK: - Request helper

extension Request {

    /// Render a Leaf template with Clerk context variables automatically injected.
    ///
    /// ```swift
    /// return try await req.clerkView("dashboard", context: [
    ///     "title": "My Dashboard",
    ///     "items": itemsArray,
    /// ])
    /// ```
    public func clerkView<C: Encodable>(
        _ template: String,
        context: [String: C]
    ) async throws -> View {
        var merged = ClerkLeafContext.base(for: self)
        for (k, v) in context { merged[k] = v }
        return try await view.render(template, ClerkViewContext(merged))
    }

    /// Render a Leaf template with only Clerk context (no additional context).
    public func clerkView(_ template: String) async throws -> View {
        try await clerkView(template, context: [String: String]())
    }
}

// MARK: - Bundle access

extension Bundle {
    /// The resource bundle for ClerkLeaf — use this to locate bundled Leaf templates.
    public static var clerkLeaf: Bundle { .module }
}
