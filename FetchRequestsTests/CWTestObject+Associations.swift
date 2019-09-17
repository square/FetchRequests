//
//  CWTestObject+Associations.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 3/29/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation
@testable import FetchRequests

//swiftlint:disable implicitly_unwrapped_optional

extension CWTestObject {
    func tagString() -> String? {
        return performFault(on: \.tag) { tag in
            fatalError("Cannot perform fallback fault")
        }
    }

    func tagObject() -> CWTestObject? {
        return performFault(on: \.tagID) { (tagID: String) -> CWTestObject? in
            fatalError("Cannot perform fallback fault")
        }
    }

    func tagObjectArray() -> [CWTestObject]? {
        return performFault(on: \.tagIDs) { (tagIDs: [String]) -> [CWTestObject]? in
            fatalError("Cannot perform fallback fault")
        }
    }
}

// MARK: - Association Requests

extension CWTestObject {
    enum AssociationRequest {
        case parents([CWTestObject], completion: ([String: String]) -> Void)
        case tagIDs([String], completion: ([CWTestObject]) -> Void)

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

        var tagIDsCompletion: (([CWTestObject]) -> Void)! {
            guard case let .tagIDs(_, completion) = self else {
                return nil
            }
            return completion
        }
    }

    static func fetchRequestAssociations(
        matching: [PartialKeyPath<CWTestObject>],
        request: @escaping (AssociationRequest) -> Void
    ) -> [CWFetchRequestAssociation<CWTestObject>] {
        let tagString = CWFetchRequestAssociation<CWTestObject>(
            keyPath: \.tag,
            request: { objects, completion in
                request(.parents(objects, completion: completion))
            }
        )

        let tagObject = CWFetchRequestAssociation<CWTestObject>(
            for: CWTestObject.self,
            keyPath: \.tagID,
            request: { objectIDs, completion in
                request(.tagIDs(objectIDs, completion: completion))
            }
        )

        let tagObjects = CWFetchRequestAssociation<CWTestObject>(
            for: [CWTestObject].self,
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

class WrappedObservableToken<T>: CWObservableToken {
    private let notificationToken: CWObservableNotificationCenterToken
    private let transform: (Notification) -> T?

    init(
        name: Notification.Name,
        transform: @escaping (Notification) -> T?
    ) {
        notificationToken = CWObservableNotificationCenterToken(name: name)
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

class TestEntityObservableToken: WrappedObservableToken<CWTestObject.RawData> {
    private let include: (CWTestObject.RawData) -> Bool

    init(
        name: Notification.Name,
        include: @escaping (CWTestObject.RawData) -> Bool = { _ in true }
    ) {
        self.include = include
        super.init(name: name, transform: { $0.object as? Parameter })
    }

    override func observe(handler: @escaping (CWTestObject.RawData) -> Void) {
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

extension CWTestObject {
    static func fetch(byIDs ids: [CWTestObject.ID]) -> [CWTestObject] {
        return ids.map { CWTestObject(id: $0) }
    }
}

extension CWFetchRequestAssociation where FetchedObject == CWTestObject {
    convenience init<AssociatedType: CWTestObject>(
        for associatedType: AssociatedType.Type,
        keyPath: KeyPath<FetchedObject, AssociatedType.ID>,
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

    convenience init<AssociatedType: CWTestObject>(
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

    convenience init<AssociatedType: CWTestObject>(
        for associatedType: Array<AssociatedType>.Type,
        keyPath: KeyPath<FetchedObject, [AssociatedType.ID]>,
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

    convenience init<AssociatedType: CWTestObject>(
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
