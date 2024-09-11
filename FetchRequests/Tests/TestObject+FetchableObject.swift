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
    func observeDataChanges(_ handler: @escaping @Sendable @MainActor () -> Void) -> InvalidatableToken {
        self.observe(\.data, options: [.old, .new]) { object, change in
            guard let old = change.oldValue, let new = change.newValue else {
                return
            }
            let oldDict = old as NSDictionary
            let newDict = new as NSDictionary

            guard oldDict != newDict else {
                return
            }

            MainActor.assumeIsolated {
                handler()
            }
        }
    }

    func observeIsDeletedChanges(_ handler: @escaping @Sendable @MainActor () -> Void) -> InvalidatableToken {
        self.observe(\.isDeleted, options: [.old, .new]) { object, change in
            guard let old = change.oldValue, let new = change.newValue, old != new else {
                return
            }
            MainActor.assumeIsolated {
                handler()
            }
        }
    }

    static func entityID(from data: RawData) -> ID? {
        data["id"] as? String
    }
}

// MARK: - Event Notifications

extension TestObject {
    static func objectWasCreated() -> Notification.Name {
        Notification.Name("TestObject.objectWasCreated")
    }

    static func dataWasCleared() -> Notification.Name {
        Notification.Name("TestObject.dataWasCleared")
    }
}
