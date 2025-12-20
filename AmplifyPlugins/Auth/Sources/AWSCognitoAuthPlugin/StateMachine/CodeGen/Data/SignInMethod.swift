//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public enum SignInMethod {

    case apiBased(AuthFlowType)

    case hostedUI(HostedUIOptions)
}

extension SignInMethod: Codable { }

extension SignInMethod: Equatable { }
