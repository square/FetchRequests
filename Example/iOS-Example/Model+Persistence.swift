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
    case cannotInflate
}

// MARK: - Event Notifications

extension Model {
    func rawObjectEventUpdated() -> Notification.Name {
        return Notification.Name("\(NSStringFromClass(type(of: self))).rawObjectEventUpdated.\(id)")
    }

    class func objectWasCreated() -> Notification.Name {
        return Notification.Name("\(NSStringFromClass(self)).objectWasCreated")
    }

    class func objectWasDeleted() -> Notification.Name {
        return Notification.Name("\(NSStringFromClass(self)).objectWasDeleted")
    }

    class func dataWasCleared() -> Notification.Name {
        return Notification.Name("\(NSStringFromClass(self)).dataWasCleared")
    }
}

// MARK: - Storage

extension Model {
    fileprivate class var storage: [String: Any] {
        assert(Thread.isMainThread)

        let key = NSStringFromClass(self)
        return UserDefaults.standard.dictionary(forKey: key) ?? [:]
    }

    fileprivate class func updateStorage(_ block: (inout [String: Any]) -> Void) {
        assert(Thread.isMainThread)

        let defaults = UserDefaults.standard
        let key = NSStringFromClass(self)

        var storage = defaults.dictionary(forKey: key) ?? [:]
        block(&storage)
        defaults.set(storage, forKey: key)
    }

    private class func validateCanUpdate(_ originalModel: Model) throws -> Model {
        var data = originalModel.data.dictionary ?? [:]
        data["updatedAt"] = Date().timeIntervalSince1970

        guard let json = JSON(data), let model = self.init(data: json) else {
            throw ModelError.cannotInflate
        }

        guard model.createdAt != .distantPast else {
            throw ModelError.invalidDate
        }

        guard let existing = self.fetch(byID: model.id) else {
            // First instance
            return model
        }
        guard existing.updatedAt <= model.updatedAt,
            existing.createdAt == model.createdAt else
        {
            throw ModelError.invalidDate
        }

        // Newest instance
        return model
    }

    class func save(_ originalModel: Model) throws {
        let model = try validateCanUpdate(originalModel)

        updateStorage {
            $0[model.id] = model.data.object
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
        return storage.values.lazy.compactMap {
            Self.RawData($0)
        }.compactMap {
            Self(data: $0)
        }
    }

    static func fetch(byID id: Model.ID) -> Self? {
        return storage[id].flatMap {
            Self.RawData($0)
        }.flatMap {
            Self(data: $0)
        }
    }
}
