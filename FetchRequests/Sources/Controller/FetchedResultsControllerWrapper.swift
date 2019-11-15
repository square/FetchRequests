//
//  FetchedResultsControllerWrapper.swift
//  Crew
//
//  Created by Adam Proschek on 1/26/17.
//  Copyright © 2017 Speramus Inc. All rights reserved.
//

import Foundation

public class FetchedResultsControllerWrapper<FetchedObject: FetchableObject> {
    public typealias Section = FetchedResultsSection<FetchedObject>
    public typealias SectionNameKeyPath = KeyPath<FetchedObject, String>

    private let controller: FetchedResultsController<FetchedObject>
    private let changeCompletion: () -> Void

    public init(
        request: FetchRequest<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true,
        didChange completion: @escaping () -> Void
    ) {
        controller = FetchedResultsController(
            request: request,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )

        changeCompletion = completion

        controller.setDelegate(self)
    }
}

// MARK: - Wrapper Functions

extension FetchedResultsControllerWrapper: FetchedResultsControllerProtocol {
    public func performFetch(completion: @escaping () -> Void) {
        controller.performFetch(completion: completion)
    }

    public func reset() {
        controller.reset()
    }

    public var request: FetchRequest<FetchedObject> {
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
        return controller.hasFetchedObjects
    }

    public var fetchedObjects: [FetchedObject] {
        return controller.fetchedObjects
    }

    public var sections: [Section] {
        return controller.sections
    }

    public func indexPath(for object: FetchedObject) -> IndexPath? {
        return controller.indexPath(for: object)
    }
}

// MARK: - FetchedResultsControllerDelegate

extension FetchedResultsControllerWrapper: FetchedResultsControllerDelegate {
    public func controllerDidChangeContent(_ controller: FetchedResultsController<FetchedObject>) {
        changeCompletion()
    }
}
