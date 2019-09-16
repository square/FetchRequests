//
//  CWFetchRequestAssociation.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/23/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public enum CWAssociationReplacement<T> {
    case same
    case changed(newValue: T)
    case invalid
}

/// Map an associated value's key to object
public class CWFetchRequestAssociation<FetchedObject: CWFetchableObject> {
    /// Fetch associated values given a list of parent objects
    public typealias AssocationRequestByParent<AssociatedEntity> = (_ objects: [FetchedObject], _ completion: @escaping ([FetchedObject.ID: AssociatedEntity]) -> Void) -> Void
    /// Fetch associated values given a list of associated IDs
    public typealias AssocationRequestByID<AssociatedEntityID: Hashable, AssociatedEntity> = (_ objects: [AssociatedEntityID], _ completion: @escaping ([AssociatedEntity]) -> Void) -> Void
    /// Event that represents the creation of an associated value object
    public typealias CreationObserved<Value, Comparison> = (Value?, Comparison) -> CWAssociationReplacement<Value>
    /// Start observing a source object
    public typealias TokenGenerator<Source, Token: CWObservableToken> = (Source) -> Token?

    internal typealias AssociationKeyPath = PartialKeyPath<FetchedObject>
    internal typealias ReferenceGenerator = (FetchedObject) -> AssociatedValueReference

    internal let keyPath: AssociationKeyPath
    internal let request: AssocationRequestByParent<Any>
    internal let referenceGenerator: ReferenceGenerator

    internal typealias KeyPathChangeHandler = (_ object: FetchedObject, _ oldValue: Any?, _ newValue: Any?) -> Void
    internal typealias KeyPathObservation = (_ object: FetchedObject, _ changeHandler: @escaping KeyPathChangeHandler) -> NSKeyValueObservation

    internal typealias OptionalKeyPathChangeHandler = (_ object: FetchedObject, _ oldValue: Any??, _ newValue: Any??) -> Void
    internal typealias OptionalKeyPathObservation = (_ object: FetchedObject, _ changeHandler: @escaping OptionalKeyPathChangeHandler) -> NSKeyValueObservation

    internal let observeKeyPath: KeyPathObservation

    private init(
        keyPath: AssociationKeyPath,
        request: @escaping AssocationRequestByParent<Any>,
        referenceGenerator: @escaping ReferenceGenerator,
        observeKeyPath: @escaping KeyPathObservation
    ) {
        self.keyPath = keyPath
        self.request = request
        self.referenceGenerator = referenceGenerator
        self.observeKeyPath = observeKeyPath
    }

    private convenience init(
        keyPath: AssociationKeyPath,
        request: @escaping AssocationRequestByParent<Any>,
        referenceGenerator: @escaping ReferenceGenerator,
        observeKeyPath: @escaping OptionalKeyPathObservation
    ) {
        let wrappedObserveKeyPath: KeyPathObservation = { object, changeHandler in
            observeKeyPath(object) { object, oldValue, newValue in
                guard let oldValue = oldValue, let newValue = newValue else {
                    return
                }
                changeHandler(object, oldValue, newValue)
            }
        }

        self.init(
            keyPath: keyPath,
            request: request,
            referenceGenerator: referenceGenerator,
            observeKeyPath: wrappedObserveKeyPath
        )
    }
}

// MARK: - Basic Associations

public extension CWFetchRequestAssociation {
    /// Association by non-optional entity ID
    convenience init<AssociatedEntity, AssociatedEntityID: Equatable>(
        keyPath: KeyPath<FetchedObject, AssociatedEntityID>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>
    ) {
        self.init(
            keyPath: keyPath,
            request: { objects, completion in
                request(objects) { results in
                    completion(results)
                }
            },
            referenceGenerator: { _ in AssociatedValueReference() },
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }

    /// Association by optional entity ID
    convenience init<AssociatedEntity, AssociatedEntityID: Equatable>(
        keyPath: KeyPath<FetchedObject, AssociatedEntityID?>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>
    ) {
        self.init(
            keyPath: keyPath,
            request: { objects, completion in
                request(objects) { results in
                    completion(results)
                }
            },
            referenceGenerator: { _ in AssociatedValueReference() },
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }
}

// MARK: - Observed Creation Associations

public extension CWFetchRequestAssociation {
    /// Association by non-optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        RawAssociatedEntity,
        AssociatedEntityID: Equatable,
        Token: CWObservableToken
    > (
        keyPath: KeyPath<FetchedObject, AssociatedEntityID>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        creationObserved: @escaping CreationObserved<AssociatedEntity, RawAssociatedEntity>
    ) where Token.Parameter == RawAssociatedEntity {
        let creationTokenGenerator: TokenGenerator<FetchedObject, FetchRequestObservableToken<Any>> = { parentObject in
            let token = creationTokenGenerator(parentObject)
            return token.map { FetchRequestObservableToken(typeErasedToken: $0) }
        }

        let creationObserved: CreationObserved<Any, Any> = { lhs, rhs in
            let lhs = lhs as? AssociatedEntity
            guard let rhs = rhs as? RawAssociatedEntity else {
                return .same
            }

            let result = creationObserved(lhs, rhs)
            switch result {
            case .invalid:
                return .invalid

            case .same:
                return .same

            case let .changed(newValue):
                return .changed(newValue: newValue)
            }
        }

        let referenceGenerator: ReferenceGenerator = { parentObject in
            let creationObserver = creationTokenGenerator(parentObject)
            return FetchableAssociatedValueReference<AssociatedEntity>(
                creationObserver: creationObserver,
                creationObserved: creationObserved
            )
        }

        self.init(
            keyPath: keyPath,
            request: { objects, completion in
                request(objects) { results in
                    completion(results)
                }
            },
            referenceGenerator: referenceGenerator,
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }

    /// Association by optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        RawAssociatedEntity,
        AssociatedEntityID: Equatable,
        Token: CWObservableToken
    > (
        keyPath: KeyPath<FetchedObject, AssociatedEntityID?>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        creationObserved: @escaping CreationObserved<AssociatedEntity, RawAssociatedEntity>
    ) where Token.Parameter == RawAssociatedEntity {
        let creationTokenGenerator: TokenGenerator<FetchedObject, FetchRequestObservableToken<Any>> = { parentObject in
            let token = creationTokenGenerator(parentObject)
            return token.map { FetchRequestObservableToken(typeErasedToken: $0) }
        }

        let creationObserved: CreationObserved<Any, Any> = { lhs, rhs in
            let lhs = lhs as? AssociatedEntity
            guard let rhs = rhs as? RawAssociatedEntity else {
                return .same
            }

            let result = creationObserved(lhs, rhs)
            switch result {
            case .invalid:
                return .invalid

            case .same:
                return .same

            case let .changed(newValue):
                return .changed(newValue: newValue)
            }
        }

        let referenceGenerator: ReferenceGenerator = { parentObject in
            let creationObserver = creationTokenGenerator(parentObject)
            return FetchableAssociatedValueReference<AssociatedEntity>(
                creationObserver: creationObserver,
                creationObserved: creationObserved
            )
        }

        self.init(
            keyPath: keyPath,
            request: { objects, completion in
                request(objects) { results in
                    completion(results)
                }
            },
            referenceGenerator: referenceGenerator,
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }

    /// Association by non-optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        AssociatedEntityID: Equatable,
        Token: CWObservableToken
    > (
        keyPath: KeyPath<FetchedObject, AssociatedEntityID>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        preferExistingValueOnCreate: Bool
    ) where Token.Parameter == AssociatedEntity {
        self.init(
            keyPath: keyPath,
            request: request,
            creationTokenGenerator: creationTokenGenerator,
            creationObserved: { lhs, rhs in
                if preferExistingValueOnCreate, lhs != nil {
                    return .same
                }
                return .changed(newValue: rhs)
            }
        )
    }

    /// Association by optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        AssociatedEntityID: Equatable,
        Token: CWObservableToken
    >(
        keyPath: KeyPath<FetchedObject, AssociatedEntityID?>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        preferExistingValueOnCreate: Bool
    ) where Token.Parameter == AssociatedEntity {
        self.init(
            keyPath: keyPath,
            request: request,
            creationTokenGenerator: creationTokenGenerator,
            creationObserved: { lhs, rhs in
                if preferExistingValueOnCreate, lhs != nil {
                    return .same
                }
                return .changed(newValue: rhs)
            }
        )
    }
}

// MARK: - Observed Creation by RawData Associations

public extension CWFetchRequestAssociation {
    /// Association by non-optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        Token: CWObservableToken
    > (
        for associatedType: AssociatedEntity.Type,
        keyPath: KeyPath<FetchedObject, AssociatedEntity.ID>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<AssociatedEntity.ID, Token>,
        preferExistingValueOnCreate: Bool
    ) where Token.Parameter == AssociatedEntity.RawData {
        let rawRequest: AssocationRequestByParent<Any> = { objects, completion in
            var valuesSet: Set<AssociatedEntity.ID> = []
            var valuesOrdered: [AssociatedEntity.ID] = []
            let mapping: [FetchedObject.ID: AssociatedEntity.ID] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                let associatedID = object[keyPath: keyPath]
                if !valuesSet.contains(associatedID) {
                    valuesSet.insert(associatedID)
                    valuesOrdered.append(associatedID)
                }
                memo[objectID] = associatedID
            }

            guard !mapping.isEmpty else {
                completion([:])
                return
            }

            request(valuesOrdered) { values in
                let mappedValues = values.createLookupTable()
                var results: [FetchedObject.ID: AssociatedEntity] = [:]
                for (objectID, associatedID) in mapping {
                    if let association = mappedValues[associatedID] {
                        results[objectID] = association
                    }
                }

                completion(results)
            }
        }

        let creationTokenGenerator: TokenGenerator<FetchedObject, FetchRequestObservableToken<Any>> = { parentObject in
            let entityID = parentObject[keyPath: keyPath]
            guard let token = creationTokenGenerator(entityID) else {
                return nil
            }
            return FetchRequestObservableToken(typeErasedToken: token)
        }

        let creationObserved: CreationObserved<Any, Any> = { lhs, rhs in
            let lhs = lhs as? AssociatedEntity
            if preferExistingValueOnCreate, lhs != nil {
                return .same
            }
            guard let rhs = rhs as? AssociatedEntity.RawData else {
                return .same
            }

            guard let newValue = AssociatedEntity(data: rhs) else {
                return .same
            }
            return .changed(newValue: newValue)
        }

        let referenceGenerator: ReferenceGenerator = { parentObject in
            let creationObserver = creationTokenGenerator(parentObject)
            return FetchableAssociatedValueReference<AssociatedEntity>(
                creationObserver: creationObserver,
                creationObserved: creationObserved
            )
        }

        self.init(
            keyPath: keyPath,
            request: rawRequest,
            referenceGenerator: referenceGenerator,
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }

    /// Association by optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        Token: CWObservableToken
    > (
        for associatedType: AssociatedEntity.Type,
        keyPath: KeyPath<FetchedObject, AssociatedEntity.ID?>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<AssociatedEntity.ID, Token>,
        preferExistingValueOnCreate: Bool
    ) where Token.Parameter == AssociatedEntity.RawData {
        let rawRequest: AssocationRequestByParent<Any> = { objects, completion in
            var valuesSet: Set<AssociatedEntity.ID> = []
            var valuesOrdered: [AssociatedEntity.ID] = []
            let mapping: [FetchedObject.ID: AssociatedEntity.ID] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                guard let associatedID = object[keyPath: keyPath] else {
                    return
                }
                if !valuesSet.contains(associatedID) {
                    valuesSet.insert(associatedID)
                    valuesOrdered.append(associatedID)
                }
                memo[objectID] = associatedID
            }

            guard !mapping.isEmpty else {
                completion([:])
                return
            }

            request(valuesOrdered) { values in
                let mappedValues = values.createLookupTable()
                var results: [FetchedObject.ID: AssociatedEntity] = [:]
                for (objectID, associatedID) in mapping {
                    if let association = mappedValues[associatedID] {
                        results[objectID] = association
                    }
                }

                completion(results)
            }
        }

        let creationTokenGenerator: TokenGenerator<FetchedObject, FetchRequestObservableToken<Any>> = { parentObject in
            guard let entityID = parentObject[keyPath: keyPath] else {
                return nil
            }
            guard let token = creationTokenGenerator(entityID) else {
                return nil
            }
            return FetchRequestObservableToken(typeErasedToken: token)
        }

        let creationObserved: CreationObserved<Any, Any> = { lhs, rhs in
            let lhs = lhs as? AssociatedEntity
            if preferExistingValueOnCreate, lhs != nil {
                return .same
            }
            guard let rhs = rhs as? AssociatedEntity.RawData else {
                return .same
            }

            guard let newValue = AssociatedEntity(data: rhs) else {
                return .same
            }
            return .changed(newValue: newValue)
        }

        let referenceGenerator: ReferenceGenerator = { parentObject in
            let creationObserver = creationTokenGenerator(parentObject)
            return FetchableAssociatedValueReference<AssociatedEntity>(
                creationObserver: creationObserver,
                creationObserved: creationObserved
            )
        }

        self.init(
            keyPath: keyPath,
            request: rawRequest,
            referenceGenerator: referenceGenerator,
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }
}

// MARK: - Observed Creation Array Associations

public extension CWFetchRequestAssociation {
    /// Array association by non-optional entity IDs whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        Token: CWObservableToken
    > (
        for associatedType: Array<AssociatedEntity>.Type,
        keyPath: KeyPath<FetchedObject, [AssociatedEntity.ID]>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<[AssociatedEntity.ID], Token>,
        creationObserved: @escaping CreationObserved<[AssociatedEntity], AssociatedEntity.RawData>
    ) where Token.Parameter == AssociatedEntity.RawData {
        let rawRequest: AssocationRequestByParent<Any> = { objects, completion in
            var valuesSet: Set<AssociatedEntity.ID> = []
            var valuesOrdered: [AssociatedEntity.ID] = []
            let mapping: [FetchedObject.ID: [AssociatedEntity.ID]] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                let associatedIDs: [AssociatedEntity.ID] = object[keyPath: keyPath]
                guard !associatedIDs.isEmpty else {
                    return
                }
                for associatedID in associatedIDs {
                    guard !valuesSet.contains(associatedID) else {
                        continue
                    }
                    valuesSet.insert(associatedID)
                    valuesOrdered.append(associatedID)
                }
                memo[objectID] = associatedIDs
            }

            guard !mapping.isEmpty else {
                completion([:])
                return
            }

            request(valuesOrdered) { values in
                let mappedValues = values.createLookupTable()
                var results: [FetchedObject.ID: [AssociatedEntity]] = [:]
                for (objectID, associatedIDs) in mapping {
                    let associations: [AssociatedEntity] = associatedIDs.compactMap { mappedValues[$0] }
                    if !associations.isEmpty {
                        results[objectID] = associations
                    }
                }

                completion(results)
            }
        }

        let creationTokenGenerator: TokenGenerator<FetchedObject, FetchRequestObservableToken<Any>> = { parentObject in
            let entityIDs = parentObject[keyPath: keyPath]
            guard !entityIDs.isEmpty else {
                return nil
            }
            guard let token = creationTokenGenerator(entityIDs) else {
                return nil
            }
            return FetchRequestObservableToken(typeErasedToken: token)
        }

        let creationObserved: CreationObserved<Any, Any> = { lhs, rhs in
            let lhs = lhs as? [AssociatedEntity] ?? []
            guard let rhs = rhs as? AssociatedEntity.RawData else {
                return .same
            }
            let result = creationObserved(lhs, rhs)
            switch result {
            case .invalid:
                return .invalid

            case .same:
                return .same

            case let .changed(newValue):
                return .changed(newValue: newValue)
            }
        }

        let referenceGenerator: ReferenceGenerator = { parentObject in
            let creationObserver = creationTokenGenerator(parentObject)
            return FetchableAssociatedValueReference<AssociatedEntity>(
                creationObserver: creationObserver,
                creationObserved: creationObserved
            )
        }

        self.init(
            keyPath: keyPath,
            request: rawRequest,
            referenceGenerator: referenceGenerator,
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }

    /// Array association by optional entity IDs whose creation event can also be observed
    convenience init<
        AssociatedEntity: CWFetchableObject,
        Token: CWObservableToken
    > (
        for associatedType: Array<AssociatedEntity>.Type,
        keyPath: KeyPath<FetchedObject, [AssociatedEntity.ID]?>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<[AssociatedEntity.ID], Token>,
        creationObserved: @escaping CreationObserved<[AssociatedEntity], AssociatedEntity.RawData>
    ) where Token.Parameter == AssociatedEntity.RawData {
        let rawRequest: AssocationRequestByParent<Any> = { objects, completion in
            var valuesSet: Set<AssociatedEntity.ID> = []
            var valuesOrdered: [AssociatedEntity.ID] = []
            let mapping: [FetchedObject.ID: [AssociatedEntity.ID]] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                guard let associatedIDs: [AssociatedEntity.ID] = object[keyPath: keyPath],
                    !associatedIDs.isEmpty else
                {
                    return
                }
                for associatedID in associatedIDs {
                    guard !valuesSet.contains(associatedID) else {
                        continue
                    }
                    valuesSet.insert(associatedID)
                    valuesOrdered.append(associatedID)
                }
                memo[objectID] = associatedIDs
            }

            guard !mapping.isEmpty else {
                completion([:])
                return
            }

            request(valuesOrdered) { values in
                let mappedValues = values.createLookupTable()
                var results: [FetchedObject.ID: [AssociatedEntity]] = [:]
                for (objectID, associatedIDs) in mapping {
                    let associations: [AssociatedEntity] = associatedIDs.compactMap { mappedValues[$0] }
                    if !associations.isEmpty {
                        results[objectID] = associations
                    }
                }

                completion(results)
            }
        }

        let creationTokenGenerator: TokenGenerator<FetchedObject, FetchRequestObservableToken<Any>> = { parentObject in
            guard let entityIDs = parentObject[keyPath: keyPath], !entityIDs.isEmpty else {
                return nil
            }
            guard let token = creationTokenGenerator(entityIDs) else {
                return nil
            }
            return FetchRequestObservableToken(typeErasedToken: token)
        }

        let creationObserved: CreationObserved<Any, Any> = { lhs, rhs in
            let lhs = lhs as? [AssociatedEntity] ?? []
            guard let rhs = rhs as? AssociatedEntity.RawData else {
                return .same
            }
            let result = creationObserved(lhs, rhs)
            switch result {
            case .invalid:
                return .invalid

            case .same:
                return .same

            case let .changed(newValue):
                return .changed(newValue: newValue)
            }
        }

        let referenceGenerator: ReferenceGenerator = { parentObject in
            let creationObserver = creationTokenGenerator(parentObject)
            return FetchableAssociatedValueReference<AssociatedEntity>(
                creationObserver: creationObserver,
                creationObserved: creationObserved
            )
        }

        self.init(
            keyPath: keyPath,
            request: rawRequest,
            referenceGenerator: referenceGenerator,
            observeKeyPath: { object, changeHandler in
                return object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }
}

// MARK: - CWFetchableEntityID Associations

public extension CWFetchRequestAssociation {
    /// Association by non-optional entity ID whose creation event can also be observed
    convenience init<
        EntityID: CWFetchableEntityID,
        Token: CWObservableToken
    > (
        keyPath: KeyPath<FetchedObject, EntityID>,
        creationTokenGenerator: @escaping TokenGenerator<EntityID, Token>,
        preferExistingValueOnCreate: Bool
    ) where Token.Parameter == EntityID.FetchableEntity.RawData {
        typealias AssociatedType = EntityID.FetchableEntity

        var valuesSet: Set<EntityID> = []
        var valuesOrdered: [EntityID] = []

        let requestQuery: AssocationRequestByParent<AssociatedType> = { objects, completion in
            let mapping: [FetchedObject.ID: EntityID] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                let associatedID = object[keyPath: keyPath]
                if !valuesSet.contains(associatedID) {
                    valuesSet.insert(associatedID)
                    valuesOrdered.append(associatedID)
                }
                memo[objectID] = associatedID
            }

            guard !mapping.isEmpty else {
                completion([:])
                return
            }

            EntityID.fetch(byIDs: valuesOrdered) { values in
                let mappedValues: [EntityID: AssociatedType] = values.reduce(into: [:]) { memo, entry in
                    guard let compositeID = EntityID(from: entry) else {
                        return
                    }
                    memo[compositeID] = entry
                }

                var results: [FetchedObject.ID: AssociatedType] = [:]
                for (objectID, associatedID) in mapping {
                    if let association = mappedValues[associatedID] {
                        results[objectID] = association
                    }
                }

                completion(results)
            }
        }

        let tokenGenerator: TokenGenerator<FetchedObject, Token> = { parent in
            let associatedID = parent[keyPath: keyPath]
            return creationTokenGenerator(associatedID)
        }

        let creationObserved: CreationObserved<AssociatedType, AssociatedType.RawData> = { lhs, rhs in
            if preferExistingValueOnCreate, lhs != nil {
                return .same
            }
            guard let newValue = AssociatedType(data: rhs) else {
                return .same
            }
            return .changed(newValue: newValue)
        }

        self.init(
            keyPath: keyPath,
            request: requestQuery,
            creationTokenGenerator: tokenGenerator,
            creationObserved: creationObserved
        )
    }

    /// Association by optional entity ID whose creation event can also be observed
    convenience init<
        EntityID: CWFetchableEntityID,
        Token: CWObservableToken
    > (
        keyPath: KeyPath<FetchedObject, EntityID?>,
        creationTokenGenerator: @escaping TokenGenerator<EntityID, Token>,
        preferExistingValueOnCreate: Bool
    ) where Token.Parameter == EntityID.FetchableEntity.RawData {
        typealias AssociatedType = EntityID.FetchableEntity

        var valuesSet: Set<EntityID> = []
        var valuesOrdered: [EntityID] = []

        let requestQuery: AssocationRequestByParent<AssociatedType> = { objects, completion in
            let mapping: [FetchedObject.ID: EntityID] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                guard let associatedID = object[keyPath: keyPath] else {
                    return
                }
                if !valuesSet.contains(associatedID) {
                    valuesSet.insert(associatedID)
                    valuesOrdered.append(associatedID)
                }
                memo[objectID] = associatedID
            }

            guard !mapping.isEmpty else {
                completion([:])
                return
            }

            EntityID.fetch(byIDs: valuesOrdered) { values in
                let mappedValues: [EntityID: AssociatedType] = values.reduce(into: [:]) { memo, entry in
                    guard let compositeID = EntityID(from: entry) else {
                        return
                    }
                    memo[compositeID] = entry
                }

                var results: [FetchedObject.ID: AssociatedType] = [:]
                for (objectID, associatedID) in mapping {
                    if let association = mappedValues[associatedID] {
                        results[objectID] = association
                    }
                }

                completion(results)
            }
        }

        let tokenGenerator: TokenGenerator<FetchedObject, Token> = { parent in
            guard let associatedID = parent[keyPath: keyPath] else {
                return nil
            }
            return creationTokenGenerator(associatedID)
        }

        let creationObserved: CreationObserved<AssociatedType, AssociatedType.RawData> = { lhs, rhs in
            if preferExistingValueOnCreate, lhs != nil {
                return .same
            }
            guard let newValue = AssociatedType(data: rhs) else {
                return .same
            }
            return .changed(newValue: newValue)
        }

        self.init(
            keyPath: keyPath,
            request: requestQuery,
            creationTokenGenerator: tokenGenerator,
            creationObserved: creationObserved
        )
    }
}

// MARK: - Helpers

private extension Sequence where Iterator.Element: CWFetchableObjectProtocol {
    func createLookupTable() -> [Iterator.Element.ID: Iterator.Element] {
        return reduce(into: [:]) { memo, entry in
            memo[entry.id] = entry
        }
    }
}
