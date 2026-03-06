import Vapor
import Crypto
import Foundation

// MARK: - Webhook Event Types

public struct ClerkWebhookEvent: Content, Sendable {
    public let id: String?
    public let object: String
    public let type: ClerkWebhookEventType
    public let timestamp: Int?
    public let data: ClerkWebhookData
}

public enum ClerkWebhookEventType: String, Codable, Sendable {
    case userCreated             = "user.created"
    case userUpdated             = "user.updated"
    case userDeleted             = "user.deleted"
    case sessionCreated          = "session.created"
    case sessionEnded            = "session.ended"
    case sessionRevoked          = "session.revoked"
    case sessionRemoved          = "session.removed"
    case orgCreated              = "organization.created"
    case orgUpdated              = "organization.updated"
    case orgDeleted              = "organization.deleted"
    case orgMembershipCreated    = "organizationMembership.created"
    case orgMembershipUpdated    = "organizationMembership.updated"
    case orgMembershipDeleted    = "organizationMembership.deleted"
    case emailCreated            = "email.created"
    case smsCreated              = "sms.created"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ClerkWebhookEventType(rawValue: raw) ?? .unknown
    }
}

/// The `data` envelope of a webhook event. Use `.decode(as:)` to read into a concrete type.
public struct ClerkWebhookData: Content, Sendable {
    public let id: String?
    public let object: String?
    private let raw: [String: AnyCodable]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringKey.self)
        var dict = [String: AnyCodable]()
        for key in container.allKeys {
            dict[key.stringValue] = try container.decode(AnyCodable.self, forKey: key)
        }
        raw    = dict
        id     = dict["id"]?.value as? String
        object = dict["object"]?.value as? String
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringKey.self)
        for (k, v) in raw { try container.encode(v, forKey: StringKey(k)) }
    }

    /// Re-decode the data payload as a concrete `Decodable` type.
    public func decode<T: Decodable>(as type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(raw)
        return try JSONDecoder().decode(type, from: data)
    }
}

private struct StringKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ s: String) { self.stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

// MARK: - ClerkWebhookVerifier

/// Verifies the Svix signature on Clerk webhook requests.
/// Obtain your webhook signing secret from Clerk Dashboard → Webhooks → Endpoint → Signing Secret.
public struct ClerkWebhookVerifier: Sendable {
    private let secret: SymmetricKey

    /// - Parameter secret: The `whsec_...` signing secret.
    public init(secret: String) {
        let raw = secret.hasPrefix("whsec_") ? String(secret.dropFirst(6)) : secret
        // Pad base64 if needed
        var b64 = raw
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        let keyData = Data(base64Encoded: b64) ?? Data(raw.utf8)
        self.secret = SymmetricKey(data: keyData)
    }

    /// Verify Svix headers on the incoming request.
    /// - Parameter tolerance: Maximum allowed age of the webhook timestamp in seconds (default 300).
    /// - Throws: `Abort(.badRequest)` for missing/malformed headers, `Abort(.unauthorized)` for bad sig.
    public func verify(request: Request, tolerance: TimeInterval = 300) throws {
        guard
            let msgId  = request.headers.first(name: "svix-id"),
            let msgTs  = request.headers.first(name: "svix-timestamp"),
            let msgSig = request.headers.first(name: "svix-signature")
        else {
            throw Abort(.badRequest, reason: "Missing required Svix webhook headers (svix-id, svix-timestamp, svix-signature).")
        }

        guard let ts = TimeInterval(msgTs) else {
            throw Abort(.badRequest, reason: "svix-timestamp is not a valid Unix timestamp.")
        }

        let age = abs(Date().timeIntervalSince1970 - ts)
        guard age <= tolerance else {
            throw Abort(.unauthorized, reason: "Webhook timestamp is too old (\(Int(age))s). Possible replay attack.")
        }

        guard let body = request.body.data,
              let bodyStr = body.getString(at: 0, length: body.readableBytes) else {
            throw Abort(.badRequest, reason: "Webhook request body is empty.")
        }

        let signed = "\(msgId).\(msgTs).\(bodyStr)"
        guard let signedData = signed.data(using: .utf8) else {
            throw Abort(.badRequest, reason: "Could not UTF-8 encode webhook signing input.")
        }

        let expected = Data(HMAC<SHA256>.authenticationCode(for: signedData, using: secret))
            .base64EncodedString()

        // svix-signature may contain multiple space-separated `v1,<b64>` values
        let isValid = msgSig.components(separatedBy: " ").contains { sig in
            (sig.hasPrefix("v1,") ? String(sig.dropFirst(3)) : sig) == expected
        }

        guard isValid else {
            throw Abort(.unauthorized, reason: "Webhook signature verification failed.")
        }
    }
}

// MARK: - RoutesBuilder convenience

extension RoutesBuilder {
    /// Register a verified Clerk webhook handler.
    ///
    /// ```swift
    /// app.clerkWebhook(at: "webhooks", "clerk", secret: Environment.get("CLERK_WEBHOOK_SECRET")!) { event, req in
    ///     switch event.type {
    ///     case .userCreated:
    ///         let user = try event.data.decode(as: ClerkUser.self)
    ///         // persist to DB…
    ///     default: break
    ///     }
    ///     return .ok
    /// }
    /// ```
    @discardableResult
    public func clerkWebhook(
        at path: PathComponent...,
        secret: String,
        handler: @Sendable @escaping (ClerkWebhookEvent, Request) async throws -> HTTPStatus
    ) -> Route {
        post(path) { req async throws -> Response in
            let verifier = ClerkWebhookVerifier(secret: secret)
            try verifier.verify(request: req)
            let event = try req.content.decode(ClerkWebhookEvent.self)
            return Response(status: try await handler(event, req))
        }
    }
}
