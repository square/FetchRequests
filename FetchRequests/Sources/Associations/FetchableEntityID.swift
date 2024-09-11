//
//  FetchableEntityID.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public protocol FetchableEntityID<FetchableEntity>: Hashable, Sendable {
    associatedtype FetchableEntity: FetchableObject

    init?(from entity: FetchableEntity)

    static func fetch(byID objectID: Self) -> FetchableEntity?
    static func fetch(byIDs objectIDs: [Self]) -> [FetchableEntity]

    static func fetch(
        byID objectID: Self,
        completion: @escaping @Sendable @MainActor (FetchableEntity?) -> Void
    )
    static func fetch(
        byIDs objectIDs: [Self],
        completion: @escaping @Sendable @MainActor ([FetchableEntity]) -> Void
    )
}

extension FetchableEntityID {
    static func fetch(byID objectID: Self) -> FetchableEntity? {
        self.fetch(byIDs: [objectID]).first
    }

    static func fetch(
        byID objectID: Self,
        completion: @escaping @Sendable @MainActor (FetchableEntity?) -> Void
    ) {
        self.fetch(byIDs: [objectID]) { objects in
            completion(objects.first)
        }
    }
}
