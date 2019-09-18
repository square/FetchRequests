//
//  CWFetchableObject.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 3/14/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

// As of Swift 5 this crashes
private let canUseRawData = false

/// A class of types that should be fetchable via CWFetchRequests
public typealias CWFetchableObject = NSObject & CWFetchableObjectProtocol

/// A class of types whose instances hold the value of an entity with stable identity.
/// This exists purely to support targetting OSes that bundle Swift before v5.1
public protocol CWIdentifiable {
    /// A type representing the stable identity of the entity associated with `self`.
    associatedtype ID: Hashable
    /// The stable identity of the entity associated with `self`.
    var id: ID { get }
}

public protocol CWRawDataRepresentable {
    #if canUseRawData
    /// A type representing the underlying data of the entity associated with `self`.
    associatedtype RawData
    #else
    typealias RawData = [String: Any]
    #endif

    /// Initialize an object from raw data
    init?(data: RawData)

    /// The underlying data of the entity associated with `self`.
    var data: RawData { get }
}

/// A class of types that should be fetchable via CWFetchRequests
public protocol CWFetchableObjectProtocol: class, CWRawDataRepresentable, CWIdentifiable {
    associatedtype KeyPathBase: CWRawDataRepresentable & CWIdentifiable where
        KeyPathBase.ID == ID, KeyPathBase.RawData == RawData

    /// Has this object been marked as deleted?
    var isDeleted: Bool { get }

    /// Parse raw data to return the expected entity ID
    ///
    /// - parameter data: Raw data that potentially represents a FetchableObject
    /// - returns: The entityID for a fetchable object
    static func entityID(from data: RawData) -> ID?

    static var idKeyPath: KeyPath<KeyPathBase, ID> { get }
    static var dataKeyPath: KeyPath<KeyPathBase, RawData> { get }
    static var deletedKeyPath: KeyPath<KeyPathBase, Bool> { get }

    var observingUpdates: Bool { get set }

    static func rawDataIsIdentical(lhs: RawData, rhs: RawData) -> Bool
}

extension CWFetchableObjectProtocol {
    static func rawDataIsIdentical(lhs: RawData?, rhs: RawData?) -> Bool {
        if lhs == nil, rhs == nil {
            return true
        } else if let lhs = lhs, let rhs = rhs {
            return rawDataIsIdentical(lhs: lhs, rhs: rhs)
        } else {
            return false
        }
    }
}

#if canUseRawData
extension CWFetchableObjectProtocol where RawData: Equatable {
    static func rawDataIsIdentical(lhs: RawData, rhs: RawData) -> Bool {
        return lhs == rhs
    }
}
#endif
