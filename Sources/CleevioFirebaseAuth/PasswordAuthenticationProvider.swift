//
//  PasswordAuthenticationProvider.swift
//  
//
//  Created by Lukáš Valenta on 19.08.2023.
//

import Foundation
import FirebaseAuth

/// A struct representing the credential for password-based authentication.
public struct PasswordAuthenticationProvider: AuthenticationProvider {
    /// The credential structure containing email and password.
    public struct Credential: Sendable, Hashable, Codable {
        public var email: String
        public var password: String

        @inlinable
        public init(email: String, password: String) {
            self.email = email
            self.password = password
        }
    }

    public struct SignInOptions: OptionSet, Sendable, Hashable, Codable {
        public let rawValue: UInt

        @inlinable
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let signUpOnUserNotFound = Self(rawValue: 1 << 0)
        /// Needed with enumeration protection turned on as Firebase returns different errors at random (such as AuthErrorCode.internalError or AuthErrorCode.invalidCredential) so that attacker cannot determine if user exists
        /// Firebase changes the error codes in runtime on their BE so it could break signup in production
        /// More information: https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection#overview
        public static let signUpOnAnyError = Self(rawValue: 1 << 1)
        /// When signing in try to link the existing account to the provided credentials
        public static let tryLinkOnSignIn = Self(rawValue: 1 << 2)
    }
    
    public let email: String
    public let password: String
    public let options: SignInOptions

    /// Initializes a `PasswordAuthenticationProvider` with the provided email and password.
    /// - Parameters:
    ///   - email: The email for authentication.
    ///   - password: The password for authentication.
    @inlinable
    public init(email: String, password: String, options: SignInOptions = []) {
        self.email = email
        self.password = password
        self.options = options
    }
    
    /// Retrieves the authentication credential asynchronously.
    /// - Returns: A `Credential` instance containing email and password.
    @inlinable
    public func credential() async throws -> Credential {
        Credential(email: email, password: password)
    }

    public func authenticate(with auth: some FirebaseAuthenticationServiceType) async throws -> AuthenticationResult {
        let credential = try await credential()
        let firebaseAuthResult: AuthDataResult

        do {
            let link = options.contains(.tryLinkOnSignIn)
            firebaseAuthResult = try await auth.signIn(with: credential.firebaseCredential, link: link)
        } catch let error as AuthErrorCode where
            error.code == .userNotFound && options.contains(.signUpOnUserNotFound) ||
            options.contains(.signUpOnAnyError) {
            firebaseAuthResult = try await auth.signUp(withEmail: credential.email, password: credential.password)
        }

        return AuthenticationResult(
            firebaseAuthResult: firebaseAuthResult,
            userData: AuthenticationResult.UserData(email: credential.email)
        )
    }
}

extension PasswordAuthenticationProvider.Credential: FirebaseCredentialProvider {
    /// The Firebase authentication credential for email and password.
    public var firebaseCredential: AuthCredential {
        EmailAuthProvider.credential(withEmail: email, password: password)
    }
}

extension PasswordAuthenticationProvider: FirebaseAuthenticationProvider { }
