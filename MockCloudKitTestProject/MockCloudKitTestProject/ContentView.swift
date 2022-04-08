//
//  ContentView.swift
//  MockCloudKitTestProject
//
//  Created by Christopher Charles Cavnor on 2/2/22.
//

import SwiftUI
import CloudKit
import MockCloudKitFramework

struct ContentView<Container: CloudContainable>: View {
    @StateObject private var viewModel: ViewModel<Container>

    // run for each test
    init(cloudController: CloudController<Container>) {
        _viewModel = StateObject(wrappedValue: ViewModel(controller: cloudController))
    }

    var body: some View {
        VStack {
            // existing messages
            List(viewModel.messages, id: \.self) { message in
                Text(message)
            }

            if viewModel.message.isEmpty {
                Text("Please enter a message to upload to icloud!")
            }
            TextField("Message", text: $viewModel.message)
                .accessibilityHint("message box")
                .accessibilityIdentifier("messageBox")
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: {
                viewModel.uploadMessage(message: viewModel.message)
            }, label: {
                Image(systemName: "icloud")
                Text("Upload to cloud")
            })
            .accessibilityIdentifier("messageButton")
            .foregroundColor(Color.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(5)
        }
        .alert(isPresented: $viewModel.hasError) {
            Alert(title: Text("An error has occurred!"),
                  message: Text(viewModel.errorInfo ?? "No error information is available"),
                  dismissButton: .default(Text("Got it!")))
        }
        //.accessibilityIdentifier("alert")
        .frame(width: 300, alignment: .bottomLeading)
        .onAppear(perform: { viewModel.getMessages() })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let container = CKContainer.init(identifier: "iCloud.com.ccavnor.Another")
        let controller = CloudController(container: container, databaseScope: CKDatabase.Scope.public)
        ContentView(cloudController: controller)
    }
}
