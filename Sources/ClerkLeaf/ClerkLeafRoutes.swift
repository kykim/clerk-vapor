import Vapor
import ClerkVapor

// MARK: - ClerkLeafRoutes

/// Registers the standard Clerk auth view routes on your application.
///
/// ```swift
/// // In routes.swift or configure.swift:
/// app.registerClerkRoutes(
///     signInPath:  "/sign-in",
///     signUpPath:  "/sign-up",
///     profilePath: "/profile",
///     afterSignIn: "/dashboard",
///     afterSignUp: "/welcome"
/// )
/// ```
extension Application {

    public func registerClerkRoutes(
        signInPath:  String = "/sign-in",
        signUpPath:  String = "/sign-up",
        profilePath: String = "/profile",
        afterSignIn: String = "/",
        afterSignUp: String = "/"
    ) {
        let signInComponent  = PathComponent(stringLiteral: String(signInPath.dropFirst()))
        let signUpComponent  = PathComponent(stringLiteral: String(signUpPath.dropFirst()))
        let profileComponent = PathComponent(stringLiteral: String(profilePath.dropFirst()))

        self.get(signInComponent) { req async throws -> View in
            try await req.clerkView("clerk-sign-in", context: [
                "pageTitle":      "Sign In",
                "afterSignInUrl": afterSignIn,
            ])
        }

        self.get(signUpComponent) { req async throws -> View in
            try await req.clerkView("clerk-sign-up", context: [
                "pageTitle":      "Sign Up",
                "afterSignUpUrl": afterSignUp,
            ])
        }

        self.grouped(ClerkMiddleware(), ClerkAuthMiddleware())
            .get(profileComponent) { req async throws -> View in
                try await req.clerkView("clerk-user-profile", context: [
                    "pageTitle": "Your Profile",
                ])
            }
    }
}
