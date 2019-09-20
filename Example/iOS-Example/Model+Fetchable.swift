//
//  Model+Fetchable.swift
//  iOS Example
//
//  Created by Adam Lickel on 7/2/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

import FetchRequests

// MARK: - Fetch Requests

extension CWFetchableObjectProtocol where Self: Model {
    static func fetchRequest() -> CWFetchRequest<Self> {
        let dataResetTokens: [ModelClearedToken<Self>] = [
            ModelClearedToken(),
        ]

        return CWFetchRequest<Self>(
            request: { completion in
                completion(fetchAll())
            },
            objectCreationToken: ModelCreationToken<Self>(),
            dataResetTokens: dataResetTokens
        )
    }
}

class ModelCreationToken<T: Model>: CWObservableToken {
    let notificationToken: CWObservableNotificationCenterToken
    let include: (T) -> Bool

    init(name: Notification.Name = T.objectWasCreated(), include: @escaping (T) -> Bool = { _ in true }) {
        notificationToken = CWObservableNotificationCenterToken(name: name)
        self.include = include
    }

    func invalidate() {
        notificationToken.invalidate()
    }

    func observe(handler: @escaping (T.RawData) -> Void) {
        let include = self.include
        notificationToken.observe { notification in
            guard let object = notification.object as? T else {
                return
            }
            guard include(object) else {
                return
            }
            handler(object.data)
        }
    }
}

class ModelClearedToken<T: Model>: CWObservableToken {
    let notificationToken: CWObservableNotificationCenterToken

    init() {
        notificationToken = CWObservableNotificationCenterToken(name: T.dataWasCleared())
    }

    func invalidate() {
        notificationToken.invalidate()
    }

    func observe(handler: @escaping (()) -> Void) {
        notificationToken.observe { notification in
            handler(())
        }
    }
}
