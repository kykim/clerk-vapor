import Vapor
@preconcurrency import JWTKit

// MARK: - ClerkOrgClaim

/// The `o` claim embedded in Clerk v2 session tokens.
public struct ClerkOrgClaim: Codable, Sendable {
    public let id: String
    public let rol: String?
    public let slg: String?
    public let per: [String]?
    public let fpm: String?

    public init(id: String, rol: String?, slg: String?, per: [String]?, fpm: String? = nil) {
        self.id = id; self.rol = rol; self.slg = slg; self.per = per; self.fpm = fpm
    }
}

// MARK: - ActorClaim (impersonation)

public struct ActorClaim: Codable, Sendable {
    public let sub: String
}

// MARK: - ClerkSessionPayload (JWTKit 4 JWTPayload)

/// The verified JWT payload for a Clerk session token.
public struct ClerkSessionPayload: JWTPayload, Sendable {
    public let sub: SubjectClaim
    public let iat: IssuedAtClaim
    public let exp: ExpirationClaim
    public let nbf: NotBeforeClaim?
    public let iss: IssuerClaim
    public let sid: String?
    public let azp: String?
    public let org: ClerkOrgClaim?
    public let sts: String?
    public let act: ActorClaim?

    private enum CodingKeys: String, CodingKey {
        case sub, iat, exp, nbf, iss, sid, azp, sts, act
        case org = "o"
    }

    public func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
        try nbf?.verifyNotBefore()
    }
}

// MARK: - ClerkJWTClaims (simple Codable — for tests and manual decoding)

/// A plain `Codable` representation of Clerk JWT claims.
/// Unlike `ClerkSessionPayload`, this does not require JWTKit and can be decoded with `JSONDecoder`.
public struct ClerkJWTClaims: Codable, Sendable {
    public let iss: String
    public let sub: String
    public let sid: String?
    public let azp: String?
    public let iat: Int
    public let exp: Int
    public let nbf: Int?
    public let jti: String?
    public let o: ClerkOrgClaim?

    private enum CodingKeys: String, CodingKey {
        case iss, sub, sid, azp, iat, exp, nbf, jti, o
    }
}
