//
//  MockCloudKitTestProjectIntegrationTest.swift
//  MockCloudKitTestProjectTests
//
//  Created by Christopher Charles Cavnor on 2/11/22.
//

import XCTest
import CloudKit
@testable import MockCloudKitTestProject // required for access to CloudController and MCF protocols loaded by app
import MockCloudKitFramework

/**
  This test case shows how to call through  a project-based controller that uses CloudKit in normal runtime but MockCloudKitFramework
    for test runs. The controller itself is unaware of the use of mocking objects.
 */
class MockCloudKitTestProjectIntegrationTest: BaseCloudkitTestCase {
    var cloudContainer: MockCKContainer!
    var cloudDatabase: MockCKDatabase!
    var cloudController: CloudController<MockCKContainer>!

    // run for each test
    override func setUpWithError() throws {
        try? super.setUpWithError()
        // reset state for each test. Each test must set up exactly the state they require.
        MockCKContainer.resetContainer()
        cloudContainer = MockCKContainer.`init`(identifier: "MockCKContainer")
        cloudDatabase = cloudContainer.privateCloudDatabase
        cloudController = CloudController(container: cloudContainer, databaseScope: .private)
    }

    // ================================
    // test accountStatus()
    // ================================
    // test that we get errors for all CKAccountStatus except for CKAccountStatus.available and that status is expected message.
    func test_accountStatus() {
        XCTAssertNotNil(cloudContainer)

        for (status, message) in ckAccountStatusMessageMappings {
            let expect = expectation(description: "CKAccountStatus")
            cloudContainer.setAccountStatus = status
            cloudController.accountStatus { result  in
                switch result {
                case .success:
                    XCTAssertEqual(self.ckAccountStatusMessageMappings[status],
                                   CKAccountStatusMessage.available.rawValue)
                case .failure(let error):
                    XCTAssertNotNil(error)
                    XCTAssertEqual(self.ckAccountStatusMessageMappings[status], message)
                }
                expect.fulfill()
            }
            waitForExpectations(timeout: 1)
        }
    }

    // call checkCloudRecordExists() when the record is not present
    func test_checkCloudRecordExists_no_record() {
        let expect = expectation(description: "CKDatabase fetch")
        let record = makeCKRecord()
        cloudController.checkCloudRecordExists(recordId: record.recordID) { result in
            switch result {
            case .success(let exists):
                XCTAssertFalse(exists, "record does not exist")
                expect.fulfill()
            case .failure:
                XCTFail("failure only when error occurs")
            }
        }
        waitForExpectations(timeout: 1)
    }

    func test_checkCloudRecordExists_success() {
        let expect = expectation(description: "CKDatabase fetch")
        let record = makeCKRecord()
        cloudDatabase.addRecords(records: [record])
        cloudController.checkCloudRecordExists(recordId: record.recordID) { result in
            switch result {
            case .success(let exists):
                XCTAssertTrue(exists)
                expect.fulfill()
            case .failure:
                XCTFail("failure only when error occurs")
            }
        }
        waitForExpectations(timeout: 1)
    }

    // call checkCloudRecordExists() when the record is present but error is set
    func test_checkCloudRecordExists_error() {
        let expect = expectation(description: "CKDatabase fetch")
        let record = makeCKRecord()
        cloudDatabase.addRecords(records: [record])
        // set an error on operation
        let nsErr = createNSError(with: CKError.Code.internalError)
        MockCKDatabaseOperation.setError = nsErr
        cloudController.checkCloudRecordExists(recordId: record.recordID) { result in
            switch result {
            case .success:
                XCTFail("should have failed")
                expect.fulfill()
            case .failure(let error):
                XCTAssertEqual(error.createCKError().code.rawValue, nsErr.code)
                expect.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }

    // test for partial failures
    func test_checkCloudRecordExists_partial_error() {
        let expect = expectation(description: "CKDatabase fetch")
        let record = makeCKRecord()
        cloudDatabase.addRecords(records: [record])
        // set an error on Record
        MockCKFetchRecordsOperation.setRecordErrors = [record.recordID]
        cloudController.checkCloudRecordExists(recordId: record.recordID) { result in
            switch result {
            case .success:
                XCTFail("should have failed")
            case .failure(let error):
                let ckError = error.createCKError()
                XCTAssertEqual(ckError.code.rawValue,
                               CKError.partialFailure.rawValue,
                               "The transaction error should always be set to CKError.partialFailure when record errors occur")
                if let partialErr: NSDictionary = error.createCKError().getPartialErrors() {
                    let ckErr = partialErr.allValues.first as? CKError
                    XCTAssertEqual("CKErrorDomain", ckErr?.toNSError().domain)
                    expect.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 1)
    }

    func test_post_message() {
        let expect = expectation(description: "post message")
        let record = CKRecord.init(recordType: "Message",
                                   recordID: CKRecord.ID.init(recordName: UUID.init().uuidString))
        record["body"] = "this is the body" as CKRecordValue
        cloudController.postMessage(message: record) { result in
            switch result {
            case .success:
                expect.fulfill()
            case .failure(let error):
                XCTFail("expected to succeed: \(error)")
            }
        }
        waitForExpectations(timeout: 1)
    }

    // test to ensure that CloudController gets the expected container type from its generic params
    func test_container_type() {
        // test with CKContainer
        let ckContainer: CKContainer = CKContainer.init(identifier: "Real container")
        let realCloudController = CloudController(container: ckContainer, databaseScope: .private)
        let containerType = type(of: realCloudController[keyPath: \.cloudContainer])
        XCTAssertTrue(containerType == CKContainer.self)
        let dbType = type(of: realCloudController[keyPath: \.database])
        XCTAssertTrue(dbType == CKDatabase.self)

        // test with MockCKContainer
        let mockContainer: MockCKContainer = MockCKContainer.`init`(identifier: "A mock container")
        let mockCloudController = CloudController(container: mockContainer, databaseScope: .private)
        let mockContainerType = type(of: mockCloudController[keyPath: \.cloudContainer])
        XCTAssertTrue(mockContainerType == MockCKContainer.self)
        let mockDbType = type(of: mockCloudController[keyPath: \.database])
        XCTAssertTrue(mockDbType == MockCKDatabase.self)
    }

    // test that adding a CKDatabaseOperation to a MockCKDabase converts the operation into a MockCKDatabaseOperation
    func test_conversion_CKModifyRecordsOperation() {
        // make records to save
        var recsToSave = [CKRecord]()
        for index in 1...5 {
            recsToSave.append(makeCKRecord(name: "record-\(index)"))
        }
        // create CKModifyRecordsOperation (it will have a CKDatabase attached to it - added implicitly by CloudKit)
        let ckModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: recsToSave, recordIDsToDelete: nil)
        XCTAssertEqual(ckModifyRecordsOperation.recordsToSave?.count, 5)

        // add this CKDatabaseOperation to MockCKDatabase and check that records were added to MockCKDatabase.
        // CKModifyRecordsOperation is internally mapped to MockCKModifyRecordsOperation:
        let mockDB: MockCKDatabase = MockCKDatabase()
        mockDB.add(ckModifyRecordsOperation)
        XCTAssertEqual(mockDB.getRecords()?.count, 5, "records are added to MockCKDatabase due to implicit conversion to a MockCKDatabaseOperation")
    }

    // test that adding a CKDatabaseOperation to a MockCKDabase converts the operation into a MockCKDatabaseOperation
    func test_conversion_CKFetchRecordsOperation() {
        // make records and add to MockDB
        var recsToSave = [CKRecord]()
        for index in 1...5 {
            recsToSave.append(makeCKRecord(name: "record-\(index)"))
        }
        let recordIDs = recsToSave.map { $0.recordID }
        let mockDB: MockCKDatabase = MockCKDatabase()
        mockDB.addRecords(records: recsToSave)

        // create CKModifyRecordsOperation (it will have a CKDatabase attached to it - added implicitly by CloudKit)
        let ckFetchRecordsOperation = CKFetchRecordsOperation(recordIDs: recordIDs)
        XCTAssertEqual(ckFetchRecordsOperation.recordIDs?.count, 5)

        // add this CKDatabaseOperation to MockCKDatabase and check that records were added to MockCKDatabase.
        // CKModifyRecordsOperation is internally mapped to MockCKModifyRecordsOperation:
        mockDB.add(ckFetchRecordsOperation)
        // we have no handle on the mock that was mapped to, nor is there any mutatable change on MockDB, but we use the
        // CKDatabaseOperation to confirm that the operation read from MockCKDatabase to confirm the mapping.
        XCTAssertEqual(ckFetchRecordsOperation.recordIDs?.count, 5)
    }

    // test that adding a CKDatabaseOperation to a MockCKDabase converts the operation into a MockCKDatabaseOperation
    func test_conversion_CKQueryRecordsOperation() {
        // make records and add to MockDB
        var recsToSave = [CKRecord]()
        for index in 1...5 {
            let id = CKRecord.ID.init(recordName: "record-\(index)")
            let rec = CKRecord(recordType: "TestRecordType", recordID: id)
            recsToSave.append(rec)
        }
        let mockDB: MockCKDatabase = MockCKDatabase()
        mockDB.addRecords(records: recsToSave)

        // create CKQueryRecordsOperation (it will have a CKDatabase attached to it - added implicitly by CloudKit)
        let pred = NSPredicate(value: true) // matches everything
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let ckQueryOperation = CKQueryOperation(query: query)

        // we can register callbacks on the CKDatabaseOperation and they will be honored
        var recCnt = 0
        let expect = expectation(description: "query")
        ckQueryOperation.recordMatchedBlock = { _, _ in
            recCnt += 1
        }
        ckQueryOperation.queryResultBlock = { _ in
            if recCnt == 5 {
                expect.fulfill()
            }
        }

        // add this CKDatabaseOperation to MockCKDatabase and check that records were added to MockCKDatabase.
        // CKModifyRecordsOperation is internally mapped to MockCKModifyRecordsOperation:
        mockDB.add(ckQueryOperation)
        waitForExpectations(timeout: 1)
        // use MockCKDatabase lastExecuted to get the type of the converted CKDatabaseOperation to confirm
        // that the operation to confirm the mapping.
        XCTAssertTrue(type(of: mockDB.lastExecuted!) === MockCKQueryOperation.self)
    }
}
