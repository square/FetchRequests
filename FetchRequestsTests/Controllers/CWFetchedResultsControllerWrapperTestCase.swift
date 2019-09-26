//
//  CWFetchedResultsControllerWrapperTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

//swiftlint:disable force_try implicitly_unwrapped_optional

class CWFetchedResultsControllerWrapperTestCase: XCTestCase, CWFetchedResultsControllerTestHarness {
    private(set) var controller: CWFetchedResultsControllerWrapper<CWTestObject>!

    private(set) var fetchCompletion: (([CWTestObject]) -> Void)!

    private var associationRequest: CWTestObject.AssociationRequest!

    private var inclusionCheck: ((CWTestObject.RawData) -> Bool)?

    private func createFetchRequest(
        associations: [PartialKeyPath<CWTestObject>] = []
    ) -> CWFetchRequest<CWTestObject> {
        let request: CWFetchRequest<CWTestObject>.Request = { [unowned self] completion in
            self.fetchCompletion = completion
        }
        
        let desiredAssociations = CWTestObject.fetchRequestAssociations(
            matching: associations
        ) { [unowned self] associationRequest in
            self.associationRequest = associationRequest
        }

        let inclusionCheck: CWFetchRequest<CWTestObject>.CreationInclusionCheck = { [unowned self] json in
            return self.inclusionCheck?(json) ?? true
        }

        return CWFetchRequest<CWTestObject>(
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

        controller = CWFetchedResultsControllerWrapper(
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
        controller = CWFetchedResultsControllerWrapper(
            request: request,
            sortDescriptors: [],
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        ) {
            calledClosure = true
        }

        let effectiveSortDescriptorKeys = [
            #selector(getter: CWTestObject.sectionName),
            #selector(getter: CWTestObject.id),
        ].map { $0.description }

        try! performFetch(["a", "b", "c"])

        XCTAssertTrue(calledClosure)

        controller.associatedFetchSize = 20

        XCTAssert(controller.request === request)
        XCTAssertEqual(controller.sortDescriptors.map { $0.key }, effectiveSortDescriptorKeys)
        XCTAssertEqual(controller.sectionNameKeyPath, \CWTestObject.sectionName)
        XCTAssertEqual(controller.associatedFetchSize, 20)
        XCTAssertTrue(controller.hasFetchedObjects)
    }

    func testWrappedIndexPathFunctions() {
        var calledClosure = false

        controller = CWFetchedResultsControllerWrapper(
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
