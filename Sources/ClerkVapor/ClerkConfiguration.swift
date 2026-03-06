import Vapor
import Foundation

// MARK: - ClerkConfiguration

public struct ClerkConfiguration: Sendable {
    /// `sk_live_...` or `sk_test_...` from Clerk Dashboard → API Keys
    public let secretKey: String

    /// `pk_live_...` or `pk_test_...` from Clerk Dashboard → API Keys
    public let publishableKey: String?

    /// Optional PEM public key for networkless JWT verification.
    public let jwtKey: String?

    /// Clerk Backend API base URL. Defaults to https://api.clerk.com
    public let apiURL: String

    /// Clerk API version. Defaults to "v1".
    public let apiVersion: String

    /// Allowed origins for the JWT `azp` claim (e.g. ["https://yourapp.com"]).
    public let authorizedParties: [String]

    /// Clock skew tolerance in seconds for JWT `exp`/`nbf` checks. Defaults to 5.
    public let clockSkewSeconds: Int

    // MARK: - Derived URLs

    /// The Frontend API URL derived from the publishable key.
    public var frontendAPIURL: URL? {
        guard let pk = publishableKey else { return nil }
        let parts = pk.split(separator: "_")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[2])
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64),
              var host = String(data: data, encoding: .utf8) else { return nil }
        if host.hasSuffix("$") { host = String(host.dropLast()) }
        return URL(string: "https://\(host)")
    }

    /// The JWKS URL derived from the frontend API URL.
    public var jwksURL: URL? {
        frontendAPIURL?.appendingPathComponent(".well-known/jwks.json")
    }

    public init(
        secretKey: String,
        publishableKey: String? = nil,
        jwtKey: String? = nil,
        apiURL: String = "https://api.clerk.com",
        apiVersion: String = "v1",
        authorizedParties: [String] = [],
        clockSkewSeconds: Int = 5
    ) {
        self.secretKey = secretKey
        self.publishableKey = publishableKey
        self.jwtKey = jwtKey
        self.apiURL = apiURL
        self.apiVersion = apiVersion
        self.authorizedParties = authorizedParties
        self.clockSkewSeconds = clockSkewSeconds
    }
}

// MARK: - Application extensions

extension Application {
    private struct ClerkConfigKey: StorageKey {
        typealias Value = ClerkConfiguration
    }

    /// The active Clerk configuration, or nil if not yet configured.
    public var clerkConfig: ClerkConfiguration? {
        get { storage[ClerkConfigKey.self] }
        set { storage[ClerkConfigKey.self] = newValue }
    }

    /// Register Clerk configuration directly (synchronous convenience).
    /// Usage: `app.useClerk(ClerkConfiguration(secretKey: "sk_..."))`
    public func useClerk(_ config: ClerkConfiguration) {
        clerkConfig = config
    }

    /// The Clerk helper namespace on Application — exposes config properties and the API client.
    public var clerk: ClerkAppHelper { ClerkAppHelper(app: self) }

    public struct ClerkAppHelper: Sendable {
        public let app: Application

        // MARK: - Async configure (for use in configure.swift)

        public func configure(
            secretKey: String,
            publishableKey: String? = nil,
            jwtKey: String? = nil,
            apiURL: String = "https://api.clerk.com",
            apiVersion: String = "v1",
            authorizedParties: [String] = [],
            clockSkewSeconds: Int = 5
        ) async throws {
            app.clerkConfig = ClerkConfiguration(
                secretKey: secretKey,
                publishableKey: publishableKey,
                jwtKey: jwtKey,
                apiURL: apiURL,
                apiVersion: apiVersion,
                authorizedParties: authorizedParties,
                clockSkewSeconds: clockSkewSeconds
            )
        }

        // MARK: - Direct config property access (for tests and inspection)

        public var secretKey: String { config.secretKey }
        public var publishableKey: String? { config.publishableKey }
        public var apiURL: String { config.apiURL }
        public var apiVersion: String { config.apiVersion }
        public var authorizedParties: [String] { config.authorizedParties }
        public var clockSkewSeconds: Int { config.clockSkewSeconds }

        private var config: ClerkConfiguration {
            guard let c = app.clerkConfig else {
                fatalError("Clerk is not configured. Call app.useClerk(_:) or app.clerk.configure(...) first.")
            }
            return c
        }

        /// Access the Clerk Backend API client.
        public var client: ClerkClient {
            ClerkClient(config: config, httpClient: app.client)
        }
    }
}
