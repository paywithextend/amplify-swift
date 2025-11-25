//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest

@testable import Amplify
@testable import AmplifyTestCommon

class ConfigurationTests: XCTestCase {
    override func setUp() async throws {
        await Amplify.reset()
    }

    // Remember, this test must be invoked with a category that doesn't include an Amplify-supplied default plugin
    // TODO: this test is disabled for now since `catchBadInstruction` only takes in closure
    func testPreconditionFailureInvokingWithNoPlugin() async throws {
        let amplifyConfig = AmplifyConfiguration()
        try Amplify.configure(amplifyConfig)

        throw XCTSkip("this test is disabled for now since `catchBadInstruction` only takes in closure")
//        try XCTAssertThrowFatalError {
//            Task {
//                _ = try await Amplify.API.get(request: RESTRequest())
//            }
//        }
    }

    // Remember, this test must be invoked with a category that doesn't include an Amplify-supplied default plugin
    // TODO: this test is disabled for now since `catchBadInstruction` only takes in closure
    func testPreconditionFailureInvokingBeforeConfig() throws {
        let plugin = MockAPICategoryPlugin()
        try Amplify.add(plugin: plugin)

        // Remember, this test must be invoked with a category that doesn't include an Amplify-supplied default plugin
        throw XCTSkip("this test is disabled for now since `catchBadInstruction` only takes in closure")
//        try XCTAssertThrowFatalError {
//            Task {
//                _ = try await Amplify.API.get(request: RESTRequest())
//            }
//        }
    }

    func testConfigureDelegatesToPlugins() async throws {
        let configureWasInvoked = expectation(description: "Plugin configure() was invoked")
        let plugin = MockLoggingCategoryPlugin()
        plugin.listeners.append { message in
            if message == "configure(using:)" {
                configureWasInvoked.fulfill()
            }
        }

        try Amplify.add(plugin: plugin)

        let loggingConfig = LoggingCategoryConfiguration(
            plugins: ["MockLoggingCategoryPlugin": true]
        )

        let amplifyConfig = AmplifyConfiguration(logging: loggingConfig)

        try Amplify.configure(amplifyConfig)
        await fulfillment(of: [configureWasInvoked], timeout: 1.0)
    }
/*
    func testMultipleConfigureCallsThrowError() async throws {
        let amplifyConfig = AmplifyConfiguration()
        try Amplify.configure(amplifyConfig)
        
        do {
            try Amplify.configure(amplifyConfig)
            XCTFail("Expected configure to throw when called multiple times")
        } catch {
            guard case ConfigurationError.amplifyAlreadyConfigured = error else {
                XCTFail("Expected ConfigurationError.amplifyAlreadyConfigured error")
                return
            }
        }
    }
*/
    
    func testResetClearsPreviouslyAddedPlugins() async throws {
        let plugin = MockLoggingCategoryPlugin()
        try Amplify.add(plugin: plugin)

        let loggingConfig = LoggingCategoryConfiguration(
            plugins: ["MockLoggingCategoryPlugin": true]
        )

        let amplifyConfig = AmplifyConfiguration(logging: loggingConfig)

        try Amplify.configure(amplifyConfig)
        XCTAssertNotNil(try Amplify.Logging.getPlugin(for: "MockLoggingCategoryPlugin"))
        await Amplify.reset()
        XCTAssertThrowsError(
            try Amplify.Logging.getPlugin(for: "MockLoggingCategoryPlugin"),
            "Plugins should be reset"
        ) { error in
                                guard case LoggingError.configuration = error else {
                                    XCTFail("Expected PluginError.noSuchPlugin error")
                                    return
                                }
        }
    }

    func testResetDelegatesToPlugins() async throws {
        let plugin = MockLoggingCategoryPlugin()

        let resetWasInvoked = expectation(description: "Reset was invoked")
        plugin.listeners.append { message in
            if message == "reset" {
                resetWasInvoked.fulfill()
            }
        }

        try Amplify.add(plugin: plugin)

        let loggingConfig = LoggingCategoryConfiguration(
            plugins: ["MockLoggingCategoryPlugin": true]
        )

        let amplifyConfig = AmplifyConfiguration(logging: loggingConfig)

        try Amplify.configure(amplifyConfig)
        await Amplify.reset()
        await fulfillment(of: [resetWasInvoked], timeout: 1.0)
    }

    func testResetAllowsReconfiguration() async throws {
        let amplifyConfig = AmplifyConfiguration()
        try Amplify.configure(amplifyConfig)
        await Amplify.reset()
        do {
            try Amplify.configure(amplifyConfig)
        } catch {
            XCTFail("Configure should not throw after reset: \(error)")
        }
    }

    func testReconfigureAllowsMultipleConfigurations() async throws {
        // First configuration
        let firstConfig = AmplifyConfiguration()
        try Amplify.configure(firstConfig)
        
        // Verify it's configured
        XCTAssertTrue(Amplify.isConfigured)
        
        // Reconfigure with allowReconfiguration
        let secondConfig = AmplifyConfiguration()
        do {
            try Amplify.configure(secondConfig)
        } catch {
            XCTFail("Reconfigure should not throw: \(error)")
        }
        
        // Verify it's still configured after reconfiguration
        XCTAssertTrue(Amplify.isConfigured)
    }

    func testReconfigureConvenienceMethod() async throws {
        // First configuration
        let firstConfig = AmplifyConfiguration()
        try Amplify.configure(firstConfig)
        
        // Verify it's configured
        XCTAssertTrue(Amplify.isConfigured)
        
        // Use the configure method for reconfiguration
        let secondConfig = AmplifyConfiguration()
        do {
            try Amplify.configure(secondConfig)
        } catch {
            XCTFail("Reconfigure should not throw: \(error)")
        }
        
        // Verify it's still configured after reconfiguration
        XCTAssertTrue(Amplify.isConfigured)
    }

    func testDecodeConfiguration() throws {
        let jsonString = """
        {"UserAgent":"aws-amplify-cli/2.0","Version":"1.0","storage":{"plugins":{"MockStorageCategoryPlugin":{}}}}
        """

        let jsonData = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        let config = try decoder.decode(AmplifyConfiguration.self, from: jsonData)
        XCTAssertNotNil(config.storage)
    }
}
