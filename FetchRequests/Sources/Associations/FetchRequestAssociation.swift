//
//  FetchRequestAssociation.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/23/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public enum AssociationReplacement<T> {
    case same
    case changed(newValue: T)
    case invalid
}

/// Map an associated value's key to object
public class FetchRequestAssociation<FetchedObject: FetchableObject> {
    /// Fetch associated values given a list of parent objects
    public typealias AssocationRequestByParent<AssociatedEntity> = @MainActor (
        _ objects: [FetchedObject],
        _ completion: @escaping @MainActor ([FetchedObject.ID: AssociatedEntity]) -> Void
    ) -> Void
    /// Fetch associated values given a list of associated IDs
    public typealias AssocationRequestByID<AssociatedEntityID: Hashable, AssociatedEntity> = @MainActor (
        _ objects: [AssociatedEntityID],
        _ completion: @escaping @MainActor ([AssociatedEntity]) -> Void
    ) -> Void
    /// Event that represents the creation of an associated value object
    public typealias CreationObserved<Value, Comparison> = (Value?, Comparison) -> AssociationReplacement<Value>
    /// Start observing a source object
    public typealias TokenGenerator<Source, Token: ObservableToken> = (Source) -> Token?

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
                guard let oldValue, let newValue else {
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

public extension FetchRequestAssociation {
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
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

public extension FetchRequestAssociation {
    /// Association by non-optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: FetchableObject,
        RawAssociatedEntity,
        AssociatedEntityID: Equatable,
        Token: ObservableToken<RawAssociatedEntity>
    >(
        keyPath: KeyPath<FetchedObject, AssociatedEntityID>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        creationObserved: @escaping CreationObserved<AssociatedEntity, RawAssociatedEntity>
    ) {
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
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
        AssociatedEntity: FetchableObject,
        RawAssociatedEntity,
        AssociatedEntityID: Equatable,
        Token: ObservableToken<RawAssociatedEntity>
    >(
        keyPath: KeyPath<FetchedObject, AssociatedEntityID?>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        creationObserved: @escaping CreationObserved<AssociatedEntity, RawAssociatedEntity>
    ) {
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
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
        AssociatedEntity: FetchableObject,
        AssociatedEntityID: Equatable,
        Token: ObservableToken<AssociatedEntity>
    >(
        keyPath: KeyPath<FetchedObject, AssociatedEntityID>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        preferExistingValueOnCreate: Bool
    ) {
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
        AssociatedEntity: FetchableObject,
        AssociatedEntityID: Equatable,
        Token: ObservableToken<AssociatedEntity>
    >(
        keyPath: KeyPath<FetchedObject, AssociatedEntityID?>,
        request: @escaping AssocationRequestByParent<AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<FetchedObject, Token>,
        preferExistingValueOnCreate: Bool
    ) {
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

public extension FetchRequestAssociation {
    /// Association by non-optional entity ID whose creation event can also be observed
    convenience init<
        AssociatedEntity: FetchableObject,
        Token: ObservableToken<AssociatedEntity.RawData>
    >(
        for associatedType: AssociatedEntity.Type,
        keyPath: KeyPath<FetchedObject, AssociatedEntity.ID>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<AssociatedEntity.ID, Token>,
        preferExistingValueOnCreate: Bool
    ) {
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
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
        AssociatedEntity: FetchableObject,
        Token: ObservableToken<AssociatedEntity.RawData>
    >(
        for associatedType: AssociatedEntity.Type,
        keyPath: KeyPath<FetchedObject, AssociatedEntity.ID?>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<AssociatedEntity.ID, Token>,
        preferExistingValueOnCreate: Bool
    ) {
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
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

public extension FetchRequestAssociation {
    /// Array association by non-optional entity IDs whose creation event can also be observed
    convenience init<
        AssociatedEntity: FetchableObject,
        Token: ObservableToken<AssociatedEntity.RawData>
    >(
        for associatedType: [AssociatedEntity].Type,
        keyPath: KeyPath<FetchedObject, [AssociatedEntity.ID]>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<[AssociatedEntity.ID], Token>,
        creationObserved: @escaping CreationObserved<[AssociatedEntity], AssociatedEntity.RawData>
    ) {
        self.init(
            for: associatedType,
            keyPath: keyPath,
            request: request,
            referenceAccessor: \.id,
            creationTokenGenerator: creationTokenGenerator,
            creationObserved: creationObserved
        )
    }

    /// Array association by non-optional entity references whose creation event can also be observed
    convenience init<
        AssociatedEntity: FetchableObject,
        Reference: Hashable,
        Token: ObservableToken<AssociatedEntity.RawData>
    >(
        for associatedType: [AssociatedEntity].Type,
        keyPath: KeyPath<FetchedObject, [Reference]>,
        request: @escaping AssocationRequestByID<Reference, AssociatedEntity>,
        referenceAccessor: @escaping (AssociatedEntity) -> Reference,
        creationTokenGenerator: @escaping TokenGenerator<[Reference], Token>,
        creationObserved: @escaping CreationObserved<[AssociatedEntity], AssociatedEntity.RawData>
    ) {
        let rawRequest: AssocationRequestByParent<Any> = { objects, completion in
            var valuesSet: Set<Reference> = []
            var valuesOrdered: [Reference] = []
            let mapping: [FetchedObject.ID: [Reference]] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                let associatedIDs: [Reference] = object[keyPath: keyPath]
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
                let mappedValues = values.associated(by: referenceAccessor)
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
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
        AssociatedEntity: FetchableObject,
        Token: ObservableToken<AssociatedEntity.RawData>
    >(
        for associatedType: [AssociatedEntity].Type,
        keyPath: KeyPath<FetchedObject, [AssociatedEntity.ID]?>,
        request: @escaping AssocationRequestByID<AssociatedEntity.ID, AssociatedEntity>,
        creationTokenGenerator: @escaping TokenGenerator<[AssociatedEntity.ID], Token>,
        creationObserved: @escaping CreationObserved<[AssociatedEntity], AssociatedEntity.RawData>
    ) {
        self.init(
            for: associatedType,
            keyPath: keyPath,
            request: request,
            referenceAccessor: \.id,
            creationTokenGenerator: creationTokenGenerator,
            creationObserved: creationObserved
        )
    }

    /// Array association by optional entity IDs whose creation event can also be observed
    convenience init<
        AssociatedEntity: FetchableObject,
        Reference: Hashable,
        Token: ObservableToken<AssociatedEntity.RawData>
    >(
        for associatedType: [AssociatedEntity].Type,
        keyPath: KeyPath<FetchedObject, [Reference]?>,
        request: @escaping AssocationRequestByID<Reference, AssociatedEntity>,
        referenceAccessor: @escaping (AssociatedEntity) -> Reference,
        creationTokenGenerator: @escaping TokenGenerator<[Reference], Token>,
        creationObserved: @escaping CreationObserved<[AssociatedEntity], AssociatedEntity.RawData>
    ) {
        let rawRequest: AssocationRequestByParent<Any> = { objects, completion in
            var valuesSet: Set<Reference> = []
            var valuesOrdered: [Reference] = []
            let mapping: [FetchedObject.ID: [Reference]] = objects.reduce(into: [:]) { memo, object in
                let objectID = object.id
                guard let associatedIDs: [Reference] = object[keyPath: keyPath],
                      !associatedIDs.isEmpty
                else {
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
                let mappedValues = values.associated(by: referenceAccessor)
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
                object.observe(keyPath, options: [.old, .new]) { object, change in
                    guard change.oldValue != change.newValue else {
                        return
                    }
                    changeHandler(object, change.oldValue, change.newValue)
                }
            }
        )
    }
}

// MARK: - FetchableEntityID Associations

public extension FetchRequestAssociation {
    /// Association by non-optional entity ID whose creation event can also be observed
    convenience init<
        EntityID: FetchableEntityID,
        Token: ObservableToken<EntityID.FetchableEntity.RawData>
    >(
        keyPath: KeyPath<FetchedObject, EntityID>,
        creationTokenGenerator: @escaping TokenGenerator<EntityID, Token>,
        preferExistingValueOnCreate: Bool
    ) {
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
        EntityID: FetchableEntityID,
        Token: ObservableToken<EntityID.FetchableEntity.RawData>
    >(
        keyPath: KeyPath<FetchedObject, EntityID?>,
        creationTokenGenerator: @escaping TokenGenerator<EntityID, Token>,
        preferExistingValueOnCreate: Bool
    ) {
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

private extension Sequence {
    func associated<Key: Hashable>(by keySelector: (Element) throws -> Key) rethrows -> [Key: Element] {
        try reduce(into: [:]) { memo, element in
            let key = try keySelector(element)
            memo[key] = element
        }
    }
}

private extension Sequence where Element: FetchableObjectProtocol {
    func createLookupTable() -> [Element.ID: Element] {
        self.associated(by: \.id)
    }
}
