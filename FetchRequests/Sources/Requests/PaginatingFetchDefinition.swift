//
//  PaginatingFetchDefinition.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public class PaginatingFetchDefinition<FetchedObject: FetchableObject>: FetchDefinition<FetchedObject> {
    public typealias PaginationRequest = (
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
    func performPagination(
        with paginationRequest: PaginatingFetchDefinition<FetchedObject>.PaginationRequest
    ) {
        let currentResults = self.fetchedObjects
        paginationRequest(currentResults) { [weak self] pageResults in
            guard let pageResults else {
                return
            }
            self?.manuallyInsert(objects: pageResults, emitChanges: true)
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

    public func performPagination() {
        performPagination(with: paginatingDefinition.paginationRequest)
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

    public func performPagination() {
        performPagination(with: paginatingDefinition.paginationRequest)
    }
}
