import Vapor
@preconcurrency import JWTKit
import Foundation

// MARK: - ClerkJWTVerifier

/// Verifies Clerk RS256 session tokens using either JWKS (network) or a static PEM key (networkless).
/// Uses JWTKit 4's `JWTSigners` API.
actor ClerkJWTVerifier {

    // MARK: - JWKS Cache

    private struct CachedSigners {
        let signers: JWTSigners
        let fetchedAt: Date
    }

    private var cache: CachedSigners?
    private let cacheTTL: TimeInterval = 3600

    // MARK: - Verify

    func verify(
        token: String,
        config: ClerkConfiguration,
        client: Client
    ) async throws -> ClerkSessionPayload {

        // 1. Split & pre-decode payload for fast checks before crypto
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw ClerkError.invalidToken("Not a valid JWT format") }

        guard let payloadData = base64URLDecode(String(parts[1])) else {
            throw ClerkError.invalidToken("Could not base64url-decode payload")
        }

        let rawClaims: RawClaims
        do {
            rawClaims = try JSONDecoder().decode(RawClaims.self, from: payloadData)
        } catch {
            throw ClerkError.invalidToken("Could not decode JWT payload: \(error)")
        }

        // 2. Time validation (with clock skew tolerance)
        let now = Date().timeIntervalSince1970
        let skew = TimeInterval(config.clockSkewSeconds)
        if Double(rawClaims.exp) < now - skew { throw ClerkError.tokenExpired }
        if let nbf = rawClaims.nbf, Double(nbf) > now + skew { throw ClerkError.tokenNotYetValid }

        // 3. Authorised party check
        if !config.authorizedParties.isEmpty {
            guard let azp = rawClaims.azp, config.authorizedParties.contains(azp) else {
                throw ClerkError.invalidToken(
                    "Unauthorized party '\(rawClaims.azp ?? "<nil>")'. " +
                    "Add it to authorizedParties in your ClerkConfiguration."
                )
            }
        }

        // 4. Signature verification
        let signers = try await resolveSigners(config: config, client: client)

        do {
            return try signers.verify(token, as: ClerkSessionPayload.self)
        } catch let err as JWTError {
            throw ClerkError.invalidToken(err.reason)
        }
    }

    // MARK: - Signer Resolution

    private func resolveSigners(
        config: ClerkConfiguration,
        client: Client
    ) async throws -> JWTSigners {

        // Networkless mode: use the supplied PEM public key directly
        if let pem = config.jwtKey {
            let signers = JWTSigners()
            try signers.use(.rs256(key: .public(pem: pem)))
            return signers
        }

        // Cache hit
        if let cached = cache, Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.signers
        }

        // Derive JWKS URL from publishable key, or fall back to the BAPI endpoint
        let jwksURL: String
        if let derivedURL = config.jwksURL {
            jwksURL = derivedURL.absoluteString
        } else {
            jwksURL = "\(config.apiURL)/\(config.apiVersion)/jwks"
        }

        let response = try await client.get(URI(string: jwksURL)) { req in
            req.headers.add(name: .authorization, value: "Bearer \(config.secretKey)")
            req.headers.add(name: "Clerk-Backend-SDK", value: "vapor-clerk/1.0.0")
        }

        guard response.status == .ok else {
            throw ClerkError.networkError("JWKS fetch returned HTTP \(response.status.code)")
        }

        guard let body = response.body,
              let data = body.getData(at: 0, length: body.readableBytes) else {
            throw ClerkError.networkError("JWKS response body was empty")
        }

        let jwks: JWKS
        do {
            jwks = try JSONDecoder().decode(JWKS.self, from: data)
        } catch {
            throw ClerkError.decodingError("Failed to parse JWKS: \(error)")
        }

        let signers = JWTSigners()
        try signers.use(jwks: jwks)

        cache = CachedSigners(signers: signers, fetchedAt: Date())
        return signers
    }

    // MARK: - Helpers

    private func base64URLDecode(_ string: String) -> Data? {
        var b64 = string.replacingOccurrences(of: "-", with: "+")
                        .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        return Data(base64Encoded: b64)
    }
}

// MARK: - Minimal raw claims for pre-validation

private struct RawClaims: Decodable {
    let exp: Int
    let nbf: Int?
    let azp: String?
}
