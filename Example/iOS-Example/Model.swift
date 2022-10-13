//
//  Model.swift
//  iOS Example
//
//  Created by Adam Lickel on 7/2/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

import FetchRequests

@dynamicMemberLookup
class Model: NSObject {
    typealias ID = String

    struct RawData: Codable, Identifiable, Equatable {
        let id: ID
        let createdAt: Date
        var updatedAt: Date
    }

    @Observable
    var data: RawData {
        willSet {
            integrate(data: newValue)
        }
    }

    @objc
    dynamic private(set) var updatedAt: Date = .distantPast

    @objc
    dynamic private(set) var isDeleted: Bool = false

    @objc
    dynamic var observingUpdates: Bool = false {
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

    subscript<Property>(dynamicMember keyPath: KeyPath<RawData, Property>) -> Property {
        data[keyPath: keyPath]
    }

    override init() {
        self.data = RawData(
            id: UUID().uuidString,
            createdAt: Date(),
            updatedAt: Date()
        )
        super.init()
        integrate(data: data)
    }

    required init(data: RawData) {
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

// MARK: - Identifiable

extension Model: Identifiable {
    var id: ID {
        return data.id
    }
}

// MARK: - Persistence Operations

extension Model {
    func save() throws {
        try Self.save(self)
    }

    func delete() throws {
        try Self.delete(self)
    }
}

// MARK: - FetchableObjectProtocol

extension Model: FetchableObjectProtocol {
    func observeDataChanges(_ handler: @escaping @MainActor () -> Void) -> InvalidatableToken {
        return _data.observeChanges { @MainActor(unsafe) change in
            handler()
        }
    }

    func observeIsDeletedChanges(_ handler: @escaping @MainActor () -> Void) -> InvalidatableToken {
        return self.observe(\.isDeleted, options: [.old, .new]) { @MainActor(unsafe) object, change in
            guard let old = change.oldValue, let new = change.newValue, old != new else {
                return
            }
            handler()
        }
    }

    static func entityID(from data: RawData) -> Model.ID? {
        return data.id
    }

    func listenForUpdates() {
        observingUpdates = true
    }
}

// MARK: - Private Helpers

private extension Model {
    func integrate(data: RawData) {
        // We only need to set KVO-able properties since we're using @dynamicMemberLookup
        updatedAt = data.updatedAt
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

        guard model.updatedAt > self.updatedAt else {
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
