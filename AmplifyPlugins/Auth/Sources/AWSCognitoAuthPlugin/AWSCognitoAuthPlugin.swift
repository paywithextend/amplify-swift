//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSPluginsCore
import Foundation

public final class AWSCognitoAuthPlugin: AWSCognitoAuthPluginBehavior {

    var authEnvironment: AuthEnvironment!

    var authStateMachine: AuthStateMachine!

    var credentialStoreStateMachine: CredentialStoreStateMachine!

     /// A queue that regulates the execution of operations.
    var queue: OperationQueue!

    /// Configuration for the auth plugin
    var authConfiguration: AuthConfiguration!

    /// Handles different auth event send through hub
    var hubEventHandler: AuthHubEventBehavior!

    var analyticsHandler: UserPoolAnalyticsBehavior!

    var taskQueue: TaskQueue<Any>!

    var httpClientEngineProxy: HttpClientEngineProxy?

    /// The user network preferences for timeout and retry
    let networkPreferences: AWSCognitoNetworkPreferences?

    /// The user secure storage preferences for access group
    let secureStoragePreferences: AWSCognitoSecureStoragePreferences?

    @_spi(InternalAmplifyConfiguration)
    public internal(set) var jsonConfiguration: JSONValue?

    /// The unique key of the plugin within the auth category.
    public var key: PluginKey {
        return "awsCognitoAuthPlugin"
    }

    /// Instantiates an instance of the AWSCognitoAuthPlugin with optional custom network
    /// preferences and optional custom secure storage preferences
    /// - Parameters:
    ///   - networkPreferences: network preferences
    ///   - secureStoragePreferences: secure storage preferences
    public init(
        networkPreferences: AWSCognitoNetworkPreferences? = nil,
        secureStoragePreferences: AWSCognitoSecureStoragePreferences = AWSCognitoSecureStoragePreferences()
    ) {
        self.networkPreferences = networkPreferences
        self.secureStoragePreferences = secureStoragePreferences
    }
    
    /// Sets authentication tokens from an external OAuth login
    ///
    /// Use this method to establish an Amplify session with tokens obtained from an external OAuth flow.
    /// After calling this, the user will be considered signed in and `fetchAuthSession()` will return these tokens.
    ///
    /// Example usage:
    /// ```swift
    /// let plugin = try Amplify.Auth.getPlugin(for: "awsCognitoAuthPlugin") as? AWSCognitoAuthPlugin
    /// try await plugin?.setTokens(
    ///     accessToken: "your-access-token",
    ///     idToken: "your-id-token",
    ///     refreshToken: "your-refresh-token"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - accessToken: The JWT access token from your OAuth provider
    ///   - idToken: The JWT ID token from your OAuth provider
    ///   - refreshToken: The refresh token from your OAuth provider
    ///   - expiration: Optional expiration date (defaults to parsing from token or 1 hour from now)
    /// - Throws: AuthError if the tokens are invalid or cannot be stored
    public func setTokens(
        accessToken: String,
        idToken: String,
        refreshToken: String,
        expiration: Date? = nil
    ) async throws {
        
        // Validate that plugin is configured
        guard let authStateMachine = authStateMachine,
              let credentialStoreStateMachine = credentialStoreStateMachine else {
            throw AuthError.configuration(
                "Auth plugin not configured",
                "Make sure Amplify.configure() has been called before using setTokens"
            )
        }
        
        // Calculate expiration if not provided
        let tokenExpiration: Date
        if let expiration = expiration {
            tokenExpiration = expiration
        } else {
            // Try to parse expiration from access token, default to 1 hour from now
            tokenExpiration = parseTokenExpiration(from: accessToken) ?? Date().addingTimeInterval(3600)
        }
        
        // Create the token structure
        let tokens = AWSCognitoUserPoolTokens(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiration: tokenExpiration
        )
        
        // Create signed in data with the tokens
        // Create a default HostedUIOptions for external OAuth tokens
        let hostedUIOptions = HostedUIOptions(
            scopes: [],
            providerInfo: HostedUIProviderInfo(authProvider: nil, idpIdentifier: nil),
            presentationAnchor: nil,
            preferPrivateSession: true,
            nonce: nil,
            language: nil,
            loginHint: nil,
            prompt: nil,
            resource: nil
        )
        
        let signedInData = SignedInData(
            signedInDate: Date(),
            signInMethod: .hostedUI(hostedUIOptions),
            deviceMetadata: .noData,
            cognitoUserPoolTokens: tokens
        )
        
        // Wrap in AmplifyCredentials based on configuration
        let credentials: AmplifyCredentials
        
        // Check if identity pool is configured
        if case .userPoolsAndIdentityPools = authConfiguration {
            // For identity pool configuration, we'll fetch AWS credentials later via normal flow
            // Just store user pool tokens for now
            credentials = .userPoolOnly(signedInData: signedInData)
        } else {
            // User pool only
            credentials = .userPoolOnly(signedInData: signedInData)
        }
        
        // Store the credentials and update auth state
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            
            // Use a task to handle the state machine updates
            Task {
                do {
                    // First, update the authentication state to signed in
                    let authEvent = AuthenticationEvent(
                        eventType: .signInCompleted(signedInData)
                    )
                    
                    // Store credentials via credential store state machine
                    let storeEvent = CredentialStoreEvent(
                        eventType: .storeCredentials(.amplifyCredentials(credentials))
                    )
                    
                    // Send events to state machines
                    await authStateMachine.send(authEvent)
                    await credentialStoreStateMachine.send(storeEvent)
                    
                    // Small delay to ensure state machines process the events
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AuthError.unknown(
                        "Failed to set tokens",
                        error
                    ))
                }
            }
        }
    }
    
    /// Helper to parse expiration from JWT token
    private func parseTokenExpiration(from token: String) -> Date? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        var base64String = segments[1]
        
        // Add padding if needed
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String += String(repeating: "=", count: 4 - remainder)
        }
        
        // Decode base64
        guard let data = Data(base64Encoded: base64String),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        
        return Date(timeIntervalSince1970: exp)
    }
}
