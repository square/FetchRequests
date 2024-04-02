//
//  PausableFetchedResultsController.swift
//  Crew
//
//  Created by Adam Lickel on 4/5/17.
//  Copyright © 2017 Speramus Inc. All rights reserved.
//

import Foundation
import Combine

@MainActor
public protocol PausableFetchedResultsControllerDelegate<FetchedObject>: AnyObject {
    associatedtype FetchedObject: FetchableObject

    func controllerWillChangeContent(_ controller: PausableFetchedResultsController<FetchedObject>)
    func controllerDidChangeContent(_ controller: PausableFetchedResultsController<FetchedObject>)

    func controller(
        _ controller: PausableFetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    )
    func controller(
        _ controller: PausableFetchedResultsController<FetchedObject>,
        didChange section: FetchedResultsSection<FetchedObject>,
        for change: FetchedResultsChange<Int>
    )
}

public extension PausableFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: PausableFetchedResultsController<FetchedObject>) {}
    func controllerDidChangeContent(_ controller: PausableFetchedResultsController<FetchedObject>) {}

    func controller(
        _ controller: PausableFetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
    }

    func controller(
        _ controller: PausableFetchedResultsController<FetchedObject>,
        didChange section: FetchedResultsSection<FetchedObject>,
        for change: FetchedResultsChange<Int>
    ) {
    }
}

public class PausableFetchedResultsController<FetchedObject: FetchableObject> {
    public typealias Delegate = PausableFetchedResultsControllerDelegate<FetchedObject>
    public typealias Section = FetchedResultsSection<FetchedObject>
    public typealias SectionNameKeyPath = KeyPath<FetchedObject, String>

    private let controller: FetchedResultsController<FetchedObject>

    private var hasFetchedObjectsSnapshot: Bool?
    private var fetchedObjectsSnapshot: [FetchedObject]?
    private var sectionsSnapshot: [Section]?

    fileprivate let objectWillChangeSubject = PassthroughSubject<Void, Never>()
    fileprivate let objectDidChangeSubject = PassthroughSubject<Void, Never>()

    public private(set) lazy var objectWillChange = objectWillChangeSubject.eraseToAnyPublisher()
    public private(set) lazy var objectDidChange = objectDidChangeSubject.eraseToAnyPublisher()

    /// Pause all eventing and return a snapshot of the value
    ///
    /// Pausing and unpausing will never trigger the delegate. While paused, the delegate will not fire for any reason.
    /// If you depend upon your delegate for eventing, you will need to reload any dependencies manually.
    /// The Publishers will trigger whenever the value of isPaused changes.
    public var isPaused: Bool = false {
        didSet {
            guard oldValue != isPaused else {
                return
            }

            objectWillChangeSubject.send()

            if isPaused {
                hasFetchedObjectsSnapshot = controller.hasFetchedObjects
                sectionsSnapshot = controller.sections
                fetchedObjectsSnapshot = controller.fetchedObjects
            } else {
                hasFetchedObjectsSnapshot = nil
                sectionsSnapshot = nil
                fetchedObjectsSnapshot = nil
            }

            objectDidChangeSubject.send()
        }
    }

    // swiftlint:disable:next weak_delegate
    private var delegate: DelegateThunk<FetchedObject>?

    public init(
        definition: FetchDefinition<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true
    ) {
        controller = FetchedResultsController(
            definition: definition,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )
    }

    // MARK: - Delegate

    public func setDelegate(_ delegate: (some Delegate)?) {
        self.delegate = delegate.flatMap {
            DelegateThunk($0, pausableController: self)
        }
        controller.setDelegate(self.delegate)
    }

    public func clearDelegate() {
        delegate = nil
        controller.clearDelegate()
    }
}

// MARK: - Wrapper Functions

extension PausableFetchedResultsController: FetchedResultsControllerProtocol {
    @MainActor
    public func performFetch(completion: @escaping @MainActor () -> Void) {
        controller.performFetch(completion: completion)
    }

    @MainActor
    public func resort(using newSortDescriptors: [NSSortDescriptor], completion: @escaping @MainActor () -> Void) {
        controller.resort(using: newSortDescriptors, completion: completion)
    }

    @MainActor
    public func reset() {
        controller.reset()
        isPaused = false
    }

    public var definition: FetchDefinition<FetchedObject> {
        controller.definition
    }

    public var sortDescriptors: [NSSortDescriptor] {
        controller.sortDescriptors
    }

    public var sectionNameKeyPath: SectionNameKeyPath? {
        controller.sectionNameKeyPath
    }

    public var associatedFetchSize: Int {
        get {
            controller.associatedFetchSize
        }
        set {
            controller.associatedFetchSize = newValue
        }
    }

    public var hasFetchedObjects: Bool {
        hasFetchedObjectsSnapshot ?? controller.hasFetchedObjects
    }

    public var fetchedObjects: [FetchedObject] {
        fetchedObjectsSnapshot ?? controller.fetchedObjects
    }

    public var sections: [Section] {
        sectionsSnapshot ?? controller.sections
    }

    internal var debounceInsertsAndReloads: Bool {
        controller.debounceInsertsAndReloads
    }
}

// MARK: - InternalFetchResultsControllerProtocol

extension PausableFetchedResultsController: InternalFetchResultsControllerProtocol {
    internal func manuallyInsert(objects: [FetchedObject], emitChanges: Bool = true) {
        controller.manuallyInsert(objects: objects, emitChanges: emitChanges)
    }
}

// MARK: - DelegateThunk

private class DelegateThunk<FetchedObject: FetchableObject> {
    typealias Parent = PausableFetchedResultsControllerDelegate<FetchedObject>
    typealias ParentController = FetchedResultsController<FetchedObject>
    typealias PausableController = PausableFetchedResultsController<FetchedObject>
    typealias Section = FetchedResultsSection<FetchedObject>

    private weak var parent: (any Parent)?
    private weak var pausableController: PausableController?

    private let willChange: @MainActor (_ controller: PausableController) -> Void
    private let didChange: @MainActor (_ controller: PausableController) -> Void

    private let changeObject: @MainActor (_ controller: PausableController, _ object: FetchedObject, _ change: FetchedResultsChange<IndexPath>) -> Void
    private let changeSection: @MainActor (_ controller: PausableController, _ section: Section, _ change: FetchedResultsChange<Int>) -> Void

    init(_ parent: some Parent, pausableController: PausableController) {
        self.parent = parent
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
}

extension DelegateThunk: FetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: ParentController) {
        guard let pausableController, !pausableController.isPaused else {
            return
        }
        pausableController.objectWillChangeSubject.send()
        self.controllerWillChangeContent(pausableController)
    }

    func controllerDidChangeContent(_ controller: ParentController) {
        guard let pausableController, !pausableController.isPaused else {
            return
        }
        self.controllerDidChangeContent(pausableController)
        pausableController.objectDidChangeSubject.send()
    }

    func controller(
        _ controller: ParentController,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
        guard let pausableController, !pausableController.isPaused else {
            return
        }
        self.controller(pausableController, didChange: object, for: change)
    }

    func controller(
        _ controller: ParentController,
        didChange section: Section,
        for change: FetchedResultsChange<Int>
    ) {
        guard let pausableController, !pausableController.isPaused else {
            return
        }
        self.controller(pausableController, didChange: section, for: change)
    }
}

extension DelegateThunk: PausableFetchedResultsControllerDelegate {
    public func controllerWillChangeContent(_ controller: PausableController) {
        self.willChange(controller)
    }

    public func controllerDidChangeContent(_ controller: PausableController) {
        self.didChange(controller)
    }

    public func controller(
        _ controller: PausableController,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
        self.changeObject(controller, object, change)
    }

    public func controller(
        _ controller: PausableController,
        didChange section: FetchedResultsSection<FetchedObject>,
        for change: FetchedResultsChange<Int>
    ) {
        self.changeSection(controller, section, change)
    }
}
