//
//  PaginatingFetchDefinition.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public class PaginatingFetchDefinition<FetchedObject: FetchableObject>: FetchDefinition<FetchedObject> {
    public typealias PaginationRequest = @MainActor (
        _ currentResults: [FetchedObject],
        _ completion: @escaping ([FetchedObject]?) -> Void
    ) -> Void

    internal let paginationRequest: PaginationRequest

    public init<
        VoidToken: ObservableToken<Void>,
        DataToken: ObservableToken<FetchedObject.RawData>
    >(
        request: @escaping Request,
        paginationRequest: @escaping PaginationRequest,
        objectCreationToken: DataToken,
        creationInclusionCheck: @escaping CreationInclusionCheck = { _ in true },
        associations: [FetchRequestAssociation<FetchedObject>] = [],
        dataResetTokens: [VoidToken] = []
    ) {
        self.paginationRequest = paginationRequest
        super.init(
            request: request,
            objectCreationToken: objectCreationToken,
            creationInclusionCheck: creationInclusionCheck,
            associations: associations,
            dataResetTokens: dataResetTokens
        )
    }
}

private extension InternalFetchResultsControllerProtocol {
    @MainActor
    func performPagination(
        with paginationRequest: PaginatingFetchDefinition<FetchedObject>.PaginationRequest,
        completion: @escaping (_ hasPageResults: Bool) -> Void
    ) {
        let currentResults = self.fetchedObjects
        paginationRequest(currentResults) { [weak self] pageResults in
            guard let pageResults else {
                completion(false)
                return
            }

            performOnMainThread {
                self?.manuallyInsert(objects: pageResults, emitChanges: true)
            }

            DispatchQueue.main.async {
                completion(!pageResults.isEmpty)
            }
        }
    }
}

public class PaginatingFetchedResultsController<
    FetchedObject: FetchableObject
>: FetchedResultsController<FetchedObject> {
    private unowned let paginatingDefinition: PaginatingFetchDefinition<FetchedObject>

    public init(
        definition: PaginatingFetchDefinition<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true
    ) {
        paginatingDefinition = definition

        super.init(
            definition: definition,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )
    }

    @MainActor
    public func performPagination(completion: @escaping (_ hasPageResults: Bool) -> Void = { _ in }) {
        performPagination(with: paginatingDefinition.paginationRequest, completion: completion)
    }

    @MainActor
    public func performPagination() async -> Bool {
        await withCheckedContinuation { continuation in
            performPagination { hasPageResults in
                continuation.resume(returning: hasPageResults)
            }
        }
    }
}

public class PausablePaginatingFetchedResultsController<
    FetchedObject: FetchableObject
>: PausableFetchedResultsController<FetchedObject> {
    private unowned let paginatingDefinition: PaginatingFetchDefinition<FetchedObject>

    public init(
        definition: PaginatingFetchDefinition<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true
    ) {
        paginatingDefinition = definition

        super.init(
            definition: definition,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )
    }

    @MainActor
    public func performPagination() {
        performPagination(with: paginatingDefinition.paginationRequest, completion: { _ in })
    }
}
