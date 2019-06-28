//
//  CWPausableFetchedResultsControllerTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/27/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

//swiftlint:disable force_try implicitly_unwrapped_optional

class CWPausableFetchedResultsControllerTestCase: XCTestCase, CWFetchedResultsControllerTestHarness {
    private(set) var controller: CWPausableFetchedResultsController<CWTestObject>!

    private(set) var fetchCompletion: (([CWTestObject]) -> Void)!

    private var associationRequest: CWTestObject.AssociationRequest!

    private var inclusionCheck: ((CWTestObject.RawData) -> Bool)?

    private var changeEvents: [(change: CWFetchedResultsChange<IndexPath>, object: CWTestObject)] = []

    private func createFetchRequest(associations: [PartialKeyPath<CWTestObject>] = []) -> CWFetchRequest<CWTestObject> {
        let request: CWFetchRequest<CWTestObject>.Request = { [unowned self] completion in
            self.fetchCompletion = completion
        }
        let allAssociations = CWTestObject.fetchRequestAssociations { [unowned self] associationRequest in
            self.associationRequest = associationRequest
        }
        let desiredAssociations = allAssociations.filter { associations.contains($0.keyPath) }

        return CWFetchRequest<CWTestObject>(
            request: request,
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
        associationRequest = nil
        inclusionCheck = nil
    }

    func testBasicFetch() {
        controller = CWPausableFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
    }

    func testExpectInsertFromBroadcastNotification() {
        controller = CWPausableFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let initialObjects = ["a", "b", "c"].compactMap { CWTestObject(id: $0) }

        try! performFetch(initialObjects)

        fetchCompletion = nil
        changeEvents.removeAll()

        // Broadcast an update event & expect an insert to occur

        let newObject = CWTestObject(id: "d")

        let notification = Notification(name: CWTestObject.objectWasCreated(), object: newObject.data, userInfo: newObject.data)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.insert(location: IndexPath(item: 3, section: 0)))
        XCTAssertEqual(changeEvents[0].object.objectID, "d")

        changeEvents.removeAll()

        // Broadcast an update event & expect an insert won't occur

        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssert(changeEvents.isEmpty)
    }

    func testExpectPausedInsertFromBroadcastNotification() {
        controller = CWPausableFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let initialObjects = ["a", "b", "c"].compactMap { CWTestObject(id: $0) }

        try! performFetch(initialObjects)

        fetchCompletion = nil
        changeEvents.removeAll()

        // Pause fetch controller

        controller.isPaused = true

        // Broadcast an update event & don't expect an insert to occur

        let newObject = CWTestObject(id: "d")

        let notification = Notification(name: CWTestObject.objectWasCreated(), object: newObject.data, userInfo: newObject.data)
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
        controller = CWPausableFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        controller.isPaused = true

        controller.reset()

        XCTAssertFalse(controller.isPaused)
    }

    func testWrappedProperties() {
        let request = createFetchRequest()

        controller = CWPausableFetchedResultsController(
            request: request,
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let effectiveSortDescriptorKeys = [
            #selector(getter: CWTestObject.sectionName),
            #selector(getter: CWTestObject.objectID),
        ].map { $0.description }

        try! performFetch(["a", "b", "c"])

        controller.associatedFetchSize = 20

        XCTAssert(controller.request === request)
        XCTAssertEqual(controller.sortDescriptors.map { $0.key }, effectiveSortDescriptorKeys)
        XCTAssertEqual(controller.sectionNameKeyPath, \CWTestObject.sectionName)
        XCTAssertEqual(controller.associatedFetchSize, 20)
        XCTAssertTrue(controller.hasFetchedObjects)
    }
}

// MARK: - CWFetchedResultsControllerDelegate

extension CWPausableFetchedResultsControllerTestCase: CWPausableFetchedResultsControllerDelegate {
    func controller(
        _ controller: CWPausableFetchedResultsController<CWTestObject>,
        didChange object: CWTestObject,
        for change: CWFetchedResultsChange<IndexPath>
    ) {
        changeEvents.append((change: change, object: object))
    }
}
