import CleevioFirebaseAuth
import FirebaseCore
import FirebaseAuth
import Foundation
import GoogleSignIn

/// A class providing Google authentication services conforming to `AuthenticationProvider`.
public final class GoogleAuthenticationProvider: AuthenticationProvider, NeedsPresentingViewController {
    /// The authentication credential structure for Google authentication.
    public struct Credential {
        /// The ID token obtained from Google authentication.
        public var idToken: String
        /// The access token obtained from Google authentication.
        public var accessToken: String

        @inlinable
        public init(idToken: String, accessToken: String) {
            self.idToken = idToken
            self.accessToken = accessToken
        }
    }

    /// Possible errors during Google authentication.
    public enum AuthenticatorError: Error {
        case firebaseClientIDNotFound
        case presentingViewControllerNotProvided
        case idTokenNotFound
    }

    static let gidInstance = GIDSignIn.sharedInstance
    
    /// The view controller used for presenting Google authentication UI.
    public weak var presentingViewController: PlatformViewController?

    /// Initializes a `GoogleAuthenticationProvider` with a presenting view controller.
    /// - Parameter presentingController: The view controller for presenting Google authentication UI.
    @inlinable
    public init() { }
    
    /// Retrieves the Google authentication credential asynchronously.
    /// - Returns: A `Credential` instance containing ID token and access token.
    /// - Throws: An error of type `AuthenticatorError` if any step fails.
    @MainActor
    public func credential() async throws -> Credential {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw AuthenticatorError.firebaseClientIDNotFound }
        guard let presentingViewController else { throw AuthenticatorError.presentingViewControllerNotProvided }
        
        let configuration = GIDConfiguration(clientID: clientID)
        
        Self.gidInstance.configuration = configuration
        
        let signInResult = try await Self.gidInstance.signIn(withPresenting: presentingViewController)
        let user = signInResult.user
        
        guard let idToken = user.idToken?.tokenString else { throw AuthenticatorError.idTokenNotFound }
        
        return Credential(idToken: idToken, accessToken: user.accessToken.tokenString)
    }

    /// Handles sign in URL to notify the GID instance of login success
    public static func handleSignInURL(_ url: URL) -> Bool {
        gidInstance.handle(url)
    }

    public func authenticate(_ auth: FirebaseAuthenticationServiceType) async throws -> AuthDataResult {
        let credential = try await credential()

        do {
            return try await auth.signIn(with: credential.firebaseCredential, link: true)
        } catch let error as AuthErrorCode where error.code == .credentialAlreadyInUse {
            let updatedCredentials = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            return try await auth.signIn(
                with: updatedCredentials ?? credential.firebaseCredential,
                link: false
            )
        }
    }
}

extension GoogleAuthenticationProvider.Credential: FirebaseCredentialProvider {
    /// The Firebase authentication credential for Google authentication.
    public var firebaseCredential: AuthCredential {
        GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
    }
}

extension GoogleAuthenticationProvider: FirebaseAuthenticationProvider { }
