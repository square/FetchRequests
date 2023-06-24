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

extension FetchableObjectProtocol where Self: Model {
    static func fetchDefinition() -> FetchDefinition<Self> {
        let dataResetTokens: [ModelClearedToken<Self>] = [
            ModelClearedToken(),
        ]

        return FetchDefinition<Self>(
            request: { completion in
                completion(fetchAll())
            },
            objectCreationToken: ModelCreationToken<Self>(),
            dataResetTokens: dataResetTokens
        )
    }
}

class ModelCreationToken<T: Model>: ObservableToken {
    let notificationToken: ObservableNotificationCenterToken
    let include: (T) -> Bool

    init(name: Notification.Name = T.objectWasCreated(), include: @escaping (T) -> Bool = { _ in true }) {
        notificationToken = ObservableNotificationCenterToken(name: name)
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

class ModelClearedToken<T: Model>: ObservableToken {
    let notificationToken: ObservableNotificationCenterToken

    init() {
        notificationToken = ObservableNotificationCenterToken(name: T.dataWasCleared())
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
