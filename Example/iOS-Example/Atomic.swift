//
//  Atomic.swift
//  iOS Example
//
//  Created by Adam Lickel on 9/22/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

@propertyWrapper
struct Atomic<Value> {
    private let queue = DispatchQueue(label: "Atomic Queue", attributes: .concurrent)
    private var storage: Value

    init(wrappedValue: Value) {
        self.storage = wrappedValue
    }

    var wrappedValue: Value {
        get {
            return queue.sync { storage }
        }
        set {
            queue.sync(flags: .barrier) { storage = newValue }
        }
    }

    mutating func mutate(_ mutation: (inout Value) throws -> Void) rethrows {
        return try queue.sync(flags: .barrier) {
            try mutation(&storage)
        }
    }
}
