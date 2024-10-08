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
        public var email: String?
        public var fullName: PersonNameComponents?
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

        var fullName = PersonNameComponents()
        fullName.familyName = user.profile?.familyName
        fullName.givenName = user.profile?.givenName
        fullName.nickname = user.profile?.name
        return Credential(
            idToken: idToken,
            accessToken: user.accessToken.tokenString,
            email: user.profile?.email,
            fullName: fullName
        )
    }

    /// Handles sign in URL to notify the GID instance of login success
    public static func handleSignInURL(_ url: URL) -> Bool {
        gidInstance.handle(url)
    }

    public func authenticate(with auth: FirebaseAuthenticationServiceType) async throws -> AuthenticationResult {
        let credential = try await credential()
        let firebaseAuthResult: AuthDataResult

        do {
            firebaseAuthResult = try await auth.signIn(with: credential.firebaseCredential, link: true)
        } catch let error as AuthErrorCode where error.code == .credentialAlreadyInUse {
            let updatedCredentials = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            firebaseAuthResult = try await auth.signIn(
                with: updatedCredentials ?? credential.firebaseCredential,
                link: false
            )
        }

        return AuthenticationResult(
            firebaseAuthResult: firebaseAuthResult,
            userData: nil
        )
    }
}

extension GoogleAuthenticationProvider.Credential: FirebaseCredentialProvider {
    /// The Firebase authentication credential for Google authentication.
    public var firebaseCredential: AuthCredential {
        GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
    }
}

extension GoogleAuthenticationProvider: FirebaseAuthenticationProvider { }
