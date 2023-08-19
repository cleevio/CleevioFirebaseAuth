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
        public let email: String
        public let password: String

        public init(email: String, password: String) {
            self.email = email
            self.password = password
        }
    }
    
    public let email: String
    public let password: String

    /// Initializes a `PasswordAuthenticationProvider` with the provided email and password.
    /// - Parameters:
    ///   - email: The email for authentication.
    ///   - password: The password for authentication.
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
    
    /// Retrieves the authentication credential asynchronously.
    /// - Returns: A `Credential` instance containing email and password.
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
