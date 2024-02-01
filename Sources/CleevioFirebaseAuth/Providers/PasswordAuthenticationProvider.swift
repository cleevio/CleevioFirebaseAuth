//
//  PasswordAuthenticationProvider.swift
//  
//
//  Created by Lukáš Valenta on 19.08.2023.
//

import Foundation
import Firebase

/// A struct representing the credential for password-based authentication.
public struct PasswordAuthenticationProvider: AuthenticationProvider {
    /// The credential structure containing email and password.
    public struct Credential {
        public var email: String
        public var password: String

        @inlinable
        public init(email: String, password: String) {
            self.email = email
            self.password = password
        }
    }

    public struct SignInOptions: OptionSet {
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
}

extension PasswordAuthenticationProvider.Credential: FirebaseCredentialProvider {
    /// The Firebase authentication credential for email and password.
    public var firebaseCredential: AuthCredential {
        EmailAuthProvider.credential(withEmail: email, password: password)
    }
}

extension PasswordAuthenticationProvider: FirebaseAuthenticationProvider { }
