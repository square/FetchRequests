//
//  PausableFetchedResultsControllerTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

// swiftlint:disable force_try implicitly_unwrapped_optional

class PausableFetchedResultsControllerTestCase: XCTestCase, FetchedResultsControllerTestHarness {
    private(set) var controller: PausableFetchedResultsController<TestObject>!

    private(set) var fetchCompletion: (([TestObject]) -> Void)!

    private var associationRequest: TestObject.AssociationRequest!

    private var inclusionCheck: ((TestObject.RawData) -> Bool)?

    private var changeEvents: [(change: FetchedResultsChange<IndexPath>, object: TestObject)] = []

    private func createFetchDefinition(
        associations: [PartialKeyPath<TestObject>] = []
    ) -> FetchDefinition<TestObject> {
        let request: FetchDefinition<TestObject>.Request = { [unowned self] completion in
            self.fetchCompletion = completion
        }

        let desiredAssociations = TestObject.fetchRequestAssociations(
            matching: associations
        ) { [unowned self] associationRequest in
            self.associationRequest = associationRequest
        }

        let inclusionCheck: FetchDefinition<TestObject>.CreationInclusionCheck = { [unowned self] json in
            return self.inclusionCheck?(json) ?? true
        }

        return FetchDefinition<TestObject>(
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
        controller = PausableFetchedResultsController(
            fetchDefinition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
    }

    func testResort() {
        controller = PausableFetchedResultsController(
            fetchDefinition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        controller.resort(using: [NSSortDescriptor(keyPath: \TestObject.id, ascending: false)])

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs.reversed())
    }

    func testExpectInsertFromBroadcastNotification() {
        controller = PausableFetchedResultsController(
            fetchDefinition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let initialObjects = ["a", "b", "c"].compactMap { TestObject(id: $0) }

        try! performFetch(initialObjects)

        fetchCompletion = nil
        changeEvents.removeAll()

        // Broadcast an update event & expect an insert to occur

        let newObject = TestObject(id: "d")

        let notification = Notification(name: TestObject.objectWasCreated(), object: newObject.data)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.insert(location: IndexPath(item: 3, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "d")

        changeEvents.removeAll()

        // Broadcast an update event & expect an insert won't occur

        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssert(changeEvents.isEmpty)
    }

    func testExpectPausedInsertFromBroadcastNotification() {
        controller = PausableFetchedResultsController(
            fetchDefinition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let initialObjects = ["a", "b", "c"].compactMap { TestObject(id: $0) }

        try! performFetch(initialObjects)

        fetchCompletion = nil
        changeEvents.removeAll()

        // Pause fetch controller

        controller.isPaused = true

        // Broadcast an update event & don't expect an insert to occur

        let newObject = TestObject(id: "d")

        let notification = Notification(name: TestObject.objectWasCreated(), object: newObject.data)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)

        XCTAssertEqual(controller.fetchedObjects, initialObjects)
        XCTAssertEqual(changeEvents.count, 0)

        let pausedIndexPath = controller.indexPath(for: newObject)
        XCTAssertNil(pausedIndexPath)

        // Unpause and don't expect an insert *event* to occur, but to be updated

        controller.isPaused = false

        XCTAssertNil(fetchCompletion)

        let unpausedIndexPath = controller.indexPath(for: newObject)
        XCTAssertEqual(unpausedIndexPath, IndexPath(item: 3, section: 0))

        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "b", "c", "d"])
        XCTAssertEqual(changeEvents.count, 0)
    }

    func testResetClearsPaused() {
        controller = PausableFetchedResultsController(
            fetchDefinition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        controller.isPaused = true

        controller.reset()

        XCTAssertFalse(controller.isPaused)
    }

    func testWrappedProperties() {
        let fetchDefinition = createFetchDefinition()

        controller = PausableFetchedResultsController(
            fetchDefinition: fetchDefinition,
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let effectiveSortDescriptorKeys = [
            #selector(getter: TestObject.sectionName),
            NSSelectorFromString("self"),
        ].map { $0.description }

        try! performFetch(["a", "b", "c"])

        controller.associatedFetchSize = 20

        XCTAssert(controller.fetchDefinition === fetchDefinition)
        XCTAssertEqual(controller.sortDescriptors.map { $0.key }, effectiveSortDescriptorKeys)
        XCTAssertEqual(controller.sectionNameKeyPath, \TestObject.sectionName)
        XCTAssertEqual(controller.associatedFetchSize, 20)
        XCTAssertTrue(controller.hasFetchedObjects)
    }
}

// MARK: - Paginating

extension PausableFetchedResultsControllerTestCase {
    func testCanCreatePausableVariation() {
        let baseDefinition = createFetchDefinition()

        var paginationRequests = 0

        let fetchDefinition = PaginatingFetchDefinition<TestObject>(
            request: baseDefinition.request,
            paginationRequest: { current, completion in
                paginationRequests += 1

                let newObject = TestObject(id: paginationRequests.description)

                completion([newObject])
            },
            creationInclusionCheck: baseDefinition.creationInclusionCheck,
            associations: baseDefinition.associations
        )

        let controller = PausablePaginatingFetchedResultsController(
            fetchDefinition: fetchDefinition,
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )
        self.controller = controller
        controller.setDelegate(self)

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        controller.isPaused = true
        changeEvents.removeAll()

        controller.performPagination()

        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "b", "c"])

        controller.isPaused = false

        XCTAssertTrue(changeEvents.isEmpty)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "b", "c", "1"])
    }
}

// MARK: - FetchedResultsControllerDelegate

extension PausableFetchedResultsControllerTestCase: PausableFetchedResultsControllerDelegate {
    func controller(
        _ controller: PausableFetchedResultsController<TestObject>,
        didChange object: TestObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
        changeEvents.append((change: change, object: object))
    }
}
