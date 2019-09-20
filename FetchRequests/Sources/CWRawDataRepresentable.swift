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
    typealias RawData = CWRawData

    /// Initialize a fetchable object from raw data
    init?(data: RawData)

    /// The underlying data of the entity associated with `self`.
    var data: RawData { get }
}

// MARK: - CWRawData

/// This represents raw data within the FetchRequests framework
/// It exists to work around compiler/runtime bugs around pointers in closure thunks
@dynamicMemberLookup
public enum CWRawData {
    case string(String)
    case dictionary([String: Any])
    case array([Any])
    case number(NSNumber)
    case bool(Bool)
    case null

    public init?(_ value: Any) {
        if let value = value as? Data {
            self.init(data: value)
        } else if let value = value as? CWRawData {
            self = value
        } else if let value = value as? String {
            self = .string(value)
        } else if let value = value as? Bool {
            self = .bool(value)
        } else if let value = value as? NSNumber {
            self = .number(value)
        } else if let value = value as? [Any] {
            self = .array(value)
        } else if let value = value as? [String: Any] {
            self = .dictionary(value)
        } else if let _ = value as? NSNull {
            self = .null
        } else {
            return nil
        }
    }

    public init?(
        data: Data,
        options: JSONSerialization.ReadingOptions = []
    ) {
        do {
            let value = try JSONSerialization.jsonObject(with: data, options: options)
            self.init(value)
        } catch {
            return nil
        }
    }

    public init?(
        parsing jsonString: String,
        options: JSONSerialization.ReadingOptions = []
    ) {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        self.init(data: data, options: options)
    }
}

// MARK: - Getters

extension CWRawData {
    public var object: Any {
        switch self {
        case let .string(value):
            return value

        case let .number(value):
            return value

        case let .dictionary(value):
            return value

        case let .array(value):
            return value

        case let .bool(value):
            return value

        case .null:
            return NSNull()
        }
    }

    public var string: String? {
        return object as? String
    }

    public var number: NSNumber? {
        return object as? NSNumber
    }

    public var int: Int? {
        return number?.intValue
    }

    public var int64: Int64? {
        return number?.int64Value
    }

    public var float: Float? {
        return number?.floatValue
    }

    public var double: Double? {
        return number?.doubleValue
    }

    public var null: NSNull? {
        return object as? NSNull
    }

    public var dictionary: [String: Any]? {
        return object as? [String: Any]
    }

    public var array: [Any]? {
        return object as? [Any]
    }

    public var bool: Bool? {
        return object as? Bool
    }
}

// MARK: - Subscripts

extension CWRawData {
    public subscript(dynamicMember member: String) -> CWRawData? {
        get {
            return self[member]
        }
        set {
            self[member] = newValue
        }
    }

    public subscript(key: String) -> CWRawData? {
        get {
            guard case let .dictionary(dictionary) = self else {
                return nil
            }
            return dictionary[key].flatMap { CWRawData($0) }
        }
        set {
            guard case var .dictionary(dictionary) = self else {
                return
            }
            dictionary[key] = newValue?.object
            self = .dictionary(dictionary)
        }
    }

    public subscript(offset: Int) -> CWRawData? {
        get {
            guard case let .array(array) = self, array.indices.contains(offset) else {
                return nil
            }
            return CWRawData(array[offset])
        }
        set {
            guard case var .array(array) = self, array.indices.contains(offset) else {
                return
            }
            array[offset] = newValue?.object ?? NSNull()
            self = .array(array)
        }
    }
}

// MARK: - Equatable

extension CWRawData: Equatable {
    public static func == (lhs: CWRawData, rhs: CWRawData) -> Bool {
        switch (lhs, rhs) {
        case let (.string(lhs), .string(rhs)):
            return lhs == rhs

        case let (.dictionary(lhs), .dictionary(rhs)):
            return (lhs as NSDictionary) == (rhs as NSDictionary)

        case let (.array(lhs), .array(rhs)):
            return (lhs as NSArray) == (rhs as NSArray)

        case let (.number(lhs), .number(rhs)):
            return lhs == rhs

        case let (.bool(lhs), .bool(rhs)):
            return lhs == rhs

        case (.null, .null):
            return true

        case (.string, _), (.dictionary, _), (.array, _), (.number, _), (.bool, _), (.null, _):
            return false
        }
    }
}

// MARK: - Collection

extension CWRawData: MutableCollection {
    public enum Index: Comparable, Hashable {
        public enum Key: Comparable, Hashable {
            case offset(Int)
            case key(String)
            case value

            public static func < (lhs: Key, rhs: Key) -> Bool {
                switch (lhs, rhs) {
                case let (.offset(lhs), .offset(rhs)):
                    return lhs < rhs

                case let (.key(lhs), .key(rhs)):
                    return lhs < rhs

                case (.offset, _), (.key, _), (.value, _):
                    return false
                }
            }
        }

        public static func < (lhs: Index, rhs: Index) -> Bool {
            switch (lhs, rhs) {
            case let (.array(lhs), .array(rhs)):
                return lhs < rhs

            case let (.dictionary(lhs), .dictionary(rhs)):
                return lhs < rhs

            case (.array, _), (.dictionary, _), (.value, _):
                return false
            }
        }

        case array(Array<Any>.Index)
        case dictionary(Dictionary<String, Any>.Index)
        case value
    }

    public var count: Int {
        switch self {
        case let .array(array):
            return array.count

        case let .dictionary(dictionary):
            return dictionary.count

        case .string, .number, .bool, .null:
            return 1
        }
    }

    public var startIndex: Index {
        switch self {
        case let .array(array):
            return .array(array.startIndex)

        case let .dictionary(dictionary):
            return .dictionary(dictionary.startIndex)

        case .string, .number, .bool, .null:
            return .value
        }
    }

    public var endIndex: Index {
        switch self {
        case let .array(array):
            return .array(array.endIndex)

        case let .dictionary(dictionary):
            return .dictionary(dictionary.endIndex)

        case .string, .number, .bool, .null:
            return .value
        }
    }

    public func index(after index: Index) -> Index {
        switch index {
        case let .array(index):
            return .array(array!.index(after: index))

        case let .dictionary(index):
            return .dictionary(dictionary!.index(after: index))

        case .value:
            return .value
        }
    }

    private func key(for index: Index) -> Index.Key {
        switch index {
        case let .array(index):
            return .offset(index)

        case let .dictionary(index):
            return .key(dictionary![index].key)

        case .value:
            return .value
        }
    }

    public subscript(index: Index) -> (key: Index.Key, value: CWRawData) {
        get {
            let key = self.key(for: index)
            return (key, self[key]!)
        }
        set {
            self[newValue.key] = newValue.value
        }
    }

    public subscript(key: Index.Key) -> CWRawData? {
        get {
            switch key {
            case let .offset(offset):
                return self[offset]

            case let .key(key):
                return self[key]

            case .value:
                return self
            }
        }
        set {
            switch key {
            case let .offset(offset):
                self[offset] = newValue

            case let .key(key):
                self[key] = newValue

            case .value:
                self = newValue ?? .null
            }
        }
    }
}

// MARK: - Literals

extension CWRawData: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let data: [String: Any] = elements.reduce(into: [:]) { memo, element in
            memo[element.0] = element.1
        }
        self = .dictionary(data)
    }
}

extension CWRawData: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        let data: [Any] = elements
        self = .array(data)
    }
}

extension CWRawData: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension CWRawData: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension CWRawData: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(NSNumber(value: value))
    }
}

extension CWRawData: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(NSNumber(value: value))
    }
}

extension CWRawData: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
