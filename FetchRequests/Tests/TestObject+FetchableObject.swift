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
        self.observe(\.data, options: [.old, .new]) { object, change in
            guard let old = change.oldValue, let new = change.newValue, old != new else {
                return
            }

            unsafeHandler(for: handler)
        }
    }

    func observeIsDeletedChanges(_ handler: @escaping @MainActor () -> Void) -> InvalidatableToken {
        self.observe(\.isDeleted, options: [.old, .new]) { object, change in
            guard let old = change.oldValue, let new = change.newValue, old != new else {
                return
            }
            unsafeHandler(for: handler)
        }
    }

    static func entityID(from data: RawData) -> ID? {
        data.id?.string
    }
}

@MainActor(unsafe)
private func unsafeHandler(for handler: @MainActor () -> Void) {
    assert(Thread.isMainThread)
    // This is a dumb wrapper, but I can't otherwise have a "clean" compile
    handler()
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
