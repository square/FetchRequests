//
//  CWCollapsibleSectionsFetchedResultsController.swift
//  Crew
//
//  Created by Adam Proschek on 2/10/17.
//  Copyright © 2017 Speramus Inc. All rights reserved.
//

import UIKit

public struct SectionCollapseConfig: Equatable {
    public let maxNumberOfItemsToDisplay: Int
    public let numberOfItemsToDisplayWhenExceedingMax: Int?

    public init(maxNumberOfItemsToDisplay: Int, whenExceedingMax: Int? = nil) {
        self.maxNumberOfItemsToDisplay = maxNumberOfItemsToDisplay
        self.numberOfItemsToDisplayWhenExceedingMax = whenExceedingMax
    }
}

public protocol CWCollapsibleSectionsFetchedResultsControllerDelegate: class {
    associatedtype FetchedObject: CWFetchableObject

    func controllerWillChangeContent(_ controller: CWCollapsibleSectionsFetchedResultsController<FetchedObject>)
    func controllerDidChangeContent(_ controller: CWCollapsibleSectionsFetchedResultsController<FetchedObject>)

    func controller(
        _ controller: CWCollapsibleSectionsFetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: CWFetchedResultsChange<IndexPath>
    )
    func controller(
        _ controller: CWCollapsibleSectionsFetchedResultsController<FetchedObject>,
        didChange section: CWCollapsibleResultsSection<FetchedObject>,
        for change: CWFetchedResultsChange<Int>
    )
}

public struct CWCollapsibleResultsSection<FetchedObject: CWFetchableObject>: Equatable {
    fileprivate let section: CWFetchedResultsSection<FetchedObject>
    private let config: SectionCollapseConfig?
    public let isCollapsed: Bool

    let displayableObjects: [FetchedObject]

    public var allObjects: [FetchedObject] {
        return section.objects
    }

    public var name: String {
        return section.name
    }

    public var numberOfDisplayableObjects: Int {
        return displayableObjects.count
    }

    init(
        section: CWFetchedResultsSection<FetchedObject>,
        collapsed: Bool,
        config: SectionCollapseConfig? = nil
    ) {
        self.section = section
        self.isCollapsed = collapsed
        self.config = config

        guard let config = config, collapsed else {
            displayableObjects = section.objects
            return
        }

        if let numberOfItemsToDisplayWhenExceedingMax = config.numberOfItemsToDisplayWhenExceedingMax,
            section.numberOfObjects > config.maxNumberOfItemsToDisplay {
            let collapsedObjects = section.objects.prefix(numberOfItemsToDisplayWhenExceedingMax)
            displayableObjects = Array(collapsedObjects)
        } else if section.numberOfObjects > config.maxNumberOfItemsToDisplay {
            let collapsedObjects = section.objects.prefix(config.maxNumberOfItemsToDisplay)
            displayableObjects = Array(collapsedObjects)
        } else {
            displayableObjects = section.objects
        }
    }
}

public class CWCollapsibleSectionsFetchedResultsController<FetchedObject: CWFetchableObject>: NSObject {
    public typealias BackingFetchController = CWFetchedResultsController<FetchedObject>
    public typealias Section = CWCollapsibleResultsSection<FetchedObject>
    public typealias SectionCollapseCheck = (_ section: BackingFetchController.Section) -> Bool
    public typealias SectionCollapseConfigCheck = (_ section: BackingFetchController.Section) -> SectionCollapseConfig?
    public typealias SectionNameKeyPath = KeyPath<FetchedObject, String>

    private var changedSectionsDuringContentChange: Set<String> = []
    private var deletedSectionsDuringContentChange: Set<String> = []
    private var previousSectionsDuringContentChange: [CWCollapsibleResultsSection<FetchedObject>] = []

    //swiftlint:disable:next identifier_name
    private var collapsedSectionsModifiedDuringContentChange: Set<String> = []
    private var collapsedSectionNames: Set<String> = []

    private let fetchController: BackingFetchController
    private let initialSectionCollapseCheck: SectionCollapseCheck
    private var sectionNamesCheckedForInitialCollapse: Set<String> = []
    private let sectionConfigCheck: SectionCollapseConfigCheck

    //swiftlint:disable:next weak_delegate
    private var delegate: CollapsibleSectionsFetchResultsDelegate<FetchedObject>?

    private var sectionConfigs: [String: SectionCollapseConfig] = [:]

    public var sections: [CWCollapsibleResultsSection<FetchedObject>] = []
    public var request: CWFetchRequest<FetchedObject> {
        return fetchController.request
    }

    public var sortDescriptors: [NSSortDescriptor] {
        return fetchController.sortDescriptors
    }

    public var fetchedObjects: [FetchedObject] {
        return fetchController.fetchedObjects
    }

    public var hasFetchedObjects: Bool {
        return fetchController.hasFetchedObjects
    }

    public var associatedFetchSize: Int {
        set {
            fetchController.associatedFetchSize = newValue
        }
        get {
            return fetchController.associatedFetchSize
        }
    }

    public init(
        request: CWFetchRequest<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true,
        initialSectionCollapseCheck: @escaping SectionCollapseCheck = { _ in false },
        sectionConfigCheck: @escaping SectionCollapseConfigCheck = { _ in return nil }
    ) {
        fetchController = CWFetchedResultsController<FetchedObject>(
            request: request,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )

        self.initialSectionCollapseCheck = initialSectionCollapseCheck
        self.sectionConfigCheck = sectionConfigCheck
        super.init()
        fetchController.setDelegate(self)
    }

    public func setDelegate<Delegate: CWCollapsibleSectionsFetchedResultsControllerDelegate>(_ delegate: Delegate?) where Delegate.FetchedObject == FetchedObject {
        self.delegate = delegate.flatMap {
            CollapsibleSectionsFetchResultsDelegate($0)
        }
    }

    public func clearDelegate() {
        self.delegate = nil
    }
}

// MARK: - Helper Methods
public extension CWCollapsibleSectionsFetchedResultsController {
    func update(section: CWCollapsibleResultsSection<FetchedObject>, maximumNumberOfItemsToDisplay max: Int, whenExceedingMax: Int? = nil) {
        guard let sectionIndex = sections.firstIndex(of: section) else {
            return
        }

        performChanges(onIndex: sectionIndex) { section in
            let config = SectionCollapseConfig(maxNumberOfItemsToDisplay: max, whenExceedingMax: whenExceedingMax)
            sectionConfigs[section.name] = config
        }
    }

    func expand(section: Section) {
        guard let sectionIndex = sections.firstIndex(of: section) else {
            return
        }

        performChanges(onIndex: sectionIndex) { section in
            self.collapsedSectionNames.remove(section.name)
        }
    }

    func collapse(section: Section) {
        guard let sectionIndex = sections.firstIndex(of: section) else {
            return
        }

        performChanges(onIndex: sectionIndex) { section in
            self.collapsedSectionNames.insert(section.name)
        }
    }

    private func performChanges(onIndex sectionIndex: Int, changes: (Section) -> Void) {
        let section = sections[sectionIndex]
        controllerWillChangeContent(fetchController)
        changes(section)
        controller(fetchController, didChange: section.section, for: .update(location: sectionIndex))
        controllerDidChangeContent(fetchController)
    }

    func object(at indexPath: IndexPath) -> FetchedObject {
        return sections[indexPath.section].displayableObjects[indexPath.row]
    }

    func indexPath(for object: FetchedObject) -> IndexPath? {
        guard let indexPath = fetchController.indexPath(for: object) else {
            return nil
        }

        let section = sections[indexPath.section]
        let numberOfItemsDisplayed = section.numberOfDisplayableObjects
        return indexPath.row < numberOfItemsDisplayed ? indexPath : nil
    }

    private func updateSections() {
        sections = fetchController.sections.map(createSection)
    }

    private func updateSections(atIndices indices: Int...) {
        for index in indices {
            sections[index] = createSection(from: fetchController.sections[index])
        }
    }

    private func createSection(from section: BackingFetchController.Section) -> Section {
        if !sectionNamesCheckedForInitialCollapse.contains(section.name) {
            if initialSectionCollapseCheck(section) {
                collapsedSectionNames.insert(section.name)
            }

            sectionConfigs[section.name] = sectionConfigCheck(section)
            sectionNamesCheckedForInitialCollapse.insert(section.name)
        }

        return CWCollapsibleResultsSection(
            section: section,
            collapsed: collapsedSectionNames.contains(section.name),
            config: sectionConfigs[section.name]
        )
    }
}

// MARK: - Fetch Methods
public extension CWCollapsibleSectionsFetchedResultsController {
    func performFetch(completion: (() -> Void)? = nil) {
        fetchController.performFetch {
            completion?()
        }
    }
}

// MARK: - CWFetchedResultsControllerDelegate
extension CWCollapsibleSectionsFetchedResultsController: CWFetchedResultsControllerDelegate {
    public func controllerWillChangeContent(_ controller: CWFetchedResultsController<FetchedObject>) {
        collapsedSectionsModifiedDuringContentChange.removeAll()
        changedSectionsDuringContentChange.removeAll()
        deletedSectionsDuringContentChange.removeAll()
        previousSectionsDuringContentChange = self.sections

        delegate?.controllerWillChangeContent(self)
    }

    public func controllerDidChangeContent(_ controller: CWFetchedResultsController<FetchedObject>) {
        let sectionsToNotify = collapsedSectionsModifiedDuringContentChange.filter { section in
            return !changedSectionsDuringContentChange.contains(section) && !deletedSectionsDuringContentChange.contains(section)
        }
        for sectionName in sectionsToNotify {
            guard let section = previousSectionsDuringContentChange.first(where: { $0.name == sectionName }),
                let index = previousSectionsDuringContentChange.firstIndex(of: section) else
            {
                continue
            }

            let change: CWFetchedResultsChange = .update(location: index)
            delegate?.controller(self, didChange: section, for: change)
        }

        collapsedSectionsModifiedDuringContentChange.removeAll()
        changedSectionsDuringContentChange.removeAll()
        deletedSectionsDuringContentChange.removeAll()
        previousSectionsDuringContentChange.removeAll()

        delegate?.controllerDidChangeContent(self)
    }

    public func controller(
        _ controller: CWFetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: CWFetchedResultsChange<IndexPath>
    ) {
        switch change {
        case let .insert(indexPath):
            updateSections(atIndices: indexPath.section)

            let section = sections[indexPath.section]
            if section.isCollapsed {
                collapsedSectionNames.insert(section.name)
                collapsedSectionsModifiedDuringContentChange.insert(section.name)
            } else {
                delegate?.controller(self, didChange: object, for: change)
            }

        case let .update(indexPath), let .delete(indexPath):
            updateSections(atIndices: indexPath.section)

            let section = sections[indexPath.section]
            if section.isCollapsed {
                collapsedSectionsModifiedDuringContentChange.insert(section.name)
            } else {
                delegate?.controller(self, didChange: object, for: change)
            }

        case let .move(fromIndexPath, toIndexPath):
            updateSections(atIndices: fromIndexPath.section, toIndexPath.section)

            let fromSection = sections[fromIndexPath.section]
            let toSection = sections[toIndexPath.section]

            if fromSection.isCollapsed && toSection.isCollapsed {
                collapsedSectionsModifiedDuringContentChange.insert(fromSection.name)
                collapsedSectionsModifiedDuringContentChange.insert(toSection.name)
            } else if fromSection.isCollapsed {
                collapsedSectionsModifiedDuringContentChange.insert(fromSection.name)
                delegate?.controller(self, didChange: object, for: .insert(location: toIndexPath))
            } else if toSection.isCollapsed {
                collapsedSectionsModifiedDuringContentChange.insert(toSection.name)
                delegate?.controller(self, didChange: object, for: .delete(location: fromIndexPath))
            } else {
                delegate?.controller(self, didChange: object, for: change)
            }
        }
    }

    public func controller(
        _ controller: CWFetchedResultsController<FetchedObject>,
        didChange section: CWFetchedResultsSection<FetchedObject>,
        for change: CWFetchedResultsChange<Int>
    ) {
        let sectionToNotify: CWCollapsibleResultsSection<FetchedObject>
        var isDelete = false
        var isInsert = false

        switch change {
        case let .insert(sectionIndex):
            isInsert = true
            sectionToNotify = createSection(from: controller.sections[sectionIndex])
            sections.insert(sectionToNotify, at: sectionIndex)

        case let .delete(sectionIndex):
            isDelete = true
            sectionToNotify = sections[sectionIndex]
            sections.remove(at: sectionIndex)

        case let .move(oldSectionIndex, newSectionIndex):
            sectionToNotify = createSection(from: controller.sections[newSectionIndex])

            sections.remove(at: oldSectionIndex)
            sections.insert(sectionToNotify, at: newSectionIndex)

        case let .update(sectionIndex):
            sectionToNotify = createSection(from: controller.sections[sectionIndex])
            sections[sectionIndex] = sectionToNotify
        }

        if isDelete {
            deletedSectionsDuringContentChange.insert(sectionToNotify.name)
            changedSectionsDuringContentChange.remove(sectionToNotify.name)
        } else {
            changedSectionsDuringContentChange.insert(sectionToNotify.name)
        }

        if isInsert {
            deletedSectionsDuringContentChange.remove(sectionToNotify.name)
        }

        delegate?.controller(self, didChange: sectionToNotify, for: change)
    }
}

private class CollapsibleSectionsFetchResultsDelegate<FetchedObject: CWFetchableObject>: CWCollapsibleSectionsFetchedResultsControllerDelegate {
    typealias Controller = CWCollapsibleSectionsFetchedResultsController<FetchedObject>
    typealias Section = CWCollapsibleResultsSection<FetchedObject>

    private let willChange: (_ controller: Controller) -> Void
    private let didChange: (_ controller: Controller) -> Void

    private let changeObject: (_ controller: Controller, _ object: FetchedObject, _ change: CWFetchedResultsChange<IndexPath>) -> Void
    private let changeSection: (_ controller: Controller, _ section: Section, _ change: CWFetchedResultsChange<Int>) -> Void

    init<Parent: CWCollapsibleSectionsFetchedResultsControllerDelegate>(
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

    func controllerWillChangeContent(_ controller: Controller) {
        self.willChange(controller)
    }

    func controllerDidChangeContent(_ controller: Controller) {
        self.didChange(controller)
    }

    func controller(
        _ controller: Controller,
        didChange object: FetchedObject,
        for change: CWFetchedResultsChange<IndexPath>
    ) {
        self.changeObject(controller, object, change)
    }

    func controller(
        _ controller: Controller,
        didChange section: Section,
        for change: CWFetchedResultsChange<Int>
    ) {
        self.changeSection(controller, section, change)
    }
}
