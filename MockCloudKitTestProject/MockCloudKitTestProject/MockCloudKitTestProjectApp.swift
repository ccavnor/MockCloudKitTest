//
//  MockCloudKitTestProjectApp.swift
//  MockCloudKitTestProject
//
//  Created by Christopher Charles Cavnor on 2/2/22.
//

import SwiftUI
import CloudKit
import MockCloudKitFramework


@main
struct MockCloudKitTestProjectApp: App {
    // Being explicit instead of using type erasure for brevity. A better approach may be coming:
    // https://forums.swift.org/t/pitch-constrained-existential-types/56361
    @StateObject var cloudController: CloudController<CKContainer>
    @StateObject var mockCloudController: CloudController<MockCKContainer>

    init() {
        // mock container
        let mockCloudContainer = MockCKContainer.`init`(identifier: "iCloud.com.ccavnor.Another")
        let mockCloudController = CloudController.init(container: mockCloudContainer, databaseScope: CKDatabase.Scope.public)
        self._mockCloudController = StateObject(wrappedValue: mockCloudController)
        // so that we can set error code via UI tests
        let errorCode = ProcessInfo.processInfo.environment["errorCode"]
        if let code = errorCode {
            // set MCF error
            MockCKDatabaseOperation.setError = NSError.init(domain: CKError.errorDomain, code: Int(code) ?? 0)
        }
        // CloudKit container
        let cloudContainer = CKContainer.init(identifier: "iCloud.com.ccavnor.Another")
        let cloudController = CloudController.init(container: cloudContainer, databaseScope: CKDatabase.Scope.public)
        self._cloudController = StateObject(wrappedValue: cloudController)
    }

    var body: some Scene {
        WindowGroup {
            if CommandLine.arguments.contains("--uitesting") {
                ContentView(cloudController: mockCloudController)
            } else {
                ContentView(cloudController: cloudController)
            }
        }
    }
}
