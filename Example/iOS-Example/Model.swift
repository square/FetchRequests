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
    typealias ID = String
    typealias RawData = CWRawData

    @objc dynamic
    private(set) var id: ID

    @objc dynamic
    private(set) var createdAt: Date = .distantPast

    @objc dynamic
    private(set) var updatedAt: Date = .distantPast

    @Observable
    var data: RawData {
        willSet {
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
        id = UUID().uuidString
        let createdAt = Date().timeIntervalSince1970
        data = [
            "id": id,
            "createdAt": createdAt,
            "updatedAt": createdAt,
        ]
        super.init()
        integrate(data: data)
    }

    required init?(data: RawData) {
        guard let id = Model.entityID(from: data) else {
            return nil
        }
        self.id = id
        self.data = data
        super.init()
        integrate(data: data)
    }

    // MARK: - NSObject Overrides

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Model else {
            return false
        }

        return id == other.id
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)

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

// MARK: - CWFetchableObjectProtocol

extension Model: CWFetchableObjectProtocol {
    func observeDataChanges(_ handler: @escaping () -> Void) -> CWInvalidatableToken {
        return _data.observeChanges { change in handler() }
    }

    func observeIsDeletedChanges(_ handler: @escaping () -> Void) -> CWInvalidatableToken {
        return self.observe(\.isDeleted, options: [.old, .new]) { object, change in
            guard let old = change.oldValue, let new = change.newValue, old != new else {
                return
            }
            handler()
        }
    }

    static func entityID(from data: RawData) -> Model.ID? {
        return data.id?.string
    }

    func listenForUpdates() {
        observingUpdates = true
    }
}

// MARK: - Private Helpers

private extension Model {
    func integrate(data: RawData) {
        if let raw = data.createdAt?.double as TimeInterval? {
            createdAt = Date(timeIntervalSince1970: raw)
        }
        if let raw = data.updatedAt?.double as TimeInterval? {
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

        guard let data = notification.userInfo?["data"] as? RawData else {
            let info = notification.userInfo ?? [:]
            fatalError("Bad notification with userInfo \(info)")
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
