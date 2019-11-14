//
//  LoggingTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/21/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class LoggingTestCase: XCTestCase {
    func testLogging() {
        LogVerbose("Verbose")
        LogDebug("Debug")
        LogInfo("Info")
        LogWarning("Warning")
        LogError("Error")
    }

    func testDiffDebug() {
        let operationTypes: [OperationType] = [.insert, .delete, .noop]
        let operationTypesStrings = operationTypes.map { $0.description }
        XCTAssertEqual(operationTypesStrings, ["+", "-", "="])

        let operations: [FetchRequests.Operation<Int>] = [
            Operation(type: .insert, elements: [0]),
            Operation(type: .delete, elements: [0]),
            Operation(type: .noop, elements: [0]),
        ]
        let operationsStrings = operations.map { $0.description }
        XCTAssertEqual(operationsStrings, ["[+0]", "[-0]", "0"])
    }
}
