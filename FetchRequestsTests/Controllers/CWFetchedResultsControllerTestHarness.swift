//
//  CWFetchedResultsControllerTestHarness.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
import Foundation
@testable import FetchRequests

//swiftlint:disable implicitly_unwrapped_optional

protocol CWFetchedResultsControllerTestHarness {
    associatedtype FetchController: CWFetchedResultsControllerProtocol where
        FetchController.FetchedObject == CWTestObject

    var controller: FetchController! { get }
    var fetchCompletion: (([CWTestObject]) -> Void)! { get }
}

extension CWFetchedResultsControllerTestHarness {
    func performFetch(_ objectIDs: [String], file: StaticString = #file, line: UInt = #line) throws {
        let objects = objectIDs.compactMap { CWTestObject(id: $0) }

        try performFetch(objects, file: file, line: line)
    }

    func performFetch(_ objects: [CWTestObject], file: StaticString = #file, line: UInt = #line) throws {
        controller.performFetch()

        self.fetchCompletion(objects)

        let sortedObjects = objects.sorted(by: controller.sortDescriptors)
        XCTAssertEqual(sortedObjects, controller.fetchedObjects, file: file, line: line)
    }

    func getObjectAtIndex(_ index: Int, withObjectID objectID: String, file: StaticString = #file, line: UInt = #line) -> CWTestObject! {
        let object = controller.fetchedObjects[index]

        XCTAssertEqual(object.id, objectID, file: file, line: line)

        return object
    }
}

extension CWFetchedResultsController where FetchedObject: CWTestObject {
    var fetchedIDs: [String] {
        return fetchedObjects.map { $0.id }
    }

    var tags: [Int] {
        return fetchedObjects.map { $0.tag }
    }
}

extension CWFetchedResultsSection where FetchedObject: CWTestObject {
    var fetchedIDs: [String] {
        return objects.map { $0.id }
    }

    var tags: [Int] {
        return objects.map { $0.tag }
    }
}
