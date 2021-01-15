//
//  PaginatingFetchedResultsControllerTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

// swiftlint:disable force_try implicitly_unwrapped_optional

class PaginatingFetchedResultsControllerTestCase: XCTestCase, FetchedResultsControllerTestHarness {
    private(set) var controller: PaginatingFetchedResultsController<TestObject>!

    private(set) var fetchCompletion: (([TestObject]) -> Void)!

    private var paginationCurrentResults: [TestObject]!
    private var paginationCompletion: (([TestObject]?) -> Void)!

    private var associationRequest: TestObject.AssociationRequest!

    private var inclusionCheck: ((TestObject.RawData) -> Bool)?

    private var changeEvents: [(change: FetchedResultsChange<IndexPath>, object: TestObject)] = []

    private func createFetchRequest(
        associations: [PartialKeyPath<TestObject>] = []
    ) -> PaginatingFetchRequest<TestObject> {
        let request: PaginatingFetchRequest<TestObject>.Request = { [unowned self] completion in
            self.fetchCompletion = completion
        }
        let paginationRequest: PaginatingFetchRequest<TestObject>.PaginationRequest = { [unowned self] currentResults, completion in
            self.paginationCurrentResults = currentResults
            self.paginationCompletion = completion
        }

        let desiredAssociations = TestObject.fetchRequestAssociations(
            matching: associations
        ) { [unowned self] associationRequest in
            self.associationRequest = associationRequest
        }

        let inclusionCheck: PaginatingFetchRequest<TestObject>.CreationInclusionCheck = { [unowned self] json in
            return self.inclusionCheck?(json) ?? true
        }

        return PaginatingFetchRequest<TestObject>(
            request: request,
            paginationRequest: paginationRequest,
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
        paginationCurrentResults = nil
        paginationCompletion = nil
        associationRequest = nil
        inclusionCheck = nil

        changeEvents = []
    }

    func testBasicFetch() {
        controller = PaginatingFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
    }

    func testResort() {
        controller = PaginatingFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        controller.resort(using: [NSSortDescriptor(keyPath: \TestObject.id, ascending: false)])

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs.reversed())
    }

    func testPaginationTriggersLoad() {
        controller = PaginatingFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )
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
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.insert(location: IndexPath(item: 3, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "d")
        XCTAssertEqual(changeEvents[1].change, FetchedResultsChange.insert(location: IndexPath(item: 4, section: 0)))
        XCTAssertEqual(changeEvents[1].object.id, "f")
    }

    func testPaginationDoesNotDisableInserts() {
        controller = PaginatingFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )
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

        let newObject = TestObject(id: "e")

        let notification = Notification(name: TestObject.objectWasCreated(), object: newObject.data)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssertNil(paginationCurrentResults)
        XCTAssertNil(paginationCompletion)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "b", "c", "d", "e", "f"])

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.insert(location: IndexPath(item: 4, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "e")
    }
}

// MARK: - FetchedResultsControllerDelegate

extension PaginatingFetchedResultsControllerTestCase: FetchedResultsControllerDelegate {
    func controller(
        _ controller: FetchedResultsController<TestObject>,
        didChange object: TestObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
        changeEvents.append((change: change, object: object))
    }
}

// MARK: - Helper Functions

private extension PaginatingFetchedResultsControllerTestCase {
    func performPagination(_ objectIDs: [String], file: StaticString = #file, line: UInt = #line) {
        let objects = objectIDs.compactMap { TestObject(id: $0) }

        performPagination(objects, file: file, line: line)
    }

    func performPagination(_ objects: [TestObject], file: StaticString = #file, line: UInt = #line) {
        controller.performPagination()

        self.paginationCompletion(objects)

        let hasAllObjects = objects.allSatisfy { controller.fetchedObjects.contains($0) }
        XCTAssertTrue(hasAllObjects, file: file, line: line)
    }
}
