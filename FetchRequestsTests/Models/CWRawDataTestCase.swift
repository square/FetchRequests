//
//  CWRawDataTestCase.swift
//  FetchRequests
//
//  Created by Adam Lickel on 9/20/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class CWRawDataTestCase: XCTestCase {
}

// MARK: - Values

extension CWRawDataTestCase {
    func testInvalidGetters() {
        let enumValue = CWRawData.null

        XCTAssertNotNil(enumValue.null)
        XCTAssertNil(enumValue.bool)
        XCTAssertNil(enumValue.number)
        XCTAssertNil(enumValue.float)
        XCTAssertNil(enumValue.double)
        XCTAssertNil(enumValue.string)
        XCTAssertNil(enumValue.array)
        XCTAssertNil(enumValue.dictionary)
    }

    func testBoolean() {
        let enumValue = CWRawData.bool(true)
        let boolRepresentable: CWRawData = true
        let nsnumberBoolInit = CWRawData(NSNumber(value: true))
        let nsnumberNumberInit = CWRawData(NSNumber(value: 1))

        XCTAssertTrue(enumValue.bool!)
        XCTAssertTrue(boolRepresentable.bool!)
        XCTAssertTrue(nsnumberBoolInit!.bool!)
        XCTAssertEqual(enumValue, nsnumberBoolInit)
        XCTAssertEqual(enumValue, boolRepresentable)
        XCTAssertNotEqual(nsnumberBoolInit, nsnumberNumberInit)
    }

    func testNumber() {
        let enumValue = CWRawData.number(1)
        let intRepresentable: CWRawData = 1
        let floatRepresentable: CWRawData = 1.0
        let numberInit = CWRawData(NSNumber(value: 1))

        XCTAssertNil(enumValue.bool)
        XCTAssertEqual(enumValue.int, 1)
        XCTAssertEqual(intRepresentable.int, 1)
        XCTAssertEqual(floatRepresentable.double, 1.0)
        XCTAssertEqual(floatRepresentable.float, 1.0)
        XCTAssertEqual(numberInit, enumValue)
        XCTAssertEqual(intRepresentable, enumValue)
        XCTAssertEqual(floatRepresentable, enumValue)
    }

    func testNull() {
        let enumValue = CWRawData.null
        let nilRepresentable: CWRawData = nil
        let nsnullValue = CWRawData(NSNull())

        XCTAssertNotNil(CWRawData.null)
        XCTAssertNotNil(enumValue.null)
        XCTAssertEqual(enumValue, CWRawData.null)
        XCTAssertEqual(nilRepresentable, CWRawData.null)
        XCTAssertEqual(nsnullValue, CWRawData.null)
    }

    func testString() {
        let string = "hello"

        let enumValue = CWRawData.string("hello")
        let stringRepresentable: CWRawData = "hello"
        let stringInit = CWRawData(string)

        XCTAssertEqual(enumValue, stringRepresentable)
        XCTAssertEqual(enumValue.string, string)
        XCTAssertEqual(stringRepresentable.string, string)
        XCTAssertEqual(stringInit?.string, string)
    }

    func testArray() {
        let array: [Any] = ["abc", 1]

        let enumValue = CWRawData.array(["abc", 1])
        let arrayRepresentable: CWRawData = ["abc", 1]
        let arrayInit = CWRawData(array)

        XCTAssertEqual(enumValue, arrayRepresentable)
        XCTAssertEqual(enumValue.array as NSArray?, array as NSArray)
        XCTAssertEqual(arrayRepresentable.array as NSArray?, array as NSArray)
        XCTAssertEqual(arrayInit?.array as NSArray?, array as NSArray)
    }

    func testDictionary() {
        let dict: [String: Any] = ["abc": 1, "def": "ghi"]

        let enumValue = CWRawData.dictionary(["abc": 1, "def": "ghi"])
        let dictRepresentable: CWRawData = ["abc": 1, "def": "ghi"]
        let dictInit = CWRawData(dict)

        XCTAssertEqual(enumValue, dictRepresentable)
        XCTAssertEqual(enumValue.dictionary as NSDictionary?, dict as NSDictionary)
        XCTAssertEqual(dictRepresentable.dictionary as NSDictionary?, dict as NSDictionary)
        XCTAssertEqual(dictInit?.dictionary as NSDictionary?, dict as NSDictionary)
    }
}

// MARK: - Subscripts

extension CWRawDataTestCase {
    func testGetKeyedValues() {
        let data: CWRawData = [
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

        XCTAssertEqual(data.id?.int, 1)
        XCTAssertEqual(data.integers?[0]?.int, 0)
        XCTAssertEqual(data.foo?.bar?.string, "baz")
        XCTAssertEqual(data.indexed?[0]?.firstValue?.bool, true)

        XCTAssertNil(data.integers?[3])
        XCTAssertNil(data.foo?.baz?.string)
    }

    func testSetKeyedValues() {
        var data: CWRawData = [
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
        data.integers?[3] = 1

        XCTAssertNil(data.id?.foo)
        XCTAssertNil(data.integers?[3])

        data.foo?.bar?.object = "bop"
        data.indexed?[0]?.object = ["firstValue": false]

        XCTAssertEqual(data.foo?.bar?.string, "bop")
        XCTAssertEqual(data.indexed?[0]?.firstValue?.bool, false)
    }

    func testMultiItemCollections() {
        let dict: CWRawData = ["abc": "def", "ghi": 2]
        let keyedReducer: Int = dict.reduce(into: 0) { memo, _ in memo += 1 }
        XCTAssertEqual(keyedReducer, 2)
        XCTAssertEqual(dict.count, 2)

        let array: CWRawData = [0, "abc", NSNull()]
        let offsetReducer: Int = array.reduce(into: 0) { memo, _ in memo += 1 }
        XCTAssertEqual(offsetReducer, 3)
        XCTAssertEqual(array.count, 3)
    }

    func testMultiItemCollectionIndexSetter() {
        var soloDict: CWRawData = ["foo": "bar"]
        soloDict[soloDict.startIndex] = (key: .key("foo"), value: CWRawData(1))

        XCTAssertEqual(soloDict.count, 1)
        XCTAssertEqual(soloDict.foo?.int, 1)

        var soloArray: CWRawData = [0]
        soloArray[soloArray.startIndex] = (key: .offset(0), value: CWRawData(1))
        XCTAssertEqual(soloArray[0]?.int, 1)
    }

    func testCollectionOfOne() {
        var value: CWRawData = true

        let fetchedStart = value[CWRawData.Index.Key.value(isStart: true)]
        let fetchedEnd = value[CWRawData.Index.Key.value(isStart: false)]
        XCTAssertTrue(fetchedStart!.bool!)
        XCTAssertNil(fetchedEnd)

        XCTAssertEqual(value.count, 1)

        XCTAssertEqual(value.compactMap { $0.value.bool }, [true])

        value[.value(isStart: true)] = "abc"

        XCTAssertEqual(value.string, "abc")

        value[.value(isStart: false)] = "def"
        XCTAssertEqual(value.string, "abc")
    }
}

// MARK: - Miscellaneous

extension CWRawDataTestCase {
    func testInitSelf() {
        let value: CWRawData = 1
        let newValue = CWRawData(value)

        XCTAssertEqual(value, newValue)
    }

    func testInitData() throws {
        let dict: [String: Any] = ["foo": "bar", "baz": [1, 2, 3]]

        let data = try JSONSerialization.data(withJSONObject: dict)
        let jsonFromData = CWRawData(data)

        let jsonString = String(data: data, encoding: .utf8)!
        let jsonFromString = CWRawData(parsing: jsonString)

        XCTAssertNotNil(jsonFromData)
        XCTAssertEqual(jsonFromData, jsonFromString)

        XCTAssert(jsonFromData?.baz?[0]?.int == 1)
    }
}
