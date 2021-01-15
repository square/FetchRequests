//
//  TestObject+Associations.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 3/29/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation
@testable import FetchRequests

// swiftlint:disable implicitly_unwrapped_optional

extension TestObject {
    func tagString() -> String? {
        return performFault(on: \.tag) { tag in
            fatalError("Cannot perform fallback fault")
        }
    }

    func tagObject() -> TestObject? {
        return performFault(on: \.tagID) { (tagID: String) -> TestObject? in
            fatalError("Cannot perform fallback fault")
        }
    }

    func tagObjectArray() -> [TestObject]? {
        return performFault(on: \.tagIDs) { (tagIDs: [String]) -> [TestObject]? in
            fatalError("Cannot perform fallback fault")
        }
    }
}

// MARK: - Association Requests

extension TestObject {
    enum AssociationRequest {
        case parents([TestObject], completion: ([String: String]) -> Void)
        case tagIDs([String], completion: ([TestObject]) -> Void)

        var parentIDs: [String]! {
            guard case let .parents(objects, _) = self else {
                return nil
            }
            return objects.map { $0.id }
        }

        var tagIDs: [String]! {
            guard case let .tagIDs(objects, _) = self else {
                return nil
            }
            return objects
        }

        var parentsCompletion: (([String: String]) -> Void)! {
            guard case let .parents(_, completion) = self else {
                return nil
            }
            return completion
        }

        var tagIDsCompletion: (([TestObject]) -> Void)! {
            guard case let .tagIDs(_, completion) = self else {
                return nil
            }
            return completion
        }
    }

    static func fetchRequestAssociations(
        matching: [PartialKeyPath<TestObject>],
        request: @escaping (AssociationRequest) -> Void
    ) -> [FetchRequestAssociation<TestObject>] {
        let tagString = FetchRequestAssociation<TestObject>(
            keyPath: \.tag,
            request: { objects, completion in
                request(.parents(objects, completion: completion))
            }
        )

        let tagObject = FetchRequestAssociation<TestObject>(
            for: TestObject.self,
            keyPath: \.tagID,
            request: { objectIDs, completion in
                request(.tagIDs(objectIDs, completion: completion))
            }
        )

        let tagObjects = FetchRequestAssociation<TestObject>(
            for: [TestObject].self,
            keyPath: \.tagIDs,
            request: { objectIDs, completion in
                request(.tagIDs(objectIDs, completion: completion))
            }
        )

        let allAssociations = [tagString, tagObject, tagObjects]

        return allAssociations.filter {
            matching.contains($0.keyPath)
        }
    }
}

// MARK: - Tokens

class WrappedObservableToken<T>: ObservableToken {
    private let notificationToken: ObservableNotificationCenterToken
    private let transform: (Notification) -> T?

    init(
        name: Notification.Name,
        transform: @escaping (Notification) -> T?
    ) {
        notificationToken = ObservableNotificationCenterToken(name: name)
        self.transform = transform
    }

    func invalidate() {
        notificationToken.invalidate()
    }

    func observe(handler: @escaping (T) -> Void) {
        let transform = self.transform
        notificationToken.observe { notification in
            guard let value = transform(notification) else {
                return
            }
            handler(value)
        }
    }
}

class TestEntityObservableToken: WrappedObservableToken<TestObject.RawData> {
    private let include: (TestObject.RawData) -> Bool

    init(
        name: Notification.Name,
        include: @escaping (TestObject.RawData) -> Bool = { _ in true }
    ) {
        self.include = include
        super.init(name: name, transform: { $0.object as? Parameter })
    }

    override func observe(handler: @escaping (TestObject.RawData) -> Void) {
        let include = self.include
        super.observe { data in
            guard include(data) else {
                return
            }
            handler(data)
        }
    }
}

class VoidNotificationObservableToken: WrappedObservableToken<Void> {
    init(name: Notification.Name) {
        super.init(name: name, transform: { _ in () })
    }
}

// MARK: - Associations

extension TestObject {
    static func fetch(byIDs ids: [TestObject.ID]) -> [TestObject] {
        return ids.map { TestObject(id: $0) }
    }
}

extension FetchRequestAssociation where FetchedObject == TestObject {
    convenience init<AssociatedType: TestObject>(
        for associatedType: AssociatedType.Type,
        keyPath: KeyPath<FetchedObject, AssociatedType.ID?>,
        request: @escaping AssocationRequestByID<AssociatedType.ID, AssociatedType>
    ) {
        self.init(
            for: associatedType,
            keyPath: keyPath,
            request: request,
            creationTokenGenerator: { objectID in
                return TestEntityObservableToken(
                    name: AssociatedType.objectWasCreated(),
                    include: { json in
                        guard let includeID = AssociatedType.entityID(from: json) else {
                            return false
                        }
                        return objectID == includeID
                    }
                )
            },
            preferExistingValueOnCreate: true
        )
    }

    convenience init<AssociatedType: TestObject>(
        for associatedType: Array<AssociatedType>.Type,
        keyPath: KeyPath<FetchedObject, [AssociatedType.ID]?>,
        request: @escaping AssocationRequestByID<AssociatedType.ID, AssociatedType>
    ) {
        self.init(
            for: associatedType,
            keyPath: keyPath,
            request: request,
            creationTokenGenerator: { objectIDs in
                return TestEntityObservableToken(
                    name: AssociatedType.objectWasCreated(),
                    include: { json in
                        guard let objectID = AssociatedType.entityID(from: json) else {
                            return false
                        }
                        return objectIDs.contains(objectID)
                    }
                )
            },
            creationObserved: { lhs, rhs in
                let lhs = lhs ?? []
                guard let objectID = AssociatedType.entityID(from: rhs) else {
                    return .same
                }
                if lhs.contains(where: { $0.id == objectID }) {
                    return .same
                }
                return .invalid
            }
        )
    }
}
