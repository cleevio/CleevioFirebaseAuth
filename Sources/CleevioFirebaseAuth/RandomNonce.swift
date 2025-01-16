import Foundation
import CryptoKit

/// Generates a random nonce string.
public func randomNonceString() -> String {
    // charset suggested in Firebase example https://firebase.google.com/docs/auth/ios/apple?authuser=0&hl=en#sign_in_with_apple_and_authenticate_with_firebase
    let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
    let length = 16
    let nonce = String((0..<length).compactMap { _ in charset.randomElement() })
    return nonce
}

/// Generates a SHA-256 hash of the input string.
/// - Parameter input: The input string to be hashed.
/// - Returns: The SHA-256 hash of the input string.
public func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
    }.joined()

    return hashString
}
