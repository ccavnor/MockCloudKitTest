//
//  BaseCloudKitTestCase.swift
//  MockCloudKitTestProjectTests
//
//  Created by Christopher Charles Cavnor on 2/2/22.
//

import XCTest
import MockCloudKitFramework
import CloudKit
@testable import MockCloudKitTestProject // required for access to CloudController and MCF protocols loaded by app

class BaseCloudkitTestCase: XCTestCase {

    // We set up access to the mock CloudKit framework statically, so that test cases that inherit from
    // BaseCloudkitTestCase don't need to create their own CKContainers, but access mockCloudContainer using Self.
    static var mockCloudContainer: MockCKContainer!
    static var mockCKDatabase: MockCKDatabase!

    // class version of setUp called exactly once
    override class func setUp() {
        mockCloudContainer = MockCKContainer.default()
        mockCKDatabase = mockCloudContainer.privateCloudDatabase
    }

    /// CKAccountStatus messages associated with CKAccountStatus codes
    enum CKAccountStatusMessage: String {
        case couldNotDetermine = "Unable to determine iCloud account status." // 0
        case available  // 1
        case restricted = "iCloud account is restricted." // 2
        case noAccount = "No iCloud account could be found." // 3
        // @available(iOS 15.0, *)
        case temporarilyUnavailable = "iCloud account is temporarily unavailable. Please try again later." // 4
    }

    /// Create a CKRecord for testing
    /// - Parameters:
    ///   - id: optional CKRecord.ID
    ///   - name: optional record name for CKRecord.ID to use
    ///   - type: optional description of CKRecord type
    /// - Returns: a CKRecord with user provided values, else default ones.
    func makeCKRecord(id: CKRecord.ID? = nil,
                      name: String? = nil,
                      type: String? = nil) -> CKRecord {
        var recordId: CKRecord.ID,
            recordName: String,
            recordType: String
        recordName = name ?? UUID().uuidString
        recordId = id ?? CKRecord.ID(recordName: recordName)
        recordType = type ?? "TestRecordType"
        return CKRecord(recordType: recordType, recordID: recordId)
    }

    /// Create array of CKRecord for testing. All records use default values.
    /// - Parameter number: the number of CKRecord records to return
    /// - Returns: an array of CKRecord
    func createRecords(number: Int) -> [CKRecord] {
        var records: [CKRecord] = [CKRecord]()
        for _ in 1...number {
            records.append(makeCKRecord())
        }
        return records
    }

    /// Create an NSError containing information from the provided CKAccountStatus.
    /// - Parameter code: a CKAccountStatus
    /// - Returns: NSError with a "CKAccountStatus" domain
    func createNSError(code: CKAccountStatus) -> NSError {
        return NSError(domain: "CKAccountStatus", code: code.rawValue, userInfo: nil)
    }

    /// Create an NSError containing information from the provided CKError code.
    /// - Parameter code: a CKError.Code
    /// - Returns: NSError with a CKErrorDomain domain
    func createNSError(with code: CKError.Code) -> NSError {
        let cKErrorDomain = CKError.errorDomain
        let error = NSError(domain: cKErrorDomain, code: code.rawValue, userInfo: nil)
        return error
    }

    /// Create an CKError from the provided CKError.Code.
    /// - Parameter code: a CKError.Code
    /// - Returns: CKError with a CKErrorDomain domain
    func createCKError(code: CKError.Code) -> CKError {
        let cKErrorDomain = CKError.errorDomain
        let error = NSError(domain: cKErrorDomain, code: code.rawValue, userInfo: nil)
        return CKError(_nsError: error)
    }

    /// Generate a random alphanumeric string of the requested length
    private func randomAlphaNumericString(length: Int) -> String {
      let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }

    /// Test that a string is a valid UUID string
    /// - Parameter uuid: the stringified UUID to test
    /// - Returns: true iff string evaluates to valid UUID
    func isUUIDString(_ uuid: String) -> Bool {
        // returns nil if not valid UUID
        let test = UUID(uuidString: uuid)
        return test == nil ? false : true
    }

    /// Lookup table for CKAccountStatus codes
    let ckAccountStatusMappings: [Int: CKAccountStatus] = [
        0: CKAccountStatus.couldNotDetermine,
        1: CKAccountStatus.available,
        2: CKAccountStatus.restricted,
        3: CKAccountStatus.noAccount,
        4: CKAccountStatus.temporarilyUnavailable
    ]

    /// Lookup table for CKAccountStatus messages
    let ckAccountStatusMessageMappings: [CKAccountStatus: String] = [
        .couldNotDetermine: CKAccountStatusMessage.couldNotDetermine.rawValue, // 0
        .available: CKAccountStatusMessage.available.rawValue, // 1
        .restricted: CKAccountStatusMessage.restricted.rawValue, // 2
        .noAccount: CKAccountStatusMessage.noAccount.rawValue, // 3
        .temporarilyUnavailable: CKAccountStatusMessage.temporarilyUnavailable.rawValue // 4
    ]

    /// The CKError types that will be simulated
    let ckErrorCodes: [CKError.Code] = [
        .internalError, // 1
        .networkUnavailable, // 3
        .networkFailure, // 4
        .badContainer, // 5
        .serviceUnavailable, // 6
        .requestRateLimited, // 7
        .notAuthenticated, // 9
        .permissionFailure, // 10
        .invalidArguments, // 12
        .zoneBusy, // 23
        .badDatabase, // 24
        .quotaExceeded, // 25
        .zoneNotFound, // 26
        .userDeletedZone, // 28
        .serverResponseLost, // 34
        .accountTemporarilyUnavailable // 36
    ]

    // ===================================================
    // Test the functions of BaseCloudKitTestCase
    // ===================================================
    func test_isUUIDString() {
        // generate strings of fake UUIDs
        // NOTE - keep commented out unless debugging the target function. Though it is highly improbable,
        // this block might occasionally fail. And I'm not a fan of non-determanistic tests.
//        for _ in 1...100 {
//            // UUID consists of dash seperated substrings of respecive length: 8-4-4-4-11
//            let uuid: String = randomAlphaNumericString(length: 8) + "-"
//            + randomAlphaNumericString(length: 4) + "-"
//            + randomAlphaNumericString(length: 4) + "-"
//            + randomAlphaNumericString(length: 4) + "-"
//            + randomAlphaNumericString(length: 11)
//            XCTAssertFalse(isUUIDString(uuid), "test MIGHT occasionally (randomly) pass")
//        }
        let realUUID = "23ADBC00-133B-4812-98B9-9E5F28A77F4F"
        XCTAssertTrue(isUUIDString(realUUID))
    }
    func test_makeCKRecord_default() {
        let ckRecord = makeCKRecord()
        XCTAssertTrue(isUUIDString(ckRecord.recordID.recordName), "the record id will be a UUID")
        XCTAssertEqual(ckRecord.recordType.description, "TestRecordType")
    }
    func test_makeCKRecord_custom_with_id() {
        let recordName = "SomeRecordName"
        let ckRecordID = CKRecord.ID.init(recordName: recordName)
        let ckRecord = makeCKRecord(id: ckRecordID)
        XCTAssertEqual(ckRecordID, ckRecord.recordID)
        XCTAssertEqual(ckRecordID.recordName, recordName)
        XCTAssertEqual(ckRecord.recordType.description, "TestRecordType", "gets default type since we didn't provide one")
    }
    func test_makeCKRecord_custom_with_name() {
        let recordName = "SomeRecordName"
        let ckRecord = makeCKRecord(name: recordName)
        XCTAssertEqual(ckRecord.recordID.recordName, recordName)
        XCTAssertEqual(ckRecord.recordType.description, "TestRecordType", "gets default type since we didn't provide one")
    }
    func test_makeCKRecord_custom_with_type() {
        let recordType = "SomeRecordType"
        let ckRecord = makeCKRecord(type: recordType)
        XCTAssertTrue(isUUIDString(ckRecord.recordID.recordName), "the record id will be a UUID")
        XCTAssertEqual(ckRecord.recordType.description, recordType)
    }
    func test_makeCKRecord_custom_with_id_name_type() {
        let recordName = "SomeRecordName"
        let recordType = "SomeRecordType"
        let ckRecordID = CKRecord.ID.init(recordName: recordName)
        let ckRecord = makeCKRecord(id: ckRecordID, name: recordName, type: recordType)
        print(ckRecord)
        XCTAssertEqual(ckRecord.recordType.description, recordType)
        XCTAssertEqual(ckRecord.recordID.recordName, recordName)
        XCTAssertEqual(ckRecordID, ckRecord.recordID)
    }
    func test_createRecords() {
        let records = createRecords(number: 100)
        for r in 0..<records.count {
            let ckRecord = records[r]
            XCTAssertEqual(ckRecord.recordType.description, "TestRecordType", "gets default type")
            XCTAssertTrue(isUUIDString(ckRecord.recordID.recordName), "the record id will be a UUID")
        }
    }
    func test_createError_CKAccountStatus() {
        _ = ckAccountStatusMappings.values.map { (v: CKAccountStatus) in
            let error: NSError = createNSError(code: v)
            XCTAssertEqual(error.domain, "CKAccountStatus", "expect a CKAccountStatus type")
            XCTAssertEqual(error.code, v.rawValue, "error code should be CKAccountStatus code")
        }
    }

    func test_createError_CKError() {
        _ = ckErrorCodes.map { (v: CKError.Code) in
            let error: CKError = createCKError(code: v)
            XCTAssertEqual(error._nsError.domain, "CKErrorDomain", "expect a CKErrorDomain domain")
            XCTAssertEqual(error.errorCode, v.rawValue, "expect error code to match input code")
            let expectedDescription = "The operation couldn’t be completed. (CKErrorDomain error \(v.rawValue).)"
            XCTAssertEqual(error.localizedDescription, expectedDescription, "error desciption should contain correct domain and error code")
        }
    }
}

