// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    // Only for development checks
    //    SwiftSetting.unsafeFlags([
    //        "-Xfrontend", "-strict-concurrency=complete",
    //        "-Xfrontend", "-warn-concurrency",
    //        "-Xfrontend", "-enable-actor-data-race-checks",
    //    ])
]

let package = Package(
    name: "CleevioFirebaseAuth",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CleevioFirebaseAuth",
            targets: ["CleevioFirebaseAuth"]),
        .library(
            name: "CleevioAppleAuth",
            targets: ["CleevioAppleAuth"]
        ),
        .library(
            name: "CleevioGoogleAuth",
            targets: ["CleevioGoogleAuth"]
        ),
        .library(
            name: "CleevioFacebookAuth",
            targets: ["CleevioFacebookAuth"]
        ),
        .library(
            name: "RouterBytesFirebaseAuth",
            targets: ["RouterBytesFirebaseAuth"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", .upToNextMajor(from: "7.1.0")),
        .package(url: "https://github.com/facebook/facebook-ios-sdk", .upToNextMajor(from: "17.0.0")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "11.0.0")),
        .package(url: "https://github.com/cleevio/RouterBytes", .upToNextMajor(from: "0.8.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CleevioFirebaseAuth",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            packageAccess: true,
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CleevioGoogleAuth",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .target(name: "CleevioFirebaseAuth")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CleevioAppleAuth",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .target(name: "CleevioFirebaseAuth")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CleevioFacebookAuth",
            dependencies: [
                .product(name: "FacebookLogin", package: "facebook-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .target(name: "CleevioFirebaseAuth")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "RouterBytesFirebaseAuth",
            dependencies: [
                "CleevioFirebaseAuth",
                .product(name: "RouterBytes", package: "RouterBytes"),
                .product(name: "RouterBytesAuthentication", package: "RouterBytes"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CleevioFirebaseAuthTests",
            dependencies: [
                "CleevioFirebaseAuth"
            ],
            swiftSettings: swiftSettings
        )
    ]
)
