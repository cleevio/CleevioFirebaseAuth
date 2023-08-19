//
//  GoogleAuthenticationProvider.swift
//  
//
//  Created by Lukáš Valenta on 19.08.2023.
//

import Foundation
import GoogleSignIn
import Firebase

import GoogleSignIn

/// A class providing Google authentication services conforming to `AuthenticationProvider`.
public final class GoogleAuthenticationProvider: AuthenticationProvider {
    /// The authentication credential structure for Google authentication.
    public struct Credential {
        /// The ID token obtained from Google authentication.
        let idToken: String
        /// The access token obtained from Google authentication.
        let accessToken: String

        public init(idToken: String, accessToken: String) {
            self.idToken = idToken
            self.accessToken = accessToken
        }
    }

    /// Possible errors during Google authentication.
    public enum AuthenticatorError: Error {
        case firebaseClientIDNotFound
        case presentingControllerNotProvided
        case idTokenNotFound
    }
    
    /// The view controller used for presenting Google authentication UI.
    private weak var presentingController: UIViewController!
    
    /// Initializes a `GoogleAuthenticationProvider` with a presenting view controller.
    /// - Parameter presentingController: The view controller for presenting Google authentication UI.
    public init(presentingController: UIViewController) {
        self.presentingController = presentingController
    }
    
    /// Retrieves the Google authentication credential asynchronously.
    /// - Returns: A `Credential` instance containing ID token and access token.
    /// - Throws: An error of type `AuthenticatorError` if any step fails.
    public func credential() async throws -> Credential {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw AuthenticatorError.firebaseClientIDNotFound }
        guard let presentingController = presentingController else { throw AuthenticatorError.presentingControllerNotProvided }
        
        let configuration = GIDConfiguration(clientID: clientID)
        
        let signIn = GIDSignIn.sharedInstance
        signIn.configuration = configuration
        
        let signInResult = try await signIn.signIn(withPresenting: presentingController)
        let user = signInResult.user
        
        guard let idToken = user.idToken?.tokenString else { throw AuthenticatorError.idTokenNotFound }
        
        return Credential(idToken: idToken, accessToken: user.accessToken.tokenString)
    }
}

extension GoogleAuthenticationProvider.Credential: FirebaseCredentialProvider {
    /// The Firebase authentication credential for Google authentication.
    public var firebaseCredential: AuthCredential {
        GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
    }
}
