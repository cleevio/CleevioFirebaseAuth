import Foundation
import FirebaseAuth

/// A protocol for providing Firebase credentials.
public protocol FirebaseCredentialProvider {
    var firebaseCredential: AuthCredential { get }
}

public struct AuthenticationResult {
    public struct UserData {
        public let fullName: PersonNameComponents?
        public let email: String?

        public init(
            fullName: PersonNameComponents? = nil,
            email: String? = nil
        ) {
            self.fullName = fullName
            self.email = email
        }
    }

    public let isAnonymous: Bool
    public let isEmailVerified: Bool
    public let isNewUser: Bool
    public let userData: UserData?

    public init(
        isAnonymous: Bool = false,
        isEmailVerified: Bool = false,
        isNewUser: Bool = false,
        userData: UserData? = nil
    ) {
        self.isAnonymous = isAnonymous
        self.isEmailVerified = isEmailVerified
        self.isNewUser = isNewUser
        self.userData = userData
    }
}

extension AuthenticationResult {
    package init (firebaseAuthResult: AuthDataResult, userData: UserData?) {
        self.init(
            isAnonymous: firebaseAuthResult.user.isAnonymous,
            isEmailVerified: firebaseAuthResult.user.isEmailVerified,
            isNewUser: firebaseAuthResult.additionalUserInfo?.isNewUser != false,
            userData: userData
        )
    }
}

/// A protocol for authentication providers.
public protocol AuthenticationProvider {
    /// The associated type of credentials.
    associatedtype Credential

    /// Retrieve the authentication credential asynchronously.
    /// - Returns: An instance of `Credential`.
    func credential() async throws -> Credential

    func authenticate(with auth: FirebaseAuthenticationServiceType) async throws -> AuthenticationResult
}

/// A protocol for authentication providers providing Firebase credentials.
public protocol FirebaseAuthenticationProvider: AuthenticationProvider where Credential: FirebaseCredentialProvider { }

/// A protocol for types that need to have presentingViewController set.
public protocol NeedsPresentingViewController {
    var presentingViewController: PlatformViewController? { get nonmutating set}
}

/// A protocol defining the interface for Firebase authentication services.
public protocol FirebaseAuthenticationServiceType {
    /// Sign in anonymously.
    func signInAnonymously() async throws

    /// Method to sign up with email and password credentials. Throws an error if user already exists
    /// - Note: Use `signInOrSignUp(with:)` with provider if you want to sign in or sign up using other than credential providers or want to sign in if user already exists
    @discardableResult
    func signUp(withEmail email: String, password: String) async throws -> AuthDataResult

    /// Sign in using the specified authentication provider.
    /// Sets presentingViewController on AuthenticationProvider conforming to NeedsPresentingViewController if the provider's presentingViewController is nil
    /// If sign in fails and provider is PasswordAuthenticationProvider, user is created calling signUp(withEmail:password) depending on PasswordAuthenticationProvider.SignInOptions
    /// - Parameter provider: An authentication provider.
    @discardableResult
    func signIn<Provider: AuthenticationProvider>(with provider: Provider) async throws -> AuthenticationResult where Provider.Credential: FirebaseCredentialProvider

    func signIn(with credential: AuthCredential, link: Bool) async throws -> AuthDataResult

    /// Sign out the current user.
    func signOut() async throws

    /// Get the authentication token associated with the current user.
    /// - Returns: A string representing the user's authentication token.
    func token() async throws -> String?

    /// Verifies code for password reset generated by firebase and throws an error if the verification fails
    func verifyPasswordResetCode(for email: String, code: String) async throws

    /// Changes user password using code (such as code user received via request to reset password)
    func changePassword(withCode code: String, newPassword password: String) async throws

    /// Requests Firebase to send user e-mail with reset password
    func requestResetPassword(for email: String) async throws

    /// Applies action code to user and reloads user state.
    /// Used e.g. for email verification code
    func applyActionCodeAndReloadUser(_ code: String) async throws

#if os(iOS)
    /// Adds APNS token to a user
    func setAPNSToken(_ token: Data, type: AuthAPNSTokenType)
#endif

    /// The currently authenticated user, if available.
    var user: FirebaseAuth.User? { get }

    /// Used by signIn method that sets presentingViewController on AuthenticationProvider conforming to NeedsPresentingViewController if the provider's presentingViewController is nil
    var presentingViewController: @MainActor () -> (PlatformViewController?) { get nonmutating set }
}

/// A class providing Firebase authentication services.
open class FirebaseAuthenticationService: FirebaseAuthenticationServiceType {
    /// Initialize the authentication service with an optional tenant ID.
    /// - Parameter tenantID: An optional tenant ID to associate with the service.
    public init(auth: Auth = Auth.auth()) { 
        self.auth = auth
    }

    private let auth: Auth
    public var user: FirebaseAuth.User? { auth.currentUser }
    public var presentingViewController: @MainActor () -> (PlatformViewController?) = { nil }

    public func signInAnonymously() async throws {
        try await auth.signInAnonymously()
    }
    
    @discardableResult
    public func signIn<Provider: AuthenticationProvider>(with provider: Provider) async throws -> AuthenticationResult where Provider.Credential: FirebaseCredentialProvider {
        if let provider = provider as? NeedsPresentingViewController, provider.presentingViewController == nil {
            provider.presentingViewController = await presentingViewController()
        }

        return try await provider.authenticate(with: self)
    }
    
    /**
     A function for signing in a user with a Firebase credential.

     - Parameters:
        - firebaseCredential: The `AuthCredential` object representing the Firebase credential to authenticate with.
        - link: A boolean value indicating whether to link the provided credential with the current user's account. Default value is `true`.

     - Returns: An `AuthDataResult` object representing the result of the sign-in operation.

     - Throws: An error if the sign-in operation fails.

     If the `link` parameter is set to `true` and there's a current user logged in, the provided `firebaseCredential` will be linked to the current user's account. Otherwise, the credential will be used for signing in.
     */
    @discardableResult
    public func signIn(with firebaseCredential: AuthCredential, link: Bool = true) async throws -> AuthDataResult {
        if let user, link {
            return try await user.link(with: firebaseCredential)
        } else {
            return try await auth.signIn(with: firebaseCredential)
        }
    }

    @discardableResult
    public func signUp(withEmail email: String, password: String) async throws -> AuthDataResult {
        try await auth.createUser(withEmail: email, password: password)
    }
    
    public func signOut() async throws {
        try auth.signOut()
    }
    
    public func token() async throws -> String? {
        try await user?.getIDToken()
    }

    public func verifyPasswordResetCode(for email: String, code: String) async throws {
        try await auth.verifyPasswordResetCode(code)
    }

    public func changePassword(withCode code: String, newPassword password: String) async throws {
        try await auth.confirmPasswordReset(withCode: code, newPassword: password)
    }

    public func requestResetPassword(for email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    public func applyActionCodeAndReloadUser(_ code: String) async throws {
        try await auth.applyActionCode(code)
        try await auth.currentUser?.reload()
    }

    #if os(iOS)
    public func setAPNSToken(_ token: Data, type: AuthAPNSTokenType) {
        auth.setAPNSToken(token, type: type)
    }
    #endif
}
