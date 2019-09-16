//
//  CWFetchableObject.swift
//  FetchRequests-iOS
//
//  Created by Adam Lickel on 3/14/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation

public typealias CWFetchableObject = NSObject & CWFetchableObjectProtocol

// As of Swift 5 this crashes
private let canUseRawData = false

@available(iOS, deprecated: 13, message: "Use system Identifiable if it won't crash on iOS 12")
public protocol CWIdentifiable {
    associatedtype ID : Hashable
    var id: Self.ID { get }
}

public protocol _CWFetchableObjectProtocolBase: class, CWIdentifiable {
    #if canUseRawData
    associatedtype RawData
    #else
    typealias RawData = [String: Any]
    #endif

    var id: ID { get }
    var data: RawData { get }
    var isDeleted: Bool { get }
}

public protocol CWFetchableObjectProtocol: _CWFetchableObjectProtocolBase {
    associatedtype KeyPathBase: _CWFetchableObjectProtocolBase where
        KeyPathBase.ID == ID, KeyPathBase.RawData == RawData

    init?(data: RawData)
    var observingUpdates: Bool { get set }

    static var idKeyPath: KeyPath<KeyPathBase, ID> { get }
    static var dataKeyPath: KeyPath<KeyPathBase, RawData> { get }
    static var deletedKeyPath: KeyPath<KeyPathBase, Bool> { get }

    static func entityID(from data: RawData) -> ID?
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
