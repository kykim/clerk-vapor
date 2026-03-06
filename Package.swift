// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClerkVapor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ClerkVapor",
            targets: ["ClerkVapor"]
        ),
        .library(
            name: "ClerkLeaf",
            targets: ["ClerkLeaf"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.13.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "ClerkVapor",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ]
        ),
        .target(
            name: "ClerkLeaf",
            dependencies: [
                .target(name: "ClerkVapor"),
                .product(name: "Leaf", package: "leaf"),
            ],
            resources: [
                .copy("Views")
            ]
        ),
        .testTarget(
            name: "ClerkVaporTests",
            dependencies: [
                .target(name: "ClerkVapor"),
                .product(name: "XCTVapor", package: "vapor"),
            ]
        ),
    ]
)
