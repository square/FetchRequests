//
//  Observable.swift
//  iOS Example
//
//  Created by Adam Lickel on 9/22/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

import FetchRequests

struct Change<Value> {
    var oldValue: Value
    var newValue: Value
}

@propertyWrapper
class Observable<Value> {
    typealias Handler = @MainActor (Change<Value>) -> Void

    fileprivate var observers: Atomic<[UUID: Handler]> = Atomic(wrappedValue: [:])

    var wrappedValue: Value {
        @MainActor(unsafe)
        didSet {
            assert(Thread.isMainThread)

            let change = Change(oldValue: oldValue, newValue: wrappedValue)
            let observers = self.observers.wrappedValue

            observers.values.forEach { $0(change) }
        }
    }

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    func observe(handler: @escaping Handler) -> InvalidatableToken {
        let token = Token(parent: self)
        observers.mutate { value in
            value[token.uuid] = handler
        }
        return token
    }
}

extension Observable where Value: Equatable {
    func observeChanges(handler: @escaping Handler) -> InvalidatableToken {
        observe { change in
            guard change.oldValue != change.newValue else {
                return
            }
            handler(change)
        }
    }
}

private class Token<Value>: InvalidatableToken {
    let uuid = UUID()
    private weak var parent: Observable<Value>?

    init(parent: Observable<Value>) {
        self.parent = parent
    }

    func invalidate() {
        parent?.observers.mutate { value in
            value[uuid] = nil
        }
        parent = nil
    }

    deinit {
        invalidate()
    }
}
