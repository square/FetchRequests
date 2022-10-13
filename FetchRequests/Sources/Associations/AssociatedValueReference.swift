//
//  AssociatedValueReference.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 3/13/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

// MARK: - Internal Structures

struct AssociatedValueKey<FetchedObject: FetchableObject>: Hashable {
    var id: FetchedObject.ID
    var keyPath: PartialKeyPath<FetchedObject>
}

class FetchableAssociatedValueReference<Entity: FetchableObject>: AssociatedValueReference {
    private var observations: [Entity: [InvalidatableToken]] = [:]

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

    private func observeChanges(for entity: Entity) -> [InvalidatableToken] {
        entity.listenForUpdates()

        let dataObserver = entity.observeDataChanges { [weak self] in
            self?.changeHandler?(false)
        }

        let isDeletedObserver = entity.observeIsDeletedChanges { [weak self, weak entity] in
            guard let entity else {
                return
            }
            self?.observedDeletionEvent(with: entity)
        }

        return [dataObserver, isDeletedObserver]
    }

    @MainActor
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
    typealias CreationObserved = @MainActor (_ value: Any?, _ entity: Any) -> AssociationReplacement<Any>
    typealias ChangeHandler = @MainActor (_ invalidate: Bool) -> Void

    private let creationObserver: FetchRequestObservableToken<Any>?
    private let creationObserved: CreationObserved

    fileprivate(set) var value: Any?
    fileprivate var changeHandler: ChangeHandler?

    var canObserveCreation: Bool {
        return creationObserver != nil
    }

    init(
        creationObserver: FetchRequestObservableToken<Any>? = nil,
        creationObserved: @escaping CreationObserved = { _, _ in .same },
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

    func observeChanges(_ changeHandler: @escaping ChangeHandler) {
        stopObserving()

        self.changeHandler = changeHandler

        startObservingValue()

        creationObserver?.observeIfNeeded { [weak self] entity in
            performOnMainThread {
                self?.observedCreationEvent(with: entity)
            }
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

    @MainActor
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

            if let currentChangeHandler {
                observeChanges(currentChangeHandler)
                currentChangeHandler(false)
            }
        }
    }
}
