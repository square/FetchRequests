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

        XCTAssertFalse(data == newData)

        newData.test = 2

        XCTAssertTrue(data == newData)
    }
}
