//
//  CollapsibleSectionsFetchedResultsController.swift
//  Crew
//
//  Created by Adam Proschek on 2/10/17.
//  Copyright © 2017 Speramus Inc. All rights reserved.
//

import Foundation

public struct SectionCollapseConfig: Equatable {
    public let maxNumberOfItemsToDisplay: Int
    public let numberOfItemsToDisplayWhenExceedingMax: Int?

    public init(maxNumberOfItemsToDisplay: Int, whenExceedingMax: Int? = nil) {
        self.maxNumberOfItemsToDisplay = maxNumberOfItemsToDisplay
        self.numberOfItemsToDisplayWhenExceedingMax = whenExceedingMax
    }
}

@MainActor
// swiftlint:disable:next type_name
public protocol CollapsibleSectionsFetchedResultsControllerDelegate<FetchedObject>: AnyObject {
    associatedtype FetchedObject: FetchableObject

    func controllerWillChangeContent(_ controller: CollapsibleSectionsFetchedResultsController<FetchedObject>)
    func controllerDidChangeContent(_ controller: CollapsibleSectionsFetchedResultsController<FetchedObject>)

    func controller(
        _ controller: CollapsibleSectionsFetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    )
    func controller(
        _ controller: CollapsibleSectionsFetchedResultsController<FetchedObject>,
        didChange section: CollapsibleResultsSection<FetchedObject>,
        for change: FetchedResultsChange<Int>
    )
}

public struct CollapsibleResultsSection<FetchedObject: FetchableObject>: Equatable, Identifiable {
    fileprivate let section: FetchedResultsSection<FetchedObject>
    private let config: SectionCollapseConfig?
    public let isCollapsed: Bool

    let displayableObjects: [FetchedObject]

    public var allObjects: [FetchedObject] {
        section.objects
    }

    public var id: String {
        section.id
    }

    public var name: String {
        section.name
    }

    public var numberOfDisplayableObjects: Int {
        displayableObjects.count
    }

    init(
        section: FetchedResultsSection<FetchedObject>,
        collapsed: Bool,
        config: SectionCollapseConfig? = nil
    ) {
        self.section = section
        self.isCollapsed = collapsed
        self.config = config

        guard let config, collapsed else {
            displayableObjects = section.objects
            return
        }

        if let numberOfItemsToDisplayWhenExceedingMax = config.numberOfItemsToDisplayWhenExceedingMax,
           section.numberOfObjects > config.maxNumberOfItemsToDisplay
        {
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

public class CollapsibleSectionsFetchedResultsController<FetchedObject: FetchableObject>: NSObject {
    public typealias Delegate = CollapsibleSectionsFetchedResultsControllerDelegate<FetchedObject>

    public typealias BackingFetchController = FetchedResultsController<FetchedObject>
    public typealias Section = CollapsibleResultsSection<FetchedObject>
    public typealias SectionCollapseCheck = (_ section: BackingFetchController.Section) -> Bool
    public typealias SectionCollapseConfigCheck = (_ section: BackingFetchController.Section) -> SectionCollapseConfig?
    public typealias SectionNameKeyPath = FetchedResultsController<FetchedObject>.SectionNameKeyPath

    private var changedSectionsDuringContentChange: Set<String> = []
    private var deletedSectionsDuringContentChange: Set<String> = []
    private var previousSectionsDuringContentChange: [CollapsibleResultsSection<FetchedObject>] = []

    // swiftlint:disable:next identifier_name
    private var collapsedSectionsModifiedDuringContentChange: Set<String> = []
    private var collapsedSectionNames: Set<String> = []

    private let fetchController: BackingFetchController
    private let initialSectionCollapseCheck: SectionCollapseCheck
    private var sectionNamesCheckedForInitialCollapse: Set<String> = []
    private let sectionConfigCheck: SectionCollapseConfigCheck

    // swiftlint:disable:next weak_delegate
    private var delegate: DelegateThunk<FetchedObject>?

    private var sectionConfigs: [String: SectionCollapseConfig] = [:]

    public var sections: [CollapsibleResultsSection<FetchedObject>] = []
    public var definition: FetchDefinition<FetchedObject> {
        fetchController.definition
    }

    public var sortDescriptors: [NSSortDescriptor] {
        fetchController.sortDescriptors
    }

    public var fetchedObjects: [FetchedObject] {
        fetchController.fetchedObjects
    }

    public var hasFetchedObjects: Bool {
        fetchController.hasFetchedObjects
    }

    public var associatedFetchSize: Int {
        get {
            fetchController.associatedFetchSize
        }
        set {
            fetchController.associatedFetchSize = newValue
        }
    }

    public init(
        definition: FetchDefinition<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true,
        initialSectionCollapseCheck: @escaping SectionCollapseCheck = { _ in false },
        sectionConfigCheck: @escaping SectionCollapseConfigCheck = { _ in nil }
    ) {
        fetchController = FetchedResultsController<FetchedObject>(
            definition: definition,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )

        self.initialSectionCollapseCheck = initialSectionCollapseCheck
        self.sectionConfigCheck = sectionConfigCheck
        super.init()
        fetchController.setDelegate(self)
    }

    // MARK: - Delegate

    public func setDelegate(_ delegate: (some Delegate)?) {
        self.delegate = delegate.flatMap {
            DelegateThunk($0)
        }
    }

    public func clearDelegate() {
        delegate = nil
    }
}

// MARK: - Helper Methods
public extension CollapsibleSectionsFetchedResultsController {
    @MainActor
    func update(section: CollapsibleResultsSection<FetchedObject>, maximumNumberOfItemsToDisplay max: Int, whenExceedingMax: Int? = nil) {
        guard let sectionIndex = sections.firstIndex(of: section) else {
            return
        }

        performChanges(onIndex: sectionIndex) { section in
            let config = SectionCollapseConfig(maxNumberOfItemsToDisplay: max, whenExceedingMax: whenExceedingMax)
            sectionConfigs[section.name] = config
        }
    }

    @MainActor
    func expand(section: Section) {
        guard let sectionIndex = sections.firstIndex(of: section) else {
            return
        }

        performChanges(onIndex: sectionIndex) { section in
            self.collapsedSectionNames.remove(section.name)
        }
    }

    @MainActor
    func collapse(section: Section) {
        guard let sectionIndex = sections.firstIndex(of: section) else {
            return
        }

        performChanges(onIndex: sectionIndex) { section in
            self.collapsedSectionNames.insert(section.name)
        }
    }

    @MainActor
    private func performChanges(onIndex sectionIndex: Int, changes: (Section) -> Void) {
        let section = sections[sectionIndex]
        controllerWillChangeContent(fetchController)
        changes(section)
        controller(fetchController, didChange: section.section, for: .update(location: sectionIndex))
        controllerDidChangeContent(fetchController)
    }

    func object(at indexPath: IndexPath) -> FetchedObject {
        sections[indexPath.section].displayableObjects[indexPath.item]
    }

    func indexPath(for object: FetchedObject) -> IndexPath? {
        guard let indexPath = fetchController.indexPath(for: object) else {
            return nil
        }

        let section = sections[indexPath.section]
        let numberOfItemsDisplayed = section.numberOfDisplayableObjects
        return indexPath.item < numberOfItemsDisplayed ? indexPath : nil
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

        return CollapsibleResultsSection(
            section: section,
            collapsed: collapsedSectionNames.contains(section.name),
            config: sectionConfigs[section.name]
        )
    }
}

// MARK: - Fetch Methods
public extension CollapsibleSectionsFetchedResultsController {
    @MainActor
    func performFetch(
        completion: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        fetchController.performFetch(completion: completion)
    }

    @MainActor
    func resort(
        using newSortDescriptors: [NSSortDescriptor],
        completion: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        fetchController.resort(using: newSortDescriptors, completion: completion)
    }
}

// MARK: - FetchedResultsControllerDelegate
extension CollapsibleSectionsFetchedResultsController: FetchedResultsControllerDelegate {
    public func controllerWillChangeContent(_ controller: FetchedResultsController<FetchedObject>) {
        collapsedSectionsModifiedDuringContentChange.removeAll()
        changedSectionsDuringContentChange.removeAll()
        deletedSectionsDuringContentChange.removeAll()
        previousSectionsDuringContentChange = self.sections

        delegate?.controllerWillChangeContent(self)
    }

    public func controllerDidChangeContent(_ controller: FetchedResultsController<FetchedObject>) {
        let sectionsToNotify = collapsedSectionsModifiedDuringContentChange.filter { section in
            !changedSectionsDuringContentChange.contains(section) && !deletedSectionsDuringContentChange.contains(section)
        }
        for sectionName in sectionsToNotify {
            guard let section = previousSectionsDuringContentChange.first(where: { $0.name == sectionName }),
                  let index = previousSectionsDuringContentChange.firstIndex(of: section)
            else {
                continue
            }

            let change: FetchedResultsChange = .update(location: index)
            delegate?.controller(self, didChange: section, for: change)
        }

        collapsedSectionsModifiedDuringContentChange.removeAll()
        changedSectionsDuringContentChange.removeAll()
        deletedSectionsDuringContentChange.removeAll()
        previousSectionsDuringContentChange.removeAll()

        delegate?.controllerDidChangeContent(self)
    }

    public func controller(
        _ controller: FetchedResultsController<FetchedObject>,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
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

            if fromSection.isCollapsed, toSection.isCollapsed {
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
        _ controller: FetchedResultsController<FetchedObject>,
        didChange section: FetchedResultsSection<FetchedObject>,
        for change: FetchedResultsChange<Int>
    ) {
        let sectionToNotify: CollapsibleResultsSection<FetchedObject>
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

// MARK: - DelegateThunk

private class DelegateThunk<FetchedObject: FetchableObject> {
    typealias Parent = CollapsibleSectionsFetchedResultsControllerDelegate<FetchedObject>
    typealias Controller = CollapsibleSectionsFetchedResultsController<FetchedObject>
    typealias Section = CollapsibleResultsSection<FetchedObject>

    private weak var parent: (any Parent)?

#if compiler(<6)
    private let willChange: @MainActor (_ controller: Controller) -> Void
    private let didChange: @MainActor (_ controller: Controller) -> Void

    private let changeObject: @MainActor (_ controller: Controller, _ object: FetchedObject, _ change: FetchedResultsChange<IndexPath>) -> Void
    private let changeSection: @MainActor (_ controller: Controller, _ section: Section, _ change: FetchedResultsChange<Int>) -> Void
#endif

    init(_ parent: some Parent) {
        self.parent = parent

#if compiler(<6)
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
#endif
    }
}

extension DelegateThunk: CollapsibleSectionsFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: Controller) {
#if compiler(>=6)
        self.parent?.controllerWillChangeContent(controller)
#else
        self.willChange(controller)
#endif
    }

    func controllerDidChangeContent(_ controller: Controller) {
#if compiler(>=6)
        self.parent?.controllerDidChangeContent(controller)
#else
        self.didChange(controller)
#endif
    }

    func controller(
        _ controller: Controller,
        didChange object: FetchedObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
#if compiler(>=6)
        self.parent?.controller(controller, didChange: object, for: change)
#else
        self.changeObject(controller, object, change)
#endif
    }

    func controller(
        _ controller: Controller,
        didChange section: Section,
        for change: FetchedResultsChange<Int>
    ) {
#if compiler(>=6)
        self.parent?.controller(controller, didChange: section, for: change)
#else
        self.changeSection(controller, section, change)
#endif
    }
}
