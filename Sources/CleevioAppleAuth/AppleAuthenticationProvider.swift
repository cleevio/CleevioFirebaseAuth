import CleevioFirebaseAuth
import Foundation
import AuthenticationServices
import FirebaseAuth

public final class AppleAuthenticationProvider: AuthenticationProvider {
    public init() { }

    /// The authentication credential structure for Apple authentication.
    public struct Credential: Sendable, Hashable, Codable {
        /// The ID token obtained from Apple authentication.
        public var idToken: String
        /// The authorization code obtained from Apple authentication.
        public var authCode: String
        public var email: String?
        /// The full name associated with the authenticated Apple account.
        public var fullName: PersonNameComponents?
        /// A nonce value used to enhance security.
        public var nonce: String?
    }

    /// Possible errors during Apple authentication.
    public enum AuthenticatorError: Error, Sendable, Hashable, Codable {
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
        return try await appleCredential(request: request, nonce: nonce)
    }

    /// Wraps main actor isolated UI interactions.
    @MainActor
    private func appleCredential(request: ASAuthorizationAppleIDRequest, nonce: String) async throws -> Credential {
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

    public func authenticate(with auth: some FirebaseAuthenticationServiceType) async throws -> AuthenticationResult {
        let credential = try await credential()
        let firebaseAuthResult: AuthDataResult

        do {
            firebaseAuthResult = try await auth.signIn(with: credential.firebaseCredential, link: true)
        } catch let error as NSError where error.code == AuthErrorCode.missingOrInvalidNonce.rawValue {
            let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            firebaseAuthResult = try await auth.signIn(with: updatedCredential ?? credential.firebaseCredential, link: false)
        }

        return AuthenticationResult(
            firebaseAuthResult: firebaseAuthResult,
            userData: AuthenticationResult.UserData(fullName: credential.fullName, email: nil)
        )
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

            completion(.success(Credential(
                idToken: idToken,
                authCode: authCode,
                email: appleIDCredential.email,
                fullName: appleIDCredential.fullName
            )))
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
