//
//  CWFetchedResultsControllerTestCase.swift
//  Crew
//
//  Created by Adam Lickel on 2/1/16.
//  Copyright © 2016 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

//swiftlint:disable force_try implicitly_unwrapped_optional
class CWFetchedResultsControllerTestCase: XCTestCase, CWFetchedResultsControllerTestHarness {
    private(set) var controller: CWFetchedResultsController<CWTestObject>!

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

        changeEvents = []
    }

    func testBasicFetch() {
        controller = CWFetchedResultsController(request: createFetchRequest(), debounceInsertsAndReloads: false)

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, objectIDs)
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
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )

        var currentTag = 0

        let objectIDs = ["a", "b", "c"]
        let objects = objectIDs.compactMap { id -> CWTestObject? in
            let object = CWTestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Replace our instances

        let secondaryObjectIDs = ["z", "a", "c", "b", "d"]
        let secondaryObjects = secondaryObjectIDs.compactMap { id -> CWTestObject? in
            let object = CWTestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }
        let sortedSecondaryObjects = secondaryObjects.sorted(by: controller.sortDescriptors)
        let sortedSecondaryObjectIDs = sortedSecondaryObjects.map { $0.id }

        try! performFetch(secondaryObjects)

        XCTAssertEqual(controller.fetchedIDs.count, secondaryObjectIDs.count)
        XCTAssertEqual(controller.fetchedIDs, sortedSecondaryObjectIDs)
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, sortedSecondaryObjectIDs)

        XCTAssertEqual(controller.tags, [0, 1, 2, 7, 3])
        XCTAssertEqual(controller.sections[0].tags, [0, 1, 2, 7, 3])
    }

    func testBasicFetchWithSortDescriptors() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            sortDescriptors: [
                NSSortDescriptor(key: CWTestObject.idKeyPath._kvcKeyPathString!, ascending: false),
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

extension CWFetchedResultsControllerTestCase {
    func testFetchingIntoSections() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]
        var objects = zip(objectIDs, objectIDs.reversed()).compactMap { CWTestObject(id: $0, sectionName: $1) }
        objects.append(CWTestObject(id: "d", sectionName: "b"))

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
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        var currentTag = 0

        let objectSectionPairs = [("a", "a"), ("b", "b"), ("d", "b"), ("c", "c")]
        let objects = objectSectionPairs.compactMap { pair -> CWTestObject? in
            let (id, sectionName) = pair
            let object = CWTestObject(id: id, tag: currentTag, sectionName: sectionName)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        XCTAssertEqual(controller.fetchedIDs, ["a", "b", "d", "c"])

        // Replace our instances

        let secondaryObjectSectionPairs = [("z", "a"), ("a", "a"), ("c", "b"), ("b", "c"), ("d", "c")]
        let secondaryObjects = secondaryObjectSectionPairs.compactMap { pair -> CWTestObject? in
            let (id, sectionName) = pair
            let object = CWTestObject(id: id, tag: currentTag, sectionName: sectionName)

            currentTag += 1

            return object
        }

        try! performFetch(secondaryObjects)

        XCTAssertEqual(controller.fetchedIDs, ["a", "z", "c", "b", "d"])
        XCTAssertEqual(controller.sections.count, 2)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "z"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["c", "b", "d"])

        XCTAssertEqual(controller.tags, [0, 4, 6, 1, 2])
        XCTAssertEqual(controller.sections[0].tags, [0, 4])
        XCTAssertEqual(controller.sections[1].tags, [6, 1, 2])
    }

    func testFetchingIntoSectionsWithSortDescriptors() {
        controller = CWFetchedResultsController<CWTestObject>(
            request: createFetchRequest(),
            sortDescriptors: [
                NSSortDescriptor(key: CWTestObject.idKeyPath._kvcKeyPathString!, ascending: true),
            ],
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectSectionPairs = [("z", "a"), ("a", "a"), ("c", "c"), ("b", "b"), ("d", "b")]
        let objects = objectSectionPairs.compactMap { pair -> CWTestObject? in
            let (id, sectionName) = pair
            let object = CWTestObject(id: id, sectionName: sectionName)

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

extension CWFetchedResultsControllerTestCase {
    func testFetchingAssociatedObjects() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tag]),
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
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tag]),
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
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tag]),
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
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tagID]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c", "d"]
        let objects = objectIDs.compactMap { id -> CWTestObject? in
            let object = CWTestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on C

        let tagObject0 = getObjectAtIndex(2, withObjectID: "c").tagObject()

        XCTAssertNil(tagObject0)
        XCTAssertEqual(associationRequest.tagIDs, ["0", "1", "2", "3"])

        associationRequest.tagIDsCompletion(
            [CWTestObject(id: "1"), CWTestObject(id: "2"), CWTestObject(id: "3")]
        )

        associationRequest = nil
        changeEvents.removeAll()

        // Broadcast tagID 0

        inclusionCheck = { json in
            CWTestObject.entityID(from: json) != "0"
        }

        let updateName = CWTestObject.objectWasCreated()
        let update: CWTestObject.RawData = ["id": "0", "updatedAt": 1]
        NotificationCenter.default.post(name: updateName, object: update, userInfo: update)

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.update(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")

        // Fetch associated value on A

        let tagObject1 = getObjectAtIndex(0, withObjectID: "a").tagObject()

        XCTAssertEqual(tagObject1?.id, "0")
    }
}

// MARK: - Observed Events

extension CWFetchedResultsControllerTestCase {
    private func setupControllerForKVO(_ file: StaticString = #file, line: UInt = #line) {
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            sortDescriptors: [
                NSSortDescriptor(key: #keyPath(CWTestObject.tag), ascending: true),
            ],
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        var currentTag = 0

        let objectSectionPairs = [("z", "a"), ("a", "a"), ("c", "c"), ("b", "b"), ("d", "c")]
        let objects = objectSectionPairs.compactMap { pair -> CWTestObject? in
            let (id, sectionName) = pair
            let object = CWTestObject(id: id, tag: currentTag, sectionName: sectionName)

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
        controller = CWFetchedResultsController(request: createFetchRequest(), debounceInsertsAndReloads: false)
        controller.setDelegate(self)

        try! performFetch(["a", "b", "c"])

        changeEvents.removeAll()

        // Delete our object in memory

        getObjectAtIndex(0, withObjectID: "a").isDeleted = true

        XCTAssertEqual(controller.fetchedIDs, ["b", "c"])
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["b", "c"])

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.delete(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")
    }

    func testAssociatedObjectDeleteFromKVO() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tagID]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c"]
        let objects = objectIDs.compactMap { id -> CWTestObject? in
            let object = CWTestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObject()
        let associatedObject = CWTestObject(id: "0")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Delete our associated object in memory

        associatedObject.isDeleted = true

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.update(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")

        // We should *not* fault here & our object should be nil

        let deletedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObject()
        XCTAssertNil(deletedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testAssociatedObjectArrayDeleteFromKVO() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tagIDs]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c", "d"]
        let objects = objectIDs.compactMap { id -> CWTestObject? in
            let object = CWTestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObjectArray()
        let associatedObject = CWTestObject(id: "1")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Delete our associated object in memory

        associatedObject.isDeleted = true

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.update(location: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "b")

        // We should *not* fault here & our object should be nil

        let deletedAssociatedObject = getObjectAtIndex(1, withObjectID: "b").tagObjectArray()?.first
        XCTAssertNil(deletedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectNoReloadFromKVO() {
        // We need a custom controller so that sort descriptors is "empty"
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectSectionPairs = [("z", "a"), ("a", "a"), ("c", "c"), ("b", "b"), ("d", "c")]
        let objects = objectSectionPairs.compactMap { CWTestObject(id: $0, sectionName: $1) }

        try! performFetch(objects)

        XCTAssertEqual(controller.fetchedIDs, ["a", "z", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "z"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c", "d"])

        // Modify Z ~> Do not reorder contents in section

        changeEvents.removeAll()

        getObjectAtIndex(1, withObjectID: "z").sectionName = "a"

        XCTAssert(changeEvents.isEmpty)

        XCTAssertEqual(controller.fetchedIDs, ["a", "z", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].fetchedIDs, ["a", "z"])
        XCTAssertEqual(controller.sections[1].fetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].fetchedIDs, ["c", "d"])
    }

    func testExpectReloadFromKVO() {
        controller = CWFetchedResultsController(request: createFetchRequest(), debounceInsertsAndReloads: false)
        controller.setDelegate(self)

        try! performFetch(["a", "b", "c"])

        changeEvents.removeAll()

        // Mutate our object in memory

        controller.fetchedObjects.first?.data = ["id": "a", "key": "value"]

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.update(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")
    }

    func testExpectReloadFromAssociatedObjectKVO() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tagID]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c"]
        let objects = objectIDs.compactMap { id -> CWTestObject? in
            let object = CWTestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)

        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObject()
        let associatedObject = CWTestObject(id: "1")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Mutate our associated object in memory

        associatedObject.data = ["id": "1", "key": "value", "updatedAt": 1]

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.update(location: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "b")

        // We should *not* fault here & our object should be non-nil

        let updatedAssociatedObject = getObjectAtIndex(1, withObjectID: "b").tagObject()
        XCTAssertEqual(associatedObject, updatedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectReloadFromAssociatedObjectArrayKVO() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(associations: [\CWTestObject.tagIDs]),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        var currentTag = 0

        let objectIDs = ["a", "b", "c", "d"]
        let objects = objectIDs.compactMap { id -> CWTestObject? in
            let object = CWTestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(objects)
        
        // Fault on A

        let faultedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObjectArray()
        let associatedObject = CWTestObject(id: "1")

        XCTAssertNil(faultedAssociatedObject)

        associationRequest.tagIDsCompletion([associatedObject])

        associationRequest = nil

        changeEvents.removeAll()

        // Mutate our associated object in memory

        associatedObject.data = ["id": "1", "key": "value", "updatedAt": 1]

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.update(location: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "b")

        // We should *not* fault here & our object should be non-nil

        let updatedAssociatedObject = getObjectAtIndex(1, withObjectID: "b").tagObjectArray()?.first
        XCTAssertEqual(associatedObject, updatedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectInsertFromBroadcastNotification() {
        controller = CWFetchedResultsController(
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

        let notification = Notification(name: CWTestObject.objectWasCreated(), object: newObject.data)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, CWFetchedResultsChange.insert(location: IndexPath(item: 3, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "d")

        changeEvents.removeAll()

        // Broadcast an update event & expect an insert won't occur

        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssert(changeEvents.isEmpty)
    }

    func testExpectNoInsertFromBroadcastNotification() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let initialObjects = ["a", "b", "c"].compactMap { CWTestObject(id: $0) }

        try! performFetch(initialObjects)

        fetchCompletion = nil
        changeEvents.removeAll()

        // Broadcast an update event & expect an insert check to occur, but no insert

        let newObject = CWTestObject(id: "d")

        inclusionCheck = { json in
            CWTestObject.entityID(from: json) != newObject.id
        }

        let notification = Notification(name: CWTestObject.objectWasCreated(), object: newObject.data)
        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssert(changeEvents.isEmpty)

        // Broadcast an update event & expect an insert won't occur

        NotificationCenter.default.post(notification)

        XCTAssertNil(fetchCompletion)
        XCTAssert(changeEvents.isEmpty)
    }
}

// MARK: - IndexPath Math

extension CWFetchedResultsControllerTestCase {
    private func setupController() {
        controller = CWFetchedResultsController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]
        var objects = objectIDs.map { CWTestObject(id: $0, sectionName: "a") }
        objects.append(CWTestObject(id: "d", sectionName: "b"))

        try! performFetch(objects)
    }

    func testIndexPathNilForMissingObject() {
        setupController()

        let object = CWTestObject(id: "e")
        XCTAssertNil(controller.indexPath(for: object))
    }

    func testIndexPathAvailableForObject() {
        setupController()

        let object = CWTestObject(id: "b")
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

// MARK: - CWFetchedResultsControllerDelegate

extension CWFetchedResultsControllerTestCase: CWFetchedResultsControllerDelegate {
    func controller(
        _ controller: CWFetchedResultsController<CWTestObject>,
        didChange object: CWTestObject,
        for change: CWFetchedResultsChange<IndexPath>
    ) {
        changeEvents.append((change: change, object: object))
    }
}
