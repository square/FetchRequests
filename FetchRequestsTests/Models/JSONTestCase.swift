//
//  JSONTestCase.swift
//  FetchRequests
//
//  Created by Adam Lickel on 9/20/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class JSONTestCase: XCTestCase {
}

// MARK: - Values

extension JSONTestCase {
    func testInvalidGetters() {
        let enumValue = JSON.null

        XCTAssertNotNil(enumValue.null)
        XCTAssertNil(enumValue.bool)
        XCTAssertNil(enumValue.number)
        XCTAssertNil(enumValue.int)
        XCTAssertNil(enumValue.int64)
        XCTAssertNil(enumValue.float)
        XCTAssertNil(enumValue.double)
        XCTAssertNil(enumValue.string)
        XCTAssertNil(enumValue.array)
        XCTAssertNil(enumValue.dictionary)
    }

    func testBoolean() {
        let enumValue = JSON.bool(true)
        let boolRepresentable: JSON = true
        let nsnumberBoolInit = JSON(NSNumber(value: true))
        let nsnumberNumberInit = JSON(NSNumber(value: 1))

        XCTAssertTrue(enumValue.bool ?? false)
        XCTAssertTrue(boolRepresentable.bool ?? false)
        XCTAssertTrue(nsnumberBoolInit?.bool ?? false)
        XCTAssertEqual(enumValue, nsnumberBoolInit)
        XCTAssertEqual(enumValue, boolRepresentable)
        XCTAssertNotEqual(nsnumberBoolInit, nsnumberNumberInit)
    }

    func testNumber() {
        let enumValue = JSON.number(1)
        let intRepresentable: JSON = 1
        let floatRepresentable: JSON = 1.0
        let numberInit = JSON(NSNumber(value: 1))

        XCTAssertNil(enumValue.bool)
        XCTAssertEqual(enumValue.int, 1)
        XCTAssertEqual(intRepresentable.int, 1)
        XCTAssertEqual(intRepresentable.int64, 1)
        XCTAssertEqual(floatRepresentable.double, 1.0)
        XCTAssertEqual(floatRepresentable.float, 1.0)
        XCTAssertEqual(numberInit, enumValue)
        XCTAssertEqual(intRepresentable, enumValue)
        XCTAssertEqual(floatRepresentable, enumValue)
    }

    func testNull() {
        let enumValue = JSON.null
        let nilRepresentable: JSON = nil
        let nsnullValue = JSON(NSNull())

        XCTAssertNotNil(JSON.null)
        XCTAssertNotNil(enumValue.null)
        XCTAssertEqual(enumValue, JSON.null)
        XCTAssertEqual(nilRepresentable, JSON.null)
        XCTAssertEqual(nsnullValue, JSON.null)
    }

    func testString() {
        let string = "hello"

        let enumValue = JSON.string("hello")
        let stringRepresentable: JSON = "hello"
        let stringInit = JSON(string)

        XCTAssertEqual(enumValue, stringRepresentable)
        XCTAssertEqual(enumValue.string, string)
        XCTAssertEqual(stringRepresentable.string, string)
        XCTAssertEqual(stringInit?.string, string)
    }

    func testArray() {
        let array: [Any] = ["abc", 1]

        let enumValue = JSON.array(["abc", 1])
        let arrayRepresentable: JSON = ["abc", 1]
        let arrayInit = JSON(array)

        XCTAssertEqual(enumValue, arrayRepresentable)
        XCTAssertEqual(enumValue.array as NSArray?, array as NSArray)
        XCTAssertEqual(arrayRepresentable.array as NSArray?, array as NSArray)
        XCTAssertEqual(arrayInit?.array as NSArray?, array as NSArray)
    }

    func testDictionary() {
        let dict: [String: Any] = ["abc": 1, "def": "ghi"]

        let enumValue = JSON.dictionary(["abc": 1, "def": "ghi"])
        let dictRepresentable: JSON = ["abc": 1, "def": "ghi"]
        let dictInit = JSON(dict)

        XCTAssertEqual(enumValue, dictRepresentable)
        XCTAssertEqual(enumValue.dictionary as NSDictionary?, dict as NSDictionary)
        XCTAssertEqual(dictRepresentable.dictionary as NSDictionary?, dict as NSDictionary)
        XCTAssertEqual(dictInit?.dictionary as NSDictionary?, dict as NSDictionary)
    }
}

// MARK: - Subscripts

extension JSONTestCase {
    private var complexJSON: JSON {
        return [
            "id": 1,
            "integers": [0, 1, 2],
            "foo": [
                "bar": "baz",
            ],
            "indexed": [
                ["firstValue": true],
                ["secondValue": true],
            ],
        ]
    }

    func testGetKeyedValues() {
        let data = complexJSON

        XCTAssertEqual(data.id?.int, 1)
        XCTAssertEqual(data.integers?[0]?.int, 0)
        XCTAssertEqual(data.foo?.bar?.string, "baz")
        XCTAssertEqual(data.indexed?[0]?.firstValue?.bool, true)

        XCTAssertNil(data.integers?[3])
        XCTAssertNil(data.foo?.baz?.string)
    }

    func testSetKeyedValues() {
        var data: JSON = [
            "id": 1,
            "integers": [0, 1, 2],
            "foo": [
                "bar": "baz",
            ],
            "indexed": [
                ["firstValue": true],
                ["secondValue": true],
            ],
        ]

        data.id = 2
        data.integers?[0] = 1

        XCTAssertEqual(data.id?.int, 2)
        XCTAssertEqual(data.integers?[0]?.int, 1)

        data.id?.foo = "bar"
        data.integers?[4] = 1

        XCTAssertNil(data.id?.foo)
        XCTAssertEqual(data.integers?[3]?.null, NSNull())
        XCTAssertEqual(data.integers?[4]?.int, 1)
        XCTAssertNil(data.integers?[5])

        data.foo?.bar?.object = "bop"
        data.foo?.baz?.inner = "boo"
        data.indexed?[0]?.object = ["firstValue": false]

        XCTAssertEqual(data.foo?.bar?.string, "bop")
        XCTAssertNil(data.foo?.baz)
        XCTAssertEqual(data.indexed?[0]?.firstValue?.bool, false)
    }

    func testMultiItemCollections() {
        let dict: JSON = ["abc": "def", "ghi": 2]
        let keyedReducer: Int = dict.reduce(into: 0) { memo, _ in memo += 1 }
        XCTAssertEqual(keyedReducer, 2)
        XCTAssertEqual(dict.count, 2)

        let array: JSON = [0, "abc", NSNull()]
        let offsetReducer: Int = array.reduce(into: 0) { memo, _ in memo += 1 }
        XCTAssertEqual(offsetReducer, 3)
        XCTAssertEqual(array.count, 3)
    }

    func testMultiItemCollectionIndexSetter() {
        var soloDict: JSON = ["foo": "bar"]
        soloDict[soloDict.startIndex] = (key: .key("foo"), value: JSON(1))

        XCTAssertEqual(soloDict.count, 1)
        XCTAssertEqual(soloDict.foo?.int, 1)

        var soloArray: JSON = [0]
        soloArray[soloArray.startIndex] = (key: .offset(0), value: JSON(1))
        XCTAssertEqual(soloArray[0]?.int, 1)
    }

    func testCollectionOfOne() {
        var value: JSON = true

        let fetchedStart = value[JSON.Index.Key.value(isStart: true)]
        let fetchedEnd = value[JSON.Index.Key.value(isStart: false)]
        XCTAssertTrue(fetchedStart?.bool ?? false)
        XCTAssertNil(fetchedEnd)

        XCTAssertEqual(value.count, 1)

        XCTAssertEqual(value.compactMap { $0.value.bool }, [true])

        value[.value(isStart: true)] = "abc"

        XCTAssertEqual(value.string, "abc")

        value[.value(isStart: false)] = "def"
        XCTAssertEqual(value.string, "abc")
    }
}

// MARK: - Initialization

extension JSONTestCase {
    func testInitSelf() {
        let value: JSON = 1
        let newValue = JSON(value)

        XCTAssertEqual(value, newValue)
    }

    func testInitData() throws {
        let dict: [String: Any] = ["foo": "bar", "baz": [1, 2, 3]]

        let data = try JSONSerialization.data(withJSONObject: dict)
        let jsonFromData = JSON(data)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        let jsonFromString = JSON(parsing: jsonString)

        XCTAssertNotNil(jsonFromData)
        XCTAssertEqual(jsonFromData, jsonFromString)

        XCTAssertEqual(jsonFromData?.baz?[0]?.int, 1)
    }
}

// MARK: - Codable

extension JSONTestCase {
    func testCanEncodeContent() throws {
        guard let json: JSON = JSON(sourceJSON) else {
            throw URLError(.cannotDecodeContentData)
        }
        let encoder = JSONEncoder()
        let encodedResult = try encoder.encode(json)

        XCTAssertNotNil(encodedResult)
        XCTAssertFalse(encodedResult.isEmpty)

        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(JSON.self, from: encodedResult)

        validate(data: decodedResult)
    }

    func testCanDecodeDataFromWire() throws {
        let json = sourceJSON
        let sourceData = try JSONSerialization.data(withJSONObject: json)

        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(JSON.self, from: sourceData)

        validate(data: decodedResult)
    }

    func testCanEncodeToTheWire() throws {
        guard let json: JSON = JSON(sourceJSON) else {
            throw URLError(.cannotDecodeContentData)
        }

        let encoder = JSONEncoder()
        let encodedResult = try encoder.encode(json)

        let rawDecodedResult = try JSONSerialization.jsonObject(with: encodedResult)
        guard let decodedResult = rawDecodedResult as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        XCTAssertEqual(sourceJSON as NSDictionary, decodedResult as NSDictionary)
    }

    func testCanEncodeToKeyedArchiver() throws {
        guard let json: JSON = JSON(sourceJSON) else {
            throw URLError(.cannotDecodeContentData)
        }

        let archiver = NSKeyedArchiver()
        archiver.requiresSecureCoding = true
        try archiver.encodeEncodable(json, forKey: NSKeyedArchiveRootObjectKey)
        let data = archiver.encodedData

        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        unarchiver.requiresSecureCoding = true
        let rawUnarchivedData = unarchiver.decodeDecodable(JSON.self, forKey: NSKeyedArchiveRootObjectKey)

        guard let unarchivedData = rawUnarchivedData else {
            throw URLError(.cannotDecodeContentData)
        }
        validate(data: unarchivedData)
    }

    private var sourceJSON: [String: Any] {
        return [
            "elements": [
                1,
                2.5,
                "string",
                true,
            ],
            "nullable": NSNull(),
        ]
    }

    private func validate(data: JSON) {
        XCTAssertEqual(data.count, 2)
        XCTAssertNotNil(data.nullable?.null)
        XCTAssertEqual(data.elements?.count, 4)
        XCTAssertEqual(data.elements?[0]?.int, 1)
        XCTAssertEqual(data.elements?[1]?.double, 2.5)
        XCTAssertEqual(data.elements?[2]?.string, "string")
        XCTAssertTrue(data.elements?[3]?.bool ?? false)
    }
}

// MARK: - Boxing

extension JSONTestCase {
    func testBoxing() {
        let data = complexJSON

        let boxed = data as BoxedJSON
        XCTAssertEqual(boxed.json, data)
    }

    func testUnboxing() {
        let data = complexJSON

        let boxed = data as BoxedJSON
        let unboxed = boxed as JSON
        XCTAssertEqual(unboxed, data)
    }

    func testAccessors() {
        let data = complexJSON

        let boxed = data as BoxedJSON
        XCTAssertEqual(boxed["integers"]?[1]?.object as? Int, 1)
    }

    func testEquatability() {
        let data = BoxedJSON(complexJSON)
        let otherData = BoxedJSON(complexJSON)
        XCTAssertEqual(data, otherData)
    }

    func testConditionalBridge() {
        let data = complexJSON
        let boxed = data as BoxedJSON

        var result: JSON?
        let success = JSON._conditionallyBridgeFromObjectiveC(boxed, result: &result)

        XCTAssertTrue(success)
        XCTAssertNotNil(result)
    }

    func testUnconditionalBridge() {
        let data = complexJSON
        let boxed = data as BoxedJSON
        _ = JSON._unconditionallyBridgeFromObjectiveC(boxed)
    }

    func testCodingForBoxedJSON() {
        let data = complexJSON
        let boxed = data as BoxedJSON

        let archiver = NSKeyedArchiver()
        archiver.requiresSecureCoding = true
        archiver.encode(boxed, forKey: NSKeyedArchiveRootObjectKey)
        let encodedData = archiver.encodedData

        let unarchiver = NSKeyedUnarchiver(forReadingWith: encodedData)
        unarchiver.requiresSecureCoding = true
        let unarchivedJSON = unarchiver.decodeObject(of: BoxedJSON.self, forKey: NSKeyedArchiveRootObjectKey)

        XCTAssertTrue(boxed.isEqual(unarchivedJSON))
    }
}
