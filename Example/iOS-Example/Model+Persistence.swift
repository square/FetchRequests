//
//  Model+Persistence.swift
//  iOS Example
//
//  Created by Adam Lickel on 7/2/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

import FetchRequests

enum ModelError: Error {
    case invalidDate
}

private let encoder = JSONEncoder()
private let decoder = JSONDecoder()

// MARK: - Event Notifications

extension Model {
    func rawObjectEventUpdated() -> Notification.Name {
        Notification.Name("\(NSStringFromClass(type(of: self))).rawObjectEventUpdated.\(id)")
    }

    class func objectWasCreated() -> Notification.Name {
        Notification.Name("\(NSStringFromClass(self)).objectWasCreated")
    }

    class func objectWasDeleted() -> Notification.Name {
        Notification.Name("\(NSStringFromClass(self)).objectWasDeleted")
    }

    class func dataWasCleared() -> Notification.Name {
        Notification.Name("\(NSStringFromClass(self)).dataWasCleared")
    }
}

// MARK: - Storage

extension Model {
    fileprivate class var storage: [String: Any] {
        assert(Thread.isMainThread)

        let key = NSStringFromClass(self)
        return UserDefaults.standard.dictionary(forKey: key) ?? [:]
    }

    private class func updateStorage(_ block: (inout [String: Any]) throws -> Void) rethrows {
        assert(Thread.isMainThread)

        let defaults = UserDefaults.standard
        let key = NSStringFromClass(self)

        var storage = defaults.dictionary(forKey: key) ?? [:]
        try block(&storage)
        defaults.set(storage, forKey: key)
    }

    private class func validateCanUpdate(_ originalModel: Model) throws -> Model {
        var data = originalModel.data
        data.updatedAt = Date()

        let model = Model(data: data)

        guard model.createdAt != .distantPast else {
            throw ModelError.invalidDate
        }

        guard let existing = self.fetch(byID: model.id) else {
            // First instance
            return model
        }
        guard existing.updatedAt <= model.updatedAt,
              existing.createdAt == model.createdAt
        else {
            throw ModelError.invalidDate
        }

        // Newest instance
        return model
    }

    class func save(_ originalModel: Model) throws {
        let model = try validateCanUpdate(originalModel)

        try updateStorage {
            let data = try encoder.encode(model.data)
            $0[model.id] = data
        }

        NotificationCenter.default.post(
            name: model.rawObjectEventUpdated(),
            object: model,
            userInfo: ["data": model.data]
        )

        NotificationCenter.default.post(name: objectWasCreated(), object: model)
    }

    class func delete(_ originalModel: Model) throws {
        let model = try validateCanUpdate(originalModel)

        updateStorage {
            $0[model.id] = nil
        }

        NotificationCenter.default.post(
            name: model.rawObjectEventUpdated(),
            object: model
        )

        NotificationCenter.default.post(name: objectWasDeleted(), object: model)
    }

    class func reset() {
        updateStorage {
            $0.removeAll()
        }

        NotificationCenter.default.post(name: dataWasCleared(), object: nil)
    }
}

extension NSObjectProtocol where Self: Model {
    static func fetchAll() -> [Self] {
        storage.values.lazy.compactMap { value in
            value as? Data
        }.compactMap { data in
            try? decoder.decode(Model.RawData.self, from: data)
        }.map {
            Self(data: $0)
        }
    }

    static func fetch(byID id: Model.ID) -> Self? {
        storage[id].flatMap { value in
            value as? Data
        }.flatMap { data in
            try? decoder.decode(Model.RawData.self, from: data)
        }.map {
            Self(data: $0)
        }
    }
}
