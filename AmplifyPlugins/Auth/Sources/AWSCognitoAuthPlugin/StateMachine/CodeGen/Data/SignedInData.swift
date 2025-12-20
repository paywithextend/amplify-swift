//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public struct SignedInData {
    public let userId: String
    public let username: String
    public let signedInDate: Date
    public let signInMethod: SignInMethod
    public let deviceMetadata: DeviceMetadata
    public let cognitoUserPoolTokens: AWSCognitoUserPoolTokens
    public var isRefreshTokenExpired: Bool?

    public init(
        signedInDate: Date,
        signInMethod: SignInMethod,
        deviceMetadata: DeviceMetadata = .noData,
        cognitoUserPoolTokens: AWSCognitoUserPoolTokens
    ) {
        let user = try? TokenParserHelper.getAuthUser(accessToken: cognitoUserPoolTokens.accessToken)
        self.userId = user?.userId ?? "unknown"
        self.username = user?.username ?? "unknown"
        self.signedInDate = signedInDate
        self.signInMethod = signInMethod
        self.deviceMetadata = deviceMetadata
        self.cognitoUserPoolTokens = cognitoUserPoolTokens
        self.isRefreshTokenExpired = false
    }
}
