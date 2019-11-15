//
//  ObservableToken.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 2/22/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

func synchronized<T>(_ lockObject: AnyObject, block: () -> T) -> T {
    objc_sync_enter(lockObject)
    defer {
        objc_sync_exit(lockObject)
    }

    return block()
}

public protocol InvalidatableToken: class {
    func invalidate()
}

public protocol ObservableToken: InvalidatableToken {
    associatedtype Parameter

    func observe(handler: @escaping (Parameter) -> Void)
}

public class ObservableNotificationCenterToken: ObservableToken {
    private let name: Notification.Name
    private unowned let notificationCenter: NotificationCenter
    private var centerToken: NSObjectProtocol?

    public init(
        name: Notification.Name,
        notificationCenter: NotificationCenter = .default
    ) {
        self.name = name
        self.notificationCenter = notificationCenter
    }

    public func observe(handler: @escaping (Notification) -> Void) {
        centerToken = notificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: nil,
            using: handler
        )
    }

    public func invalidate() {
        defer {
            centerToken = nil
        }
        guard let existing = centerToken else {
            return
        }
        notificationCenter.removeObserver(existing)
    }

    deinit {
        self.invalidate()
    }
}

extension NSKeyValueObservation: InvalidatableToken {}

internal class LegacyKeyValueObserving<Object: NSObject, Value: Any>: NSObject, InvalidatableToken {
    typealias Handler = (_ object: Object, _ oldValue: Value?, _ newValue: Value?) -> Void

    private weak var object: Object?
    private let keyPath: String
    private let handler: Handler

    private var unsafeIsObserving = true

    convenience init(object: Object, keyPath: AnyKeyPath, type: Value.Type, handler: @escaping Handler) {
        self.init(object: object, keyPath: keyPath._kvcKeyPathString!, type: type, handler: handler)
    }

    init(object: Object, keyPath: String, type: Value.Type, handler: @escaping Handler) {
        self.object = object
        self.keyPath = keyPath
        self.handler = handler

        super.init()

        object.addObserver(self, forKeyPath: keyPath, options: [.old, .new], context: nil)
    }

    func invalidate() {
        synchronized(self) {
            guard unsafeIsObserving else {
                return
            }
            defer {
                unsafeIsObserving = false
            }

            object?.removeObserver(self, forKeyPath: keyPath)
        }
    }

    deinit {
        invalidate()
    }

    //swiftlint:disable:next block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let typedObject = object as? Object, typedObject == self.object, keyPath == self.keyPath else {
            return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }

        let oldValue = change?[.oldKey] as? Value
        let newValue = change?[.newKey] as? Value

        handler(typedObject, oldValue, newValue)
    }
}

internal class FetchRequestObservableToken<Parameter>: ObservableToken {
    private let _observe: (_ handler: @escaping (Parameter) -> Void) -> Void
    private let _invalidate: () -> Void

    var isObserving: Bool {
        return synchronized(self) {
            unsafeIsObserving
        }
    }

    private var unsafeIsObserving = false

    private init(observe: @escaping (_ handler: @escaping (Parameter) -> Void) -> Void, invalidate: @escaping () -> Void) {
        _observe = observe
        _invalidate = invalidate
    }

    init<Token: ObservableToken>(token: Token) where Token.Parameter == Parameter {
        _observe = { token.observe(handler: $0) }
        _invalidate = { token.invalidate() }
    }

    func observeIfNeeded(handler: @escaping (Parameter) -> Void) {
        synchronized(self) {
            guard !unsafeIsObserving else {
                return
            }
            defer {
                unsafeIsObserving = true
            }

            observe(handler: handler)
        }
    }

    func observe(handler: @escaping (Parameter) -> Void) {
        synchronized(self) {
            _observe(handler)
        }
    }

    func invalidateIfNeeded() {
        synchronized(self) {
            guard unsafeIsObserving else {
                return
            }
            defer {
                unsafeIsObserving = false
            }

            invalidate()
        }
    }

    func invalidate() {
        synchronized(self) {
            _invalidate()
        }
    }

    deinit {
        guard isObserving else {
            return
        }
        assert(false)
        invalidate()
    }
}

extension FetchRequestObservableToken where Parameter == Any {
    convenience init<Token: ObservableToken>(typeErasedToken: Token) {
        self.init(
            observe: { typeErasedToken.observe(handler: $0) },
            invalidate: { typeErasedToken.invalidate() }
        )
    }
}
