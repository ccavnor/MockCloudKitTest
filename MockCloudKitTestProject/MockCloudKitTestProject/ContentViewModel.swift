//
//  ContentViewModel.swift
//  MockCloudKitTestProject
//
//  Created by Christopher Charles Cavnor on 3/25/22.
//

import SwiftUI
import CloudKit
import MockCloudKitFramework

extension ContentView {
    @MainActor class ViewModel<Container: CloudContainable>: ObservableObject {
        @Published var messages: [String] = []
        @Published var message: String = ""
        @Published var hasError: Bool = false
        @Published var errorInfo: String?
        private var cloudController: CloudController<Container>

        init(controller: CloudController<Container>) {
            self.cloudController = controller
        }

        func uploadMessage(message: String) {
            // make a CKRecord from message
            let record = CKRecord.init(recordType: "Message",
                                       recordID: CKRecord.ID.init(recordName: UUID.init().uuidString))
            record["body"] = message

            cloudController.postMessage(message: record) { [self] result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        messages.append(message)
                        self.message = ""
                    }
                case .failure(let error):
                    hasError = true
                    errorInfo = error.localizedDescription
                    print(">>>> \(error)")
                }
            }
        }

        func getMessages() -> Void {
            cloudController.getMessages() { [self] result in
                switch result {
                case .success(let messages):
                    DispatchQueue.main.async {
                        self.messages = messages
                            .map { $0["body"]?.description ?? "" }
                    }

                case .failure(let error):
                    hasError = true
                    errorInfo = error.localizedDescription
                    print(">>>> \(error)")
                }
            }
        }

    }
}
