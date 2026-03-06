import XCTest
import XCTVapor
@preconcurrency import JWTKit
@testable import ClerkVapor

final class ClerkVaporTests: XCTestCase {

    // MARK: - ClerkConfiguration tests

    func testConfigurationParsesPublishableKey() {
        let raw = "clerk.example.clerk.accounts.dev$"
        let base64 = Data(raw.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let publishableKey = "pk_test_\(base64)"

        let config = ClerkConfiguration(
            secretKey: "sk_test_abc",
            publishableKey: publishableKey
        )

        XCTAssertNotNil(config.frontendAPIURL)
        XCTAssertNotNil(config.jwksURL)
    }

    func testConfigurationDefaultValues() {
        let config = ClerkConfiguration(
            secretKey: "sk_test_abc",
            publishableKey: "pk_test_abc"
        )
        XCTAssertEqual(config.apiURL, "https://api.clerk.com")
        XCTAssertEqual(config.apiVersion, "v1")
        XCTAssertEqual(config.clockSkewSeconds, 5)
        XCTAssertTrue(config.authorizedParties.isEmpty)
        XCTAssertNil(config.jwtKey)
    }

    // MARK: - ClerkError tests

    func testClerkErrorHTTPStatuses() {
        XCTAssertEqual(ClerkError.missingToken.status, .unauthorized)
        XCTAssertEqual(ClerkError.unauthenticated.status, .unauthorized)
        XCTAssertEqual(ClerkError.tokenExpired.status, .unauthorized)
        XCTAssertEqual(ClerkError.configuration("test").status, .internalServerError)
        XCTAssertEqual(ClerkError.apiError(status: .notFound, message: "").status, .notFound)
    }

    func testClerkErrorMessages() {
        let err = ClerkError.invalidToken("bad sig")
        XCTAssertTrue(err.errorDescription?.contains("bad sig") ?? false)

        let cfg = ClerkError.configuration("missing key")
        XCTAssertTrue(cfg.errorDescription?.contains("missing key") ?? false)
    }

    // MARK: - ClerkAuth tests

    func testClerkAuthPermissionHelper() throws {
        let payload = makeFakePayload(
            userId: "user_test",
            sessionId: "sess_test",
            orgId: "org_test",
            orgRole: "org:admin",
            orgPermissions: ["org:invoice:read", "org:invoice:write"]
        )
        let auth = ClerkAuth(payload: payload, token: "test_token")

        XCTAssertEqual(auth.userId, "user_test")
        XCTAssertEqual(auth.sessionId, "sess_test")
        XCTAssertEqual(auth.orgId, "org_test")
        XCTAssertEqual(auth.orgRole, "org:admin")
        XCTAssertTrue(auth.has(permission: "org:invoice:read"))
        XCTAssertTrue(auth.has(permission: "org:invoice:write"))
        XCTAssertFalse(auth.has(permission: "org:billing:manage"))
        XCTAssertTrue(auth.has(role: "org:admin"))
        XCTAssertFalse(auth.has(role: "org:member"))
        XCTAssertFalse(auth.isImpersonating)
    }

    func testClerkAuthWithoutOrg() {
        let payload = makeFakePayload(userId: "user_1", sessionId: "sess_1")
        let auth = ClerkAuth(payload: payload, token: "tok")
        XCTAssertNil(auth.orgId)
        XCTAssertNil(auth.orgRole)
        XCTAssertFalse(auth.has(permission: "anything"))
        XCTAssertFalse(auth.has(role: "org:admin"))
    }

    // MARK: - Middleware integration tests

    func testMiddlewareRejectsMissingToken() async throws {
        let app = try await Application.make(.testing)

        app.useClerk(ClerkConfiguration(
            secretKey: "sk_test_fake",
            publishableKey: "pk_test_ZmFrZQ"
        ))

        app.grouped(ClerkMiddleware(), ClerkAuthMiddleware()).get("secure") { req async throws -> String in
            "ok"
        }

        try await app.test(.GET, "/secure") { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
        try await app.asyncShutdown()
    }

    func testOptionalMiddlewareAllowsMissingToken() async throws {
        let app = try await Application.make(.testing)

        app.useClerk(ClerkConfiguration(
            secretKey: "sk_test_fake",
            publishableKey: "pk_test_ZmFrZQ"
        ))

        app.grouped(ClerkMiddleware()).get("public") { req async throws -> String in
            req.clerkAuth.isAuthenticated ? "authed" : "anonymous"
        }

        try await app.test(.GET, "/public") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "anonymous")
        }
        try await app.asyncShutdown()
    }

    func testUnconfiguredMiddlewareReturns500() async throws {
        let app = try await Application.make(.testing)

        app.grouped(ClerkMiddleware()).get("secure") { req async throws -> String in "ok" }

        try await app.test(.GET, "/secure") { res async in
            XCTAssertEqual(res.status, .internalServerError)
        }
        try await app.asyncShutdown()
    }

    func testClerkProtectedRouteBuilder() async throws {
        let app = try await Application.make(.testing)

        app.useClerk(ClerkConfiguration(
            secretKey: "sk_test_fake",
            publishableKey: "pk_test_ZmFrZQ"
        ))

        app.clerkProtected().get("secret") { _ in "secret" }

        try await app.test(.GET, "/secret") { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
        try await app.asyncShutdown()
    }

    // MARK: - WebhookVerifier tests

    func testWebhookVerifierCanBeInstantiated() {
        let verifier = ClerkWebhookVerifier(secret: "whsec_dGVzdA==")
        XCTAssertNotNil(verifier)
    }

    func testAnyCodable() throws {
        let json = """
        {"string": "hello", "number": 42, "bool": true, "array": [1, 2], "null": null}
        """
        let data = json.data(using: .utf8)!
        let dict = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        XCTAssertEqual(dict["string"]?.value as? String, "hello")
        XCTAssertEqual(dict["number"]?.value as? Int, 42)
        XCTAssertEqual(dict["bool"]?.value as? Bool, true)
    }

    // MARK: - Helpers

    private func makeFakePayload(
        userId: String,
        sessionId: String,
        orgId: String? = nil,
        orgRole: String? = nil,
        orgPermissions: [String]? = nil
    ) -> ClerkSessionPayload {
        let org: ClerkOrgClaim? = orgId.map {
            ClerkOrgClaim(id: $0, rol: orgRole, slg: nil, per: orgPermissions)
        }
        return ClerkSessionPayload(
            sub: SubjectClaim(value: userId),
            iat: IssuedAtClaim(value: Date()),
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            nbf: nil,
            iss: IssuerClaim(value: "https://example.clerk.accounts.dev"),
            sid: sessionId,
            azp: nil,
            org: org,
            sts: "active",
            act: nil
        )
    }
}
