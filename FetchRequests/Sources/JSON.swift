//
//  JSON.swift
//  FetchRequests
//
//  Created by Adam Lickel on 9/19/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

/// This represents raw data within the FetchRequests framework
/// It exists to work around compiler/runtime bugs around pointers in closure thunks
@dynamicMemberLookup
public enum JSON {
    case string(String)
    case dictionary([String: Any])
    case array([Any])
    case number(NSNumber)
    case bool(Bool)
    case null

    public init?(_ value: Any) {
        if let value = value as? Data {
            self.init(data: value)
        } else if let value = value as? JSONConvertible {
            self.init(value)
        } else if let value = value as? [String: Any] {
            // This intentionally does not deeply evaluate child values
            self = .dictionary(value)
        } else if let value = value as? [Any] {
            // This intentionally does not deeply evaluate child values
            self = .array(value)
        } else {
            return nil
        }
    }

    public init(_ value: JSONConvertible) {
        self = value.jsonRepresentation()
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

extension JSON {
    public internal(set) var object: Any {
        get {
            switch self {
            case let .string(value):
                value

            case let .number(value):
                value

            case let .dictionary(value):
                value

            case let .array(value):
                value

            case let .bool(value):
                value

            case .null:
                NSNull()
            }
        }
        set {
            let expected = JSON(newValue)
            self[.value(isStart: true)] = expected
        }
    }

    public var string: String? {
        object as? String
    }

    public var number: NSNumber? {
        object as? NSNumber
    }

    public var int: Int? {
        number?.intValue
    }

    public var int64: Int64? {
        number?.int64Value
    }

    public var float: Float? {
        number?.floatValue
    }

    public var double: Double? {
        number?.doubleValue
    }

    public var null: NSNull? {
        object as? NSNull
    }

    public var dictionary: [String: Any]? {
        object as? [String: Any]
    }

    public var array: [Any]? {
        object as? [Any]
    }

    public var bool: Bool? {
        guard case .bool = self else {
            return nil
        }
        return object as? Bool
    }
}

// MARK: - Subscripts

extension JSON {
    public subscript(dynamicMember member: String) -> JSON? {
        get {
            self[member]
        }
        set {
            self[member] = newValue
        }
    }

    public subscript(key: String) -> JSON? {
        get {
            guard case let .dictionary(dictionary) = self else {
                return nil
            }
            return dictionary[key].flatMap { JSON($0) }
        }
        set {
            guard case var .dictionary(dictionary) = self else {
                return
            }
            dictionary[key] = newValue?.object
            self = .dictionary(dictionary)
        }
    }

    public subscript(offset: Int) -> JSON? {
        get {
            guard case let .array(array) = self, array.indices.contains(offset) else {
                return nil
            }
            return JSON(array[offset])
        }
        set {
            guard case var .array(array) = self, offset >= 0 else {
                return
            }
            while array.count <= offset {
                // Fill in any gaps with NSNull
                array.append(NSNull())
            }
            array[offset] = newValue?.object ?? NSNull()
            self = .array(array)
        }
    }
}

// MARK: - Equatable

extension JSON: Equatable {
    public static func == (lhs: JSON, rhs: JSON) -> Bool {
        switch (lhs, rhs) {
        case let (.string(lhs), .string(rhs)):
            lhs == rhs

        case let (.dictionary(lhs), .dictionary(rhs)):
            (lhs as NSDictionary) == (rhs as NSDictionary)

        case let (.array(lhs), .array(rhs)):
            (lhs as NSArray) == (rhs as NSArray)

        case let (.number(lhs), .number(rhs)):
            lhs == rhs

        case let (.bool(lhs), .bool(rhs)):
            lhs == rhs

        case (.null, .null):
            true

        case (.string, _), (.dictionary, _), (.array, _), (.number, _), (.bool, _), (.null, _):
            false
        }
    }
}

// MARK: - Collection

extension JSON: Collection {
    public enum Index: Comparable, Hashable {
        public enum Key: Comparable, Hashable {
            case offset(Int)
            case key(String)
            case value(isStart: Bool)

            public static func < (lhs: Key, rhs: Key) -> Bool {
                switch (lhs, rhs) {
                case let (.offset(lhs), .offset(rhs)):
                    return lhs < rhs

                case let (.key(lhs), .key(rhs)):
                    return lhs < rhs

                case let (.value(lhs), .value(rhs)):
                    let lhs = lhs ? 0 : 1
                    let rhs = rhs ? 0 : 1
                    return lhs < rhs

                case (.offset, _), (.key, _), (.value, _):
                    return false
                }
            }
        }

        public static func < (lhs: Index, rhs: Index) -> Bool {
            switch (lhs, rhs) {
            case let (.array(lhs), .array(rhs)):
                lhs < rhs

            case let (.dictionary(lhs), .dictionary(rhs)):
                lhs < rhs

            case (.array, _), (.dictionary, _), (.value, _):
                false
            }
        }

        case array(Array<Any>.Index)
        case dictionary(Dictionary<String, Any>.Index)
        case value(isStart: Bool)
    }

    public var count: Int {
        switch self {
        case let .array(array):
            array.count

        case let .dictionary(dictionary):
            dictionary.count

        case .string, .number, .bool, .null:
            1
        }
    }

    public var startIndex: Index {
        switch self {
        case let .array(array):
            .array(array.startIndex)

        case let .dictionary(dictionary):
            .dictionary(dictionary.startIndex)

        case .string, .number, .bool, .null:
            .value(isStart: true)
        }
    }

    public var endIndex: Index {
        switch self {
        case let .array(array):
            .array(array.endIndex)

        case let .dictionary(dictionary):
            .dictionary(dictionary.endIndex)

        case .string, .number, .bool, .null:
            .value(isStart: false)
        }
    }

    public func index(after index: Index) -> Index {
        switch index {
        case let .array(index):
            .array(array!.index(after: index))

        case let .dictionary(index):
            .dictionary(dictionary!.index(after: index))

        case .value:
            .value(isStart: false)
        }
    }

    private func key(for index: Index) -> Index.Key {
        switch index {
        case let .array(index):
            .offset(index)

        case let .dictionary(index):
            .key(dictionary![index].key)

        case let .value(isStart):
            .value(isStart: isStart)
        }
    }

    public subscript(index: Index) -> (key: Index.Key, value: JSON) {
        get {
            let key = self.key(for: index)
            return (key, self[key]!)
        }
        set {
            let key = self.key(for: index)
            precondition(key == newValue.key, "Invalid Key")
            self[newValue.key] = newValue.value
        }
    }

    public subscript(key: Index.Key) -> JSON? {
        get {
            switch key {
            case let .offset(offset):
                return self[offset]

            case let .key(key):
                return self[key]

            case let .value(isStart):
                guard isStart else {
                    return nil
                }
                return self
            }
        }
        set {
            switch key {
            case let .offset(offset):
                self[offset] = newValue

            case let .key(key):
                self[key] = newValue

            case let .value(isStart):
                guard isStart else {
                    return
                }
                self = newValue ?? .null
            }
        }
    }
}

// MARK: - Literals

extension JSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONConvertible)...) {
        // This should be consistent with [String: JSONConvertible].jsonRepresentation()
        let data: [String: Any] = elements.reduce(into: [:]) { memo, element in
            memo[element.0] = element.1.jsonRepresentation().object
        }
        self = .dictionary(data)
    }
}

extension JSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONConvertible...) {
        // This should be consistent with [JSONConvertible].jsonRepresentation()
        let data: [Any] = elements.map { $0.jsonRepresentation().object }
        self = .array(data)
    }
}

extension JSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension JSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension JSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension JSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension JSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

// MARK: - Codable

public enum JSONError: Error {
    case invalidContent
}

private extension [String: Any] {
    func encodableDictionary() throws -> [String: JSON] {
        try reduce(into: [:]) { memo, kvp in
            guard let value = JSON(kvp.value) else {
                throw JSONError.invalidContent
            }
            memo[kvp.key] = value
        }
    }
}

private extension [Any] {
    func encodableArray() throws -> [JSON] {
        try map { element in
            guard let value = JSON(element) else {
                throw JSONError.invalidContent
            }
            return value
        }
    }
}

extension JSON: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .dictionary(dictionary):
            let value = try dictionary.encodableDictionary()
            try container.encode(value)

        case let .array(array):
            let value = try array.encodableArray()
            try container.encode(value)

        case let .string(string):
            try container.encode(string)

        case let .number(number):
            switch number.expectedType {
            case .boolean:
                try container.encode(number.boolValue)

            case .floatingPoint:
                try container.encode(number.doubleValue)

            case .integer:
                try container.encode(number.int64Value)
            }

        case let .bool(bool):
            try container.encode(bool)

        case .null:
            try container.encodeNil()
        }
    }
}

extension JSON: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let object: JSONConvertible

        if container.decodeNil() {
            object = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            object = bool
        } else if let string = try? container.decode(String.self) {
            object = string
        } else if let array = try? container.decode([JSON].self) {
            object = array
        } else if let dictionary = try? container.decode([String: JSON].self) {
            object = dictionary
        } else if let int = try? container.decode(Int64.self) {
            object = int
        } else if let int = try? container.decode(Int32.self) {
            object = int
        } else if let int = try? container.decode(Int16.self) {
            object = int
        } else if let int = try? container.decode(Int8.self) {
            object = int
        } else if let int = try? container.decode(Int.self) {
            object = int
        } else if let int = try? container.decode(UInt64.self) {
            object = int
        } else if let int = try? container.decode(UInt32.self) {
            object = int
        } else if let int = try? container.decode(UInt16.self) {
            object = int
        } else if let int = try? container.decode(UInt8.self) {
            object = int
        } else if let int = try? container.decode(UInt.self) {
            object = int
        } else if let double = try? container.decode(Double.self) {
            object = double
        } else if let float = try? container.decode(Float.self) {
            object = float
        } else {
            throw JSONError.invalidContent
        }
        self = object.jsonRepresentation()
    }
}

// MARK: - NSNumber Helpers

private let nsBool: NSNumber = true as NSNumber
private let cfBool: CFBoolean = true as CFBoolean

private extension NSNumber {
    var isBool: Bool {
        type(of: self) == type(of: nsBool) || type(of: self) == type(of: cfBool)
    }

    var isFloatingPoint: Bool {
        CFNumberIsFloatType(self as CFNumber)
    }

    var expectedType: NumberType {
        if isBool {
            .boolean
        } else if isFloatingPoint {
            .floatingPoint
        } else {
            .integer
        }
    }

    enum NumberType {
        case integer
        case floatingPoint
        case boolean
    }
}

// MARK: - JSONConvertible

public protocol JSONConvertible {
    func jsonRepresentation() -> JSON
}

extension JSON: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        self
    }
}

extension Array: JSONConvertible where Element: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .array(map { $0.jsonRepresentation().object })
    }
}

extension Dictionary: JSONConvertible where Key == String, Value: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .dictionary(
            reduce(into: [:]) { memo, kvp in
                memo[kvp.key] = kvp.value.jsonRepresentation().object
            }
        )
    }
}

extension String: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .string(self)
    }
}

extension NSString: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .string(self as String)
    }
}

extension NSNull: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .null
    }
}

extension NSNumber: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        if self.isBool {
            .bool(boolValue)
        } else {
            .number(self)
        }
    }
}

extension Bool: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .bool(self)
    }
}

extension Int64: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension Int32: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension Int16: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension Int8: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension Int: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension UInt64: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension UInt32: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension UInt16: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension UInt8: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension UInt: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension Double: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}

extension Float: JSONConvertible {
    public func jsonRepresentation() -> JSON {
        .number(NSNumber(value: self))
    }
}
