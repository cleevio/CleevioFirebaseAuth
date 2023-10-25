//
//  FirebaseAuthenticationService+APITokenProvider.swift
//
//
//  Created by Lukáš Valenta on 19.08.2023.
//

import Foundation
import CleevioAuthentication
import CleevioFirebaseAuth

extension FirebaseAuthenticationService: CleevioAuthentication.APITokenProvider {
    /// Retrieves the API token associated with the currently logged-in user.
    /// - Returns: A string representing the API token.
    /// - Throws: `NotLoggedInError` if the user is not logged in.
    public var apiToken: String { get async throws {
        if let token = try await token() {
            return token
        } else {
            throw NotLoggedInError()
        }
    } }
    
    /// Checks if the current user is logged in.
    public var isUserLoggedIn: Bool {
        user?.isAnonymous == false
    }
    
    /// Removes the API token from storage by signing the user out.
    public func removeAPITokenFromStorage() async {
        do {
            try await signOut()
        } catch let signOutError as NSError {
            assertionFailure("Unable to sign out \(signOutError)")
        }
    }
}
