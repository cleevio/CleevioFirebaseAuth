import CleevioFirebaseAuthCore
import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

public final class AppleAuthenticationProvider: AuthenticationProvider {
    public init() { }

    /// The authentication credential structure for Apple authentication.
    public struct Credential {
        /// The ID token obtained from Apple authentication.
        public var idToken: String
        /// The authorization code obtained from Apple authentication.
        public var authCode: String
        /// The full name associated with the authenticated Apple account.
        public var fullName: PersonNameComponents?
        /// A nonce value used to enhance security.
        public var nonce: String?

        @inlinable
        public init(idToken: String,
                    authCode: String,
                    fullName: PersonNameComponents?,
                    nonce: String? = nil) {
            self.idToken = idToken
            self.authCode = authCode
            self.fullName = fullName
            self.nonce = nonce
        }
    }

    /// Possible errors during Apple authentication.
    public enum AuthenticatorError: Error {
        case appleIDCredentialNotFound
        case identityTokenNotFound
        case authCodeNotFound
    }

    /// Retrieves the Apple authentication credential asynchronously.
    /// - Returns: A `Credential` instance containing ID token, authorization code, full name, and nonce.
    /// - Throws: An error of type `AuthenticatorError` if any step fails.
    public func credential() async throws -> Credential {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        let authorizationDelegate = AppleAuthorizationDelegate(controller: authorizationController)
        var continuationResumed = false

        return try await withCheckedThrowingContinuation { continuation in
            authorizationDelegate.completion = { result in
                guard !continuationResumed else { return }
                continuationResumed = true

                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case var .success(credential):
                    credential.nonce = nonce
                    continuation.resume(returning: credential)
                }
            }

            authorizationController.performRequests()
        }
    }

    public func authenticate(_ auth: FirebaseAuthenticationServiceType) async throws -> AuthDataResult {
        let credential = try await credential()

        do {
            return try await auth.signIn(with: credential.firebaseCredential, link: true)
        } catch
            let error as AuthErrorCode where 
                error.code == .credentialAlreadyInUse ||
                error.code == .missingOrInvalidNonce {
            let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            return try await auth.signIn(with: updatedCredential ?? credential.firebaseCredential, link: false)
        }
    }

    /// Generates a random nonce string.
    private func randomNonceString() -> String {
        return Data(AES.GCM.Nonce()).base64EncodedString()
    }

    /// Generates a SHA-256 hash of the input string.
    /// - Parameter input: The input string to be hashed.
    /// - Returns: The SHA-256 hash of the input string.
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
  
    /// A private delegate class for handling Apple authorization.
    private final class AppleAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate {
        var completion: (Result<Credential, Error>) -> Void = { _ in }

        init(controller: ASAuthorizationController) {
            super.init()
            controller.delegate = self
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return completion(.failure(AuthenticatorError.appleIDCredentialNotFound))  }
            guard
                let appleIDToken = appleIDCredential.identityToken,
                let idToken = String(data: appleIDToken, encoding: .utf8)
            else { return completion(.failure(AuthenticatorError.identityTokenNotFound)) }
            guard
                let appleAuthCode = appleIDCredential.authorizationCode,
                let authCode = String(data: appleAuthCode, encoding: .utf8)
            else { return completion(.failure(AuthenticatorError.authCodeNotFound)) }
            
            completion(.success(Credential(idToken: idToken, authCode: authCode, fullName: appleIDCredential.fullName)))
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            completion(.failure(error))
        }
    }
}

extension AppleAuthenticationProvider.Credential: FirebaseCredentialProvider {
    /// The Firebase authentication credential for Apple authentication.
    public var firebaseCredential: AuthCredential {
        OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: fullName)
    }
}

extension AppleAuthenticationProvider: FirebaseAuthenticationProvider { }
