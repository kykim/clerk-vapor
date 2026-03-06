import Leaf
import LeafKit

// MARK: - #clerkSignIn

/// Renders a mount `<div>` and inline JS to mount Clerk's SignIn component.
///
/// ```
/// #clerkSignIn()
/// #clerkSignIn("my-div-id")
/// #clerkSignIn("sign-in", "/dashboard")
/// ```
public struct ClerkSignInTag: UnsafeUnescapedLeafTag {
    public init() {}
    public func render(_ ctx: LeafContext) throws -> LeafData {
        let divId       = ctx.parameters.first?.string ?? "clerk-sign-in"
        let redirectOpt = ctx.parameters.count > 1 ? ctx.parameters[1].string : nil
        let redirectJS  = redirectOpt.map { "afterSignInUrl: \"\($0)\"," } ?? ""
        return .string("""
        <div id="\(divId)"></div>
        <script>
        window.addEventListener('load', async function () {
          await window.Clerk.load();
          window.Clerk.mountSignIn(document.getElementById('\(divId)'), { \(redirectJS) });
        });
        </script>
        """)
    }
}

// MARK: - #clerkSignUp

/// Renders a mount `<div>` and inline JS to mount Clerk's SignUp component.
///
/// ```
/// #clerkSignUp()
/// #clerkSignUp("my-div-id")
/// #clerkSignUp("sign-up", "/welcome")
/// ```
public struct ClerkSignUpTag: UnsafeUnescapedLeafTag {
    public init() {}
    public func render(_ ctx: LeafContext) throws -> LeafData {
        let divId       = ctx.parameters.first?.string ?? "clerk-sign-up"
        let redirectOpt = ctx.parameters.count > 1 ? ctx.parameters[1].string : nil
        let redirectJS  = redirectOpt.map { "afterSignUpUrl: \"\($0)\"," } ?? ""
        return .string("""
        <div id="\(divId)"></div>
        <script>
        window.addEventListener('load', async function () {
          await window.Clerk.load();
          window.Clerk.mountSignUp(document.getElementById('\(divId)'), { \(redirectJS) });
        });
        </script>
        """)
    }
}

// MARK: - #clerkUserButton

/// Renders a mount `<div>` and inline JS to mount Clerk's UserButton component.
///
/// ```
/// #clerkUserButton()
/// #clerkUserButton("my-div-id")
/// #clerkUserButton("user-btn", "/")
/// ```
public struct ClerkUserButtonTag: UnsafeUnescapedLeafTag {
    public init() {}
    public func render(_ ctx: LeafContext) throws -> LeafData {
        let divId        = ctx.parameters.first?.string ?? "clerk-user-button"
        let afterSignOut = ctx.parameters.count > 1 ? ctx.parameters[1].string : nil
        let afterJS      = afterSignOut.map { "afterSignOutUrl: \"\($0)\"," } ?? ""
        return .string("""
        <div id="\(divId)"></div>
        <script>
        window.addEventListener('load', async function () {
          await window.Clerk.load();
          window.Clerk.mountUserButton(document.getElementById('\(divId)'), { \(afterJS) });
        });
        </script>
        """)
    }
}

// MARK: - #clerkUserProfile

/// Renders a mount `<div>` and inline JS to mount Clerk's UserProfile component.
///
/// ```
/// #clerkUserProfile()
/// #clerkUserProfile("my-div-id")
/// ```
public struct ClerkUserProfileTag: UnsafeUnescapedLeafTag {
    public init() {}
    public func render(_ ctx: LeafContext) throws -> LeafData {
        let divId = ctx.parameters.first?.string ?? "clerk-user-profile"
        return .string("""
        <div id="\(divId)"></div>
        <script>
        window.addEventListener('load', async function () {
          await window.Clerk.load();
          window.Clerk.mountUserProfile(document.getElementById('\(divId)'));
        });
        </script>
        """)
    }
}

// MARK: - #clerkOrganizationProfile

/// Renders a mount `<div>` and inline JS to mount Clerk's OrganizationProfile component.
public struct ClerkOrganizationProfileTag: UnsafeUnescapedLeafTag {
    public init() {}
    public func render(_ ctx: LeafContext) throws -> LeafData {
        let divId = ctx.parameters.first?.string ?? "clerk-org-profile"
        return .string("""
        <div id="\(divId)"></div>
        <script>
        window.addEventListener('load', async function () {
          await window.Clerk.load();
          window.Clerk.mountOrganizationProfile(document.getElementById('\(divId)'));
        });
        </script>
        """)
    }
}

// MARK: - #clerkOrganizationSwitcher

/// Renders a mount `<div>` and inline JS to mount Clerk's OrganizationSwitcher component.
public struct ClerkOrganizationSwitcherTag: UnsafeUnescapedLeafTag {
    public init() {}
    public func render(_ ctx: LeafContext) throws -> LeafData {
        let divId = ctx.parameters.first?.string ?? "clerk-org-switcher"
        return .string("""
        <div id="\(divId)"></div>
        <script>
        window.addEventListener('load', async function () {
          await window.Clerk.load();
          window.Clerk.mountOrganizationSwitcher(document.getElementById('\(divId)'));
        });
        </script>
        """)
    }
}
