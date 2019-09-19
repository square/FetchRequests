//
//  CWRawDataRepresentable.swift
//  FetchRequests
//
//  Created by Adam Lickel on 9/19/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

/// A class of types whose instances hold raw data of that entity
public protocol CWRawDataRepresentable {
    #if false
    /// A type representing the underlying data of the entity associated with `self`.
    associatedtype RawData: Equatable
    #else
    typealias RawData = CWRawData
    #endif

    /// Initialize a fetchable object from raw data
    init?(data: RawData)

    /// The underlying data of the entity associated with `self`.
    var data: RawData { get }
}

// MARK: - CWRawData

/// This represents raw data within the FetchRequests framework
/// It exists to work around compiler/runtime bugs around pointers in closure thunks
public struct CWRawData {
    public typealias Storage = [String: Any]

    public var storage: Storage

    public init(storage: Storage) {
        self.storage = storage
    }
}

extension CWRawData: Equatable {
    public static func == (lhs: CWRawData, rhs: CWRawData) -> Bool {
        return (lhs.storage as NSDictionary) == (rhs.storage as NSDictionary)
    }
}

extension CWRawData: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let data: [String: Any] = elements.reduce(into: [:]) { memo, element in
            memo[element.0] = element.1
        }
        self.init(storage: data)
    }
}

public extension CWRawData {
    subscript(key: String) -> Any? {
        get {
            return storage[key]
        }
        set {
            storage[key] = newValue
        }
    }
}
