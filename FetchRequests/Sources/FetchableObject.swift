//
//  FetchableObject.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 3/14/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

/// A class of types that should be fetchable via FetchRequests
public typealias FetchableObject = NSObject & FetchableObjectProtocol

/// A class of types whose instances hold the value of an entity with stable identity.
/// This exists purely to support targetting OSes that bundle Swift before v5.1
public protocol FRIdentifiable {
    /// A type representing the stable identity of the entity associated with `self`.
    associatedtype ID: Hashable
    /// The stable identity of the entity associated with `self`.
    var id: ID { get }
}

/// A class of types whose instances hold raw data of that entity
public protocol RawDataRepresentable {
    associatedtype RawData

    /// Initialize a fetchable object from raw data
    init?(data: RawData)

    /// The underlying data of the entity associated with `self`.
    var data: RawData { get }
}

/// A class of types that should be fetchable via FetchRequests
public protocol FetchableObjectProtocol: AnyObject, FRIdentifiable, RawDataRepresentable
    where ID: Comparable
{
    /// Has this object been marked as deleted?
    var isDeleted: Bool { get }

    /// Parse raw data to return the expected entity ID
    ///
    /// - parameter data: Raw data that potentially represents a FetchableObject
    /// - returns: The entityID for a fetchable object
    static func entityID(from data: RawData) -> ID?

    /// Listen for changes to the underlying data of `self`
    func observeDataChanges(_ handler: @escaping () -> Void) -> InvalidatableToken

    /// Listen for changes to whether `self` is deleted
    func observeIsDeletedChanges(_ handler: @escaping () -> Void) -> InvalidatableToken

    /// Enforce listening for changes to the underlying data of `self`
    func listenForUpdates()
}

extension FetchableObjectProtocol {
    public func listenForUpdates() {}
}
