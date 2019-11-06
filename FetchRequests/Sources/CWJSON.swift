//
//  CWJSON.swift
//  FetchRequests
//
//  Created by Adam Lickel on 9/19/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

/// This represents raw data within the FetchRequests framework
/// It exists to work around compiler/runtime bugs around pointers in closure thunks
@dynamicMemberLookup
public enum CWJSON {
    case string(String)
    case dictionary([String: Any])
    case array([Any])
    case number(NSNumber)
    case bool(Bool)
    case null

    public init?(_ value: Any) {
        if let value = value as? Data {
            self.init(data: value)
        } else if let value = value as? CWJSON {
            self = value
        } else if let value = value as? String {
            self = .string(value)
        } else if let value = value as? NSNumber, value.isBool {
            self = .bool(value.boolValue)
        } else if let value = value as? NSNumber {
            self = .number(value)
        } else if let value = value as? [CWJSON] {
            self = .array(value.map { $0.object })
        } else if let value = value as? [Any] {
            self = .array(value)
        } else if let value = value as? [String: CWJSON] {
            self = .dictionary(value.reduce(into: [:]) { memo, kvp in
                memo[kvp.key] = kvp.value.object
            })
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

extension CWJSON {
    public internal(set) var object: Any {
        get {
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
        set {
            let expected = CWJSON(newValue)
            self[.value(isStart: true)] = expected
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
        guard case .bool = self else {
            return nil
        }
        return object as? Bool
    }
}

// MARK: - Subscripts

extension CWJSON {
    public internal(set) subscript(dynamicMember member: String) -> CWJSON? {
        get {
            return self[member]
        }
        set {
            self[member] = newValue
        }
    }

    public internal(set) subscript(key: String) -> CWJSON? {
        get {
            guard case let .dictionary(dictionary) = self else {
                return nil
            }
            return dictionary[key].flatMap { CWJSON($0) }
        }
        set {
            guard case var .dictionary(dictionary) = self else {
                return
            }
            dictionary[key] = newValue?.object
            self = .dictionary(dictionary)
        }
    }

    public internal(set) subscript(offset: Int) -> CWJSON? {
        get {
            guard case let .array(array) = self, array.indices.contains(offset) else {
                return nil
            }
            return CWJSON(array[offset])
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

extension CWJSON: Equatable {
    public static func == (lhs: CWJSON, rhs: CWJSON) -> Bool {
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

extension CWJSON: Collection {
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
                return lhs < rhs

            case let (.dictionary(lhs), .dictionary(rhs)):
                return lhs < rhs

            case (.array, _), (.dictionary, _), (.value, _):
                return false
            }
        }

        case array(Array<Any>.Index)
        case dictionary(Dictionary<String, Any>.Index)
        case value(isStart: Bool)
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
            return .value(isStart: true)
        }
    }

    public var endIndex: Index {
        switch self {
        case let .array(array):
            return .array(array.endIndex)

        case let .dictionary(dictionary):
            return .dictionary(dictionary.endIndex)

        case .string, .number, .bool, .null:
            return .value(isStart: false)
        }
    }

    public func index(after index: Index) -> Index {
        switch index {
        case let .array(index):
            return .array(array!.index(after: index))

        case let .dictionary(index):
            return .dictionary(dictionary!.index(after: index))

        case .value:
            return .value(isStart: false)
        }
    }

    private func key(for index: Index) -> Index.Key {
        switch index {
        case let .array(index):
            return .offset(index)

        case let .dictionary(index):
            return .key(dictionary![index].key)

        case let .value(isStart):
            return .value(isStart: isStart)
        }
    }

    public internal(set) subscript(index: Index) -> (key: Index.Key, value: CWJSON) {
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

    public internal(set) subscript(key: Index.Key) -> CWJSON? {
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

extension CWJSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let data: [String: Any] = elements.reduce(into: [:]) { memo, element in
            memo[element.0] = element.1
        }
        self = .dictionary(data)
    }
}

extension CWJSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        let data: [Any] = elements
        self = .array(data)
    }
}

extension CWJSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension CWJSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension CWJSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(NSNumber(value: value))
    }
}

extension CWJSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(NSNumber(value: value))
    }
}

extension CWJSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

// MARK: - Codable

public enum CWJSONError: Error {
    case invalidContent
}

private extension Dictionary where Key == String, Value == Any {
    func encodableDictionary() throws -> [String: CWJSON] {
        return try reduce(into: [:]) { memo, kvp in
            guard let value = CWJSON(kvp.value) else {
                throw CWJSONError.invalidContent
            }
            memo[kvp.key] = value
        }
    }
}

private extension Array where Element == Any {
    func encodableArray() throws -> [CWJSON] {
        return try map { element in
            guard let value = CWJSON(element) else {
                throw CWJSONError.invalidContent
            }
            return value
        }
    }
}

extension CWJSON: Encodable {
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

extension CWJSON: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let object: Any

        if container.decodeNil() {
            object = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            object = bool
        } else if let string = try? container.decode(String.self) {
            object = string
        } else if let array = try? container.decode([CWJSON].self) {
            object = array
        } else if let dictionary = try? container.decode([String: CWJSON].self) {
            object = dictionary
        } else {
            var signedNumber: NSNumber? {
                if let int = try? container.decode(Int64.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(Int32.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(Int16.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(Int8.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(Int.self) {
                    return NSNumber(value: int)
                } else {
                    return nil
                }
            }
            var unsignedNumber: NSNumber? {
                if let int = try? container.decode(UInt64.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(UInt32.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(UInt16.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(UInt8.self) {
                    return NSNumber(value: int)
                } else if let int = try? container.decode(UInt.self) {
                    return NSNumber(value: int)
                } else {
                    return nil
                }
            }
            var floatingPointNumber: NSNumber? {
                if let double = try? container.decode(Double.self) {
                    return NSNumber(value: double)
                } else if let float = try? container.decode(Float.self) {
                    return NSNumber(value: float)
                } else {
                    return nil
                }
            }

            guard let number = signedNumber ?? unsignedNumber ?? floatingPointNumber else {
                throw CWJSONError.invalidContent
            }
            object = number
        }

        guard let data = CWJSON(object) else {
            throw CWJSONError.invalidContent
        }
        self = data
    }
}

// MARK: - NSNumber Helpers

private let nsBool: NSNumber = true as NSNumber
private let cfBool: CFBoolean = true as CFBoolean

private extension NSNumber {
    var isBool: Bool {
        return type(of: self) == type(of: nsBool) || type(of: self) == type(of: cfBool)
    }

    var isFloatingPoint: Bool {
        return CFNumberIsFloatType(self as CFNumber)
    }

    var expectedType: NumberType {
        if isBool {
            return .boolean
        } else if isFloatingPoint {
            return .floatingPoint
        } else {
            return .integer
        }
    }

    enum NumberType {
        case integer
        case floatingPoint
        case boolean
    }
}
