//
//  CWFetchableObjectProtocolTestCase.swift
//  Crew-iOSTests
//
//  Created by Adam Lickel on 9/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class CWFetchableObjectProtocolTestCase: XCTestCase {
    func testDataEquality() {
        let data: CWTestObject.RawData = ["id": "1", "test": 2]
        var newData: CWTestObject.RawData = ["id": "1", "test": 3]

        XCTAssertFalse(CWTestObject.rawDataIsIdentical(lhs: data, rhs: newData))

        newData["test"] = 2

        XCTAssertTrue(CWTestObject.rawDataIsIdentical(lhs: data, rhs: newData))
    }

    func testNullableDataEquality() {
        let data: CWTestObject.RawData = ["id": "1", "test": 2]

        XCTAssertTrue(CWTestObject.rawDataIsIdentical(lhs: nil, rhs: nil))
        XCTAssertFalse(CWTestObject.rawDataIsIdentical(lhs: data, rhs: nil))
    }
}
