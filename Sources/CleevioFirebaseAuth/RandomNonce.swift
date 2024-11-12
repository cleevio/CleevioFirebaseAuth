import Foundation
import CryptoKit

/// Generates a random nonce string.
public func randomNonceString() -> String {
    return Data(AES.GCM.Nonce()).base64EncodedString()
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
