import Vapor

// MARK: - Backend User Object

/// Represents a Clerk Backend User as returned by GET /v1/users/{user_id}.
public struct ClerkUser: Content, Sendable {
    public let id: String
    public let object: String
    public let username: String?
    public let firstName: String?
    public let lastName: String?
    public let imageUrl: String?
    public let hasImage: Bool
    public let primaryEmailAddressId: String?
    public let primaryPhoneNumberId: String?
    public let emailAddresses: [ClerkEmailAddress]
    public let phoneNumbers: [ClerkPhoneNumber]
    public let externalAccounts: [ClerkExternalAccount]
    public let publicMetadata: [String: AnyCodable]
    public let privateMetadata: [String: AnyCodable]
    public let unsafeMetadata: [String: AnyCodable]
    public let banned: Bool
    public let locked: Bool
    public let createdAt: Int
    public let updatedAt: Int
    public let lastSignInAt: Int?
    public let lastActiveAt: Int?

    private enum CodingKeys: String, CodingKey {
        case id, object, username
        case firstName = "first_name"
        case lastName = "last_name"
        case imageUrl = "image_url"
        case hasImage = "has_image"
        case primaryEmailAddressId = "primary_email_address_id"
        case primaryPhoneNumberId = "primary_phone_number_id"
        case emailAddresses = "email_addresses"
        case phoneNumbers = "phone_numbers"
        case externalAccounts = "external_accounts"
        case publicMetadata = "public_metadata"
        case privateMetadata = "private_metadata"
        case unsafeMetadata = "unsafe_metadata"
        case banned, locked
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastSignInAt = "last_sign_in_at"
        case lastActiveAt = "last_active_at"
    }
}

// MARK: - Supporting User Types

public struct ClerkEmailAddress: Content, Sendable {
    public let id: String
    public let emailAddress: String
    public let verification: ClerkVerification?

    private enum CodingKeys: String, CodingKey {
        case id
        case emailAddress = "email_address"
        case verification
    }
}

public struct ClerkPhoneNumber: Content, Sendable {
    public let id: String
    public let phoneNumber: String
    public let verification: ClerkVerification?

    private enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber = "phone_number"
        case verification
    }
}

public struct ClerkExternalAccount: Content, Sendable {
    public let id: String
    public let provider: String
    public let identificationId: String?
    public let externalId: String?
    public let approvedScopes: String?
    public let emailAddress: String?
    public let username: String?

    private enum CodingKeys: String, CodingKey {
        case id, provider
        case identificationId = "identification_id"
        case externalId = "external_id"
        case approvedScopes = "approved_scopes"
        case emailAddress = "email_address"
        case username
    }
}

public struct ClerkVerification: Content, Sendable {
    public let status: String
    public let strategy: String?
}

// MARK: - Session Object

/// Represents a Clerk Backend Session as returned by GET /v1/sessions/{session_id}.
public struct ClerkSession: Content, Sendable {
    public let id: String
    public let object: String
    public let clientId: String
    public let userId: String
    public let status: String
    public let lastActiveAt: Int
    public let expireAt: Int
    public let abandonAt: Int
    public let createdAt: Int
    public let updatedAt: Int

    private enum CodingKeys: String, CodingKey {
        case id, object, status
        case clientId = "client_id"
        case userId = "user_id"
        case lastActiveAt = "last_active_at"
        case expireAt = "expire_at"
        case abandonAt = "abandon_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Organisation Object

public struct ClerkOrganization: Content, Sendable {
    public let id: String
    public let object: String
    public let name: String
    public let slug: String?
    public let imageUrl: String?
    public let membersCount: Int?
    public let maxAllowedMemberships: Int
    public let publicMetadata: [String: AnyCodable]
    public let createdAt: Int
    public let updatedAt: Int

    private enum CodingKeys: String, CodingKey {
        case id, object, name, slug
        case imageUrl = "image_url"
        case membersCount = "members_count"
        case maxAllowedMemberships = "max_allowed_memberships"
        case publicMetadata = "public_metadata"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Generic List Response

public struct ClerkListResponse<T: Content & Sendable>: Content, Sendable {
    public let data: [T]
    public let totalCount: Int

    private enum CodingKeys: String, CodingKey {
        case data
        case totalCount = "total_count"
    }
}
