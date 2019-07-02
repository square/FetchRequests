//
//  Model.swift
//  iOS Example
//
//  Created by Adam Lickel on 7/2/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

import FetchRequests

class Model: NSObject {
    typealias ObjectID = String
    typealias RawData = [String: Any]

    @objc dynamic
    private(set) var objectID: ObjectID

    @objc dynamic
    private(set) var createdAt: Date = .distantPast

    @objc dynamic
    private(set) var updatedAt: Date = .distantPast

    private var _data: RawData = [:]
    @objc dynamic var data: RawData {
        get {
            return _data
        }
        set {
            _data = newValue
            integrate(data: newValue)
        }
    }

    @objc dynamic
    private(set) var isDeleted: Bool = false
    
    @objc dynamic
    var observingUpdates: Bool = false {
        didSet {
            guard observingUpdates != oldValue else {
                return
            }

            if observingUpdates {
                startObservingEvents()
            } else {
                stopObservingEvents()
            }
        }
    }

    override init() {
        objectID = UUID().uuidString
        super.init()
        data = [
            "id": objectID,
            "createdAt": Date().timeIntervalSince1970
        ]
    }

    required init?(data: RawData) {
        guard let id = Model.entityID(from: data) else {
            return nil
        }
        objectID = id
        super.init()
        self.data = data
    }

    // MARK: - NSObject Overrides

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Model else {
            return false
        }

        return objectID == other.objectID
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(objectID)

        return hasher.finalize()
    }
}

// MARK: - Persistence Operations

extension Model {
    func save() throws {
        try type(of: self).save(self)
    }

    func delete() throws {
        try type(of: self).delete(self)
    }
}

// MARK: - Private Helpers

private extension Model {
    func integrate(data: RawData) {
        if let raw = data["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: raw)
        }
        if let raw = data["updatedAt"] as? TimeInterval {
            updatedAt = Date(timeIntervalSince1970: raw)
        }
    }

    func stopObservingEvents() {
        NotificationCenter.default.removeObserver(
            self,
            name: self.rawObjectEventUpdated(),
            object: nil
        )
    }

    func startObservingEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dataUpdateNotification),
            name: self.rawObjectEventUpdated(),
            object: nil
        )
    }

    @objc
    func dataUpdateNotification(notification: Notification) {
        guard let model = notification.object as? Model, self == model else {
            fatalError("Bad notification with object \(String(describing: notification.object))")
        }

        guard model.updatedAt > updatedAt else {
            return
        }

        guard notification.userInfo != nil else {
            processDelete(of: model)
            return
        }

        guard let data = notification.userInfo as? RawData else {
            fatalError("Bad notification with userInfo \(String(describing: notification.userInfo))")
        }
        processUpdate(of: model, with: data)
    }

    func processUpdate(of model: Model, with data: RawData) {
        assert(Thread.isMainThread, "\(#function) must be called on the main thread")

        self.data = data
        if isDeleted {
            isDeleted = false
        }
    }

    func processDelete(of model: Model) {
        assert(Thread.isMainThread, "\(#function) must be called on the main thread")

        isDeleted = true
    }
}
