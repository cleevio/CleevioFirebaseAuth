import CleevioFirebaseAuth
import FBSDKLoginKit
import FirebaseAuth
import Foundation

/// `FacebookAuthenticationProvider` is a class that implements `AuthenticationProvider` and
/// `NeedsPresentingViewController` to provide authentication via Facebook. It handles the
/// process of obtaining a Facebook access token and uses it to authenticate with Firebase.
public final class FacebookAuthenticationProvider: AuthenticationProvider, NeedsPresentingViewController {
    /// `Credential` struct stores the access token obtained from Facebook.
    public struct Credential {
        enum Token {
            case access(String)
            case id(String)
        }
        let token: Token
        let nonce: String
    }

    /// `AuthenticatorError` enum defines the various errors that can occur during the
    /// Facebook authentication process.
    public enum AuthenticatorError: Error {
        /// Error when the user cancels the authentication process.
        case authenticationCancelled
        /// Error when the user declines one or more requested permissions.
        case permissionDeclined(Set<Permission>)
        /// Error when the access token is missing after attempting to authenticate.
        case missingAccessToken
    }

    public let permissions: Set<FBSDKLoginKit.Permission>
    public let tracking: FBSDKLoginKit.LoginTracking

    /// A weak reference to the view controller that presents the Facebook login UI.
    public weak var presentingViewController: PlatformViewController?

    /// Initializes a new instance of `FacebookAuthenticationProvider`.
    @inlinable
    public init(
        permissions: Set<FBSDKLoginKit.Permission>,
        tracking: FBSDKLoginKit.LoginTracking = .limited
    ) {
        self.permissions = permissions
        self.tracking = tracking
    }

    /// Asynchronously retrieves a `Credential` containing a Facebook access token.
    ///
    /// This method handles the Facebook login process, requests the necessary permissions,
    /// and returns the access token upon successful login. If the login fails or is cancelled,
    /// it throws an appropriate error.
    ///
    /// - Returns: A `Credential` containing the Facebook access token.
    /// - Throws: An `AuthenticatorError` if authentication fails.
    @MainActor
    public func credential() async throws -> Credential {
        try await withCheckedThrowingContinuation {
            [presentingViewController, permissions, tracking] continuation in
            let nonce = randomNonceString()
            FBSDKLoginKit.LoginManager().logIn(
                viewController: presentingViewController,
                configuration: .init(
                    permissions: permissions,
                    tracking: tracking,
                    nonce: nonce
                )
            ) { result in
                switch result {
                case .cancelled:
                    // Resume with an error if the user cancels the login process.
                    continuation.resume(throwing: AuthenticatorError.authenticationCancelled)
                case let .failed(error):
                    // Resume with an error if there is one.
                    continuation.resume(throwing: error)
                case let .success(granted: _, declined, token: _) where !declined.isEmpty:
                    // Resume with an error if the user declines any requested permissions.
                    let declinedPermissions = Set(declined.map(\.name).compactMap(Permission.init))
                    continuation.resume(throwing: AuthenticatorError.permissionDeclined(declinedPermissions))
                case let .success(granted: _, declined: _, token: token):
                    if let accessToken = token?.tokenString {
                        continuation.resume(returning: Credential(token: .access(accessToken), nonce: nonce))
                    } else if let idToken = FBSDKLoginKit.AuthenticationToken.current?.tokenString {
                        continuation.resume(returning: Credential(token: .id(idToken), nonce: nonce))
                    } else {
                        continuation.resume(throwing: AuthenticatorError.missingAccessToken)
                    }
                }
            }
        }
    }

    /// Authenticates with Firebase using the Facebook access token obtained via the `credential()` method.
    ///
    /// This method attempts to sign in to Firebase using the Facebook access token. If the credential
    /// is already in use, it attempts to sign in with the updated credentials provided by Firebase.
    ///
    /// - Parameter auth: The Firebase authentication service used to perform the sign-in.
    /// - Returns: An `AuthDataResult` representing the result of the Firebase authentication.
    /// - Throws: An error if authentication fails.
    public func authenticate(_ auth: FirebaseAuthenticationServiceType) async throws -> AuthDataResult {
        let credential = try await credential()

        do {
            // Attempt to sign in with the obtained Facebook credentials, with linking enabled.
            return try await auth.signIn(with: credential.firebaseCredential, link: true)
        } catch let error as AuthErrorCode where [.credentialAlreadyInUse, .emailAlreadyInUse].contains(error.code) {
            // Handle the case where the Facebook credential is already in use.
            let updatedCredentials = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            return try await auth.signIn(
                with: updatedCredentials ?? credential.firebaseCredential,
                link: false
            )
        } catch {
            FBSDKLoginKit.LoginManager().logOut()
            throw error
        }
    }
}

/// Allows the Facebook access token to be converted to a Firebase `AuthCredential`.
extension FacebookAuthenticationProvider.Credential: FirebaseCredentialProvider {
    /// Converts the Facebook access token to a Firebase `AuthCredential`.
    public var firebaseCredential: AuthCredential {
        switch token {
        case let .id(token):
            OAuthProvider.credential(
                withProviderID: FacebookAuthProviderID,
                idToken: token,
                rawNonce: nonce
            )
        case let .access(token):
            FacebookAuthProvider.credential(withAccessToken: token)
        }
    }
}

extension FacebookAuthenticationProvider: FirebaseAuthenticationProvider { }
