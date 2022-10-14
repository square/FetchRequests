//
//  FetchedResultsControllerTestCase.swift
//  Crew
//
//  Created by Adam Lickel on 2/1/16.
//  Copyright © 2016 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

// swiftlint:disable force_try implicitly_unwrapped_optional
class FetchedResultsControllerTestCase: XCTestCase, FetchedResultsControllerTestHarness {
    private(set) var controller: FetchedResultsController<TestObject>!

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

        let inclusionCheck: FetchDefinition<TestObject>.CreationInclusionCheck = { [unowned self] rawData in
            return self.inclusionCheck?(rawData) ?? true
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

        changeEvents = []
    }

    func testBasicFetch() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
    }

    func testResort() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        controller.resort(using: [NSSortDescriptor(keyPath: \TestObject.id, ascending: false)])

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs.reversed())
    }

    func testReset() {
        testBasicFetch()
        controller.setDelegate(self)

        changeEvents.removeAll()

        controller.reset()

        XCTAssertEqual(changeEvents.count, 3)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.delete(location: IndexPath(item: 2, section: 0)))
        XCTAssertEqual(changeEvents[1].change, FetchedResultsChange.delete(location: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(changeEvents[2].change, FetchedResultsChange.delete(location: IndexPath(item: 0, section: 0)))

        XCTAssertFalse(controller.hasFetchedObjects)
        XCTAssertEqual(controller.fetchedObjects, [])
    }

    func testClearDelegate() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertEqual(changeEvents.count, 3)
        XCTAssertEqual(controller.fetchedObjects.count, 3)

        changeEvents.removeAll()
        controller.clearDelegate()

        try! performFetch(objectIDs)

        XCTAssertEqual(changeEvents.count, 0)
        XCTAssertEqual(controller.fetchedObjects.count, 3)
    }

    func testAccessByIndexPath() {
        testBasicFetch()

        let firstIndexPath = IndexPath(item: 0, section: 0)
        let lastIndexPath = IndexPath(item: 2, section: 0)

        let firstObject = controller.object(at: firstIndexPath)
        let lastObject = controller.object(at: lastIndexPath)

        XCTAssertEqual(firstObject, controller.fetchedObjects[0])
        XCTAssertEqual(lastObject, controller.fetchedObjects[2])

        let fetchedFirstIndexPath = controller.indexPath(for: firstObject)
        let fetchedLastIndexPath = controller.indexPath(for: lastObject)

        XCTAssertEqual(firstIndexPath, fetchedFirstIndexPath)
        XCTAssertEqual(lastIndexPath, fetchedLastIndexPath)
    }

    func testFetchAvoidsReplacingInstances() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )

        var currentTag = 0

        let objectIDs = ["a", "b", "c"]
        let objects = objectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Replace our instances

        let secondaryObjectIDs = ["z", "a", "c", "b", "d"]
        let secondaryObjects = secondaryObjectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(secondaryObjects)

        XCTAssertEqual(controller.fetchedIDs.count, secondaryObjectIDs.count)
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["z", "a", "c", "b", "d"])

        XCTAssertEqual(controller.tags, [3, 0, 2, 6, 7])
        XCTAssertEqual(controller.sections[0].tags, [3, 0, 2, 6, 7])
    }

    func testBasicFetchWithSortDescriptors() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            sortDescriptors: [
                NSSortDescriptor(keyPath: \TestObject.id, ascending: false),
            ],
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["c", "b", "a"]

        // Handle all kinds of order variations

        try! performFetch(["c", "b", "a"])
        try! performFetch(["a", "b", "c"])
        try! performFetch(["b", "a", "c"])

        XCTAssertEqual(controller.fetchedIDs, objectIDs)
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
    }
}

// MARK: - Sections

extension FetchedResultsControllerTestCase {
    func testFetchingIntoSections() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]
        var objects = zip(objectIDs, objectIDs.reversed()).compactMap { TestObject(id: $0, sectionName: $1) }
        objects.append(TestObject(id: "d", sectionName: "b"))

        try! performFetch(objects)

        // Make sure our sections meet our expectations

        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.fetchedIDs, ["c", "b", "d", "a"])
        XCTAssertEqual(controller.sections[0].objects, [objects[2]])
        XCTAssertEqual(controller.sections[1].objects, [objects[1], objects[3]])
        XCTAssertEqual(controller.sections[2].objects, [objects[0]])
    }

    func testFetchingIntoSectionsAndAccessingByIndexPath() {
        testFetchingIntoSections()

        let firstIndexPath = IndexPath(item: 0, section: 0)
        let middleIndexPath = IndexPath(item: 1, section: 1)
        let lastIndexPath = IndexPath(item: 0, section: 2)

        let firstObject = controller.object(at: firstIndexPath)
        let middleObject = controller.object(at: middleIndexPath)
        let lastObject = controller.object(at: lastIndexPath)

        XCTAssertEqual(firstObject, controller.fetchedObjects[0])
        XCTAssertEqual(middleObject, controller.fetchedObjects[2])
        XCTAssertEqual(lastObject, controller.fetchedObjects[3])

        let fetchedFirstIndexPath = controller.indexPath(for: firstObject)
        let fetchedMiddleIndexPath = controller.indexPath(for: middleObject)
        let fetchedLastIndexPath = controller.indexPath(for: lastObject)

        XCTAssertEqual(firstIndexPath, fetchedFirstIndexPath)
        XCTAssertEqual(middleIndexPath, fetchedMiddleIndexPath)
        XCTAssertEqual(lastIndexPath, fetchedLastIndexPath)
    }

    func testFetchingIntoSectionsAvoidsReplacingInstances() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        var currentTag = 0

        let objectSectionPairs = [("a", "a"), ("b", "b"), ("d", "b"), ("c", "c")]
        let objects = objectSectionPairs.compactMap { pair -> TestObject? in
            let (id, sectionName) = pair
            let object = TestObject(id: id, tag: currentTag, sectionName: sectionName)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        XCTAssertEqual(controller.fetchedIDs, ["a", "b", "d", "c"])

        // Replace our instances

        let secondaryObjectSectionPairs = [("z", "a"), ("a", "a"), ("c", "b"), ("b", "c"), ("d", "c")]
        let secondaryObjects = secondaryObjectSectionPairs.compactMap { pair -> TestObject? in
            let (id, sectionName) = pair
            let object = TestObject(id: id, tag: currentTag, sectionName: sectionName)

            currentTag += 1

            return object
        }

        try! performFetch(secondaryObjects)

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "c", "b", "d"])
        XCTAssertEqual(controller.sections.count, 2)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["c", "b", "d"])

        XCTAssertEqual(controller.tags, [4, 0, 6, 1, 2])
        XCTAssertEqual(controller.sections[0].tags, [4, 0])
        XCTAssertEqual(controller.sections[1].tags, [6, 1, 2])
    }

    func testFetchingIntoSectionsWithSortDescriptors() {
        controller = FetchedResultsController<TestObject>(
            definition: createFetchDefinition(),
            sortDescriptors: [
                NSSortDescriptor(keyPath: \TestObject.id, ascending: true),
            ],
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectSectionPairs = [("z", "a"), ("a", "a"), ("c", "c"), ("b", "b"), ("d", "b")]
        let objects = objectSectionPairs.compactMap { pair -> TestObject? in
            let (id, sectionName) = pair
            let object = TestObject(id: id, sectionName: sectionName)

            return object
        }

        try! performFetch(objects)

        // Verify sorts work inside of sections

        XCTAssertEqual(controller.fetchedIDs, ["a", "z", "b", "d", "c"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "z"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b", "d"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c"])
    }
}

// MARK: - Associated Values

extension FetchedResultsControllerTestCase {
    func testFetchingAssociatedObjects() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tag]),
            debounceInsertsAndReloads: false
        )
        controller.associatedFetchSize = 3

        try! performFetch(["a", "b", "c", "d"])

        // Fault on C

        let tagString0 = getObjectAtIndex(2, withObjectID: "c").tagString()

        XCTAssertNil(tagString0)
        XCTAssertEqual(associationRequest.parentIDs, ["b", "c", "d"])

        associationRequest.parentsCompletion(["b": "0", "c": "0", "d": "0"])

        associationRequest = nil

        // Return non-nil value for C, D

        let tagString1 = getObjectAtIndex(2, withObjectID: "c").tagString()
        let tagString2 = getObjectAtIndex(3, withObjectID: "d").tagString()

        XCTAssertEqual("0", tagString1)
        XCTAssertEqual("0", tagString2)

        XCTAssertNil(associationRequest)

        // Fault on A

        let tagString3 = getObjectAtIndex(0, withObjectID: "a").tagString()

        XCTAssertNil(tagString3)
        XCTAssertEqual(associationRequest.parentIDs, ["a"])

        associationRequest.parentsCompletion([:])

        associationRequest = nil

        // Return nil value for A

        let tagString4 = getObjectAtIndex(0, withObjectID: "a").tagString()

        XCTAssertNil(tagString4)
        XCTAssertNil(associationRequest)
    }

#if canImport(UIKit) && !os(watchOS)
    func testAssociatedValuesAreDumpedOnMemoryPressure() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tag]),
            debounceInsertsAndReloads: false
        )

        try! performFetch(["a", "b", "c", "d"])

        // Fault on C

        let tagString0 = getObjectAtIndex(2, withObjectID: "c").tagString()

        XCTAssertNil(tagString0)
        XCTAssertEqual(associationRequest.parentIDs, ["a", "b", "c", "d"])

        associationRequest.parentsCompletion(["b": "0", "c": "0", "d": "0"])

        associationRequest = nil

        let tagString1 = getObjectAtIndex(2, withObjectID: "c").tagString()

        XCTAssertNotNil(tagString1)

        // Send Memory Pressure Broadcast

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil, userInfo: nil)

        // Fault on C

        let tagString2 = getObjectAtIndex(2, withObjectID: "c").tagString()

        XCTAssertNil(tagString2)

        associationRequest.parentsCompletion([:])
    }
#endif

    func testAssociatedObjectsInvalidatedFromKVO() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tag]),
            debounceInsertsAndReloads: false
        )

        try! performFetch(["a", "b", "c", "d"])

        // Fault on C

        let tagString0 = getObjectAtIndex(2, withObjectID: "c").tagString()

        XCTAssertNil(tagString0)
        XCTAssertEqual(associationRequest.parentIDs, ["a", "b", "c", "d"])

        associationRequest.parentsCompletion(["b": "0", "c": "0", "d": "0"])

        associationRequest = nil

        // Modify D

        getObjectAtIndex(3, withObjectID: "d").tag = 2

        // Fault on D

        let tagString1 = getObjectAtIndex(3, withObjectID: "d").tagString()

        XCTAssertNil(tagString1)
        XCTAssertEqual(associationRequest.parentIDs, ["d"])

        associationRequest.parentsCompletion(["d": "2"])

        let tagString2 = getObjectAtIndex(3, withObjectID: "d").tagString()

        XCTAssertEqual(tagString2, "2")
    }

    func testMissingAssociatedObjectsInvalidatedFromNotifications() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tagID]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c", "d"]
        let objects = objectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on C

        let tagObject0 = getObjectAtIndex(2, withObjectID: "c").tagObject()

        XCTAssertNil(tagObject0)
        XCTAssertEqual(associationRequest.tagIDs, ["0", "1", "2", "3"])

        associationRequest.tagIDsCompletion(
            [TestObject(id: "1"), TestObject(id: "2"), TestObject(id: "3")]
        )

        associationRequest = nil
        changeEvents.removeAll()

        // Broadcast tagID 0

        inclusionCheck = { rawData in
            TestObject.entityID(from: rawData) != "0"
        }

        let updateName = TestObject.objectWasCreated()
        let update: TestObject.RawData = ["id": "0", "updatedAt": 1]
        NotificationCenter.default.post(name: updateName, object: update)

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.update(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")

        // Fetch associated value on A

        let tagObject1 = getObjectAtIndex(0, withObjectID: "a").tagObject()

        XCTAssertEqual(tagObject1?.id, "0")
    }
}

// MARK: - Observed Events

extension FetchedResultsControllerTestCase {
    private func setupControllerForKVO(_ file: StaticString = #file, line: UInt = #line) {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            sortDescriptors: [
                NSSortDescriptor(key: #keyPath(TestObject.tag), ascending: true),
            ],
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        var currentTag = 0

        let objectSectionPairs = [("z", "a"), ("a", "a"), ("c", "c"), ("b", "b"), ("d", "c")]
        let objects = objectSectionPairs.compactMap { pair -> TestObject? in
            let (id, sectionName) = pair
            let object = TestObject(id: id, tag: currentTag, sectionName: sectionName)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "b", "c", "d"], file: file, line: line)
        XCTAssertEqual(controller.sections.count, 3, file: file, line: line)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["z", "a"], file: file, line: line)
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b"], file: file, line: line)
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c", "d"], file: file, line: line)
    }

    func testSectionChangeFromKVO() {
        setupControllerForKVO()

        // Modify C ~> Move Section w/o Adding or Deleting

        let indexPath = IndexPath(item: 0, section: 2)
        let object = controller.object(at: indexPath)

        object.sectionName = "b"

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "c", "b", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["c", "b"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["d"])
    }

    func testSectionCreationFromKVO() {
        setupControllerForKVO()

        // Modify Z ~> Move Section Adding Section

        let indexPath = IndexPath(item: 0, section: 0)
        let object = controller.object(at: indexPath)

        object.sectionName = "d"

        XCTAssertEqual(controller.fetchedIDs, ["a", "b", "c", "d", "z"])
        XCTAssertEqual(controller.sections.count, 4)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c", "d"])
        XCTAssertEqual(controller.sections[3].fetchedIDs, ["z"])
    }

    func testSectionDeletionFromKVO() {
        setupControllerForKVO()

        // Modify B ~> Move Section Deleting Section

        let indexPath = IndexPath(item: 0, section: 1)
        let object = controller.object(at: indexPath)

        object.sectionName = "c"

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "c", "b", "d"])
        XCTAssertEqual(controller.sections.count, 2)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["c", "b", "d"])
    }

    func testOrderChangeFromKVO() {
        setupControllerForKVO()

        // Modify Z ~> Reorder contents in section

        getObjectAtIndex(0, withObjectID: "z").tag = 99

        XCTAssertEqual(controller.fetchedIDs, ["a", "z", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "z"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c", "d"])
    }

    func testDeleteFromKVO() {
        controller = FetchedResultsController(definition: createFetchDefinition(), debounceInsertsAndReloads: false)
        controller.setDelegate(self)

        try! performFetch(["a", "b", "c"])

        changeEvents.removeAll()

        // Delete our object in memory

        getObjectAtIndex(0, withObjectID: "a").isDeleted = true

        XCTAssertEqual(controller.fetchedIDs, ["b", "c"])
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["b", "c"])

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.delete(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")
    }

    func testAssociatedObjectDeleteFromKVO() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tagID]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c"]
        let objects = objectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObject()
        let associatedObject = TestObject(id: "0")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Delete our associated object in memory

        associatedObject.isDeleted = true

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.update(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")

        // We should *not* fault here & our object should be nil

        let deletedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObject()
        XCTAssertNil(deletedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testAssociatedObjectArrayDeleteFromKVO() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tagIDs]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c", "d"]
        let objects = objectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObjectArray()
        let associatedObject = TestObject(id: "1")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Delete our associated object in memory

        associatedObject.isDeleted = true

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.update(location: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "b")

        // We should *not* fault here & our object should be nil

        let deletedAssociatedObject = getObjectAtIndex(1, withObjectID: "b").tagObjectArray()?.first
        XCTAssertNil(deletedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectNoReloadFromKVO() {
        // We need a custom controller so that sort descriptors is "empty"
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectSectionPairs = [("z", "a"), ("a", "a"), ("c", "c"), ("b", "b"), ("d", "c")]
        let objects = objectSectionPairs.compactMap { TestObject(id: $0, sectionName: $1) }

        try! performFetch(objects)

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c", "d"])

        // Modify Z ~> Do not reorder contents in section

        changeEvents.removeAll()

        getObjectAtIndex(1, withObjectID: "a").sectionName = "a"

        XCTAssert(changeEvents.isEmpty)

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c", "d"])
    }

    func testExpectReloadFromKVO() {
        controller = FetchedResultsController(definition: createFetchDefinition(), debounceInsertsAndReloads: false)
        controller.setDelegate(self)

        try! performFetch(["a", "b", "c"])

        changeEvents.removeAll()

        // Mutate our object in memory

        controller.fetchedObjects.first?.data = ["id": "a", "key": "value"]

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.update(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")
    }

    func testExpectReloadFromAssociatedObjectKVO() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tagID]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c"]
        let objects = objectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObject()
        let associatedObject = TestObject(id: "1")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Mutate our associated object in memory

        associatedObject.data = ["id": "1", "key": "value", "updatedAt": 1]

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.update(location: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "b")

        // We should *not* fault here & our object should be non-nil

        let updatedAssociatedObject = getObjectAtIndex(1, withObjectID: "b").tagObject()
        XCTAssertEqual(associatedObject, updatedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectReloadFromAssociatedObjectArrayKVO() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(associations: [\TestObject.tagIDs]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c", "d"]
        let objects = objectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObjectArray()
        let associatedObject = TestObject(id: "1")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Mutate our associated object in memory

        associatedObject.data = ["id": "1", "key": "value", "updatedAt": 1]

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.update(location: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "b")

        // We should *not* fault here & our object should be non-nil

        let updatedAssociatedObject = getObjectAtIndex(1, withObjectID: "b").tagObjectArray()?.first
        XCTAssertEqual(associatedObject, updatedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectInsertFromBroadcastNotification() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
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

    func testExpectNoInsertFromBroadcastNotification() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let initialObjects = ["a", "b", "c"].compactMap { TestObject(id: $0) }

        try! performFetch(initialObjects)

        fetchCompletion = nil
        changeEvents.removeAll()

        // Broadcast an update event & expect an insert check to occur, but no insert

        let newObject = TestObject(id: "d")

        inclusionCheck = { rawData in
            TestObject.entityID(from: rawData) != newObject.id
        }

        let update = newObject.data
        let notification = Notification(name: TestObject.objectWasCreated(), object: update)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssert(changeEvents.isEmpty)

        // Broadcast an update event & expect an insert won't occur

        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssert(changeEvents.isEmpty)
    }

    func testExpectReloadFromDatabaseReset() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        try! performFetch(["a", "b", "c"])

        XCTAssertEqual(changeEvents.count, 3)

        fetchCompletion = nil
        changeEvents.removeAll()

        let notification = Notification(name: TestObject.dataWasCleared(), object: nil)
        NotificationCenter.default.post(notification)

        XCTAssertNotNil(fetchCompletion)

        fetchCompletion([TestObject(id: "1")])

        XCTAssertEqual(changeEvents.count, 4)
        XCTAssertEqual(controller.fetchedIDs, ["1"])
    }
}

// MARK: - IndexPath Math

extension FetchedResultsControllerTestCase {
    private func setupController() {
        controller = FetchedResultsController(
            definition: createFetchDefinition(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]
        var objects = objectIDs.map { TestObject(id: $0, sectionName: "a") }
        objects.append(TestObject(id: "d", sectionName: "b"))

        try! performFetch(objects)
    }

    func testIndexPathNilForMissingObject() {
        setupController()

        let object = TestObject(id: "e")
        XCTAssertNil(controller.indexPath(for: object))
    }

    func testIndexPathAvailableForObject() {
        setupController()

        let object = TestObject(id: "b")
        XCTAssertEqual(controller.indexPath(for: object), IndexPath(item: 1, section: 0))
    }

    func testIndexPathNilForMissingObjectMatching() {
        setupController()

        let indexPath = controller.indexPath(forObjectMatching: { $0.id == "e" })
        XCTAssertNil(indexPath)
    }

    func testIndexPathAvailableForObjectMatching() {
        setupController()

        let indexPath = controller.indexPath(forObjectMatching: { $0.id == "b" })
        XCTAssertEqual(indexPath, IndexPath(item: 1, section: 0))
    }

    func testIndexPathBeforeFirstSection() {
        setupController()

        XCTAssertNil(controller.getIndexPath(before: IndexPath(item: 0, section: 0)))
    }

    func testIndexPathBeforeRegularSection() {
        setupController()

        let indexPath = controller.getIndexPath(before: IndexPath(item: 0, section: 1))
        XCTAssertEqual(indexPath, IndexPath(item: 2, section: 0))
    }

    func testIndexPathBeforeItem() {
        setupController()

        let indexPath = controller.getIndexPath(before: IndexPath(item: 1, section: 0))
        XCTAssertEqual(indexPath, IndexPath(item: 0, section: 0))
    }

    func testIndexPathAfterLastSection() {
        setupController()

        XCTAssertNil(controller.getIndexPath(after: IndexPath(item: 0, section: 1)))
    }

    func testIndexPathAfterRegularSection() {
        setupController()

        let indexPath = controller.getIndexPath(after: IndexPath(item: 2, section: 0))
        XCTAssertEqual(indexPath, IndexPath(item: 0, section: 1))
    }

    func testIndexPathAfterItem() {
        setupController()

        let indexPath = controller.getIndexPath(after: IndexPath(item: 1, section: 0))
        XCTAssertEqual(indexPath, IndexPath(item: 2, section: 0))
    }
}

// MARK: - FetchedResultsControllerDelegate

extension FetchedResultsControllerTestCase: FetchedResultsControllerDelegate {
    func controller(
        _ controller: FetchedResultsController<TestObject>,
        didChange object: TestObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
        changeEvents.append((change: change, object: object))
    }
}
