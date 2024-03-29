//
//  PaginatingFetchedResultsControllerTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class PaginatingFetchedResultsControllerTestCase: XCTestCase, FetchedResultsControllerTestHarness {
    // swiftlint:disable implicitly_unwrapped_optional test_case_accessibility

    private(set) var controller: PaginatingFetchedResultsController<TestObject>!

    private(set) var fetchCompletion: (([TestObject]) -> Void)!

    private var paginationCurrentResults: [TestObject]!
    private var paginationCompletion: (([TestObject]?) -> Void)!

    private var associationRequest: TestObject.AssociationRequest!

    // swiftlint:enable implicitly_unwrapped_optional test_case_accessibility

    private var inclusionCheck: ((TestObject.RawData) -> Bool)?

    private var changeEvents: [(change: FetchedResultsChange<IndexPath>, object: TestObject)] = []

    private func createFetchDefinition(
        associations: [PartialKeyPath<TestObject>] = []
    ) -> PaginatingFetchDefinition<TestObject> {
        let request: PaginatingFetchDefinition<TestObject>.Request = { [unowned self] completion in
            self.fetchCompletion = completion
        }
        let paginationRequest: PaginatingFetchDefinition<TestObject>.PaginationRequest = { [unowned self] currentResults, completion in
            self.paginationCurrentResults = currentResults
            self.paginationCompletion = completion
        }

        let desiredAssociations = TestObject.fetchRequestAssociations(
            matching: associations
        ) { [unowned self] associationRequest in
            self.associationRequest = associationRequest
        }

        let inclusionCheck: PaginatingFetchDefinition<TestObject>.CreationInclusionCheck = { [unowned self] rawData in
            self.inclusionCheck?(rawData) ?? true
        }

        return PaginatingFetchDefinition<TestObject>(
            request: request,
            paginationRequest: paginationRequest,
            creationInclusionCheck: inclusionCheck,
            associations: desiredAssociations
        )
    }

    override func setUp() {
        super.setUp()

        cleanup()
    }

    override func tearDown() {
        super.tearDown()

        cleanup()
    }

    private func cleanup() {
        controller = nil
        fetchCompletion = nil
        paginationCurrentResults = nil
        paginationCompletion = nil
        associationRequest = nil
        inclusionCheck = nil

        changeEvents = []
    }

    func testBasicFetch() throws {
        controller = PaginatingFetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try performFetch(objectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
    }

    func testResort() throws {
        controller = PaginatingFetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try performFetch(objectIDs)

        controller.resort(using: [NSSortDescriptor(keyPath: \TestObject.id, ascending: false)])

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs.reversed())
    }

    func testPaginationTriggersLoad() throws {
        controller = PaginatingFetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        // Fetch some objects

        let objectIDs = ["a", "b", "c"]

        try performFetch(objectIDs)

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

    func testPaginationDoesNotDisableInserts() throws {
        controller = PaginatingFetchedResultsController(
            definition: createFetchDefinition(),
            sortDescriptors: [
                NSSortDescriptor(keyPath: \FetchedObject.id, ascending: true),
            ],
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        // Fetch some objects

        let objectIDs = ["a", "b", "c"]

        try performFetch(objectIDs)

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
