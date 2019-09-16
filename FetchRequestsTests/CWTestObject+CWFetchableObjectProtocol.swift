//
//  File.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 3/29/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation
import FetchRequests

// MARK: - CWFetchableObjectProtocol

extension CWTestObject: CWFetchableObjectProtocol {
    static var idKeyPath: KeyPath<CWTestObject, ID> {
        return \.id
    }

    static var dataKeyPath: KeyPath<CWTestObject, RawData> {
        return \.data
    }

    static var deletedKeyPath: KeyPath<CWTestObject, Bool> {
        return \.isDeleted
    }

    static func entityID(from data: RawData) -> ID? {
        return data["id"] as? ID
    }

    static func rawDataIsIdentical(lhs: RawData, rhs: RawData) -> Bool {
        return (lhs as NSDictionary) == (rhs as NSDictionary)
    }
}

// MARK: - Event Notifications

extension CWTestObject {
    static func objectWasCreated() -> Notification.Name {
        return Notification.Name("CWTestObject.objectWasCreated")
    }

    static func dataWasCleared() -> Notification.Name {
        return Notification.Name("CWTestObject.dataWasCleared")
    }
}
