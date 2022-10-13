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

// swiftlint:disable implicitly_unwrapped_optional

@MainActor
protocol FetchedResultsControllerTestHarness {
    associatedtype FetchController: FetchedResultsControllerProtocol where
        FetchController.FetchedObject == TestObject

    var controller: FetchController! { get }
    var fetchCompletion: (@MainActor ([TestObject]) -> Void)! { get }
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

    func getObjectAtIndex(_ index: Int, withObjectID objectID: String, file: StaticString = #file, line: UInt = #line) -> TestObject! {
        let object = controller.fetchedObjects[index]

        XCTAssertEqual(object.id, objectID, file: file, line: line)

        return object
    }
}

extension FetchedResultsController where FetchedObject: TestObject {
    var fetchedIDs: [String] {
        return fetchedObjects.map { $0.id }
    }

    var tags: [Int] {
        return fetchedObjects.map { $0.tag }
    }
}

extension FetchedResultsSection where FetchedObject: TestObject {
    var fetchedIDs: [String] {
        return objects.map { $0.id }
    }

    var tags: [Int] {
        return objects.map { $0.tag }
    }
}
