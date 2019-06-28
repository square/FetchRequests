//
//  File.swift
//  Crew
//
//  Created by Adam Lickel on 4/5/17.
//  Copyright © 2017 Speramus Inc. All rights reserved.
//

import Foundation

public protocol CWPausableFetchedResultsControllerDelegate: class {
    associatedtype FetchedObject: CWFetchableObject

    func controllerWillChangeContent(_ controller: CWPausableFetchedResultsController<FetchedObject>)
    func controllerDidChangeContent(_ controller: CWPausableFetchedResultsController<FetchedObject>)

    func controller(
        _ controller: CWPausableFetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: CWFetchedResultsChange<IndexPath>
    )
    func controller(
        _ controller: CWPausableFetchedResultsController<FetchedObject>,
        didChange section: CWFetchedResultsSection<FetchedObject>,
        for change: CWFetchedResultsChange<Int>
    )
}

public extension CWPausableFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: CWPausableFetchedResultsController<FetchedObject>) {}
    func controllerDidChangeContent(_ controller: CWPausableFetchedResultsController<FetchedObject>) {}

    func controller(
        _ controller: CWPausableFetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: CWFetchedResultsChange<IndexPath>
    ) {
    }

    func controller(
        _ controller: CWPausableFetchedResultsController<FetchedObject>,
        didChange section: CWFetchedResultsSection<FetchedObject>,
        for change: CWFetchedResultsChange<Int>
    ) {
    }
}

public class CWPausableFetchedResultsController<FetchedObject: CWFetchableObject> {
    private let controller: CWFetchedResultsController<FetchedObject>

    public typealias Section = CWFetchedResultsSection<FetchedObject>
    public typealias SectionNameKeyPath = KeyPath<FetchedObject, String>

    private var hasFetchedObjectsSnapshot: Bool?
    private var fetchedObjectsSnapshot: [FetchedObject]?
    private var sectionsSnapshot: [Section]?

    public var isPaused: Bool = false {
        didSet {
            guard oldValue != isPaused else {
                return
            }
            if isPaused {
                hasFetchedObjectsSnapshot = controller.hasFetchedObjects
                sectionsSnapshot = controller.sections
                fetchedObjectsSnapshot = controller.fetchedObjects
            } else {
                hasFetchedObjectsSnapshot = nil
                sectionsSnapshot = nil
                fetchedObjectsSnapshot = nil
            }
        }
    }

    //swiftlint:disable:next weak_delegate
    private var delegate: PausableFetchResultsDelegate<FetchedObject>?

    public init(
        request: CWFetchRequest<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true
    ) {
        controller = CWFetchedResultsController(
            request: request,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )
    }
}

// MARK: - Wrapper Functions

extension CWPausableFetchedResultsController: CWFetchedResultsControllerProtocol {
    public func performFetch(completion: @escaping () -> Void) {
        controller.performFetch(completion: completion)
    }

    public func reset() {
        controller.reset()
        isPaused = false
    }

    public var request: CWFetchRequest<FetchedObject> {
        return controller.request
    }

    public var sortDescriptors: [NSSortDescriptor] {
        return controller.sortDescriptors
    }

    public var sectionNameKeyPath: SectionNameKeyPath? {
        return controller.sectionNameKeyPath
    }

    public var associatedFetchSize: Int {
        get {
            return controller.associatedFetchSize
        }
        set {
            controller.associatedFetchSize = newValue
        }
    }

    public var hasFetchedObjects: Bool {
        return hasFetchedObjectsSnapshot ?? controller.hasFetchedObjects
    }

    public var fetchedObjects: [FetchedObject] {
        return fetchedObjectsSnapshot ?? controller.fetchedObjects
    }

    public var sections: [Section] {
        return sectionsSnapshot ?? controller.sections
    }

    public func setDelegate<Delegate: CWPausableFetchedResultsControllerDelegate>(_ delegate: Delegate?) where Delegate.FetchedObject == FetchedObject {
        self.delegate = delegate.flatMap {
            PausableFetchResultsDelegate($0, pausableController: self)
        }
        controller.setDelegate(self.delegate)
    }

    public func clearDelegate() {
        self.delegate = nil
        controller.clearDelegate()
    }
}

// MARK: - CWInternalFetchResultsControllerProtocol

extension CWPausableFetchedResultsController: CWInternalFetchResultsControllerProtocol {
    internal func manuallyInsert(objects: [FetchedObject], emitChanges: Bool = true) {
        controller.manuallyInsert(objects: objects, emitChanges: emitChanges)
    }
}

// MARK: - PausableFetchResultsDelegate

internal class PausableFetchResultsDelegate<FetchedObject: CWFetchableObject>: CWFetchedResultsControllerDelegate {
    typealias ParentController = CWFetchedResultsController<FetchedObject>
    typealias PausableController = CWPausableFetchedResultsController<FetchedObject>
    typealias Section = CWFetchedResultsSection<FetchedObject>

    private weak var pausableController: PausableController?

    private let willChange: (_ controller: PausableController) -> Void
    private let didChange: (_ controller: PausableController) -> Void

    private let changeObject: (_ controller: PausableController, _ object: FetchedObject, _ change: CWFetchedResultsChange<IndexPath>) -> Void
    private let changeSection: (_ controller: PausableController, _ section: Section, _ change: CWFetchedResultsChange<Int>) -> Void

    init<Parent: CWPausableFetchedResultsControllerDelegate>(
        _ parent: Parent,
        pausableController: PausableController
    ) where Parent.FetchedObject == FetchedObject {
        self.pausableController = pausableController

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

    func controllerWillChangeContent(_ controller: ParentController) {
        guard let pausableController = pausableController, !pausableController.isPaused else {
            return
        }
        self.willChange(pausableController)
    }

    func controllerDidChangeContent(_ controller: ParentController) {
        guard let pausableController = pausableController, !pausableController.isPaused else {
            return
        }
        self.didChange(pausableController)
    }

    func controller(
        _ controller: ParentController,
        didChange object: FetchedObject,
        for change: CWFetchedResultsChange<IndexPath>
    ) {
        guard let pausableController = pausableController, !pausableController.isPaused else {
            return
        }
        self.changeObject(pausableController, object, change)
    }

    func controller(
        _ controller: ParentController,
        didChange section: Section,
        for change: CWFetchedResultsChange<Int>
    ) {
        guard let pausableController = pausableController, !pausableController.isPaused else {
            return
        }
        self.changeSection(pausableController, section, change)
    }
}
