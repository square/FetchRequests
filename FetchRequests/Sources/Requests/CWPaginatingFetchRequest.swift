//
//  CWPaginatingFetchRequest.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public class CWPaginatingFetchRequest<FetchedObject: CWFetchableObject>: CWFetchRequest<FetchedObject> {
    public typealias PaginationRequest = (
        _ currentResults: [FetchedObject],
        _ completion: @escaping ([FetchedObject]?) -> Void
    ) -> Void

    internal let paginationRequest: PaginationRequest

    public init<VoidToken: CWObservableToken, DataToken: CWObservableToken>(
        request: @escaping Request,
        paginationRequest: @escaping PaginationRequest,
        objectCreationToken: DataToken,
        creationInclusionCheck: @escaping CreationInclusionCheck = { _ in true },
        associations: [CWFetchRequestAssociation<FetchedObject>] = [],
        dataResetTokens: [VoidToken] = []
    ) where VoidToken.Parameter == Void, DataToken.Parameter == FetchedObject.RawData {
        self.paginationRequest = paginationRequest
        super.init(
            request: request,
            objectCreationToken: objectCreationToken,
            creationInclusionCheck: creationInclusionCheck,
            associations: associations,
            dataResetTokens: dataResetTokens
        )
    }

    fileprivate func performPagination<Controller>(in fetchController: Controller) where Controller: CWInternalFetchResultsControllerProtocol, Controller.FetchedObject == FetchedObject {
        let currentResults = fetchController.fetchedObjects
        paginationRequest(currentResults) { [weak fetchController] pageResults in
            guard let pageResults = pageResults else {
                return
            }
            fetchController?.manuallyInsert(objects: pageResults, emitChanges: true)
        }
    }
}

public class CWPaginatingFetchedResultsController<
    FetchedObject: CWFetchableObject
>: CWFetchedResultsController<FetchedObject> {
    private unowned let paginatingRequest: CWPaginatingFetchRequest<FetchedObject>

    public init(
        request: CWPaginatingFetchRequest<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true
    ) {
        paginatingRequest = request

        super.init(
            request: request,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )
    }

    public func performPagination() {
        paginatingRequest.performPagination(in: self)
    }
}

public class CWPausablePaginatingFetchedResultsController<
    FetchedObject: CWFetchableObject
>: CWPausableFetchedResultsController<FetchedObject> {
    private unowned let paginatingRequest: CWPaginatingFetchRequest<FetchedObject>
    
    public init(
        request: CWPaginatingFetchRequest<FetchedObject>,
        sortDescriptors: [NSSortDescriptor] = [],
        sectionNameKeyPath: SectionNameKeyPath? = nil,
        debounceInsertsAndReloads: Bool = true
    ) {
        paginatingRequest = request
        
        super.init(
            request: request,
            sortDescriptors: sortDescriptors,
            sectionNameKeyPath: sectionNameKeyPath,
            debounceInsertsAndReloads: debounceInsertsAndReloads
        )
    }
    
    public func performPagination() {
        paginatingRequest.performPagination(in: self)
    }
}
