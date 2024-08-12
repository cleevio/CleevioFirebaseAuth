# CleevioFirebaseAuth

CleevioFirebaseAuth is a Swift package that provides a set of libraries for integrating various authentication providers with Firebase. This package supports authentication via Apple, Google, and Facebook, making it easier to manage user authentication in your iOS and macOS applications.

## Features

- **Firebase Authentication**: Core functionality for integrating Firebase authentication.
- **Apple Sign-In**: Integrate Apple Sign-In with Firebase.
- **Google Sign-In**: Integrate Google Sign-In with Firebase.
- **Facebook Login**: Integrate Facebook Login with Firebase.
- **Modular Design**: Each authentication method is provided as a separate library, allowing you to only include the functionality you need.

## Setup Guides
To set up the various authentication providers, please refer to the following guides:

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.8+
- Xcode 14.0+

## Installation

To integrate `CleevioFirebaseAuth` into your Xcode project using Swift Package Manager, add it as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(
        url: "git@gitlab.cleevio.cz:cleevio-dev-ios/CleevioFirebaseAuth.git", 
        .upToNextMajor(from: "0.2.0")
    )
]
```

## Usage

After integrating the package, you can start using the libraries in your project. Here is an example of how to use the CleevioGoogleAuth for Google authentication:

```swift
import CleevioGoogleAuth

let authService = FirebaseAuthenticationService()
let googleAuthProvider = GoogleAuthenticationProvider()
googleAuthProvider.presentingViewController = yourViewController

do {
    let authResult = try await authService.signIn(with: googleAuthProvider)
    // Handle successful authentication
} catch {
    // Handle errors
}
```
