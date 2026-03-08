import Vapor
import Leaf
import LeafKit
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

    /// Merge a typed `Encodable` struct with a base context dictionary.
    /// The struct is JSON round-tripped to extract its keys, then merged with `base`.
    /// `base` keys take precedence (Clerk metadata always wins).
    public init<C: Encodable>(_ context: C, merging base: [String: any Encodable]) throws {
        let data = try JSONEncoder().encode(context)
        let json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var storage: [String: AnyEncodable] = [:]
        for (k, v) in json {
            storage[k] = AnyEncodable(JSONValue(v))
        }
        for (k, v) in base {
            storage[k] = AnyEncodable(v)
        }
        self.storage = storage
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        for (key, value) in storage {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }
}

// Helpers for ClerkViewContext

/// Wraps a JSON-deserialized `Any` value (from `JSONSerialization`) as `Encodable`.
/// Handles the types JSONSerialization produces: String, Int, Double, Bool, [Any], [String:Any], NSNull.
private enum JSONValue: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(_ any: Any) {
        // Bool must be checked before Int/Double — on Apple platforms NSNumber
        // bridges to all three, and Int/Double would match a boolean NSNumber first.
        switch any {
        case let v as Bool:           self = .bool(v)
        case let v as String:         self = .string(v)
        case let v as Int:            self = .int(v)
        case let v as Double:         self = .double(v)
        case let v as [Any]:          self = .array(v.map(JSONValue.init))
        case let v as [String: Any]:  self = .object(v.mapValues(JSONValue.init))
        case is NSNull:               self = .null
        default:                      self = .string("\(any)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v):  try c.encode(v)
        case .int(let v):     try c.encode(v)
        case .double(let v):  try c.encode(v)
        case .bool(let v):    try c.encode(v)
        case .array(let v):   try c.encode(v)
        case .object(let v):  try c.encode(v)
        case .null:           try c.encodeNil()
        }
    }
}

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

    /// Render a Leaf template with an `Encodable` struct as context.
    /// The struct's properties are merged with the Clerk base context keys before rendering.
    ///
    /// ```swift
    /// struct PageContext: Encodable {
    ///     var exchanges: [Exchange]
    ///     var flash: String?
    ///     var flashType: String?
    /// }
    /// return try await req.clerkView("exchanges", context: PageContext(...))
    /// ```
    public func clerkView<C: Encodable>(
        _ template: String,
        context: C
    ) async throws -> View {
        let ctx = try ClerkViewContext(context, merging: ClerkLeafContext.base(for: self))
        return try await view.render(template, ctx)
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

// MARK: - Application Leaf source registration

extension Application {

    /// Adds the bundled ClerkLeaf templates as a Leaf source, merged with your
    /// app's own `Resources/Views` directory.
    ///
    /// Call this instead of (or after) manually configuring `app.leaf.sources`:
    /// ```swift
    /// app.useClerkLeaf()         // registers tags + enables Leaf
    /// app.addClerkLeafSources()  // adds bundled templates as a source
    /// ```
    public func addClerkLeafSources() {
        guard let clerkViewsURL = Bundle.clerkLeaf.resourceURL?
            .appendingPathComponent("Views") else {
            logger.warning("[ClerkLeaf] Could not locate bundled Views directory.")
            return
        }

        // App's own views directory
        let appViewsPath = directory.viewsDirectory

        let appSource = NIOLeafFiles(
            fileio: self.fileio,
            limits: .default,
            sandboxDirectory: appViewsPath,
            viewDirectory: appViewsPath
        )

        let clerkSource = NIOLeafFiles(
            fileio: self.fileio,
            limits: .default,
            sandboxDirectory: clerkViewsURL.path,
            viewDirectory: clerkViewsURL.path
        )

        let sources = LeafSources()
        try? sources.register(using: appSource)
        try? sources.register(source: "clerk", using: clerkSource)
        leaf.sources = sources
    }
}
