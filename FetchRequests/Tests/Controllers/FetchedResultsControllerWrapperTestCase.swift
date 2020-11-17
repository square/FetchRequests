//
//  FetchedResultsControllerWrapperTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

//swiftlint:disable force_try implicitly_unwrapped_optional

class FetchedResultsControllerWrapperTestCase: XCTestCase, FetchedResultsControllerTestHarness {
    private(set) var controller: FetchedResultsControllerWrapper<TestObject>!

    private(set) var fetchCompletion: (([TestObject]) -> Void)!

    private var associationRequest: TestObject.AssociationRequest!

    private var inclusionCheck: ((TestObject.RawData) -> Bool)?

    private func createFetchRequest(
        associations: [PartialKeyPath<TestObject>] = []
    ) -> FetchRequest<TestObject> {
        let request: FetchRequest<TestObject>.Request = { [unowned self] completion in
            self.fetchCompletion = completion
        }
        
        let desiredAssociations = TestObject.fetchRequestAssociations(
            matching: associations
        ) { [unowned self] associationRequest in
            self.associationRequest = associationRequest
        }

        let inclusionCheck: FetchRequest<TestObject>.CreationInclusionCheck = { [unowned self] json in
            return self.inclusionCheck?(json) ?? true
        }

        return FetchRequest<TestObject>(
            request: request,
            creationInclusionCheck: inclusionCheck,
            associations: desiredAssociations
        )
    }

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()

        controller = nil
        fetchCompletion = nil
        associationRequest = nil
        inclusionCheck = nil
    }

    func testBasicFetch() {
        var calledClosure = false

        controller = FetchedResultsControllerWrapper(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        ) {
            calledClosure = true
        }

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertTrue(calledClosure)
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
        XCTAssertEqual(controller.fetchedObjects.map { $0.id }, objectIDs)
    }

    func testWrappedProperties() {
        let request = createFetchRequest()

        var calledClosure = false
        controller = FetchedResultsControllerWrapper(
            request: request,
            sortDescriptors: [],
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        ) {
            calledClosure = true
        }

        let effectiveSortDescriptorKeys = [
            #selector(getter: TestObject.sectionName),
            #selector(getter: TestObject.id),
        ].map { $0.description }

        try! performFetch(["a", "b", "c"])

        XCTAssertTrue(calledClosure)

        controller.associatedFetchSize = 20

        XCTAssert(controller.request === request)
        XCTAssertEqual(controller.sortDescriptors.map { $0.key }, effectiveSortDescriptorKeys)
        XCTAssertEqual(controller.sectionNameKeyPath, \TestObject.sectionName)
        XCTAssertEqual(controller.associatedFetchSize, 20)
        XCTAssertTrue(controller.hasFetchedObjects)
    }

    func testWrappedIndexPathFunctions() {
        var calledClosure = false

        controller = FetchedResultsControllerWrapper(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        ) {
            calledClosure = true
        }

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertTrue(calledClosure)

        let expectedIndexPath = IndexPath(item: 0, section: 0)
        let object = controller.object(at: expectedIndexPath)
        let actualIndexPath = controller.indexPath(for: object)

        XCTAssertEqual(expectedIndexPath, actualIndexPath)
    }
}
