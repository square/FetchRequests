//
//  FetchedResultsControllerTestHarness.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
import Foundation
@testable import FetchRequests

@MainActor
protocol FetchedResultsControllerTestHarness {
    associatedtype FetchController: FetchedResultsControllerProtocol where
        FetchController.FetchedObject == TestObject

    // swiftlint:disable implicitly_unwrapped_optional

    var controller: FetchController! { get }
    var fetchCompletion: (([TestObject]) -> Void)! { get }

    // swiftlint:enable implicitly_unwrapped_optional
}

extension FetchedResultsControllerTestHarness {
    @MainActor
    func performFetch(_ objectIDs: [String], file: StaticString = #file, line: UInt = #line) throws {
        let objects = objectIDs.compactMap { TestObject(id: $0) }

        try performFetch(objects, file: file, line: line)
    }

    @MainActor
    func performFetch(_ objects: [TestObject], file: StaticString = #file, line: UInt = #line) throws {
        controller.performFetch()

        self.fetchCompletion(objects)

        let sortedObjects = objects.sorted(by: controller.sortDescriptors)
        XCTAssertEqual(sortedObjects, controller.fetchedObjects, file: file, line: line)
    }

    // swiftlint:disable:next implicitly_unwrapped_optional
    func getObjectAtIndex(_ index: Int, withObjectID objectID: String, file: StaticString = #file, line: UInt = #line) -> TestObject! {
        let object = controller.fetchedObjects[index]

        XCTAssertEqual(object.id, objectID, file: file, line: line)

        return object
    }
}

extension FetchedResultsController where FetchedObject: TestObject {
    var fetchedIDs: [String] {
        fetchedObjects.map(\.id)
    }

    var tags: [Int] {
        fetchedObjects.map(\.tag)
    }
}

extension FetchedResultsSection where FetchedObject: TestObject {
    var fetchedIDs: [String] {
        objects.map(\.id)
    }

    var tags: [Int] {
        objects.map(\.tag)
    }
}
