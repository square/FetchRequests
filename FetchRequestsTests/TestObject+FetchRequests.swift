//
//  TestObject+FetchRequests.swift
//  FetchRequests
//
//  Created by Adam Lickel on 9/16/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation
import FetchRequests

extension FetchRequest where FetchedObject: TestObject {
    convenience init(
        request: @escaping Request,
        objectCreationNotification: Notification.Name? = nil,
        creationInclusionCheck: @escaping CreationInclusionCheck = { _ in true },
        associations: [FetchRequestAssociation<FetchedObject>] = []
    ) {
        let objectCreationNotification = objectCreationNotification ?? FetchedObject.objectWasCreated()

        let dataResetNotifications = [
            FetchedObject.dataWasCleared(),
        ]

        self.init(
            request: request,
            objectCreationToken: TestEntityObservableToken(name: objectCreationNotification),
            creationInclusionCheck: creationInclusionCheck,
            associations: associations,
            dataResetTokens: dataResetNotifications.map {
                VoidNotificationObservableToken(name: $0)
            }
        )
    }
}

extension PaginatingFetchRequest where FetchedObject: TestObject {
    convenience init(
        request: @escaping Request,
        paginationRequest: @escaping PaginationRequest,
        objectCreationNotification: Notification.Name? = nil,
        creationInclusionCheck: @escaping CreationInclusionCheck = { _ in true },
        associations: [FetchRequestAssociation<FetchedObject>] = []
    ) {
        let objectCreationNotification = objectCreationNotification ?? FetchedObject.objectWasCreated()

        let dataResetNotifications = [
            FetchedObject.dataWasCleared(),
        ]

        self.init(
            request: request,
            paginationRequest: paginationRequest,
            objectCreationToken: TestEntityObservableToken(name: objectCreationNotification),
            creationInclusionCheck: creationInclusionCheck,
            associations: associations,
            dataResetTokens: dataResetNotifications.map {
                VoidNotificationObservableToken(name: $0)
            }
        )
    }
}
