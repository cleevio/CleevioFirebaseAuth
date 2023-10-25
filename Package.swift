// swift-tools-version: 5.8
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
            name: "CleevioFirebaseAuthCleevioAuthentication",
            targets: ["CleevioFirebaseAuthCleevioAuthentication"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", .upToNextMajor(from: "7.0.0")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "10.3.0")),
        .package(url: "git@gitlab.cleevio.cz:cleevio-dev-ios/cleevioapi.git", .upToNextMinor(from: "0.4.1-dev1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CleevioFirebaseAuth",
            dependencies: [
               .product(name: "Algorithms", package: "swift-algorithms"),
               .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
               .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ],
            swiftSettings: swiftSettings),
        .target(
            name: "CleevioFirebaseAuthCleevioAuthentication",
            dependencies: [
                "CleevioFirebaseAuth",
               .product(name: "CleevioAPI", package: "cleevioapi"),
               .product(name: "CleevioAuthentication", package: "cleevioapi"),
            ],
            swiftSettings: swiftSettings),
        .testTarget(
            name: "CleevioFirebaseAuthTests",
            dependencies: [
                "CleevioFirebaseAuth"
            ],
            swiftSettings: swiftSettings)
    ]
)
