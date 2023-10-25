//
//  FirebaseAuthenticationService.swift
//  
//
//  Created by Lukáš Valenta on 19.08.2023.
//

import Foundation
import FirebaseAuth
import CleevioAuthentication

/// A protocol for providing Firebase credentials.
public protocol FirebaseCredentialProvider {
    var firebaseCredential: AuthCredential { get }
}

/// A protocol for authentication providers.
public protocol AuthenticationProvider {
    /// The associated type of credentials conforming to `FirebaseCredentialProvider`.
    associatedtype Credential: FirebaseCredentialProvider
    
    /// Retrieve the authentication credential asynchronously.
    /// - Returns: An instance of `Credential`.
    func credential() async throws -> Credential
}

/// A protocol defining the interface for Firebase authentication services.
public protocol FirebaseAuthenticationServiceType {
    /// Sign in anonymously.
    func signInAnonymously() async throws

    /// Sign in using the specified authentication provider.
    /// - Parameter provider: An authentication provider.
    func signIn(with provider: some AuthenticationProvider) async throws

    /// Sign in using the specified authentication provider.
    /// If sign in fails on AuthErrorCode.userNotFound exception and the provider is PasswordAuthenticationProvider, method tries to create user with specified email and password.
    func signInOrSignUp(with provider: some AuthenticationProvider) async throws

    /// Sign out the current user.
    func signOut() async throws

    /// Get the authentication token associated with the current user.
    /// - Returns: A string representing the user's authentication token.
    func token() async throws -> String?

    /// Verifies code for password reset generated by firebase and throws an error if the verification fails
    func verifyPasswordResetCode(for email: String, code: String) async throws

    /// Changes user password using code (such as code user received via request to reset password)
    func changePassword(for email: String, withCode code: String, newPassword password: String) async throws

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
}

/// A class providing Firebase authentication services.
open class FirebaseAuthenticationService: FirebaseAuthenticationServiceType {
    /// Initialize the authentication service with an optional tenant ID.
    /// - Parameter tenantID: An optional tenant ID to associate with the service.
    public init(auth: Auth = Auth.auth()) { 
        self.auth = auth
    }

    let auth: Auth
    public var user: FirebaseAuth.User? { Auth.auth().currentUser }
    
    public func signInAnonymously() async throws {
        try await auth.signInAnonymously()
    }
    
    public func signIn(with provider: some AuthenticationProvider) async throws {
        let credential = try await provider.credential()
        if let user {
            try await user.link(with: credential.firebaseCredential)
        } else {
            try await auth.signIn(with: credential.firebaseCredential)
        }
    }

    public func signInOrSignUp(with provider: some AuthenticationProvider) async throws {
        do {
            try await signIn(with: provider)
        } catch AuthErrorCode.userNotFound {
            if let provider = provider as? PasswordAuthenticationProvider {
                let credentials = try await provider.credential()
                try await auth.createUser(withEmail: credentials.email, password: credentials.password)
            } else {
                throw AuthErrorCode(.userNotFound)
            }
        }
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

    public func changePassword(for email: String, withCode code: String, newPassword password: String) async throws {
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
