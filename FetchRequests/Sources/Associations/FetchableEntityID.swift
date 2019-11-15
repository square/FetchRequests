//
//  FetchableEntityID.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public protocol FetchableEntityID: Hashable {
    associatedtype FetchableEntity: FetchableObject

    init?(from entity: FetchableEntity)

    static func fetch(byID objectID: Self) -> FetchableEntity?
    static func fetch(byIDs objectIDs: [Self]) -> [FetchableEntity]

    static func fetch(byID objectID: Self, completion: @escaping (FetchableEntity?) -> Void)
    static func fetch(byIDs objectIDs: [Self], completion: @escaping ([FetchableEntity]) -> Void)
}

extension FetchableEntityID {
    static func fetch(byID objectID: Self) -> FetchableEntity? {
        return self.fetch(byIDs: [objectID]).first
    }

    static func fetch(byID objectID: Self, completion: @escaping (FetchableEntity?) -> Void) {
        self.fetch(byIDs: [objectID]) { objects in
            completion(objects.first)
        }
    }
}
