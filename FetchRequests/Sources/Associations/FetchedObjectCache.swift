//
//  FetchedObjectCache.swift
//  FetchRequests
//
//  Created by Ansel Merino Crew Work on 1/15/21.
//  Copyright © 2021 Speramus Inc. All rights reserved.
//

import Foundation

public class FetchedObjectCache<T: CachableEntityID> {
    private var storage: [T.FetchableEntity.ID: T.FetchableEntity] = [:]

    public subscript(key: T.FetchableEntity.ID) -> T.FetchableEntity? {
        get {
            return get(byID: key)
        }
        set {
            guard key == newValue?.id else {
                storage[key] = nil
                return
            }
            storage[key] = newValue
        }
    }

    private func get(byID id: T.FetchableEntity.ID) -> T.FetchableEntity? {
        guard let object = storage[id], object.id == id else {
            let foundObject = T.fetch(byID: T(id: id))
            foundObject?.listenForUpdates()
            storage[id] = foundObject
            return foundObject
        }
        return object
    }
}

public protocol CachableEntityID: FetchableEntityID {
    var id: Self.FetchableEntity.ID { get }
    init(id: Self.FetchableEntity.ID)
}
