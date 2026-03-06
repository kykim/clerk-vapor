import Vapor
import Foundation

// MARK: - ClerkClient

/// The Clerk Backend API client. Access via `req.clerk.client` or `app.clerk.client`.
public struct ClerkClient: Sendable {
    let config: ClerkConfiguration
    let httpClient: Client

    public init(config: ClerkConfiguration, httpClient: Client) {
        self.config = config
        self.httpClient = httpClient
    }

    var base: String { "\(config.apiURL)/\(config.apiVersion)" }

    public var users: UsersAPI         { UsersAPI(client: self) }
    public var sessions: SessionsAPI   { SessionsAPI(client: self) }
    public var organizations: OrgsAPI  { OrgsAPI(client: self) }
}

// MARK: - Request extension

extension Request {
    public var clerkClient: ClerkClient {
        guard let config = application.clerkConfig else {
            fatalError("Clerk is not configured. Call app.clerk.configure(...) first.")
        }
        return ClerkClient(config: config, httpClient: self.client)
    }
}

// MARK: - Internal HTTP helpers

extension ClerkClient {
    func headers() -> HTTPHeaders {
        var h = HTTPHeaders()
        h.add(name: .authorization,  value: "Bearer \(config.secretKey)")
        h.add(name: .contentType,    value: "application/json")
        h.add(name: "Clerk-Backend-SDK", value: "vapor-clerk/1.0.0")
        return h
    }

    func decode<T: Decodable>(_ type: T.Type, from response: ClientResponse) throws -> T {
        guard let body = response.body,
              let data = body.getData(at: 0, length: body.readableBytes) else {
            throw ClerkError.decodingError("Empty response body")
        }
        if response.status.code >= 400 {
            if let e = try? JSONDecoder().decode(ClerkAPIErrorResponse.self, from: data) {
                let first = e.errors.first
                throw ClerkError.apiError(
                    status: HTTPStatus(statusCode: Int(response.status.code)),
                    message: first?.message ?? "Unknown error"
                )
            }
            throw ClerkError.apiError(
                status: HTTPStatus(statusCode: Int(response.status.code)),
                message: "HTTP \(response.status.code)"
            )
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ClerkError.decodingError(error.localizedDescription)
        }
    }

    func buildURL(_ base: String, params: [URLQueryItem]) -> String {
        guard !params.isEmpty,
              var comps = URLComponents(string: base) else { return base }
        comps.queryItems = params
        return comps.url?.absoluteString ?? base
    }
}

// MARK: - Users API

public struct UsersAPI: Sendable {
    let client: ClerkClient

    public func getUser(userId: String) async throws -> ClerkUser {
        let res = try await client.httpClient.get(URI(string: "\(client.base)/users/\(userId)")) {
            $0.headers = client.headers()
        }
        return try client.decode(ClerkUser.self, from: res)
    }

    public func listUsers(
        limit: Int = 10,
        offset: Int = 0,
        emailAddress: [String]? = nil,
        username: [String]? = nil,
        query: String? = nil,
        orderBy: String? = nil
    ) async throws -> ClerkListResponse<ClerkUser> {
        var params: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ]
        emailAddress?.forEach { params.append(.init(name: "email_address", value: $0)) }
        username?.forEach     { params.append(.init(name: "username",      value: $0)) }
        if let q = query   { params.append(.init(name: "query",    value: q)) }
        if let o = orderBy { params.append(.init(name: "order_by", value: o)) }

        let url = client.buildURL("\(client.base)/users", params: params)
        let res = try await client.httpClient.get(URI(string: url)) { $0.headers = client.headers() }
        return try client.decode(ClerkListResponse<ClerkUser>.self, from: res)
    }

    public func updateUser(userId: String, body: UpdateUserRequest) async throws -> ClerkUser {
        let res = try await client.httpClient.patch(URI(string: "\(client.base)/users/\(userId)")) {
            $0.headers = client.headers()
            try $0.content.encode(body, as: .json)
        }
        return try client.decode(ClerkUser.self, from: res)
    }

    public func deleteUser(userId: String) async throws -> DeletedObject {
        let res = try await client.httpClient.delete(URI(string: "\(client.base)/users/\(userId)")) {
            $0.headers = client.headers()
        }
        return try client.decode(DeletedObject.self, from: res)
    }

    public func banUser(userId: String) async throws -> ClerkUser {
        let res = try await client.httpClient.post(URI(string: "\(client.base)/users/\(userId)/ban")) {
            $0.headers = client.headers()
        }
        return try client.decode(ClerkUser.self, from: res)
    }

    public func unbanUser(userId: String) async throws -> ClerkUser {
        let res = try await client.httpClient.post(URI(string: "\(client.base)/users/\(userId)/unban")) {
            $0.headers = client.headers()
        }
        return try client.decode(ClerkUser.self, from: res)
    }

    public func count() async throws -> Int {
        let res = try await client.httpClient.get(URI(string: "\(client.base)/users/count")) {
            $0.headers = client.headers()
        }
        struct R: Decodable { let totalCount: Int; enum CodingKeys: String, CodingKey { case totalCount = "total_count" } }
        return try client.decode(R.self, from: res).totalCount
    }
}

// MARK: - Sessions API

public struct SessionsAPI: Sendable {
    let client: ClerkClient

    public func getSession(sessionId: String) async throws -> ClerkSession {
        let res = try await client.httpClient.get(URI(string: "\(client.base)/sessions/\(sessionId)")) {
            $0.headers = client.headers()
        }
        return try client.decode(ClerkSession.self, from: res)
    }

    public func revokeSession(sessionId: String) async throws -> ClerkSession {
        let res = try await client.httpClient.post(URI(string: "\(client.base)/sessions/\(sessionId)/revoke")) {
            $0.headers = client.headers()
        }
        return try client.decode(ClerkSession.self, from: res)
    }

    public func listSessions(
        userId: String? = nil,
        status: String? = nil,
        limit: Int = 10,
        offset: Int = 0
    ) async throws -> ClerkListResponse<ClerkSession> {
        var params: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ]
        if let u = userId { params.append(.init(name: "user_id", value: u)) }
        if let s = status { params.append(.init(name: "status",  value: s)) }
        let url = client.buildURL("\(client.base)/sessions", params: params)
        let res = try await client.httpClient.get(URI(string: url)) { $0.headers = client.headers() }
        return try client.decode(ClerkListResponse<ClerkSession>.self, from: res)
    }
}

// MARK: - Organizations API

public struct OrgsAPI: Sendable {
    let client: ClerkClient

    public func getOrganization(orgId: String) async throws -> ClerkOrganization {
        let res = try await client.httpClient.get(URI(string: "\(client.base)/organizations/\(orgId)")) {
            $0.headers = client.headers()
        }
        return try client.decode(ClerkOrganization.self, from: res)
    }

    public func listOrganizations(
        limit: Int = 10,
        offset: Int = 0,
        query: String? = nil
    ) async throws -> ClerkListResponse<ClerkOrganization> {
        var params: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ]
        if let q = query { params.append(.init(name: "query", value: q)) }
        let url = client.buildURL("\(client.base)/organizations", params: params)
        let res = try await client.httpClient.get(URI(string: url)) { $0.headers = client.headers() }
        return try client.decode(ClerkListResponse<ClerkOrganization>.self, from: res)
    }

    public func deleteOrganization(orgId: String) async throws -> DeletedObject {
        let res = try await client.httpClient.delete(URI(string: "\(client.base)/organizations/\(orgId)")) {
            $0.headers = client.headers()
        }
        return try client.decode(DeletedObject.self, from: res)
    }
}

// MARK: - Request / Response types

public struct UpdateUserRequest: Content, Sendable {
    public var firstName: String?
    public var lastName: String?
    public var username: String?
    public var primaryEmailAddressId: String?
    public var primaryPhoneNumberId: String?
    public var publicMetadata: [String: AnyCodable]?
    public var privateMetadata: [String: AnyCodable]?
    public var unsafeMetadata: [String: AnyCodable]?

    private enum CodingKeys: String, CodingKey {
        case firstName = "first_name", lastName = "last_name", username
        case primaryEmailAddressId = "primary_email_address_id"
        case primaryPhoneNumberId  = "primary_phone_number_id"
        case publicMetadata  = "public_metadata"
        case privateMetadata = "private_metadata"
        case unsafeMetadata  = "unsafe_metadata"
    }

    public init(
        firstName: String? = nil, lastName: String? = nil, username: String? = nil,
        primaryEmailAddressId: String? = nil, primaryPhoneNumberId: String? = nil,
        publicMetadata: [String: AnyCodable]? = nil,
        privateMetadata: [String: AnyCodable]? = nil,
        unsafeMetadata: [String: AnyCodable]? = nil
    ) {
        self.firstName = firstName; self.lastName = lastName; self.username = username
        self.primaryEmailAddressId = primaryEmailAddressId
        self.primaryPhoneNumberId  = primaryPhoneNumberId
        self.publicMetadata  = publicMetadata
        self.privateMetadata = privateMetadata
        self.unsafeMetadata  = unsafeMetadata
    }
}

public struct DeletedObject: Content, Sendable {
    public let id: String?
    public let object: String?
    public let deleted: Bool
}

struct ClerkAPIErrorResponse: Decodable {
    struct E: Decodable { let message: String; let code: String? }
    let errors: [E]
}
