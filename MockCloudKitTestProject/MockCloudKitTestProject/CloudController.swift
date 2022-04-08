//
//  CloudController.swift
//  MockCloudKitTestProject
//
//  Created by Christopher Charles Cavnor on 2/11/22.
//

import CloudKit
import MockCloudKitFramework

class CloudController<Container: CloudContainable>: ObservableObject {
    let cloudContainer: Container
    let database: Container.DatabaseType

    init(container: Container, databaseScope: CKDatabase.Scope) {
        self.cloudContainer = container
        self.database = container.database(with: databaseScope)
    }

    /// CKAccountStatus codes are constants that indicate the availability of the user’s iCloud account. Note that ONLY the return of
    /// CKAccountStatus.available signifies that the user is signed into iCloud. Any other return value indicates an error.
    func accountStatus(completion: @escaping (Result<CKAccountStatus, Error>) -> Void) {
        cloudContainer.accountStatus { status, error in
            switch status {
            case .available:
                completion(.success(.available))
            default:
                    guard let error = error else {
                        let error = NSError.init(domain: "AccountStatusError", code: 0) as Error
                        completion(.failure(error))
                        return
                    }
                completion(.failure(error))
            }
        }
    }

    /// Check if a record exists in iCloud.
    /// - Parameters:
    ///   - recordId: the record id to locate
    ///   - completion: closure to execute on caller
    /// - Returns: success(true) when record is located,  success(false) when record is not found, failure if an error occurred.
    func checkCloudRecordExists( recordId: CKRecord.ID, _ completion: @escaping (Result<Bool, Error>) -> Void) {
            let dbOperation = CKFetchRecordsOperation(recordIDs: [recordId])
            dbOperation.recordIDs = [recordId]
            var record: CKRecord?
            dbOperation.desiredKeys = ["recordID"]
            // perRecordResultBlock doesn't get called if the record doesn't exist
            dbOperation.perRecordResultBlock = { _, result in
                // success iff no partial failure
                switch result {
                case .success(let r):
                    record = r
                case .failure:
                    record = nil
                }
            }
            // fetchRecordsResultBlock always gets called when finished processing.
            dbOperation.fetchRecordsResultBlock = { result in
                // success if no transaction error
                switch result {
                case .success():
                    if let _ = record { // record exists and no errors
                        completion(.success(true))
                    } else { // record does not exist
                        completion(.success(false))
                    }
                case .failure(let error): // either transaction or partial failure occurred
                    completion(.failure(error))
                }
            }
            database.add(dbOperation)
        }


    func getMessages(_ completion: @escaping (Result<[CKRecord], Error>) -> Void){
        let pred = NSPredicate(value: true) // matches everything
        let query = CKQuery(recordType: "Message", predicate: pred)
        let operation = CKQueryOperation.init(query: query)
        var records: [CKRecord] = [CKRecord]()
        // for each matching result
        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                completion(.failure(error))
            }
        }
        // we are finished fetching records
        operation.queryResultBlock = { result in
            switch result {
            case .success:
                completion(.success(records))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        database.add(operation)
    }

    func postMessage(message: CKRecord, _ completion: @escaping (Result<Void, Error>) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: [message], recordIDsToDelete: nil)
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        database.add(operation)
    }
}
