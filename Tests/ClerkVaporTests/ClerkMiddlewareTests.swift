import XCTest
import XCTVapor
@testable import ClerkVapor

final class ClerkMiddlewareTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testUnauthenticatedRequestReturnsEmptyAuth() async throws {
        app.useClerk(ClerkConfiguration(
            secretKey: "sk_test_dummy",
            authorizedParties: ["http://localhost:3000"]
        ))
        app.middleware.use(ClerkMiddleware())

        app.get("test") { req -> String in
            XCTAssertFalse(req.clerkAuth.isAuthenticated)
            XCTAssertNil(req.clerkAuth.userId)
            return "ok"
        }

        try await app.test(.GET, "test") { res async in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testRequireClerkAuthThrowsWhenUnauthenticated() async throws {
        app.useClerk(ClerkConfiguration(secretKey: "sk_test_dummy"))
        app.middleware.use(ClerkMiddleware())

        app.get("protected") { req -> String in
            _ = try req.requireClerkAuth()
            return "should not reach here"
        }

        try await app.test(.GET, "protected") { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testClerkAuthMiddlewareReturns401WhenUnauthenticated() async throws {
        app.useClerk(ClerkConfiguration(secretKey: "sk_test_dummy"))

        let protected = app.grouped(ClerkMiddleware(), ClerkAuthMiddleware())
        protected.get("secret") { _ in "secret data" }

        try await app.test(.GET, "secret") { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testMissingConfigurationFatalErrors() {
        let config = ClerkConfiguration(
            secretKey: "sk_live_test123",
            publishableKey: "pk_live_test456",
            apiURL: "https://api.clerk.com",
            apiVersion: "v1",
            authorizedParties: ["https://myapp.com"],
            clockSkewSeconds: 10
        )
        app.useClerk(config)

        XCTAssertEqual(app.clerk.secretKey, "sk_live_test123")
        XCTAssertEqual(app.clerk.publishableKey, "pk_live_test456")
        XCTAssertEqual(app.clerk.authorizedParties, ["https://myapp.com"])
        XCTAssertEqual(app.clerk.clockSkewSeconds, 10)
    }
}

// MARK: - JWT Parsing Tests

final class ClerkJWTClaimsTests: XCTestCase {

    func testClaimsDecoding() throws {
        let json = """
        {
            "iss": "https://clerk.myapp.com",
            "sub": "user_2abc123",
            "sid": "sess_xyz",
            "azp": "https://myapp.com",
            "iat": 1700000000,
            "exp": 1700003600,
            "nbf": 1700000000
        }
        """.data(using: .utf8)!

        let claims = try JSONDecoder().decode(ClerkJWTClaims.self, from: json)
        XCTAssertEqual(claims.sub, "user_2abc123")
        XCTAssertEqual(claims.sid, "sess_xyz")
        XCTAssertEqual(claims.azp, "https://myapp.com")
    }

    func testClaimsWithOrgClaim() throws {
        let json = """
        {
            "iss": "https://clerk.myapp.com",
            "sub": "user_2abc123",
            "iat": 1700000000,
            "exp": 1700003600,
            "o": {
                "id": "org_123",
                "rol": "org:admin",
                "slg": "my-org"
            }
        }
        """.data(using: .utf8)!

        let claims = try JSONDecoder().decode(ClerkJWTClaims.self, from: json)
        XCTAssertEqual(claims.o?.id, "org_123")
        XCTAssertEqual(claims.o?.rol, "org:admin")
        XCTAssertEqual(claims.o?.slg, "my-org")
    }
}

// MARK: - Webhook Tests

final class ClerkWebhookTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testWebhookRouteRegistration() async throws {
        app.useClerk(ClerkConfiguration(secretKey: "sk_test_dummy"))

        app.clerkWebhook(at: "webhooks", "clerk", secret: "secret") { event, req in
            return .ok
        }

        try await app.test(.POST, "webhooks/clerk", beforeRequest: { req in
            req.body = .init(string: "{}")
            req.headers.contentType = .json
        }, afterResponse: { res async in
            XCTAssertNotEqual(res.status, .notFound)
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testWebhookEventDecoding() throws {
        let json = """
        {
            "data": { "id": "user_abc", "object": "user" },
            "object": "event",
            "type": "user.created",
            "timestamp": 1700000000,
            "id": "evt_123"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(ClerkWebhookEvent.self, from: json)
        XCTAssertEqual(event.type, .userCreated)
        XCTAssertEqual(event.id, "evt_123")
        XCTAssertEqual(event.data.id, "user_abc")
    }

    func testUnknownWebhookEventType() throws {
        let json = """
        {
            "data": {},
            "object": "event",
            "type": "some.future.event"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(ClerkWebhookEvent.self, from: json)
        XCTAssertEqual(event.type, .unknown)
    }
}

// MARK: - Error Tests

final class ClerkSDKErrorTests: XCTestCase {
    func testErrorDescriptions() {
        XCTAssertNotNil(ClerkSDKError.missingToken.errorDescription)
        XCTAssertNotNil(ClerkSDKError.tokenExpired.errorDescription)
        XCTAssertNotNil(ClerkSDKError.invalidSignature.errorDescription)
        XCTAssertNotNil(ClerkSDKError.unauthorizedParty("http://bad.com").errorDescription)
    }

    func testAbortStatusCodes() {
        XCTAssertEqual(ClerkSDKError.missingToken.abort.status, .unauthorized)
        XCTAssertEqual(ClerkSDKError.tokenExpired.abort.status, .unauthorized)
        XCTAssertEqual(ClerkSDKError.notConfigured.abort.status, .internalServerError)
    }
}
