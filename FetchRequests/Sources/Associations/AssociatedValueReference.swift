//
//  AssociatedValueReference.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 3/13/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

// MARK: - Internal Structures

struct AssociatedValueKey<FetchedObject: CWFetchableObject>: Hashable {
    var objectID: FetchedObject.ObjectID
    var keyPath: PartialKeyPath<FetchedObject>
}

class FetchableAssociatedValueReference<Entity: CWFetchableObject>: AssociatedValueReference {
    private var observations: [Entity: [KeyValueObservationToken]] = [:]

    fileprivate override func stopObservingValue() {
        observations.values.forEach { $0.forEach { $0.invalidate() } }
        observations.removeAll()
    }

    fileprivate override func startObservingValue() {
        let entities: [Entity]
        if let value = value as? Entity {
            entities = [value]
        } else if let value = value as? [Entity] {
            entities = value
        } else {
            entities = []
        }

        for entity in entities {
            observations[entity] = observeChanges(for: entity)
        }
    }

    private func observeChanges(for entity: Entity) -> [KeyValueObservationToken] {
        var tokens: [KeyValueObservationToken] = []

        entity.observingUpdates = true

        let dataObserver: KeyValueObservationToken = LegacyKeyValueObserving(
            object: entity,
            keyPath: Entity.dataKeyPath
        ) { [weak self] object, oldValue, newValue in
            guard !Entity.rawDataIsIdentical(lhs: oldValue, rhs: newValue) else {
                return
            }

            self?.changeHandler?(false)
        }

        let deleteObserver: KeyValueObservationToken = LegacyKeyValueObserving(
            object: entity,
            keyPath: Entity.deletedKeyPath
        ) { [weak self] object, oldValue, newValue in
            guard oldValue != newValue, newValue == true else {
                return
            }
            self?.observedDeletionEvent(with: entity)
        }

        tokens += [dataObserver, deleteObserver]

        return tokens
    }

    private func observedDeletionEvent(with entity: Entity) {
        var invalidate = false
        if let value = value as? Entity, value == entity {
            observations.removeAll()
            self.value = nil
        } else if let value = self.value as? [Entity] {
            observations[entity] = nil
            self.value = value.filter { !($0 == entity) }
        } else {
            invalidate = true
        }
        changeHandler?(invalidate)
    }
}

class AssociatedValueReference: NSObject {
    private let creationObserver: FetchRequestObservableToken<Any>?
    private let creationObserved: (Any?, Any) -> CWAssociationReplacement<Any>

    fileprivate(set) var value: Any?
    fileprivate var changeHandler: ((_ invalidate: Bool) -> Void)?

    var canObserveCreation: Bool {
        return creationObserver != nil
    }

    init(
        creationObserver: FetchRequestObservableToken<Any>? = nil,
        creationObserved: @escaping (Any?, Any) -> CWAssociationReplacement<Any> = { _, _ in .same },
        value: Any? = nil
    ) {
        self.creationObserver = creationObserver
        self.creationObserved = creationObserved
        self.value = value
    }

    deinit {
        stopObserving()
    }

    fileprivate func startObservingValue() { }

    fileprivate func stopObservingValue() { }
}

extension AssociatedValueReference {
    func stopObservingAndUpdateValue(to value: Any) {
        stopObserving()

        self.value = value
    }

    func observeChanges(_ changeHandler: @escaping (_ invalidate: Bool) -> Void) {
        stopObserving()

        self.changeHandler = changeHandler

        startObservingValue()

        creationObserver?.observeIfNeeded { [weak self] entity in
            assert(Thread.isMainThread)
            self?.observedCreationEvent(with: entity)
        }
    }

    func stopObserving() {
        guard changeHandler != nil else {
            return
        }

        stopObservingValue()

        creationObserver?.invalidateIfNeeded()

        changeHandler = nil
    }

    private func observedCreationEvent(with entity: Any) {
        // We just received a notification about an entity being created

        switch creationObserved(value, entity) {
        case .same:
            return

        case .invalid:
            changeHandler?(true)

        case let .changed(newValue):
            let currentChangeHandler = self.changeHandler

            stopObservingAndUpdateValue(to: newValue)

            if let currentChangeHandler = currentChangeHandler {
                observeChanges(currentChangeHandler)
                currentChangeHandler(false)
            }
        }
    }
}
