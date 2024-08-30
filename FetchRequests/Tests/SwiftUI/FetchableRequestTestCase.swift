//
//  FetchableRequestTestCase.swift
//  FetchableRequestTestCase
//
//  Created by Adam Lickel on 7/22/21.
//  Copyright © 2021 Speramus Inc. All rights reserved.
//

import XCTest

@testable import FetchRequests

class FetchableRequestTestCase: XCTestCase {
}

extension FetchableRequestTestCase {
    private func createFetchDefinition(ids: [String] = ["a", "b", "c"]) -> FetchDefinition<TestObject> {
        let request: FetchDefinition<TestObject>.Request = { completion in
            completion(ids.map { TestObject(id: $0, sectionName: $0) })
        }

        return FetchDefinition(request: request)
    }

    @MainActor
    func testCreation() {
        var instance = FetchableRequest(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        XCTAssertFalse(instance.hasFetchedObjects)

        let results = instance.wrappedValue
        XCTAssertEqual(results.map(\.id), [])

        // Note: This will trigger a runtime warning about a static binding
        instance.update()

        XCTAssertTrue(instance.hasFetchedObjects)
    }

    @MainActor
    func testSectionedCreation() {
        var instance = SectionedFetchableRequest(
            definition: createFetchDefinition(),
            sectionNameKeyPath: \TestObject.sectionName,
            debounceInsertsAndReloads: false
        )
        instance.update()

        let results = instance.wrappedValue
        XCTAssertEqual(results[0].objects[0].id, "a")
        XCTAssertEqual(results.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(results.map(\.name), ["a", "b", "c"])
        XCTAssertEqual(results.map(\.numberOfObjects), [1, 1, 1])
        XCTAssertEqual(results.flatMap(\.objects).map(\.id), ["a", "b", "c"])
    }
}
