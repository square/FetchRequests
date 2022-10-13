//
//  FetchedResultsController.swift
//  Crew
//
//  Created by Adam Lickel on 2/1/16.
//  Copyright © 2016 Speramus Inc. All rights reserved.
//

import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

// MARK: - Delegate

public enum FetchedResultsChange<Location: Equatable>: Equatable {
    case insert(location: Location)
    case delete(location: Location)
    case update(location: Location)

    case move(from: Location, to: Location)

    public static func == (lhs: FetchedResultsChange<Location>, rhs: FetchedResultsChange<Location>) -> Bool {
        switch (lhs, rhs) {
        case let (.insert(left), .insert(right)):
            return left == right

        case let (.delete(left), .delete(right)):
            return left == right

        case let (.update(left), .update(right)):
            return left == right

        case let (.move(leftFrom, leftTo), .move(rightFrom, rightTo)):
            return leftFrom == rightFrom && leftTo == rightTo

        case (.insert, _), (.update, _), (.delete, _), (.move, _):
            return false
        }
    }
}

@MainActor
public protocol FetchedResultsControllerDelegate<FetchedObject>: AnyObject {
    associatedtype FetchedObject: FetchableObject

    func controllerWillChangeContent(_ controller: FetchedResultsController<FetchedObject>)
    func controllerDidChangeContent(_ controller: FetchedResultsController<FetchedObject>)

    func controller(
        _ controller: FetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    )
    func controller(
        _ controller: FetchedResultsController<FetchedObject>,
        didChange section: FetchedResultsSection<FetchedObject>,
        for change: FetchedResultsChange<Int>
    )
}

public extension FetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: FetchedResultsController<FetchedObject>) {}
    func controllerDidChangeContent(_ controller: FetchedResultsController<FetchedObject>) {}

    func controller(
        _ controller: FetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
    }

    func controller(
        _ controller: FetchedResultsController<FetchedObject>,
        didChange section: FetchedResultsSection<FetchedObject>,
        for change: FetchedResultsChange<Int>
    ) {
    }
}

internal class FetchResultsDelegate<FetchedObject: FetchableObject> {
    typealias Controller = FetchedResultsController<FetchedObject>
    typealias Section = FetchedResultsSection<FetchedObject>

    private let willChange: @MainActor (_ controller: Controller) -> Void
    private let didChange: @MainActor (_ controller: Controller) -> Void

    private let changeObject: @MainActor (_ controller: Controller, _ object: FetchedObject, _ change: FetchedResultsChange<IndexPath>) -> Void
    private let changeSection: @MainActor (_ controller: Controller, _ section: Section, _ change: FetchedResultsChange<Int>) -> Void

    init<Parent: FetchedResultsControllerDelegate>(
        _ parent: Parent
    ) where Parent.FetchedObject == FetchedObject {
        willChange = { [weak parent] controller in
            parent?.controllerWillChangeContent(controller)
        }
        didChange = { [weak parent] controller in
            parent?.controllerDidChangeContent(controller)
        }

        changeObject = { [weak parent] controller, object, change in
            parent?.controller(controller, didChange: object, for: change)
        }
        changeSection = { [weak parent] controller, section, change in
            parent?.controller(controller, didChange: section, for: change)
        }
    }
}

extension FetchResultsDelegate: FetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: Controller) {
        self.willChange(controller)
    }

    func controllerDidChangeContent(_ controller: Controller) {
        self.didChange(controller)
    }

    func controller(
        _ controller: Controller,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
        self.changeObject(controller, object, change)
    }

    func controller(
        _ controller: Controller,
        didChange section: Section,
        for change: FetchedResultsChange<Int>
    ) {
        self.changeSection(controller, section, change)
    }
}

// MARK: - Errors

public enum FetchedResultsError: Error {
    case objectNotFound
}

// MARK: - Sections

public struct FetchedResultsSection<FetchedObject: FetchableObject>: Equatable, Identifiable {
    public let name: String
    public fileprivate(set) var objects: [FetchedObject]

    public var id: String {
        return name
    }

    public var numberOfObjects: Int {
        return objects.count
    }

    public init(name: String, objects: [FetchedObject] = []) {
        self.name = name
        self.objects = objects
    }
}

// MARK: - FetchedResultsController

func performOnMainThread(async: Bool = true, handler: @escaping @MainActor () -> Void) {
    if !Thread.isMainThread {
        if async {
            DispatchQueue.main.async(execute: handler)
        } else {
            DispatchQueue.main.sync(execute: handler)
        }
    } else {
        @MainActor(unsafe)
        func unsafeHandler() {
            handler()
        }
        unsafeHandler()
    }
}

public class FetchedResultsController<FetchedObject: FetchableObject>: NSObject, FetchedResultsControllerProtocol {
    public typealias Section = FetchedResultsSection<FetchedObject>
    public typealias SectionNameKeyPath = KeyPath<FetchedObject, String>

    public let definition: FetchDefinition<FetchedObject>
    public let sectionNameKeyPath: SectionNameKeyPath?
    private var rawSortDescriptors: [NSSortDescriptor] {
        didSet {
            sortDescriptors = rawSortDescriptors.finalize(with: self)
        }
    }
    public private(set) var sortDescriptors: [NSSortDescriptor] = []

    private var observationTokens: [ObjectIdentifier: [InvalidatableToken]] = [:]

    private var associatedValues: [AssociatedValueKey<FetchedObject>: AssociatedValueReference] = [:]

    private lazy var memoryPressureToken: FetchRequestObservableToken<Notification>? = {
#if canImport(UIKit) && !os(watchOS)
        return FetchRequestObservableToken(
            token: ObservableNotificationCenterToken(name: UIApplication.didReceiveMemoryWarningNotification)
        )
#else
        return nil
#endif
    }()

    // swiftlint:disable:next weak_delegate
    private var delegate: FetchResultsDelegate<FetchedObject>?

    public var associatedFetchSize: Int = 10

    public private(set) var hasFetchedObjects: Bool = false
    public private(set) var fetchedObjects: [FetchedObject] = []
    fileprivate private(set) var fetchedObjectIDs: OrderedSet<FetchedObject.ID> = []

    private var _indexPathsTable: [FetchedObject: IndexPath]?
    private var indexPathsTable: [FetchedObject: IndexPath] {
        if let existing = _indexPathsTable {
            return existing
        }

        let new = generateIndexPathsTable()
        _indexPathsTable = new
        return new
    }

    private let debounceInsertsAndReloads: Bool
    private var objectsToReload: Set<FetchedObject> = []
    private var objectsToInsert: OrderedSet<FetchedObject> = []

    private let objectWillChangeSubject = PassthroughSubject<Void, Never>()
    private let objectDidChangeSubject = PassthroughSubject<Void, Never>()

    public private(set) lazy var objectWillChange = objectWillChangeSubject.eraseToAnyPublisher()
    public private(set) lazy var objectDidChange = objectDidChangeSubject.eraseToAnyPublisher()

    public private(set) var sections: [Section] = [] {
        didSet {
            _indexPathsTable = nil
        }
    }

    private lazy var context: Context<FetchedObject> = {
        return Context { [weak self] keyPath, objectID in
            guard let self else {
                throw FetchedResultsError.objectNotFound
            }

            return try self.unsafeAssociatedValue(with: keyPath, forObjectID: objectID)
        }
    }()

    public init(
        definition: FetchDefinition<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true
    ) {
        self.definition = definition
        self.rawSortDescriptors = sortDescriptors
        self.sectionNameKeyPath = sectionNameKeyPath
        self.debounceInsertsAndReloads = debounceInsertsAndReloads

        super.init()

        self.sortDescriptors = sortDescriptors.finalize(with: self)
    }

    deinit {
        performOnMainThread(async: false) {
            self.reset(emitChanges: false)
        }
    }

    public func setDelegate<
        Delegate: FetchedResultsControllerDelegate
    >(
        _ delegate: Delegate?
    ) where Delegate.FetchedObject == FetchedObject {
        self.delegate = delegate.flatMap {
            FetchResultsDelegate($0)
        }
    }

    public func clearDelegate() {
        self.delegate = nil
    }

    // MARK: - Actions

    @objc
    @MainActor
    private func debouncedReload() {
        assert(Thread.isMainThread)

        guard !objectsToReload.isEmpty else {
            return
        }
        reload(objectsToReload)
        objectsToReload.removeAll()
    }

    @objc
    @MainActor
    private func debouncedInsert() {
        assert(Thread.isMainThread)

        guard !objectsToInsert.isEmpty else {
            return
        }
        insert(objectsToInsert) {
            // Finished insert
        }
        objectsToInsert.removeAll()
    }

    @objc
    @MainActor
    private func debouncedFetch() {
        assert(Thread.isMainThread)

        performFetch()
    }
}

// MARK: Fetches

public extension FetchedResultsController {
    @MainActor
    func performFetch(completion: @escaping () -> Void) {
        startObservingNotificationsIfNeeded()

        definition.request { [weak self] objects in
            self?.assign(fetchedObjects: objects, completion: completion)
        }
    }

    @MainActor
    func resort(using newSortDescriptors: [NSSortDescriptor], completion: @escaping () -> Void) {
        assert(Thread.isMainThread)

        rawSortDescriptors = newSortDescriptors

        guard hasFetchedObjects else {
            completion()
            return
        }

        assign(
            fetchedObjects: fetchedObjects,
            updateFetchOrder: false,
            dropObjectsToInsert: false,
            completion: completion
        )
    }

    func indexPath(for object: FetchedObject) -> IndexPath? {
        return indexPathsTable[object]
    }

    @MainActor
    func reset() {
        reset(emitChanges: true)
    }

    @MainActor
    private func reset(emitChanges: Bool) {
        stopObservingNotifications()
        removeAll(emitChanges: emitChanges)
    }
}

// MARK: Associated Values

private extension FetchedResultsController {
    func unsafeAssociatedValue(
        with keyPath: PartialKeyPath<FetchedObject>,
        forObjectID objectID: FetchedObject.ID
    ) throws -> Any? {
        let key = AssociatedValueKey(id: objectID, keyPath: keyPath)

        if let holder = associatedValues[key] {
            return holder.value
        }

        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                do {
                    try self?.fetchAssociatedValues(around: key)
                } catch {
                    CWLogVerbose("Invalid async association request for \(key): \(error)")
                }
            }
            return nil
        } else {
            try fetchAssociatedValues(around: key)

            // On the off chance that the fetch is synchronous, return the new hash value
            let holder = associatedValues[key]
            return holder?.value
        }
    }

    @MainActor(unsafe)
    func fetchAssociatedValues(
        around key: AssociatedValueKey<FetchedObject>
    ) throws {
        assert(Thread.isMainThread)

        guard let index = fetchedObjects.firstIndex(where: { $0.id == key.id }) else {
            throw FetchedResultsError.objectNotFound
        }

        guard let association = definition.associationsByKeyPath[key.keyPath] else {
            throw FetchedResultsError.objectNotFound
        }

        let objects: [FetchedObject]
        if associatedFetchSize == 0 {
            objects = fetchedObjects
        } else {
            let difference = associatedFetchSize / 2
            let smallIndex = max(0, index - difference)
            let largeIndex = min(fetchedObjects.endIndex - 1, index + difference)

            objects = Array(fetchedObjects[smallIndex ... largeIndex])
        }
        let fetchableObjects = objects.filter {
            let objectID = $0.id
            let key = AssociatedValueKey(id: objectID, keyPath: key.keyPath)
            return associatedValues[key] == nil
        }

        var valueReferences: [AssociatedValueKey<FetchedObject>: AssociatedValueReference] = [:]

        for object in fetchableObjects {
            // Mark fetchable objects as visited
            let objectID = object.id
            let key = AssociatedValueKey(id: objectID, keyPath: key.keyPath)
            let reference = association.referenceGenerator(object)

            valueReferences[key] = reference
            associatedValues[key] = reference
        }

        association.request(fetchableObjects) { [weak self] values in
            self?.assignAssociatedValues(
                values,
                with: key.keyPath,
                for: fetchableObjects,
                references: valueReferences
            )
        }
    }
}

// MARK: Contents

private extension FetchedResultsController {
    @MainActor
    func assignAssociatedValues(
        _ values: [FetchedObject.ID: Any],
        with keyPath: PartialKeyPath<FetchedObject>,
        for objects: [FetchedObject],
        references: [AssociatedValueKey<FetchedObject>: AssociatedValueReference],
        emitChanges: Bool = true
    ) {
        assert(Thread.isMainThread)

        performChanges(emitChanges: emitChanges) {
            for object in objects {
                guard let indexPath = indexPath(for: object) else {
                    continue
                }

                let objectID = object.id
                guard let value = values[objectID] else {
                    continue
                }

                let key = AssociatedValueKey(id: objectID, keyPath: keyPath)
                let reference = references[key]

                reference?.stopObservingAndUpdateValue(to: value)

                notifyUpdating(object, at: indexPath, emitChanges: emitChanges)
            }
        }

        for object in objects {
            let objectID = object.id
            let key = AssociatedValueKey(id: objectID, keyPath: keyPath)
            let reference = references[key]

            reference?.observeChanges { [weak self, weak object] invalid in
                assert(Thread.isMainThread)

                guard let object else {
                    return
                }

                if invalid {
                    self?.associatedValues[key] = nil
                }

                self?.enqueueReload(of: object)
            }
        }
    }

    @MainActor
    func removeAssociatedValue(
        for object: FetchedObject,
        keyPath: PartialKeyPath<FetchedObject>,
        emitChanges: Bool = true
    ) {
        assert(Thread.isMainThread)

        let objectID = object.id
        guard let indexPath = indexPath(for: object) else {
            return
        }

        performChanges(emitChanges: emitChanges) {
            let key = AssociatedValueKey(id: objectID, keyPath: keyPath)
            associatedValues[key] = nil

            notifyUpdating(object, at: indexPath, emitChanges: emitChanges)
        }
    }

    @MainActor
    func assign(
        fetchedObjects objects: [FetchedObject],
        updateFetchOrder: Bool = true,
        emitChanges: Bool = true,
        dropObjectsToInsert: Bool = true,
        completion: @escaping () -> Void
    ) {
        assert(Thread.isMainThread)

        unsafeAssign(
            fetchedObjects: objects,
            updateFetchOrder: updateFetchOrder,
            emitChanges: emitChanges,
            dropObjectsToInsert: dropObjectsToInsert,
            completion: completion
        )
    }

    private func unsafeAssign(
        fetchedObjects objects: [FetchedObject],
        updateFetchOrder: Bool = true,
        emitChanges: Bool = true,
        dropObjectsToInsert: Bool = true,
        completion: @escaping () -> Void
    ) {
        guard objects.count <= 100 || !Thread.isMainThread else {
            // Bounce ourself off of the main queue
            Task.detached(priority: .userInitiated) { [weak self] in
                assert(!Thread.isMainThread)
                self?.unsafeAssign(
                    fetchedObjects: objects,
                    emitChanges: emitChanges,
                    completion: completion
                )
            }
            return
        }

        let fetchOrder = updateFetchOrder ? OrderedSet(objects.map(\.id)) : fetchedObjectIDs
        let sortedObjects = sortedAssignableObjects(objects, fetchOrder: fetchOrder)

        guard !sortedObjects.isEmpty else {
            return
        }

        performOnMainThread {
            self.assign(
                sortedObjects: sortedObjects,
                initialOrder: fetchOrder,
                emitChanges: emitChanges,
                dropObjectsToInsert: dropObjectsToInsert
            )
            completion()
        }
    }

    private func sortedAssignableObjects<C: Collection>(
        _ objects: C,
        fetchOrder: OrderedSet<FetchedObject.ID>
    ) -> [FetchedObject] where C.Element == FetchedObject {
        let sortDescriptors = rawSortDescriptors.finalize(sectionNameKeyPath: sectionNameKeyPath) { id in
            fetchOrder.firstIndex(of: id)
        }

        let sortedObjects = objects.sorted(by: sortDescriptors)

        return sortedObjects
    }

    @MainActor
    func assign<C: BidirectionalCollection>(
        sortedObjects objects: C,
        initialOrder: OrderedSet<FetchedObject.ID>,
        emitChanges: Bool,
        dropObjectsToInsert: Bool
    ) where C.Element == FetchedObject {
        assert(Thread.isMainThread)

        if dropObjectsToInsert {
            objectsToInsert.removeAll()
        }

        performChanges(emitChanges: emitChanges) {
            fetchedObjectIDs = initialOrder

            let operations = objects.difference(from: fetchedObjects)

            for operation in operations {
                switch operation {
                case let .remove(index, element, _):
                    remove(element, atIndex: index, emitChanges: emitChanges)

                case let .insert(index, element, _):
                    insert(element, atIndex: index, emitChanges: emitChanges)
                }
            }
        }
    }

    @MainActor
    func delete(_ object: FetchedObject, emitChanges: Bool = true) throws {
        guard let indexPath = indexPath(for: object), let fetchIndex = fetchIndex(for: indexPath) else {
            throw FetchedResultsError.objectNotFound
        }

        performChanges(emitChanges: emitChanges) {
            fetchedObjectIDs.remove(object.id)
            remove(object, atIndex: fetchIndex, emitChanges: emitChanges)
        }
    }

    @MainActor
    func insert<C: Collection>(
        _ objects: C,
        emitChanges: Bool = true,
        completion: @escaping () -> Void
    ) where C.Element == FetchedObject {
        // This is snapshotted because we're potentially about to be off the main thread
        let fetchedObjectIDs = self.fetchedObjectIDs

        unsafeInsert(
            objects,
            fetchedObjectIDs: fetchedObjectIDs,
            emitChanges: emitChanges,
            completion: completion
        )
    }

    private func sortedInsertableObjects<C: Collection>(
        _ objects: C,
        initialOrder: OrderedSet<FetchedObject.ID>,
        fetchedObjectIDs: OrderedSet<FetchedObject.ID>
    ) -> [FetchedObject] where C.Element == FetchedObject {
        let initialOrder = OrderedSet(objects.map(\.id))

        let fetchOrder = fetchedObjectIDs.union(initialOrder)
        let sortDescriptors = rawSortDescriptors.finalize(sectionNameKeyPath: sectionNameKeyPath) { id in
            fetchOrder.firstIndex(of: id)
        }

        let sortedObjects = objects.filter { object in
            guard !object.isDeleted else {
                return false
            }
            return !fetchedObjectIDs.contains(object.id)
        }.sorted(by: sortDescriptors)

        return sortedObjects
    }

    private func unsafeInsert<C: Collection>(
        _ objects: C,
        fetchedObjectIDs: OrderedSet<FetchedObject.ID>,
        emitChanges: Bool = true,
        completion: @escaping () -> Void
    ) where C.Element == FetchedObject {
        guard objects.count <= 100 || !Thread.isMainThread else {
            // Bounce ourself off of the main queue
            Task.detached(priority: .userInitiated) { [weak self] in
                assert(!Thread.isMainThread)
                self?.unsafeInsert(
                    objects,
                    fetchedObjectIDs: fetchedObjectIDs,
                    emitChanges: emitChanges,
                    completion: completion
                )
            }
            return
        }

        let initialOrder = OrderedSet(objects.map(\.id))
        let sortedObjects = sortedInsertableObjects(
            objects,
            initialOrder: initialOrder,
            fetchedObjectIDs: fetchedObjectIDs
        )

        guard !sortedObjects.isEmpty else {
            return
        }

        performOnMainThread {
            self.insert(
                sortedObjects: sortedObjects,
                initialOrder: initialOrder,
                emitChanges: emitChanges
            )
            completion()
        }
    }

    @MainActor
    private func insert<C: BidirectionalCollection>(
        sortedObjects objects: C,
        initialOrder: OrderedSet<FetchedObject.ID>,
        emitChanges: Bool = true
    ) where C.Element == FetchedObject {
        assert(Thread.isMainThread)

        performChanges(emitChanges: emitChanges) {
            fetchedObjectIDs.formUnion(initialOrder)

            for object in objects {
                guard !object.isDeleted else {
                    continue
                }
                let newFetchIndex = idealObjectIndex(for: object, inArray: fetchedObjects)

                if newFetchIndex != fetchedObjects.count {
                    guard fetchedObjects[newFetchIndex] != object else {
                        continue
                    }
                }

                insert(object, atIndex: newFetchIndex, emitChanges: emitChanges)
            }
        }

        CWLogVerbose("Inserted \(objects.count) objects")
    }

    @MainActor
    func reload<C: Collection>(
        _ objects: C,
        emitChanges: Bool = true
    ) where C.Element == FetchedObject {
        var objectPaths: [FetchedObject: IndexPath] = [:]
        for object in objects {
            guard let indexPath = indexPath(for: object) else {
                CWLogError("Failed to reload object with ID: \(object.id)")
                continue
            }
            objectPaths[object] = indexPath
        }

        guard !objectPaths.isEmpty else {
            return
        }

        performChanges(emitChanges: emitChanges) {
            for (object, indexPath) in objectPaths {
                notifyUpdating(object, at: indexPath, emitChanges: emitChanges)
            }
        }

        CWLogVerbose("Reloaded \(objects.count) objects")
    }

    @MainActor
    func move(_ object: FetchedObject, emitChanges: Bool = true) throws {
        guard let indexPath = indexPath(for: object) else {
            throw FetchedResultsError.objectNotFound
        }

        try move(object, from: indexPath, emitChanges: emitChanges)
    }

    @MainActor
    func move(_ object: FetchedObject, fromSectionName sectionName: String, emitChanges: Bool = true) throws {
        guard !sections.isEmpty else {
            throw FetchedResultsError.objectNotFound
        }

        let sectionIndex = idealSectionIndex(forSectionName: sectionName)
        guard sectionIndex < sections.count,
              let itemIndex = sections[sectionIndex].objects.firstIndex(of: object)
        else {
            throw FetchedResultsError.objectNotFound
        }

        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
        try move(object, from: indexPath, emitChanges: emitChanges)
    }

    @MainActor
    func move(_ object: FetchedObject, from fromIndexPath: IndexPath, emitChanges: Bool = true) throws {
        guard let oldFetchIndex = fetchIndex(for: fromIndexPath), object == self.object(at: fromIndexPath) else {
            throw FetchedResultsError.objectNotFound
        }

        performChanges(emitChanges: emitChanges) {
            let newSectionName = object.sectionName(forKeyPath: sectionNameKeyPath)
            var newSectionIndex = idealSectionIndex(forSectionName: newSectionName)

            let addedSection: Bool
            let changedSection: Bool
            if sections.endIndex <= newSectionIndex || sections[newSectionIndex].name != newSectionName {
                addedSection = true
                changedSection = true
            } else if fromIndexPath.section != newSectionIndex {
                addedSection = false
                changedSection = true
            } else {
                addedSection = false
                changedSection = false
            }

            let removedSection: Bool
            if changedSection {
                let oldSection = sections[fromIndexPath.section]
                removedSection = oldSection.numberOfObjects == 1
            } else {
                removedSection = false
            }

            // Remove our entry
            sections[fromIndexPath.section].objects.remove(at: fromIndexPath.item)

            if removedSection || addedSection {
                // Moves don't work if we made a section change
                notifyDeleting(object, at: fromIndexPath, emitChanges: emitChanges)
            }

            if removedSection {
                // Remove our old section
                let oldSection = sections.remove(at: fromIndexPath.section)

                notifyDeleting(oldSection, at: fromIndexPath.section, emitChanges: emitChanges)

                newSectionIndex = idealSectionIndex(forSectionName: newSectionName)
            }

            if addedSection {
                // Insert our new section

                let newSection = Section(name: newSectionName)
                sections.insert(newSection, at: newSectionIndex)

                notifyInserting(newSection, at: newSectionIndex, emitChanges: emitChanges)
            }

            let newObjectIndex = idealObjectIndex(for: object, inArray: sections[newSectionIndex].objects)

            sections[newSectionIndex].objects.insert(object, at: newObjectIndex)

            fetchedObjects.remove(at: oldFetchIndex)
            let newFetchIndex = idealObjectIndex(for: object, inArray: fetchedObjects)
            fetchedObjects.insert(object, at: newFetchIndex)

            let toIndexPath = IndexPath(item: newObjectIndex, section: newSectionIndex)

            if removedSection || addedSection {
                notifyInserting(object, at: toIndexPath, emitChanges: emitChanges)
            } else {
                notifyMoving(object, from: fromIndexPath, to: toIndexPath, emitChanges: emitChanges)
            }
        }
    }

    @MainActor
    func removeAll(emitChanges: Bool = true) {
        performChanges(emitChanges: emitChanges, updateHasFetchedObjects: false) {
            if let delegate, emitChanges {
                for (sectionIndex, section) in sections.enumerated().reversed() {
                    for (objectIndex, object) in section.objects.enumerated().reversed() {
                        let indexPath = IndexPath(item: objectIndex, section: sectionIndex)
                        delegate.controller(self, didChange: object, for: .delete(location: indexPath))
                    }

                    delegate.controller(self, didChange: section, for: .delete(location: sectionIndex))
                }
            }

            for object in fetchedObjects {
                stopObserving(object)
            }

            rawRemoveAll()
        }
    }

    @MainActor
    private func rawRemoveAll() {
        hasFetchedObjects = false
        fetchedObjects = []
        sections = []
        fetchedObjectIDs = []
        associatedValues = [:]
    }

    @MainActor
    func removeAllAssociatedValues(emitChanges: Bool = true) {
        performChanges(emitChanges: emitChanges) {
            for (sectionIndex, section) in sections.enumerated() {
                for (objectIndex, object) in section.objects.enumerated() {
                    let indexPath = IndexPath(item: objectIndex, section: sectionIndex)

                    notifyUpdating(object, at: indexPath, emitChanges: emitChanges)
                }
            }
            associatedValues = [:]
        }
    }

    @MainActor
    func remove(_ object: FetchedObject, atIndex index: Int, emitChanges: Bool = true) {
        guard let indexPath = self.indexPath(forFetchIndex: index) else {
            return
        }

        stopObserving(object)

        fetchedObjects.remove(at: index)
        sections[indexPath.section].objects.remove(at: indexPath.item)

        notifyDeleting(object, at: indexPath, emitChanges: emitChanges)

        if sections[indexPath.section].objects.isEmpty {
            let section = sections.remove(at: indexPath.section)
            notifyDeleting(section, at: indexPath.section, emitChanges: emitChanges)
        }
    }

    @MainActor
    func insert(_ object: FetchedObject, atIndex index: Int, emitChanges: Bool = true) {
        assert(fetchedObjectIDs.contains(object.id))

        let sectionName = object.sectionName(forKeyPath: sectionNameKeyPath)
        let sectionIndex = idealSectionIndex(forSectionName: sectionName)

        let sectionPrefix = sections[0 ..< sectionIndex].reduce(0) { $0 + $1.numberOfObjects }
        let sectionObjectIndex = index - sectionPrefix

        if sections.endIndex <= sectionIndex || sections[sectionIndex].name != sectionName {
            assert(sectionObjectIndex == 0, "For some reason a section wasn't deleted")
            let section = Section(name: sectionName)
            sections.insert(section, at: sectionIndex)

            notifyInserting(section, at: sectionIndex, emitChanges: emitChanges)
        }

        fetchedObjects.insert(object, at: index)
        sections[sectionIndex].objects.insert(object, at: sectionObjectIndex)

        let indexPath = IndexPath(item: sectionObjectIndex, section: sectionIndex)
        notifyInserting(object, at: indexPath, emitChanges: emitChanges)

        startObserving(object)
    }

    @MainActor
    func startObserving(_ object: FetchedObject) {
        assert(Thread.isMainThread)

        var observations: [InvalidatableToken] = []

        for association in definition.associations {
            let keyPath = association.keyPath
            let observer = association.observeKeyPath(object) { [weak self] object, oldValue, newValue in
                // Nil out associated value and send change event
                self?.removeAssociatedValue(for: object, keyPath: keyPath)
            }

            observations.append(observer)
        }

        let handleChange: @MainActor (FetchedObject) -> Void = { [weak self] object in
            assert(Thread.isMainThread)

            guard let self else {
                return
            }
            do {
                if object.isDeleted {
                    try self.delete(object)
                } else {
                    self.enqueueReload(of: object)
                }
            } catch {
                CWLogInfo("Failed to reload object \(object)?!")
            }
        }

        let dataObserver = object.observeDataChanges { [weak object] in
            guard let object else {
                return
            }
            handleChange(object)
        }

        let isDeletedObserver = object.observeIsDeletedChanges { [weak object] in
            guard let object else {
                return
            }
            handleChange(object)
        }

        observations += [dataObserver, isDeletedObserver]

        let handleSort: @MainActor (FetchedObject, Bool, Any?, Any?) -> Void = { [weak self] object, isSection, old, new in
            assert(Thread.isMainThread)

            guard let self else {
                return
            }

            if let old = old as? NSObject, let new = new as? NSObject {
                guard old != new else {
                    return
                }
            }

            do {
                if isSection, let oldName = old as? String {
                    try self.move(object, fromSectionName: oldName)
                } else {
                    try self.move(object)
                }
            } catch {
                CWLogInfo("Failed to move object \(object)?!")
            }
        }

        for (index, sort) in sortDescriptors.enumerated() {
            guard let keyPath = sort.key, keyPath != "self" else {
                continue
            }
            let isSectionNameKeyPath: Bool
            if sectionNameKeyPath != nil, index == 0 {
                isSectionNameKeyPath = true
            } else {
                isSectionNameKeyPath = false
            }

            let observation = LegacyKeyValueObserving(
                object: object,
                keyPath: keyPath,
                type: Any.self
            ) { object, oldValue, newValue in
                handleSort(object, isSectionNameKeyPath, oldValue, newValue)
            }
            observations.append(observation)
        }

        object.listenForUpdates()
        object.context = context

        observationTokens[ObjectIdentifier(object)] = observations
    }

    @MainActor
    func stopObserving(_ object: FetchedObject) {
        assert(Thread.isMainThread)

        object.context = nil
        observationTokens[ObjectIdentifier(object)] = nil
    }

    @MainActor
    func startObservingNotificationsIfNeeded() {
        assert(Thread.isMainThread)

        memoryPressureToken?.observeIfNeeded { [weak self] notification in
            performOnMainThread {
                self?.removeAllAssociatedValues()
            }
        }
        definition.objectCreationToken.observeIfNeeded { [weak self] data in
            performOnMainThread {
                self?.observedObjectUpdate(data)
            }
        }

        for dataResetToken in definition.dataResetTokens {
            dataResetToken.observeIfNeeded { [weak self] _ in
                performOnMainThread {
                    self?.handleDatabaseClear()
                }
            }
        }
    }

    @MainActor
    func stopObservingNotifications() {
        assert(Thread.isMainThread)

        memoryPressureToken?.invalidateIfNeeded()
        definition.objectCreationToken.invalidateIfNeeded()

        for dataResetToken in definition.dataResetTokens {
            dataResetToken.invalidateIfNeeded()
        }
    }
}

// MARK: - Object Updates

private extension FetchedResultsController {
    @MainActor
    func observedObjectUpdate(_ data: FetchedObject.RawData) {
        guard let id = FetchedObject.entityID(from: data) else {
            return
        }

        guard !fetchedObjectIDs.contains(id) else {
            return
        }

        guard definition.creationInclusionCheck(data) else {
            return
        }

        enqueueInsert(of: data)
    }
}

// MARK: - Debouncing

private extension FetchedResultsController {
    @MainActor
    func enqueueReload(of object: FetchedObject, emitChanges: Bool = true) {
        assert(Thread.isMainThread)

        guard debounceInsertsAndReloads else {
            reload([object], emitChanges: emitChanges)
            return
        }

        objectsToReload.insert(object)

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(debouncedReload), object: nil)
        perform(#selector(debouncedReload), with: nil, afterDelay: 0)
    }

    @MainActor
    func enqueueInsert(of object: FetchedObject.RawData, emitChanges: Bool = true) {
        guard let insertedObject = FetchedObject(data: object) else {
            return
        }
        manuallyInsert(objects: [insertedObject], emitChanges: emitChanges)
    }

    @MainActor
    func handleDatabaseClear() {
        assert(Thread.isMainThread)

        guard debounceInsertsAndReloads else {
            performFetch()
            return
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(debouncedFetch), object: nil)
        perform(#selector(debouncedFetch), with: nil, afterDelay: 0)
    }
}

internal extension FetchedResultsController {
    var listeningForInserts: Bool {
        return definition.objectCreationToken.isObserving
    }
}

// MARK: - InternalFetchResultsControllerProtocol

extension FetchedResultsController: InternalFetchResultsControllerProtocol {
    internal func manuallyInsert(objects: [FetchedObject], emitChanges: Bool = true) {
        assert(Thread.isMainThread)

        guard listeningForInserts, !objects.isEmpty else {
            return
        }

        objects.forEach { $0.listenForUpdates() }

        guard debounceInsertsAndReloads else {
            insert(objects, emitChanges: emitChanges) {
                // Finished insert
            }
            return
        }

        objectsToInsert.formUnion(objects)

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(debouncedInsert), object: nil)
        perform(#selector(debouncedInsert), with: nil, afterDelay: 0)
    }
}

// MARK: Delegate Change Events

private extension FetchedResultsController {
    @MainActor
    func performChanges(
        emitChanges: Bool = true,
        updateHasFetchedObjects: Bool = true,
        changes: () -> Void
    ) {
        assert(Thread.isMainThread)
        let delegate = self.delegate

        if emitChanges {
            objectWillChangeSubject.send()
            delegate?.controllerWillChangeContent(self)
        }

        changes()

        if updateHasFetchedObjects {
            hasFetchedObjects = true
        }

        if emitChanges {
            delegate?.controllerDidChangeContent(self)
            objectDidChangeSubject.send()
        }
    }

    func generateIndexPathsTable() -> [FetchedObject: IndexPath] {
        var updatedIndexPaths: [FetchedObject: IndexPath] = [:]
        for (sectionIndex, section) in sections.enumerated() {
            for (itemIndex, object) in section.objects.enumerated() {
                updatedIndexPaths[object] = IndexPath(item: itemIndex, section: sectionIndex)
            }
        }

        return updatedIndexPaths
    }

    @MainActor
    func notifyInserting(_ object: FetchedObject, at indexPath: IndexPath, emitChanges: Bool) {
        assert(Thread.isMainThread)
        guard let delegate, emitChanges else {
            return
        }

        delegate.controller(self, didChange: object, for: .insert(location: indexPath))
    }

    @MainActor
    func notifyMoving(_ object: FetchedObject, from fromIndexPath: IndexPath, to toIndexPath: IndexPath, emitChanges: Bool) {
        assert(Thread.isMainThread)
        guard let delegate, emitChanges else {
            return
        }

        delegate.controller(self, didChange: object, for: .move(from: fromIndexPath, to: toIndexPath))
    }

    @MainActor
    func notifyUpdating(_ object: FetchedObject, at indexPath: IndexPath, emitChanges: Bool) {
        assert(Thread.isMainThread)
        guard let delegate, emitChanges else {
            return
        }

        delegate.controller(self, didChange: object, for: .update(location: indexPath))
    }

    @MainActor
    func notifyDeleting(_ object: FetchedObject, at indexPath: IndexPath, emitChanges: Bool) {
        assert(Thread.isMainThread)
        guard let delegate, emitChanges else {
            return
        }

        delegate.controller(self, didChange: object, for: .delete(location: indexPath))
    }

    @MainActor
    func notifyInserting(_ section: Section, at sectionIndex: Int, emitChanges: Bool) {
        assert(Thread.isMainThread)
        guard let delegate, emitChanges else {
            return
        }

        delegate.controller(self, didChange: section, for: .insert(location: sectionIndex))
    }

    @MainActor
    func notifyDeleting(_ section: Section, at sectionIndex: Int, emitChanges: Bool) {
        assert(Thread.isMainThread)
        guard let delegate, emitChanges else {
            return
        }

        delegate.controller(self, didChange: section, for: .delete(location: sectionIndex))
    }
}

// MARK: - Associated Values Extensions

private class Context<FetchedObject: FetchableObject>: NSObject {
    typealias Wrapped = (_ keyPath: PartialKeyPath<FetchedObject>, _ objectID: FetchedObject.ID) throws -> Any?

    let wrapped: Wrapped

    func associatedValue(with keyPath: PartialKeyPath<FetchedObject>, forObjectID objectID: FetchedObject.ID) throws -> Any? {
        return try wrapped(keyPath, objectID)
    }

    init(wrapped: @escaping Wrapped) {
        self.wrapped = wrapped
    }
}

private class Weak<Element: AnyObject>: NSObject {
    private(set) weak var value: Element?

    init(_ value: Element) {
        self.value = value
    }
}

private struct AssociatedKeys {
    static var context = "context"
}

private extension FetchableObjectProtocol where Self: NSObject {
    weak var context: Context<Self>? {
        get {
            let weakContainer = objc_getAssociatedObject(self, &AssociatedKeys.context) as? Weak<Context<Self>>

            return weakContainer?.value
        }
        set {
            if let newValue {
                objc_setAssociatedObject(self, &AssociatedKeys.context, Weak(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &AssociatedKeys.context, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }

    func getAssociatedValue<Value>(with keyPath: PartialKeyPath<Self>) throws -> Value? {
        guard let context else {
            throw FetchedResultsError.objectNotFound
        }

        if let rawValue = try context.associatedValue(with: keyPath, forObjectID: id) {
            return rawValue as? Value
        } else {
            return nil
        }
    }
}

// MARK: Fetchable Entity IDs

public extension FetchableObjectProtocol where Self: NSObject {
    func performFault<EntityID: FetchableEntityID>(
        on keyPath: KeyPath<Self, EntityID>,
        performFetchIfNeeded: Bool = true
    ) -> EntityID.FetchableEntity? {
        let fallback: (EntityID) -> EntityID.FetchableEntity? = { entityID in
            guard performFetchIfNeeded else {
                return nil
            }
            return EntityID.fetch(byID: entityID)
        }

        return performFault(on: keyPath, fallback: fallback)
    }

    func performFault<EntityID: FetchableEntityID>(
        on keyPath: KeyPath<Self, EntityID?>,
        performFetchIfNeeded: Bool = true
    ) -> EntityID.FetchableEntity? {
        let fallback: (EntityID) -> EntityID.FetchableEntity? = { entityID in
            guard performFetchIfNeeded else {
                return nil
            }
            return EntityID.fetch(byID: entityID)
        }

        return performFault(on: keyPath, fallback: fallback)
    }
}

// MARK: Fetchable Entity ID Arrays

public extension FetchableObjectProtocol where Self: NSObject {
    func performFault<EntityID: FetchableEntityID>(
        on keyPath: KeyPath<Self, [EntityID]>,
        performFetchIfNeeded: Bool = true
    ) -> [EntityID.FetchableEntity]? {
        let fallback: ([EntityID]) -> [EntityID.FetchableEntity]? = { entityIDs in
            guard performFetchIfNeeded else {
                return nil
            }
            return EntityID.fetch(byIDs: entityIDs)
        }

        return performFault(on: keyPath, fallback: fallback)
    }

    func performFault<EntityID: FetchableEntityID>(
        on keyPath: KeyPath<Self, [EntityID]?>,
        performFetchIfNeeded: Bool = true
    ) -> [EntityID.FetchableEntity]? {
        let fallback: ([EntityID]) -> [EntityID.FetchableEntity]? = { entityIDs in
            guard performFetchIfNeeded else {
                return nil
            }
            return EntityID.fetch(byIDs: entityIDs)
        }

        return performFault(on: keyPath, fallback: fallback)
    }
}

// MARK: Raw Entity IDs

public extension FetchableObjectProtocol where Self: NSObject {
    func performFault<EntityID: Equatable, Entity>(
        on keyPath: KeyPath<Self, EntityID>,
        fallback: (EntityID) -> Entity?
    ) -> Entity? {
        let entityID = self[keyPath: keyPath]

        do {
            return try getAssociatedValue(with: keyPath)
        } catch {
            CWLogInfo("Failed to fetch \(keyPath) in batch")
        }

        return fallback(entityID)
    }

    func performFault<EntityID: Equatable, Entity>(
        on keyPath: KeyPath<Self, EntityID?>,
        fallback: (EntityID) -> Entity?
    ) -> Entity? {
        guard let entityID = self[keyPath: keyPath] else {
            return nil
        }

        do {
            return try getAssociatedValue(with: keyPath)
        } catch {
            CWLogInfo("Failed to fetch \(keyPath) in batch")
        }

        return fallback(entityID)
    }
}

// MARK: - Raw Entity ID Arrays

public extension FetchableObjectProtocol where Self: NSObject {
    func performFault<EntityID: Equatable, Entity>(
        on keyPath: KeyPath<Self, [EntityID]>,
        fallback: ([EntityID]) -> [Entity]?
    ) -> [Entity]? {
        let entityID = self[keyPath: keyPath]
        guard !entityID.isEmpty else {
            return []
        }

        do {
            return try getAssociatedValue(with: keyPath)
        } catch {
            CWLogInfo("Failed to fetch \(keyPath) in batch")
        }

        return fallback(entityID)
    }

    func performFault<EntityID: Equatable, Entity>(
        on keyPath: KeyPath<Self, [EntityID]?>,
        fallback: ([EntityID]) -> [Entity]?
    ) -> [Entity]? {
        guard let entityID = self[keyPath: keyPath] else {
            return nil
        }

        guard !entityID.isEmpty else {
            return []
        }

        do {
            return try getAssociatedValue(with: keyPath)
        } catch {
            CWLogInfo("Failed to fetch \(keyPath) in batch")
        }

        return fallback(entityID)
    }
}

private extension [NSSortDescriptor] {
    func finalize<FetchedObject: FetchableObject>(
        with controller: FetchedResultsController<FetchedObject>
    ) -> Self {
        return finalize(sectionNameKeyPath: controller.sectionNameKeyPath) { [weak controller] id in
            // Note: OrderedSet.firstIndex(of:) is *not* O(n)
            controller?.fetchedObjectIDs.firstIndex(of: id)
        }
    }

    func finalize<FetchedObject: FetchableObject>(
        sectionNameKeyPath: KeyPath<FetchedObject, String>?,
        insertionOrder: @escaping (FetchedObject.ID) -> Int?
    ) -> Self {
        var sortDescriptors = self

        if let sectionNameKeyPath {
            assert(sectionNameKeyPath._kvcKeyPathString != nil, "\(sectionNameKeyPath) is not KVC compliant?")

            // Make sure we have our section name included if appropriate
            let sectionNameDescriptor = NSSortDescriptor(
                keyPath: sectionNameKeyPath,
                ascending: true,
                comparator: { lhs, rhs in
                    let lhs = lhs as? String ?? ""
                    let rhs = rhs as? String ?? ""
                    return lhs.localizedStandardCompare(rhs)
                }
            )
            sortDescriptors.insert(sectionNameDescriptor, at: 0)
        }

        let idDescriptor = NSSortDescriptor(key: "self", ascending: true) { lhs, rhs in
            guard let lhs = lhs as? FetchedObject, let rhs = rhs as? FetchedObject else {
                assert(false, "We were used against the wrong type?")
                return .orderedSame
            }

            let lhsInsertion = insertionOrder(lhs.id) ?? .max
            let rhsInsertion = insertionOrder(rhs.id) ?? .max

            assert(lhsInsertion != .max)
            assert(rhsInsertion != .max)

            if lhsInsertion < rhsInsertion {
                return .orderedAscending
            } else if lhsInsertion > rhsInsertion {
                return .orderedDescending
            } else {
                return .orderedSame
            }
        }
        sortDescriptors.append(idDescriptor)

        return sortDescriptors
    }
}
