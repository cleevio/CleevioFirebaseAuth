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

    /// Sign out the current user.
    func signOut() async throws

    /// Get the authentication token associated with the current user.
    /// - Returns: A string representing the user's authentication token.
    func token() async throws -> String?

#if os(iOS)
    /// Adds APNS token to a user
    static func setAPNSToken(_ token: Data, type: AuthAPNSTokenType)
#endif

    /// The currently authenticated user, if available.
    var user: FirebaseAuth.User? { get }
}

/// A class providing Firebase authentication services.
open class FirebaseAuthenticationService: FirebaseAuthenticationServiceType {
    /// Initialize the authentication service with an optional tenant ID.
    /// - Parameter tenantID: An optional tenant ID to associate with the service.
    public init(tenantID: String? = nil) {
        Auth.auth().tenantID = tenantID
    }
    
    public var user: FirebaseAuth.User? { Auth.auth().currentUser }
    
    public func signInAnonymously() async throws {
        try await Auth.auth().signInAnonymously()
    }
    
    public func signIn(with provider: some AuthenticationProvider) async throws {
        let credential = try await provider.credential()
        if let user {
            try await user.link(with: credential.firebaseCredential)
        } else {
            try await Auth.auth().signIn(with: credential.firebaseCredential)
        }
    }
    
    public func signOut() async throws {
        try Auth.auth().signOut()
    }
    
    public func token() async throws -> String? {
        try await user?.getIDToken()
    }

    #if os(iOS)
    public static func setAPNSToken(_ token: Data, type: AuthAPNSTokenType) {
        Auth.auth().setAPNSToken(token, type: type)
    }
    #endif
}
