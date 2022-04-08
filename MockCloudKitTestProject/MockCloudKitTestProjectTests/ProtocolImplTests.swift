//
//  ProtocolImplTests.swift
//  MockCloudKitTestProjectTests
//
//  Created by Christopher Charles Cavnor on 3/21/22.
//

import XCTest
import CloudKit
import MockCloudKitFramework
@testable import MockCloudKitTestProject // required for access to CloudController and MCF protocols loaded by app

class ProtocolTesting<T: CloudContainable> {
    let cloudContainer: T
    let database: T.DatabaseType

    init(container: T, databaseScope: CKDatabase.Scope) {
        self.cloudContainer = container
        self.database = container.database(with: databaseScope)
    }

    // O.OperationType == T.DatabaseType.OperationType else compile error.
    // We get the compiler error "Cannot convert value of type 'O' to expected argument type 'T.DatabaseType.OperationType"
    // iff we don't use AnyCKDatabaseProtocol protocol as a shadow protocol and provide a default CKDatabaseProtocol extension
    // to implement the add() function.
    func setOperator<O: DatabaseOperational>(dbOperator: O) {
        database.add(dbOperator)
    }
}

class ProtocolImplTests: BaseCloudkitTestCase {
    var ckContainer: CKContainer!
    var ckProtoTest: ProtocolTesting<CKContainer>!
    var mockContainer: MockCKContainer!
    var mockProtoTest: ProtocolTesting<MockCKContainer>!

    override func setUpWithError() throws {
        ckContainer = CKContainer.init(identifier: "Real container")
        ckProtoTest = ProtocolTesting(container: ckContainer, databaseScope: CKDatabase.Scope.private)
        mockContainer = MockCKContainer.`init`(identifier: "Mock container")
        mockProtoTest = ProtocolTesting(container: mockContainer, databaseScope: CKDatabase.Scope.private)
    }

    // test to ensure that CloudController gets the expected container type from its generic params
    func test_container_type() {
        let ckContainerType = type(of: ckProtoTest[keyPath: \.cloudContainer])
        XCTAssertTrue(ckContainerType == CKContainer.self)
        let ckDbType = type(of: ckProtoTest[keyPath: \.database])
        XCTAssertTrue(ckDbType == CKDatabase.self)
        XCTAssertEqual(ckContainer.containerIdentifier, "Real container")

        let mockContainerType = type(of: mockProtoTest[keyPath: \.cloudContainer])
        XCTAssertTrue(mockContainerType == MockCKContainer.self)
        let mockDbType = type(of: mockProtoTest[keyPath: \.database])
        XCTAssertTrue(mockDbType == MockCKDatabase.self)
        XCTAssertEqual(mockContainer.containerIdentifier, "Mock container")
    }

    /// This test requires the implementation of:
    /// @objc public func performCKOperation()
    /// to pass. See extension above.
//    // test completion block on CKDatabaseOperation
//    func test_CKDatabaseOperation_completionBlock() {
//        let expect = expectation(description: "completion")
//        let dbOp = CKDatabaseOperation()
//        dbOp.completionBlock = {
//            expect.fulfill()
//        }
//        ckProtoTest.database.add(dbOp)
//        waitForExpectations(timeout: 1)
//    }

    // tests that CKDatabaseOperationProtocol.OperationType == CKContainerProtocol.DatabaseType.OperationType.
    func test_OperationType_parity() {
        XCTAssertTrue(MockCKContainer.DatabaseType.self == MockCKDatabase.self)
        XCTAssertTrue(MockCKDatabase.OperationType.self == MockCKDatabaseOperation.self)
        XCTAssertTrue(MockCKDatabaseOperation.DatabaseType.self == MockCKDatabase.self)
        XCTAssertTrue(MockCKContainer.DatabaseType.self == MockCKDatabaseOperation.DatabaseType.self)

        XCTAssertTrue(CKContainer.DatabaseType.self == CKDatabase.self)
        XCTAssertTrue(CKDatabase.OperationType.self == CKDatabaseOperation.self)
        XCTAssertTrue(CKDatabaseOperation.DatabaseType.self == CKDatabase.self)
        XCTAssertTrue(CKContainer.DatabaseType.self == CKDatabaseOperation.DatabaseType.self)
    }

}
