//
//  CWPaginatingFetchedResultsControllerTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

//swiftlint:disable force_try implicitly_unwrapped_optional

class CWPaginatingFetchedResultsControllerTestCase: XCTestCase, CWFetchedResultsControllerTestHarness {
    private(set) var controller: CWPaginatingFetchedResultsController<CWTestObject>!

    private(set) var fetchCompletion: (([CWTestObject]) -> Void)!

    private var paginationCurrentResults: [CWTestObject]!
    private var paginationCompletion: (([CWTestObject]?) -> Void)!

    private var associationRequest: CWTestObject.AssociationRequest!

    private var inclusionCheck: ((CWTestObject.RawData) -> Bool)?

    private var changeEvents: [(change: CWFetchedResultsChange<IndexPath>, object: CWTestObject)] = []

    private func createFetchRequest(associations: [PartialKeyPath<CWTestObject>] = []) -> CWPaginatingFetchRequest<CWTestObject> {
        let request: CWPaginatingFetchRequest<CWTestObject>.Request = { [unowned self] completion in
            self.fetchCompletion = completion
        }
        let paginationRequest: CWPaginatingFetchRequest<CWTestObject>.PaginationRequest = { [unowned self] currentResults, completion in
            self.paginationCurrentResults = currentResults
            self.paginationCompletion = completion
        }
        let allAssociations = CWTestObject.fetchRequestAssociations { [unowned self] associationRequest in
            self.associationRequest = associationRequest
        }
        let desiredAssociations = allAssociations.filter { associations.contains($0.keyPath) }

        return CWPaginatingFetchRequest<CWTestObject>(
            request: request,
            paginationRequest: paginationRequest,
            creationInclusionCheck: { [unowned self] json in
                return self.inclusionCheck?(json) ?? true
            },
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
        paginationCurrentResults = nil
        paginationCompletion = nil
        associationRequest = nil
        inclusionCheck = nil

        changeEvents = []
    }

    func testBasicFetch() {
        controller = CWPaginatingFetchedResultsController(request: createFetchRequest(), debounceInsertsAndReloads: false)

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
    }

    func testPaginationTriggersLoad() {
        controller = CWPaginatingFetchedResultsController(request: createFetchRequest(), debounceInsertsAndReloads: false)
        controller.setDelegate(self)

        // Fetch some objects

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        fetchCompletion = nil
        paginationCurrentResults = nil
        paginationCompletion = nil
        changeEvents.removeAll()

        // Trigger pagination

        let paginationObjectIDs = ["d", "f"]

        performPagination(paginationObjectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs + paginationObjectIDs)

        XCTAssertEqual(changeEvents.count, 2)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.insert(location: IndexPath(item: 3, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "d")
        XCTAssertEqual(changeEvents[1].change, CWFetchedResultsChange.insert(location: IndexPath(item: 4, section: 0)))
        XCTAssertEqual(changeEvents[1].object.id, "f")
    }

    func testPaginationDoesNotDisableInserts() {
        controller = CWPaginatingFetchedResultsController(request: createFetchRequest(), debounceInsertsAndReloads: false)
        controller.setDelegate(self)

        // Fetch some objects

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        fetchCompletion = nil
        paginationCurrentResults = nil
        paginationCompletion = nil
        changeEvents.removeAll()

        // Trigger pagination

        let paginationObjectIDs = ["d", "f"]

        performPagination(paginationObjectIDs)

        fetchCompletion = nil
        paginationCurrentResults = nil
        paginationCompletion = nil
        changeEvents.removeAll()

        // Trigger insert

        let newObject = CWTestObject(id: "e")

        let notification = Notification(name: CWTestObject.objectWasCreated(), object: newObject.data)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssertNil(paginationCurrentResults)
        XCTAssertNil(paginationCompletion)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "b", "c", "d", "e", "f"])

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.insert(location: IndexPath(item: 4, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "e")
    }
}

// MARK: - CWFetchedResultsControllerDelegate

extension CWPaginatingFetchedResultsControllerTestCase: CWFetchedResultsControllerDelegate {
    func controller(
        _ controller: CWFetchedResultsController<CWTestObject>,
        didChange object: CWTestObject,
        for change: CWFetchedResultsChange<IndexPath>
    ) {
        changeEvents.append((change: change, object: object))
    }
}

// MARK: - Helper Functions

private extension CWPaginatingFetchedResultsControllerTestCase {
    func performPagination(_ objectIDs: [String], file: StaticString = #file, line: UInt = #line) {
        let objects = objectIDs.compactMap { CWTestObject(id: $0) }

        performPagination(objects, file: file, line: line)
    }

    func performPagination(_ objects: [CWTestObject], file: StaticString = #file, line: UInt = #line) {
        controller.performPagination()

        self.paginationCompletion(objects)

        let hasAllObjects = objects.allSatisfy { controller.fetchedObjects.contains($0) }
        XCTAssertTrue(hasAllObjects, file: file, line: line)
    }
}
