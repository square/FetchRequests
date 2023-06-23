//
//  FetchableObjectProtocolTestCase.swift
//  Crew-iOSTests
//
//  Created by Adam Lickel on 9/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class FetchableObjectProtocolTestCase: XCTestCase {
    func testDataEquality() {
        let data: TestObject.RawData = ["id": "1", "test": 2]
        var newData: TestObject.RawData = ["id": "1", "test": 3]

        XCTAssertNotEqual(data, newData)

        newData.test = 2

        XCTAssertEqual(data, newData)
    }
}
