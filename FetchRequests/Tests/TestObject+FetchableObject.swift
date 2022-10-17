//
//  TestObject+FetchableObject.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 3/29/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation
import FetchRequests

// MARK: - FetchableObjectProtocol

extension TestObject: FetchableObjectProtocol {
    func observeDataChanges(_ handler: @escaping @MainActor () -> Void) -> InvalidatableToken {
        return self.observe(\.data, options: [.old, .new]) { @MainActor(unsafe) object, change in
            guard let old = change.oldValue, let new = change.newValue, old != new else {
                return
            }

            handler()
        }
    }

    func observeIsDeletedChanges(_ handler: @escaping @MainActor () -> Void) -> InvalidatableToken {
        return self.observe(\.isDeleted, options: [.old, .new]) { @MainActor(unsafe) object, change in
            guard let old = change.oldValue, let new = change.newValue, old != new else {
                return
            }
            handler()
        }
    }

    static func entityID(from data: RawData) -> ID? {
        return data.id?.string
    }
}

// MARK: - Event Notifications

extension TestObject {
    static func objectWasCreated() -> Notification.Name {
        return Notification.Name("TestObject.objectWasCreated")
    }

    static func dataWasCleared() -> Notification.Name {
        return Notification.Name("TestObject.dataWasCleared")
    }
}
