//
//  FetchableRequest.swift
//
//  Created by Adam Lickel on 6/10/21.
//

import Foundation
import SwiftUI

@propertyWrapper
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
public struct SectionedFetchableRequest<FetchedObject: FetchableObject>: DynamicProperty {
    @FetchableRequest
    private var base: FetchableResults<FetchedObject>

    public var wrappedValue: SectionedFetchableResults<FetchedObject> {
        return SectionedFetchableResults(contents: _base.fetchController.sections)
    }

    public init(
        fetchDefinition: FetchDefinition<FetchedObject>,
        sectionNameKeyPath: KeyPath<FetchedObject, String>,
        sortDescriptors: [NSSortDescriptor] = [],
        debounceInsertsAndReloads: Bool = true,
        animation: Animation? = nil
    ) {
        let controller = FetchedResultsController(
            fetchDefinition: fetchDefinition,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )

        _base = FetchableRequest(controller: controller, animation: animation)
    }

    public mutating func update() {
        _base.update()
    }
}

@propertyWrapper
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
public struct FetchableRequest<FetchedObject: FetchableObject>: DynamicProperty {
    @State
    public private(set) var wrappedValue = FetchableResults<FetchedObject>()

    @State
    fileprivate var fetchController: FetchedResultsController<FetchedObject>

    @State
    private var observer = FetchableRequestObserver<FetchedObject>()

    private let animation: Animation?

    internal var hasFetchedObjects: Bool {
        return fetchController.hasFetchedObjects
    }

    public init(
        fetchDefinition: FetchDefinition<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        debounceInsertsAndReloads: Bool = true,
        animation: Animation? = nil
    ) {
        let controller = FetchedResultsController(
            fetchDefinition: fetchDefinition,
            sortDescriptors: sortDescriptors,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )

        self.init(controller: controller, animation: animation)
    }

    internal init(
        controller: FetchedResultsController<FetchedObject>,
        animation: Animation? = nil
    ) {
        _fetchController = State(initialValue: controller)
        self.animation = animation
    }

    public mutating func update() {
        _wrappedValue.update()
        _fetchController.update()

        guard !fetchController.hasFetchedObjects else {
            return
        }

        defer {
            fetchController.performFetch()
        }

        let controller = fetchController
        let binding = $wrappedValue
        let animation = self.animation

        observer.handler = { [weak controller] in
            guard let controller = controller else {
                return
            }
            withAnimation(animation) {
                let newVersion = binding.wrappedValue.version + 1
                binding.wrappedValue = FetchableResults(
                    contents: controller.fetchedObjects,
                    version: newVersion
                )
            }
        }

        fetchController.setDelegate(observer)
    }
}

public struct FetchableResults<FetchedObject: FetchableObject> {
    private var contents: [FetchedObject]
    fileprivate var version: Int

    fileprivate init(
        contents: [FetchedObject] = [],
        version: Int = 0
    ) {
        self.contents = contents

        // Version forces our view to re-render even if the contents haven't changed
        // This is necessary because of things like associated values or model updates
        self.version = version
    }
}

public struct SectionedFetchableResults<FetchedObject: FetchableObject> {
    private let contents: [FetchedResultsSection<FetchedObject>]

    fileprivate init(contents: [FetchedResultsSection<FetchedObject>] = []) {
        self.contents = contents
    }
}

extension FetchableResults: RandomAccessCollection {
    public var startIndex: Int {
      return contents.startIndex
    }

    public var endIndex: Int {
      return contents.endIndex
    }

    public subscript (position: Int) -> FetchedObject {
        return contents[position]
    }
}

extension SectionedFetchableResults: RandomAccessCollection {
    public var startIndex: Int {
      return contents.startIndex
    }

    public var endIndex: Int {
      return contents.endIndex
    }

    public subscript (position: Int) -> FetchedResultsSection<FetchedObject> {
        return contents[position]
    }
}

private class FetchableRequestObserver<
    FetchedObject: FetchableObject
>: FetchedResultsControllerDelegate {
    var handler: () -> Void = { }

    func controllerDidChangeContent(_ controller: FetchedResultsController<FetchedObject>) {
        handler()
    }
}
