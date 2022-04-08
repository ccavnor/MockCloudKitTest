//
//  MockCloudKitTestProjectTests.swift
//  MockCloudKitTestProjectTests
//
//  Created by Christopher Charles Cavnor on 2/2/22.
//

import XCTest
import CloudKit
import MockCloudKitFramework

class MockCloudKitFrameworkTests: BaseCloudkitTestCase {

    // run for each test
    override func setUpWithError() throws {
        // clears the block setters of any existing values. Each test must set up exactly the state they require.
        MockCKContainer.resetContainer()
    }

    // test OperationError
    func test_OperationError_operationNotValid() {
        let operation = MockCKDatabaseOperation.self
        let opErr = OperationError.invalidDatabaseOperation(operation: operation)
        XCTAssertEqual(opErr.errorDescription, "An invalid or unsupported CKDatabaseOperation was performed.")
        XCTAssertEqual(opErr.failureReason, "\(operation) is not a supported operation.")
        XCTAssertEqual(opErr.recoverySuggestion, "See CKDatabaseOperation docs for valid operations.")
    }
    func test_OperationError_operationNotImplemented() {
        let operationName = "some operation"
        let recoveryMessage = "try using other operation instead"
        let opErr = OperationError.operationNotImplemented(operationName: operationName,
                                                           recoveryMessage: recoveryMessage)
        XCTAssertEqual(opErr.errorDescription, "Operation \'\(operationName)\' is not implemented.")
        XCTAssertEqual(opErr.failureReason, "\(operationName) is not implemented.")
        XCTAssertEqual(opErr.recoverySuggestion, recoveryMessage)
    }

    // ====================================
    // CKContainer
    // ====================================
    // test that convenience constructor returns MockCKContainer
    func test_init_with_identifier() {
        //let container1 = CKContainer.`init`(identifier: "someIdentifier")
        let container1 = MockCKContainer.`init`(identifier: "someIdentifier")
        let container2 = MockCKContainer.`init`(identifier: "someIdentifier")
        XCTAssertEqual(container1.containerIdentifier, container2.containerIdentifier)
        XCTAssertTrue(type(of: container1) == type(of: container2), "CKContainer is an alias for MockCKContainer")
        XCTAssertFalse(container1 === container2, "MockCKContainer is not a singleton")
    }

    // Test that container instances share databases of a given scope, but that every container has
    // public, private, and shared databases as distinct instances.
    func test_container_database() {
        let container1 = MockCKContainer.default()
        let container2 = MockCKContainer.default()
        // Container instances are seperate
        XCTAssertFalse(container1 === container2, "containers don't share memory")
        // but must point to same database with same scope
        XCTAssertTrue(container1.publicCloudDatabase === container2.publicCloudDatabase,
                      "CKDatabase instances of a particular scope DO share memory")
        XCTAssertTrue(container1.privateCloudDatabase === container2.privateCloudDatabase,
                      "CKDatabase instances of a particular scope DO share memory")
        XCTAssertTrue(container1.sharedCloudDatabase === container2.sharedCloudDatabase,
                      "CKDatabase instances of a particular scope DO share memory")
        // but scopes in the same container instance are seperate
        XCTAssertFalse(container1.publicCloudDatabase === container2.privateCloudDatabase,
                      "CKDatabase scopes do not share memory")
        XCTAssertFalse(container1.publicCloudDatabase === container2.sharedCloudDatabase,
                      "CKDatabase scopes do not share memory")
        // make sure that records are seen in their respective scope regardless of CKContainer instance
        let record: CKRecord = makeCKRecord(name: "myRecord", type: "myType")
        // add record to public CKDatabase for one instance
        container1.publicCloudDatabase.addRecords(records: [record])
        // CKContainer instances must point to same database for a given scope, but scopes are distinct MockCKDatabase
        // instances within container.
        XCTAssertTrue(container1.publicCloudDatabase.getRecords()?.count == 1)
        XCTAssertTrue(container1.privateCloudDatabase.getRecords()?.count == 0)
        XCTAssertTrue(container1.sharedCloudDatabase.getRecords()?.count == 0)
        XCTAssertTrue(container2.publicCloudDatabase.getRecords()?.count == 1)
        XCTAssertTrue(container2.privateCloudDatabase.getRecords()?.count == 0)
        XCTAssertTrue(container2.sharedCloudDatabase.getRecords()?.count == 0)
    }

    // test setting a database of some scope
    func test_container_set_database() {
        let container1 = MockCKContainer.default()
        let record: CKRecord = makeCKRecord(name: "myRecord", type: "myType")
        // add record to public CKDatabase for one instance
        container1.publicCloudDatabase.addRecords(records: [record])
        // Each CKContainer instance has three distinct CKDatabase objects
        XCTAssertTrue(container1.publicCloudDatabase.getRecords()?.count == 1)
        // create new public CKDatabase
        let pdb = MockCKDatabase.init(with: .public)
        XCTAssertTrue(pdb.getRecords()?.count == 0)
        container1.publicCloudDatabase = pdb
        XCTAssertTrue(container1.publicCloudDatabase.getRecords()?.count == 0)
    }

    // =============================================================================================
    // CKContainer instance method tests:
    //  func accountStatus(completionHandler: @escaping (CKAccountStatus, Error?) -> Void)
    //  func fetchUserRecordID(completionHandler: @escaping (CKRecord.ID?, Error?) -> Void)
    // =============================================================================================

    // CKContainer accountStatus tests
    // ----------------------------------
    // test that we get the expected CKAccountStatus.couldNotDetermine if no AccountStatus is set.
    func test_accountStatus_unset() {
        let expect = expectation(description: "CKAccountStatus")
        Self.mockCloudContainer.accountStatus { status, error  in
            XCTAssertEqual(status.rawValue, CKAccountStatus.couldNotDetermine.rawValue)
            XCTAssertNotNil(error)
            let nserror = error as NSError?
            XCTAssertEqual(nserror?.code, CKAccountStatus.couldNotDetermine.rawValue)
            expect.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // test that we get the expected CKAccountStatus code for what we set.
    func test_accountStatus_set() {
        for (status, message) in ckAccountStatusMessageMappings {
            let expect = expectation(description: "CKAccountStatus message")
            Self.mockCloudContainer.setAccountStatus = status
            Self.mockCloudContainer.accountStatus { status, error  in
                if status == .available {
                    XCTAssertNil(error)
                    XCTAssertEqual(self.ckAccountStatusMessageMappings[status],
                                   CKAccountStatusMessage.available.rawValue)
                } else {
                    XCTAssertNotNil(error)
                    let nserror = error as NSError?
                    XCTAssertEqual(nserror?.domain, "CKAccountStatus")
                    // Where AccountStatus "error" codes are:
                    //  .couldNotDetermine // 0
                    //  .restricted // 2
                    //  .noAccount // 3
                    //  .temporarilyUnavailable // 4
                    XCTAssertTrue([0, 2, 3, 4].contains(nserror?.code) )
                    XCTAssertEqual(self.ckAccountStatusMessageMappings[status], message)
                }
                expect.fulfill()
            }
            waitForExpectations(timeout: 1)
        }
    }

    // CKContainer fetchUserRecordID tests
    // -----------------------------------

    // test fetchUserRecordID() with no user record set (simulates no account or failure to retrieve account info).
    // Expect CKError.notAuthenticated (per Apple docs, no record exists).
    func test_fetchUserRecordID_no_record() {
        let expect = expectation(description: "No user record")
        Self.mockCloudContainer.fetchUserRecordID { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            XCTAssertTrue(error!.localizedDescription.contains(" operation couldn’t be completed"))
            let nserror = error as NSError?
            XCTAssertEqual(nserror!.domain, "CKErrorDomain")
            XCTAssertEqual(nserror!.code, CKError.notAuthenticated.rawValue)
            expect.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // test fetchUserRecordID() with record set and failure condition
    // Expect CKAccountStatus other than .available
    func test_fetchUserRecordID_fail_accountError() {
        let expect = expectation(description: "record set but expect fail")
        let record = makeCKRecord()
        Self.mockCloudContainer.setUserRecord = record
        Self.mockCloudContainer.setAccountStatus = CKAccountStatus.couldNotDetermine
        Self.mockCloudContainer.fetchUserRecordID { recordID, error in
            XCTAssertNil(recordID)
            XCTAssertNotNil(error)
            let nserror = error as NSError?
            XCTAssertEqual(nserror!.code, CKAccountStatus.couldNotDetermine.rawValue)
            expect.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // test fetchUserRecordID() with record set but no account status set
    func test_fetchUserRecordID_fail_no_account_status() {
        let expect = expectation(description: "record set")
        let record = makeCKRecord()
        Self.mockCloudContainer.setUserRecord = record
        Self.mockCloudContainer.fetchUserRecordID { recordID, error in
            XCTAssertNil(recordID)
            XCTAssertNotNil(error)
            let nserror = error as NSError?
            XCTAssertEqual(nserror!.code, CKAccountStatus.couldNotDetermine.rawValue)
            expect.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // test fetchUserRecordID() with record and account status available
    // Expect CKAccountStatus other than .available
    func test_fetchUserRecordID_success() {
        let expect = expectation(description: "record set but expect fail")
        let record = makeCKRecord()
        Self.mockCloudContainer.setUserRecord = record
        Self.mockCloudContainer.setAccountStatus = CKAccountStatus.available
        Self.mockCloudContainer.fetchUserRecordID { recordID, error in
            XCTAssertNotNil(recordID)
            XCTAssertEqual(record.recordID, recordID)
            XCTAssertNil(error)
            expect.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // ======================================================================================================
    // CKDatabase - we use MockDataBase (a backing store) for mocking CKDatabase. Following are the
    //  convenience methods to add, remove, and fetch records from MockCKDatabase.
    // ======================================================================================================

    // test addRecords(records: [CKRecord]): add records to MockCKDatabase
    func test_CKDatabase_addRecords() {
        if let records = Self.mockCKDatabase.getRecords() {
            XCTAssertTrue(records.isEmpty)
        } else {
            XCTFail()
        }
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        Self.mockCKDatabase.addRecords(records: records)
        if let fetched = Self.mockCKDatabase.getRecords() {
            XCTAssertEqual(fetched.count, 2)
        } else {
            XCTFail()
        }
    }
    // test getRecords() -> [CKRecord]? : get all records
    func test_CKDatabase_get_all_records() {
        XCTAssertTrue(Self.mockCKDatabase.getRecords()?.count == 0)
        var records: [CKRecord] = [CKRecord]()
        for _ in 1...100 {
            records.append(makeCKRecord())
        }
        Self.mockCKDatabase.addRecords(records: records)
        if let records = Self.mockCKDatabase.getRecords() {
            XCTAssertEqual(records.count, 100)
        } else {
            XCTFail()
        }
    }
    // test getRecords(with ids: [CKRecord.ID]) -> [CKRecord]? : get records matching CKRecord.ID
    func test_CKDatabase_get_records_with_id() {
        let recordName = "SomeRecordName"
        // three records, one that will match recordName
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        let recordID = CKRecord.ID(recordName: recordName)
        records.append(makeCKRecord(id: recordID))
        Self.mockCKDatabase.addRecords(records: records)
        if let records = Self.mockCKDatabase.getRecords(matching: [recordID]) {
            XCTAssertEqual(records.count, 1)
        } else {
            XCTFail()
        }
    }
    // test getRecords(matching: CKQuery) -> [CKRecord]? : get records matching given CKQuery
    func test_CKDatabase_get_records_matching_query() {
        // three records, one that will match query
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        records.append(CKRecord.init(recordType: "MATCH"))
        Self.mockCKDatabase.addRecords(records: records)

        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        if let records = Self.mockCKDatabase.getRecords(matching: query) {
            XCTAssertEqual(records.count, 1)
        } else {
            XCTFail()
        }
    }
    // test removeRecords(with ids: [CKRecord.ID]) : remove records matching CKRecord.ID
    func test_CKDatabase_remove_records() {
        // add the records and verify count
        var records: [CKRecord] = [CKRecord]()
        for _ in 1...100 {
            records.append(makeCKRecord())
        }
        Self.mockCKDatabase.addRecords(records: records)
        if let records = Self.mockCKDatabase.getRecords() {
            XCTAssertEqual(records.count, 100)
        } else {
            XCTFail()
        }
        // remove half and verify
        let recordIDs = records.map { $0.recordID }
        let halfRecordIds = Array(recordIDs.dropLast(50))
        Self.mockCKDatabase.removeRecords(with: halfRecordIds)
        if let records = Self.mockCKDatabase.getRecords() {
            XCTAssertEqual(records.count, 50)
        } else {
            XCTFail()
        }
        // try to remove the original set even though half are gone
        Self.mockCKDatabase.removeRecords(with: recordIDs)
        if let records = Self.mockCKDatabase.getRecords() {
            XCTAssertEqual(records.count, 0)
        } else {
            XCTFail()
        }
    }

    func test_resetStore() {
        // add records and verify count
        var records: [CKRecord] = [CKRecord]()
        for _ in 1...100 {
            records.append(makeCKRecord())
        }
        Self.mockCKDatabase.addRecords(records: records)
        if let records = Self.mockCKDatabase.getRecords() {
            XCTAssertEqual(records.count, 100)
        } else {
            XCTFail()
        }
        Self.mockCKDatabase.resetStore()
        if let records = Self.mockCKDatabase.getRecords() {
            XCTAssertEqual(records.count, 0)
        } else {
            XCTFail()
        }
    }

    // Test that public, private, and shared database scopes are distinct instances with independent data and operations.
    func test_distinct_databases() {
        let container = MockCKContainer.default()
        let publicDB = container.publicCloudDatabase
        let privateDB = container.privateCloudDatabase

        let records = createRecords(number: 5)
        let recordIDs = records.map { $0.recordID }
        publicDB.addRecords(records: records)
        XCTAssertEqual(publicDB.getRecords()?.count, 5, "public and private MockCKDatabase instances are distict")
        XCTAssertEqual(privateDB.getRecords()?.count, 0, "public and private MockCKDatabase instances are distict")

        privateDB.addRecords(records: records)
        XCTAssertEqual(publicDB.getRecords()?.count, 5, "public and private MockCKDatabase instances are distict")
        XCTAssertEqual(privateDB.getRecords()?.count, 5, "public and private MockCKDatabase instances are distict")

        publicDB.resetStore()
        XCTAssertEqual(publicDB.getRecords()?.count, 0, "public and private MockCKDatabase instances are distict")
        XCTAssertEqual(privateDB.getRecords()?.count, 5, "public and private MockCKDatabase instances are distict")

        publicDB.addRecords(records: records)
        XCTAssertEqual(publicDB.getRecords()?.count, 5, "public and private MockCKDatabase instances are distict")
        XCTAssertEqual(privateDB.getRecords()?.count, 5, "public and private MockCKDatabase instances are distict")

        let expect = expectation(description: "MockCKModifyRecordsOperation on publicDB")
        let fetchOp = MockCKModifyRecordsOperation.init(recordsToSave: nil, recordIDsToDelete: recordIDs)
        fetchOp.completionBlock = {
            XCTAssertEqual(publicDB.getRecords()?.count, 0, "public and private MockCKDatabase instances are distict")
            XCTAssertEqual(privateDB.getRecords()?.count, 5, "public and private MockCKDatabase instances are distict")
            expect.fulfill()
        }
        publicDB.add(fetchOp)
        waitForExpectations(timeout: 1)
    }


    // Substitute CKModifyRecordsOperation
    // ------------------------------------
    func test_save() {
        let expect = expectation(description: "CKDataBase save")
        let operationName = "save"
        let record = makeCKRecord()
        Self.mockCKDatabase.save(record) { record, error in
            XCTAssertNil(record)
            if let opErr = error as? OperationError {
                XCTAssertNotNil(opErr)
                XCTAssertEqual(opErr.errorDescription!, "Operation \'\(operationName)\' is not implemented.")
                XCTAssertEqual(opErr.failureReason!, "\(operationName) is not implemented.")
                XCTAssertTrue(opErr.recoverySuggestion!.contains("CKModifyRecordsOperation"))
                expect.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }
    func test_delete() {
        let expect = expectation(description: "CKDataBase delete")
        let operationName = "delete(withRecordID:)"
        let record = makeCKRecord()
        Self.mockCKDatabase.delete(withRecordID: record.recordID) { record, error in
            XCTAssertNil(record)
            if let opErr = error as? OperationError {
                XCTAssertNotNil(opErr)
                XCTAssertEqual(opErr.errorDescription!, "Operation \'\(operationName)\' is not implemented.")
                XCTAssertEqual(opErr.failureReason!, "\(operationName) is not implemented.")
                XCTAssertTrue(opErr.recoverySuggestion!.contains("CKModifyRecordsOperation"))
                expect.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }
    // Substitute CKFetchRecordsOperation
    // ------------------------------------
    func test_fetch_withRecordID() {
        let expect = expectation(description: "CKDataBase fetch")
        let operationName = "fetch(withRecordID:)"
        let record = makeCKRecord()
        // note that nil is returned
        Self.mockCKDatabase.fetch(withRecordID: record.recordID) { record, error in
            XCTAssertNil(record)
            if let opErr = error as? OperationError {
                XCTAssertNotNil(opErr)
                XCTAssertEqual(opErr.errorDescription!, "Operation \'\(operationName)\' is not implemented.")
                XCTAssertEqual(opErr.failureReason!, "\(operationName) is not implemented.")
                XCTAssertTrue(opErr.recoverySuggestion!.contains("CKFetchRecordsOperation"))
                expect.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }
    func test_fetch_withRecordIDs() {
        let expect = expectation(description: "CKDataBase fetch")
        let operationName = "fetch(withRecordIDs:)"
        let record = makeCKRecord()
        Self.mockCKDatabase.fetch(withRecordIDs: [record.recordID]) { result in
            switch result {
            case .success(let result):
                // should not get here
                XCTAssertNil(result)
            case .failure(let error):
                if let opErr = error as? OperationError {
                    XCTAssertNotNil(opErr)
                    XCTAssertEqual(opErr.errorDescription!, "Operation \'\(operationName)\' is not implemented.")
                    XCTAssertEqual(opErr.failureReason!, "\(operationName) is not implemented.")
                    XCTAssertTrue(opErr.recoverySuggestion!.contains("CKFetchRecordsOperation"))
                    expect.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 1)
    }

    // Substitute CKQueryOperation
    // ------------------------------------
    func test_perform_withQuery() {
        let expect = expectation(description: "CKDataBase perform")
        let operationName = "perform(_:CKQuery:inZoneWith)"
        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let zone = CKRecordZone.default()
        Self.mockCKDatabase.perform(query, inZoneWith: zone.zoneID) { record, error in
            XCTAssertNil(record)
            if let opErr = error as? OperationError {
                XCTAssertNotNil(opErr)
                XCTAssertEqual(opErr.errorDescription!, "Operation \'\(operationName)\' is not implemented.")
                XCTAssertEqual(opErr.failureReason!, "\(operationName) is not implemented.")
                XCTAssertTrue(opErr.recoverySuggestion!.contains("CKQueryOperation"))
                expect.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }

    func test_fetch_withQuery() {
        let expect = expectation(description: "CKDataBase fetch")
        let operationName = "fetch(withQuery:inZoneWith:desiredKeys:resultsLimit)"
        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let zone = CKRecordZone.default()
        Self.mockCKDatabase.fetch(withQuery: query,
                                  inZoneWith: zone.zoneID,
                                  desiredKeys: [],
                                  resultsLimit: 5 ) { result in
            XCTAssertNotNil(result)
            switch result {
            case .success(let result):
                // should not get here
                XCTAssertNil(result)
            case .failure(let error):
                if let opErr = error as? OperationError {
                    XCTAssertNotNil(opErr)
                    XCTAssertEqual(opErr.errorDescription!, "Operation \'\(operationName)\' is not implemented.")
                    XCTAssertEqual(opErr.failureReason!, "\(operationName) is not implemented.")
                    XCTAssertTrue(opErr.recoverySuggestion!.contains("CKQueryOperation"))
                    expect.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 1)
    }

    // =====================================================================================================
    // CKDatabaseOperation
    // ======================================================================================================
    // ----------------------------------------------------------------------------------------------------
    // Test using a custom completion block: called once as the last operation, even if other completion
    // handlers are registered.
    // ----------------------------------------------------------------------------------------------------
    func test_CKDataBase_add_custom_operation_CKModifyRecordsOperation() {
        let expect = expectation(description: "CKDataBase add CKModifyRecordsOperation")
        let modifyOp = MockCKModifyRecordsOperation()
        modifyOp.completionBlock = {
            expect.fulfill()
        }
        Self.mockCKDatabase.add(modifyOp)
        waitForExpectations(timeout: 1)
    }

    func test_CKDataBase_add_custom_operation_CKFetchRecordsOperation() {
        let expect = expectation(description: "CKDataBase add CKFetchRecordsOperation")
        let fetchOp = MockCKFetchRecordsOperation()
        fetchOp.completionBlock = {
            expect.fulfill()
        }
        Self.mockCKDatabase.add(fetchOp)
        waitForExpectations(timeout: 1)
    }

    func test_CKDataBase_add_custom_operation_CKQueryOperation() {
        let expect = expectation(description: "CKDataBase add CKQueryOperation")
        let queryOp = MockCKQueryOperation()
        queryOp.completionBlock = {
            expect.fulfill()
        }
        Self.mockCKDatabase.add(queryOp)
        waitForExpectations(timeout: 1)
    }

    // add a generic CKDatabaseOperation operation with no support
    func test_CKDataBase_add_custom_operation_NOOP() {
        let expect = expectation(description: "CKDataBase add NOOP")
        // invert so that expectation is to fail
        expect.isInverted = true
        let noOp = MockCKDatabaseOperation()
        noOp.completionBlock = {
            expect.fulfill()
        }
        Self.mockCKDatabase.add(noOp)
        waitForExpectations(timeout: 1)
    }

    // test that the custom completion block is always called last
    func test_CKDataBase_add_custom_operation_last_called() {
        let expect = expectation(description: "custom completion block")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        let recordIDs = records.map { $0.recordID }
        // there are 5 operations, make sure that the custom completion block is the last called.
        var perRecordSaveBlockCalled = false
        var perRecordDeleteBlockCalled = false
        var perRecordProgressBlockCalled = false // actually called twice: once for save and once for delete
        var modifyRecordsResultBlockCalled = false
        let modifyOp = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: recordIDs)
        modifyOp.perRecordSaveBlock = { _, _ in
            perRecordSaveBlockCalled = true
        }
        // This should be the last operation called
        modifyOp.completionBlock = {
            if perRecordSaveBlockCalled && perRecordDeleteBlockCalled && perRecordProgressBlockCalled && modifyRecordsResultBlockCalled {
                expect.fulfill()
            }
        }
        modifyOp.perRecordDeleteBlock = { _, _ in
            perRecordDeleteBlockCalled = true
        }
        modifyOp.perRecordProgressBlock = { _, _ in
            perRecordProgressBlockCalled = true
        }
        modifyOp.modifyRecordsResultBlock = { _ in
            modifyRecordsResultBlockCalled = true
        }
        Self.mockCKDatabase.add(modifyOp)
        waitForExpectations(timeout: 1)
    }

    // test that each MockCKDatabaseOperation has fully initialized references to their respective database and container.
    enum DBScope: Int {
        case `public` = 1
        case `private` = 2
        case `shared` = 3
    }
    func getScopeString(_ scope: Int?) -> String {
        let scope = DBScope(rawValue: scope ?? 0)
        switch scope {
        case .public:
            return "public"
        case .private:
            return "private"
        case .shared:
            return "shared"
        case .none:
            return "ERROR"
        }
    }

    func test_distinct_database_references() {
        let container = MockCKContainer.`init`(identifier: "MyMockContainer")
        let publicDB = container.publicCloudDatabase
        let privateDB = container.privateCloudDatabase
        let sharedDB = container.sharedCloudDatabase

        let mockOp: MockCKDatabaseOperation = MockCKDatabaseOperation()
        XCTAssertEqual(getScopeString(mockOp.database?.databaseScope.rawValue),
                       "ERROR",
                       "database is not assigned to operation until call to MockCKDatabase.add()")

        publicDB.add(mockOp)
        XCTAssertEqual(getScopeString(mockOp.database?.databaseScope.rawValue), "public")
        privateDB.add(mockOp)
        XCTAssertEqual(getScopeString(mockOp.database?.databaseScope.rawValue), "private")
        sharedDB.add(mockOp)
        XCTAssertEqual(getScopeString(mockOp.database?.databaseScope.rawValue), "shared")
    }

    // ----------------------------------------------------------------------------------------------------
    // Test CKModifyRecordsOperation:
    //  Success and failure conditions tested for each of the callback blocks:
    //      modifyRecordsResultBlock: The closure to execute after CloudKit modifies all of the records.
    //      perRecordResultBlock: The closure to execute with progress information for individual records.
    //      perRecordProgressBlock: The closure to execute when a record becomes available.
    // ----------------------------------------------------------------------------------------------------

    // test modifyRecordsResultBlock callback with success setup
    func test_CKModifyRecordsOperation_modifyRecordsResultBlock_success() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                expect.fulfill()
            case .failure(let error):
                XCTAssertNil(error) // shouldn't be reached
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test modifyRecordsResultBlock callback with failure setup
    func test_CKModifyRecordsOperation_modifyRecordsResultBlock_failure() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        // choose random CKAccountStatus other than .available
        let randomStatus = [0, 2, 3, 4].randomElement()!
        let errorStatus = ckAccountStatusMappings[randomStatus]!
        operation.setError = createNSError(code: errorStatus)
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTAssertFalse(true, "this should not be reachable")
            case .failure(let error):
                XCTAssertNotNil(error)
                let nserror = error as NSError?
                XCTAssertEqual(nserror!.code, errorStatus.rawValue)
                expect.fulfill()
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordSaveBlock callback with success setup
    func test_CKModifyRecordsOperation_perRecordSaveBlock_success() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.perRecordSaveBlock = { _, _ in
            resultCount += 1
            if resultCount == 2 {
                expect.fulfill()
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordSaveBlock callback with failure setup
    func test_CKModifyRecordsOperation_perRecordSaveBlock_failure() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        operation.perRecordSaveBlock = { _, result in
            switch result {
            case .success:
                resultCount += 1
            case .failure:
                XCTFail("records should not fail")
            }
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("transaction should fail")
            case .failure:
                if resultCount == records.count {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordDeleteBlock callback with success setup
    func test_CKModifyRecordsOperation_perRecordDeleteBlock_success() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        Self.mockCKDatabase.addRecords(records: records)
        let recordIDs = records.map { $0.recordID }
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.perRecordDeleteBlock = { _, _ in
            resultCount += 1
            if resultCount == records.count {
                expect.fulfill()
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordDeleteBlock callback with failure setup
    func test_CKModifyRecordsOperation_perRecordDeleteBlock_failure() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        Self.mockCKDatabase.addRecords(records: records)
        var resultCount = 0
        let recordIDs = records.map { $0.recordID }
        let operation = MockCKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        operation.perRecordDeleteBlock = { _, result in
            switch result {
            case .success:
                resultCount += 1
            case .failure:
                XCTFail("records should not fail")
            }
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("transaction should fail")
            case .failure:
                if resultCount == records.count {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test that perRecordProgressBlock only gets called with CKModifyRecordsOperation recordsToSave
    // and not with recordIDsToDelete.
    func test_CKModifyRecordsOperation_perRecordProgressBlock_not_called_with_recordIDsToDelete() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        Self.mockCKDatabase.addRecords(records: records)
        let recordIDs = records.map { $0.recordID }
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.perRecordProgressBlock = { _, progress in
            // this block should not be called
            resultCount += 1
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                if resultCount == 0 {
                    expect.fulfill()
                }
            case .failure:
                XCTFail("transaction should succeed")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordProgressBlock callback with success setup
    func test_CKModifyRecordsOperation_perRecordProgressBlock_success() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.perRecordProgressBlock = { _, progress in
            resultCount += 1
            XCTAssertEqual(progress, 1.0)
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                if resultCount == records.count {
                    expect.fulfill()
                }
            case .failure:
                XCTFail("transaction should succeed")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordProgressBlock callback with transaction failure setup (records succeed)
    func test_CKModifyRecordsOperation_perRecordProgressBlock_failure() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        operation.perRecordProgressBlock = { record, progress in
            XCTAssertEqual(progress, 1.0)
            resultCount += 1
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("transaction should fail")
            case .failure(let error):
                let nserror = error as NSError?
                XCTAssertEqual(nserror?.code, errorCode.rawValue)
                if resultCount == records.count {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordProgressBlock callback with no transaction error set (records errors set) for recordsToSave
    func test_CKModifyRecordsOperation_perRecordProgressBlock_transaction_no_error_records_error() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        let recordIds = records.map { return $0.recordID }
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.setRecordErrors = recordIds
        operation.perRecordProgressBlock = { record, progress in
            XCTAssertLessThan(progress, 1.0, "progress should be incomplete with record errors set")
        }
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                XCTFail("should not be called")
            case .failure:
                resultCount += 1
            }
        }
        operation.perRecordDeleteBlock = { recordID, result in
            XCTFail("should not be called")
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("transaction should fail")
            case .failure(let error):
                let nserror = error as NSError?
                XCTAssertEqual(nserror?.code,
                               CKError.partialFailure.rawValue,
                               "The transaction error should always be set to CKError.partialFailure when record errors occur")
                if let partialErrors = nserror?.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
                    XCTAssertEqual(records.count, partialErrors.count)
                    for (_, error) in partialErrors {
                        let nserror = error as! NSError?
                        XCTAssertEqual(nserror?.domain, CKError.errorDomain)
                    }
                } else {
                    XCTFail("Expected record errors")
                }
                if resultCount == records.count {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordProgressBlock callback with transaction error set and records errors set for recordsToSave
    func test_CKModifyRecordsOperation_perRecordProgressBlock_transaction_error_records_error() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        let recordIds = records.map { return $0.recordID }
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        operation.setRecordErrors = recordIds
        operation.perRecordProgressBlock = { record, progress in
            XCTAssertLessThan(progress, 1.0, "progress should be incomplete with record errors set")
        }
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                XCTFail("should not be called")
            case .failure:
                resultCount += 1
            }
        }
        operation.perRecordDeleteBlock = { recordID, result in
            XCTFail("should not be called")
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("transaction should fail")
            case .failure(let error):
                let nserror = error as NSError?
                // Note: the setError is overridden with CKError.partialFailure, as expected.
                XCTAssertEqual(nserror?.code,
                               CKError.partialFailure.rawValue,
                               "The transaction error should always be set to CKError.partialFailure when record errors occur")
                if let partialErrors = nserror?.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
                    XCTAssertEqual(records.count, partialErrors.count)
                    for (_, error) in partialErrors {
                        let nserror = error as? NSError
                        XCTAssertEqual(nserror?.domain, CKError.errorDomain)
                        XCTAssertNotEqual(nserror?.code, CKError.partialFailure.rawValue)
                    }
                } else {
                    XCTFail("Expected record errors")
                }

                if resultCount == records.count {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test perRecordProgressBlock callback with records errors set (transaction error unset) for recordIDsToDelete
    func test_CKModifyRecordsOperation_modifyRecordsResultBlock_records_errors_recordIDsToDelete() {
        let expect = expectation(description: "CKModifyRecordsOperation")
        var records: [CKRecord] = [CKRecord]()
        records.append(makeCKRecord())
        records.append(makeCKRecord())
        let recordIds = records.map { return $0.recordID }
        Self.mockCKDatabase.addRecords(records: records)
        var resultCount = 0
        let operation = MockCKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIds)
        operation.setRecordErrors = recordIds
        operation.perRecordProgressBlock = { record, progress in
            XCTAssertLessThan(progress, 1.0, "progress should be incomplete with record errors set")
        }
        operation.perRecordSaveBlock = { recordID, result in
            XCTFail("should not be called")
        }
        operation.perRecordDeleteBlock = { recordID, result in
            switch result {
            case .success:
                XCTFail("should not be called")
            case .failure:
                resultCount += 1
            }
        }
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("transaction should fail")
            case .failure(let error):
                let ckError = error.createCKError()
                // Note: the setError is overridden with CKError.partialFailure, as expected.
                XCTAssertEqual(ckError.code.rawValue,
                               CKError.partialFailure.rawValue,
                               "The transaction error should always be set to CKError.partialFailure when record errors occur")
                if let partialErrors: NSDictionary = ckError.getPartialErrors() {
                    XCTAssertEqual(records.count, partialErrors.count)
                    for rec in partialErrors {
                        let (id, error) = (rec.key as! String, rec.value as! NSError)
                        let recID = CKRecord.ID.init(recordName: id)
                        XCTAssertTrue(recordIds.contains(recID))
                        XCTAssertNotEqual(error.code,
                                          CKError.partialFailure.rawValue,
                                          "individual records should not have CKError.partialFailure type")
                        XCTAssertEqual(error.domain, CKError.errorDomain)
                    }
                } else {
                    XCTFail("Expected record errors")
                }

                if resultCount == records.count {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // --------------------------------------------
    // Test CKFetchRecordsOperation
    // --------------------------------------------

    // test that the CKFetchRecordsOperation holds the records to be inserted (but that operation does not insert into database)
    func test_CKFetchRecordsOperation_fetchRecordsResultBlock_success() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let records = createRecords(number: 5)
        let recordIds = records.map { $0.recordID }
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success:
                // even if not added to database, operation still holds recordIDs to fetch
                XCTAssertEqual(operation.recordIDs?.count, 5, "records were set on operation")
                XCTAssertTrue(Self.mockCKDatabase.getRecords()?.count == 0, "but they were not added to database")
                expect.fulfill()
            case .failure(let error):
                XCTAssertFalse(true, "operation expected to succeed")
                print(">>> fetchRecordsResultBlock error: \(error.localizedDescription)")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    func test_CKFetchRecordsOperation_fetchRecordsResultBlock_desiredKeys_success() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        // add records first
        var records = [CKRecord]()
        let record1 = CKRecord.init(recordType: "SomeRecordType")
        record1["this"] = "that"
        record1["one"] = "uno"
        record1["two"] = "dos"
        records.append(record1)
        let record2 = CKRecord.init(recordType: "SomeRecordType")
        record2["this"] = "that"
        record2["one"] = "uno"
        record2["two"] = "dos"
        records.append(record2)
        Self.mockCKDatabase.addRecords(records: records)
        let recordIds = records.map { $0.recordID }
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        operation.desiredKeys = ["one", "two"]
        // check that records have the expected keys
        operation.perRecordResultBlock = { recordID, result in
            switch result {
            case .success(let record):
                XCTAssertEqual(record.allKeys().count, 2)
                XCTAssertTrue(record.allKeys().contains("one"))
                XCTAssertTrue(record.value(forKey: "one") as? String == "uno")
                XCTAssertTrue(record.allKeys().contains("two"))
                XCTAssertTrue(record.value(forKey: "two") as? String == "dos")
            case .failure(let error):
                XCTFail("operation expected to succeed: \(error.localizedDescription)")
            }
        }
        operation.fetchRecordsResultBlock = { result in
            expect.fulfill()
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    func test_CKFetchRecordsOperation_fetchRecordsResultBlock_failure() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let recordIds = createRecords(number: 5).map { $0.recordID }
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTAssertFalse(true, "operation expected to fail")
            case .failure(let error):
                expect.fulfill()
                XCTAssertNotNil(error)
                let nserror = error as NSError?
                XCTAssertEqual(nserror!.code, errorCode.rawValue)
                XCTAssertEqual(operation.recordIDs?.count, 5, "records were set on operation")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test fetchRecordsResultBlock callback with records errors set (transaction error unset) for partialErrors
    func test_CKFetchRecordsOperation_fetchRecordsResultBlock_records_partial_errors() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let records = createRecords(number: 5)
        let recordIds = records.map { return $0.recordID }
        Self.mockCKDatabase.addRecords(records: records)
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        operation.setRecordErrors = recordIds
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("result should fail")
            case .failure(let error):
                let ckErr = error.createCKError()
                XCTAssertEqual(ckErr.code, CKError.partialFailure, "transaction error should be set to CKError.partialFailure")
                if let partialErrs: NSDictionary = ckErr.getPartialErrors() {
                    XCTAssertEqual(partialErrs.count, records.count)
                    for rec in partialErrs {
                        let (id, error) = (rec.key as! String, rec.value as! NSError)
                        let recID = CKRecord.ID.init(recordName: id)
                        XCTAssertTrue(recordIds.contains(recID))
                        XCTAssertNotEqual(error.code,
                                          CKError.partialFailure.rawValue,
                                          "individual records should not have CKError.partialFailure type")
                    }
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test fetchRecordsResultBlock callback with records errors and transaction error set for partialErrors
    func test_CKFetchRecordsOperation_fetchRecordsResultBlock_records_partial_errors_with_transaction_error() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let records = createRecords(number: 5)
        let recordIds = records.map { return $0.recordID }
        Self.mockCKDatabase.addRecords(records: records)
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        operation.setRecordErrors = recordIds
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("result should fail")
            case .failure(let error):
                let ckErr = error.createCKError()
                // Note: the setError is overridden with CKError.partialFailure, as expected.
                XCTAssertEqual(ckErr.code.rawValue,
                               CKError.partialFailure.rawValue,
                               "The transaction error should always be set to CKError.partialFailure when record errors occur")
                if let partialErrs: NSDictionary = ckErr.getPartialErrors() {
                    XCTAssertEqual(partialErrs.count, records.count)
                    for rec in partialErrs {
                        let (id, error) = (rec.key as! String, rec.value as! NSError)
                        let recID = CKRecord.ID.init(recordName: id)
                        XCTAssertTrue(recordIds.contains(recID))
                        XCTAssertNotEqual(error.code,
                                          CKError.partialFailure.rawValue,
                                          "individual records should not have CKError.partialFailure type")
                    }
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    func test_CKFetchRecordsOperation_perRecordResultBlock_success() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let records = createRecords(number: 5)
        let recordIds = records.map { $0.recordID }
        Self.mockCKDatabase.addRecords(records: records)
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        var receivedCnt = 0
        operation.perRecordResultBlock = {  id, record in
            XCTAssertTrue(recordIds.contains(id))
            switch record {
            case .success:
                receivedCnt += 1
                if receivedCnt == recordIds.count - 1 {
                    expect.fulfill()
                }
            case .failure:
                XCTFail("operation expected to succeed")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test that CKFetchRecordsOperation returns a transaction error but records have no errors set
    func test_CKFetchRecordsOperation_perRecordResultBlock_failure() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let records = createRecords(number: 5)
        let recordIds = records.map { $0.recordID }
        Self.mockCKDatabase.addRecords(records: records)
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        var receivedCnt = 0
        // records should all succeed
        operation.perRecordResultBlock = {  id, record in
            XCTAssertTrue(recordIds.contains(id))
            switch record {
            case .success:
                receivedCnt += 1
            case .failure:
                XCTFail("operation expected to succeed")
            }
        }
        // but the overall transaction fails
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success:
                XCTFail("operation expected to fail")
            case .failure(let error):
                XCTAssertNotNil(error)
                let nserror = error as NSError?
                XCTAssertEqual(nserror!.code, errorCode.rawValue)
                if receivedCnt == records.count {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    func test_CKFetchRecordsOperation_perRecordProgressBlock_success() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let records = createRecords(number: 5)
        let recordIds = records.map { $0.recordID }
        Self.mockCKDatabase.addRecords(records: records)
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        var receivedCnt = 0
        operation.perRecordProgressBlock = {  recordId, _ in
            XCTAssertTrue(recordIds.contains(recordId))
            receivedCnt += 1
            if receivedCnt == recordIds.count - 1 {
                expect.fulfill()
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    func test_CKFetchRecordsOperation_perRecordProgressBlock_failure() {
        let expect = expectation(description: "CKFetchRecordsOperation")
        let records = createRecords(number: 5)
        let recordIds = records.map { $0.recordID }
        Self.mockCKDatabase.addRecords(records: records)
        let operation = MockCKFetchRecordsOperation(recordIDs: recordIds)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        var receivedCnt = 0
        operation.perRecordProgressBlock = {  recordId, _ in
            XCTAssertTrue(recordIds.contains(recordId))
            receivedCnt += 1
            if receivedCnt == recordIds.count - 1 {
                expect.fulfill()
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // --------------------------------------------
    // Test CKQueryOperation
    // --------------------------------------------
    // test that we get expected number of results for predicate
    func test_CKQueryOperation_queryResultBlock_success() {
        var matchedRecordCount = 0
        // add records first (expecting 2 matches out of 5)
        var records = createRecords(number: 3) // non-matching
        let record1 = CKRecord.init(recordType: "MATCH")
        record1["this"] = "that"
        record1["one"] = "uno"
        record1["two"] = "dos"
        records.append(record1)
        let record2 = CKRecord.init(recordType: "MATCH")
        record2["this"] = "that"
        record2["one"] = "uno"
        record2["two"] = "dos"
        records.append(record2)
        Self.mockCKDatabase.addRecords(records: records)

        // then perform CKQueryOperation
        let expect = expectation(description: "CKQueryOperation")
        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let operation = MockCKQueryOperation(query: query)

        // for each matching result
        operation.recordMatchedBlock = { _, _ in
            matchedRecordCount += 1
        }
        // we are finished fetching records
        operation.queryResultBlock = { result in
            switch result {
            case .success(let cursor):
                XCTAssertNil(cursor)
                XCTAssertEqual(matchedRecordCount, 2)
                expect.fulfill()
            case .failure:
                XCTAssertFalse(true, "operation expected to succeed")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test that we get the expected results with limit applied
    func test_CKQueryOperation_queryResultBlock_success_limit() {
        var matchedRecordCount = 0
        // add records first (expecting 2 matches out of 5)
        var records = createRecords(number: 3) // non-matching
        let record1 = CKRecord.init(recordType: "MATCH")
        record1["this"] = "that"
        record1["one"] = "uno"
        record1["two"] = "dos"
        records.append(record1)
        let record2 = CKRecord.init(recordType: "MATCH")
        record2["this"] = "that"
        record2["one"] = "uno"
        record2["two"] = "dos"
        records.append(record2)
        Self.mockCKDatabase.addRecords(records: records)

        // then perform CKQueryOperation
        let expect = expectation(description: "CKQueryOperation")
        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let operation = MockCKQueryOperation(query: query)
        // we apply a limit so that we get one result (though two matched)
        //operation.setResultsLimit = 1
        operation.resultsLimit = 1

        // for each matching result
        operation.recordMatchedBlock = { _, _ in
            matchedRecordCount += 1
        }
        // we are finished fetching records
        operation.queryResultBlock = { result in
            switch result {
            case .success(let cursor):
                XCTAssertNil(cursor)
                XCTAssertEqual(matchedRecordCount, 1)
                expect.fulfill()
            case .failure:
                XCTAssertFalse(true, "operation expected to succeed")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // test that we get the expected results with only the desired keys
    func test_CKQueryOperation_queryResultBlock_success_desired_keys() {
        var matchedRecordCount = 0
        // add records first (expecting 2 matches out of 5)
        var records = createRecords(number: 3) // non-matching
        let record1 = CKRecord.init(recordType: "MATCH")
        record1["this"] = "that"
        record1["one"] = "uno"
        record1["two"] = "dos"
        records.append(record1)
        let record2 = CKRecord.init(recordType: "MATCH")
        record2["this"] = "that"
        record2["one"] = "uno"
        record2["two"] = "dos"
        records.append(record2)
        Self.mockCKDatabase.addRecords(records: records)

        // then perform CKQueryOperation
        let expect = expectation(description: "CKQueryOperation")
        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let operation = MockCKQueryOperation(query: query)
        operation.desiredKeys = ["one", "two"]

        // for each matching result
        operation.recordMatchedBlock = { _, record in
            if let record = try? record.get() {
                XCTAssertEqual(record.allKeys().count, 2)
                XCTAssertTrue(record.allKeys().contains("one"))
                XCTAssertTrue(record.value(forKey: "one") as? String == "uno")
                XCTAssertTrue(record.allKeys().contains("two"))
                XCTAssertTrue(record.value(forKey: "two") as? String == "dos")
            }
            matchedRecordCount += 1
        }
        // we are finished fetching records
        operation.queryResultBlock = { result in
            switch result {
            case .success(let cursor):
                XCTAssertNil(cursor)
                XCTAssertEqual(matchedRecordCount, 2)
                expect.fulfill()
            case .failure:
                XCTAssertFalse(true, "operation expected to succeed")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // called once upon completion of query
    func test_CKQueryOperation_queryResultBlock_failure() {
        let expect = expectation(description: "CKQueryOperation")
        let recordID = CKRecord.ID(recordName: "some record")
        let reference = CKRecord.Reference(recordID: recordID, action: .none)
        let pred = NSPredicate(format: "project == %@", reference)
        let sort = NSSortDescriptor(key: "title", ascending: true)
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        query.sortDescriptors = [sort]
        let operation = MockCKQueryOperation(query: query)
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        operation.desiredKeys = ["title", "detail", "completed"]
        operation.resultsLimit = 50
        // we are finished fetching records
        operation.queryResultBlock = { result in
            switch result {
            case .success:
                XCTAssertFalse(true, "operation expected to fail")
            case .failure(let error):
                XCTAssertNotNil(error)
                let nserror = error as NSError?
                XCTAssertEqual(nserror!.code, errorCode.rawValue)
                expect.fulfill()
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // called for each query result
    func test_CKQueryOperation_recordMatchedBlock_success() {
        var matchedRecordCount = 0
        // add records first (expecting 2 matches out of 5)
        var records = createRecords(number: 3) // non-matching
        let record1 = CKRecord.init(recordType: "MATCH")
        record1["this"] = "that"
        record1["one"] = "uno"
        record1["two"] = "dos"
        records.append(record1)
        let record2 = CKRecord.init(recordType: "MATCH")
        record2["this"] = "that"
        record2["one"] = "uno"
        record2["two"] = "dos"
        records.append(record2)
        Self.mockCKDatabase.addRecords(records: records)

        // then perform CKQueryOperation
        let expect = expectation(description: "CKQueryOperation")
        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let operation = MockCKQueryOperation(query: query)

        // each result that matched the query
        operation.recordMatchedBlock = { recordId, result in
            switch result {
            case .success:
                XCTAssertNotNil(recordId)
                matchedRecordCount += 1
                if matchedRecordCount == 2 {
                    expect.fulfill()
                }
            case .failure:
                XCTAssertFalse(true, "operation expected to succeed")
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }

    // called for each query result
    func test_CKQueryOperation_recordMatchedBlock_failure() {
        var matchedRecordCount = 0
        // add records first (expecting 2 matches out of 5)
        var records = createRecords(number: 3) // non-matching
        let record1 = CKRecord.init(recordType: "MATCH")
        record1["this"] = "that"
        record1["one"] = "uno"
        record1["two"] = "dos"
        records.append(record1)
        let record2 = CKRecord.init(recordType: "MATCH")
        record2["this"] = "that"
        record2["one"] = "uno"
        record2["two"] = "dos"
        records.append(record2)
        Self.mockCKDatabase.addRecords(records: records)

        // then perform CKQueryOperation
        let expect = expectation(description: "CKQueryOperation")
        let pred = NSPredicate(format: "recordType == %@", "MATCH")
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let operation = MockCKQueryOperation(query: query)
        // set error
        let errorCode: CKError.Code = ckErrorCodes[Int.random(in: 0..<ckErrorCodes.count-1)]
        operation.setError = createNSError(with: errorCode)
        // each result that matched the query
        operation.recordMatchedBlock = { recordId, result in
            switch result {
            case .success:
                XCTAssertFalse(true, "operation expected to fail")
            case .failure(let error):
                XCTAssertNotNil(recordId)
                XCTAssertNotNil(error)
                let nserror = error as NSError?
                XCTAssertEqual(nserror!.code, errorCode.rawValue)
                matchedRecordCount += 1
                if matchedRecordCount == 2 {
                    expect.fulfill()
                }
            }
        }
        Self.mockCKDatabase.add(operation)
        waitForExpectations(timeout: 1)
    }


    // -------------------------------------------------------------------------------
    // Test CKDatabaseOperation ==> MockCKDatabaseOperation conversions.
    //  these are provided for when a CKDatabaseOperation is added to MockCKDatabase.
    // -------------------------------------------------------------------------------

    // test that CKModifyRecordsOperation converts to MockCKModifyRecordsOperation
    func test_conversion_CKModifyRecordsOperation() {
        // make records to save
        var recsToSave = [CKRecord]()
        for index in 1...5 {
            recsToSave.append(makeCKRecord(name: "record-\(index)"))
        }
        let recIdsToDelete = recsToSave.map { $0.recordID }
        // create CKModifyRecordsOperation (it will have a CKDatabase attached to it - added implicitly by CloudKit) which
        // must be replaced with MockCKDatabase:
        let ckModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: recsToSave, recordIDsToDelete: recIdsToDelete)
        ckModifyRecordsOperation.modifyRecordsResultBlock = {x in print("hello")}
        ckModifyRecordsOperation.name = "some name"
        XCTAssertTrue(ckModifyRecordsOperation.database!.isKind(of: CKDatabase.self))
        XCTAssertEqual(ckModifyRecordsOperation.recordsToSave?.count, 5)
        XCTAssertEqual(ckModifyRecordsOperation.recordIDsToDelete?.count, 5)

        // Do the conversion to MockCKModifyRecordsOperation and check fields
        let mockDB: MockCKDatabase = MockCKDatabase()
        let mockOp: MockCKModifyRecordsOperation = ckModifyRecordsOperation.getMock(database: mockDB)
        XCTAssertTrue(type(of: mockOp) == MockCKModifyRecordsOperation.self, "operation is converted to MockCKModifyRecordsOperation")
        XCTAssertTrue(type(of: mockOp.database!) == MockCKDatabase.self, "new MockCKDatabaseOperation must contain reference to MockDabase")
        XCTAssertEqual(mockOp.recordsToSave?.count, 5)
        XCTAssertEqual(mockOp.recordIDsToDelete?.count, 5)
        XCTAssertTrue(mockOp.database! === mockDB) // === analyses type but not value
        XCTAssertEqual(mockOp.database?.databaseScope, mockDB.databaseScope)
        XCTAssertEqual(mockOp.database?.getRecords()?.count, mockDB.getRecords()?.count)
        XCTAssertEqual(mockOp.recordsToSave, ckModifyRecordsOperation.recordsToSave)
        XCTAssertEqual(mockOp.recordIDsToDelete, ckModifyRecordsOperation.recordIDsToDelete)
        XCTAssertEqual(mockOp.configuration, ckModifyRecordsOperation.configuration)
        XCTAssertEqual(mockOp.savePolicy, ckModifyRecordsOperation.savePolicy)
        XCTAssertEqual(mockOp.name, ckModifyRecordsOperation.name)
        XCTAssertEqual(mockOp.name, "some name")
        XCTAssertEqual(mockOp.qualityOfService, ckModifyRecordsOperation.qualityOfService)
        XCTAssertEqual(mockOp.queuePriority, ckModifyRecordsOperation.queuePriority)
        XCTAssertNotEqual(mockOp.description, ckModifyRecordsOperation.description, "Mock description differs by way of its class name")

        // check operations
        XCTAssertTrue(
            mockOp.modifyRecordsResultBlock.customMirror.subjectType
            == ckModifyRecordsOperation.modifyRecordsResultBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.perRecordSaveBlock.customMirror.subjectType
            == ckModifyRecordsOperation.perRecordSaveBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.perRecordDeleteBlock.customMirror.subjectType
            == ckModifyRecordsOperation.perRecordDeleteBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.perRecordProgressBlock.customMirror.subjectType
            == ckModifyRecordsOperation.perRecordProgressBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.completionBlock.customMirror.subjectType
            == ckModifyRecordsOperation.completionBlock.customMirror.subjectType
        )
    }

    // test that CKFetchRecordsOperation converts to MockCKModifyRecordsOperation

    //    var recordIDs: [CKRecord.ID]? { get set }
    //    var desiredKeys: [CKRecord.FieldKey]? { get set }
    //    // `CKDatabaseOperation`s:
    //    /// The closure to execute with progress information for individual records
    //    var perRecordProgressBlock: ((CKRecord.ID, Double) -> Void)? { get set }
    //    /// The closure to execute after CloudKit modifies all of the records
    //    var fetchRecordsResultBlock: ((Result<Void, Error>) -> Void)? { get set }
    //    /// The closure to execute once for every fetched record
    //    var perRecordResultBlock: ((CKRecord.ID, Result<CKRecord, Error>) -> Void)? { get set }

    func test_conversion_CKFetchRecordsOperation() {
        // make records to fetch
        var recsToSave = [CKRecord]()
        for index in 1...5 {
            let rec = makeCKRecord(name: "record-\(index)", type: "MATCH")
            recsToSave.append(rec)
        }
        let recIds = recsToSave.map { $0.recordID }
        let desiredKeys: [CKRecord.FieldKey] = ["name"]
        let mockDB: MockCKDatabase = MockCKDatabase()
        mockDB.addRecords(records: recsToSave)

        // create CKFetchRecordsOperation (it will have a CKDatabase attached to it - added implicitly by CloudKit) which
        // must be replaced with MockCKDatabase:
        let ckFetchRecordsOperation = CKFetchRecordsOperation(recordIDs: recIds)
        ckFetchRecordsOperation.name = "some name"
        ckFetchRecordsOperation.desiredKeys = desiredKeys
        XCTAssertEqual(ckFetchRecordsOperation.recordIDs?.count, 5)
        XCTAssertEqual(ckFetchRecordsOperation.desiredKeys?.count, 1)
        XCTAssertTrue(ckFetchRecordsOperation.database!.isKind(of: CKDatabase.self))
        XCTAssertTrue(ckFetchRecordsOperation.database!.isKind(of: CKDatabase.self))

        // Do the conversion to MockCKModifyRecordsOperation and check fields
        let mockOp: MockCKFetchRecordsOperation = ckFetchRecordsOperation.getMock(database: mockDB)
        XCTAssertTrue(type(of: mockOp) == MockCKFetchRecordsOperation.self, "operation is converted to MockCKFetchRecordsOperation")
        XCTAssertTrue(type(of: mockOp.database!) == MockCKDatabase.self, "new MockCKDatabaseOperation must contain reference to MockDabase")
        XCTAssertTrue(mockOp.database! === mockDB) // === analyses type but not value
        XCTAssertEqual(mockOp.database?.databaseScope, mockDB.databaseScope)
        XCTAssertEqual(mockOp.database?.getRecords()?.count, mockDB.getRecords()?.count)
        XCTAssertEqual(mockOp.name, ckFetchRecordsOperation.name)
        XCTAssertEqual(mockOp.configuration, ckFetchRecordsOperation.configuration)
        XCTAssertEqual(mockOp.qualityOfService, ckFetchRecordsOperation.qualityOfService)
        XCTAssertEqual(mockOp.recordIDs?.count, ckFetchRecordsOperation.recordIDs?.count)
        XCTAssertEqual(mockOp.desiredKeys?.count, ckFetchRecordsOperation.desiredKeys?.count)
        // check operations
        XCTAssertTrue(
            mockOp.fetchRecordsResultBlock.customMirror.subjectType
            == ckFetchRecordsOperation.fetchRecordsResultBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.perRecordResultBlock.customMirror.subjectType
            == ckFetchRecordsOperation.perRecordResultBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.perRecordProgressBlock.customMirror.subjectType
            == ckFetchRecordsOperation.perRecordProgressBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.completionBlock.customMirror.subjectType
            == ckFetchRecordsOperation.completionBlock.customMirror.subjectType
        )
    }

    func test_conversion_CKQueryOperation() {
        let desiredKeys: [CKRecord.FieldKey] = ["name"]
        let mockDB: MockCKDatabase = MockCKDatabase()

        // create CKQueryOperation (it will have a CKDatabase attached to it - added implicitly by CloudKit) which
        // must be replaced with MockCKDatabase:
        let pred = NSPredicate(value: true) // matches everything
        let query = CKQuery(recordType: "TestRecordType", predicate: pred)
        let ckQueryOperation = CKQueryOperation(query: query)
        ckQueryOperation.name = "some name"
        ckQueryOperation.desiredKeys = desiredKeys
        XCTAssertEqual(ckQueryOperation.desiredKeys?.count, 1)
        XCTAssertTrue(ckQueryOperation.database!.isKind(of: CKDatabase.self))
        XCTAssertTrue(ckQueryOperation.database!.isKind(of: CKDatabase.self))

        // Do the conversion to MockCKModifyRecordsOperation and check fields
        let mockOp: MockCKQueryOperation = ckQueryOperation.getMock(database: mockDB)
        XCTAssertTrue(type(of: mockOp) == MockCKQueryOperation.self, "operation is converted to MockCKQueryOperation")
        XCTAssertTrue(type(of: mockOp.database!) == MockCKDatabase.self, "new MockCKDatabaseOperation must contain reference to MockDabase")
        XCTAssertTrue(mockOp.database! === mockDB) // === analyses type but not value
        XCTAssertEqual(mockOp.database?.databaseScope, mockDB.databaseScope)
        XCTAssertEqual(mockOp.database?.getRecords()?.count, mockDB.getRecords()?.count)
        XCTAssertEqual(mockOp.configuration, ckQueryOperation.configuration)
        XCTAssertEqual(mockOp.desiredKeys?.count, ckQueryOperation.desiredKeys?.count)
        XCTAssertEqual(mockOp.query, ckQueryOperation.query)
        XCTAssertEqual(mockOp.cursor, ckQueryOperation.cursor)
        XCTAssertEqual(mockOp.resultsLimit, ckQueryOperation.resultsLimit)
        XCTAssertEqual(mockOp.name, ckQueryOperation.name)
        XCTAssertEqual(mockOp.qualityOfService, ckQueryOperation.qualityOfService)
        // check operations
        XCTAssertTrue(
            mockOp.queryResultBlock.customMirror.subjectType
            == ckQueryOperation.queryResultBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.recordMatchedBlock.customMirror.subjectType
            == ckQueryOperation.recordMatchedBlock.customMirror.subjectType
        )
        XCTAssertTrue(
            mockOp.completionBlock.customMirror.subjectType
            == ckQueryOperation.completionBlock.customMirror.subjectType
        )
    }

}
