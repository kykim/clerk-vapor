import Leaf
import LeafKit
import Foundation

// MARK: - #clerkScript

/// Emits the ClerkJS `<script>` loader tag.
/// Resolves the publishable key and Frontend API URL from the Leaf context
/// variables injected by `ClerkLeafContext.base(for:)`.
///
/// Leaf usage:
/// ```
/// #clerkScript()
/// ```
public struct ClerkScriptTag: UnsafeUnescapedLeafTag {

    public init() {}

    public func render(_ ctx: LeafContext) throws -> LeafData {
        let pubKey: String
        if let arg = ctx.parameters.first?.string, !arg.isEmpty {
            pubKey = arg
        } else if let key = ctx.data["clerkPublishableKey"]?.string, !key.isEmpty {
            pubKey = key
        } else {
            throw LeafError(.unknownError(
                "#clerkScript: publishable key not found. " +
                "Ensure Clerk is configured and you are using req.clerkView(_:context:)."
            ))
        }

        let frontendAPI: String
        if let api = ctx.data["clerkFrontendAPIURL"]?.string, !api.isEmpty {
            frontendAPI = api
        } else if let derived = deriveFrontendAPI(from: pubKey) {
            frontendAPI = derived
        } else {
            frontendAPI = "https://clerk.accounts.dev"
        }

        let version = ctx.data["clerkJSVersion"]?.string ?? "latest"

        let html = """
        <script
          async
          crossorigin="anonymous"
          data-clerk-publishable-key="\(pubKey)"
          src="\(frontendAPI)/npm/@clerk/clerk-js@\(version)/dist/clerk.browser.js"
          type="text/javascript"
        ></script>
        """
        return .string(html)
    }

    private func deriveFrontendAPI(from publishableKey: String) -> String? {
        let parts = publishableKey.split(separator: "_")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[2])
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64),
              var host = String(data: data, encoding: .utf8) else { return nil }
        if host.hasSuffix("$") { host = String(host.dropLast()) }
        return "https://\(host)"
    }
}
