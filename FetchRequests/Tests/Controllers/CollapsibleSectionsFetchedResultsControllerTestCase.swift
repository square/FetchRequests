//
//  CollapsibleSectionsFetchedResultsControllerTestCase.swift
//  Crew
//
//  Created by Adam Proschek on 2/13/17.
//  Copyright © 2017 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

// swiftlint:disable force_try implicitly_unwrapped_optional

// swiftlint:disable:next type_name
class CollapsibleSectionsFetchedResultsControllerTestCase: XCTestCase {
    typealias FetchController = CollapsibleSectionsFetchedResultsController<TestObject>

    private var controller: CollapsibleSectionsFetchedResultsController<TestObject>!

    private var fetchCompletion: (([TestObject]) -> Void)!

    private var associationRequest: TestObject.AssociationRequest!

    private var inclusionCheck: ((TestObject.RawData) -> Bool)?

    private var changeEvents: [(change: FetchedResultsChange<IndexPath>, object: TestObject)] = []
    private var sectionChangeEvents: [(change: FetchedResultsChange<Int>, section: CollapsibleResultsSection<TestObject>)] = []

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
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()

        controller = nil
        fetchCompletion = nil
        associationRequest = nil
        inclusionCheck = nil

        changeEvents = []
    }
}

// MARK: - FetchedResultsControllerDelegate

extension CollapsibleSectionsFetchedResultsControllerTestCase: CollapsibleSectionsFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: CollapsibleSectionsFetchedResultsController<TestObject>) { }

    func controllerDidChangeContent(_ controller: CollapsibleSectionsFetchedResultsController<TestObject>) { }

    func controller(_ controller: CollapsibleSectionsFetchedResultsController<TestObject>, didChange section: CollapsibleResultsSection<TestObject>, for change: FetchedResultsChange<Int>) {
        sectionChangeEvents.append((change: change, section: section))
    }

    func controller(
        _ controller: CollapsibleSectionsFetchedResultsController<TestObject>,
        didChange object: TestObject,
        for change: FetchedResultsChange<IndexPath>
    ) {
        changeEvents.append((change: change, object: object))
    }
}

// MARK: - Collapse/Expand Tests
extension CollapsibleSectionsFetchedResultsControllerTestCase {
    func testInitialSectionCollapse() {
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "0"
            }
        )

        let objects = createTestObjects(count: 15, inSectionsOfLength: 5)
        try! performFetch(objects)

        XCTAssertTrue(controller.sections[0].isCollapsed)
    }

    func testHidingSection() {
        testInitialSectionCollapse()
        let sectionToCollapse = controller.sections[1]
        controller.collapse(section: sectionToCollapse)
        let updatedSection = controller.sections[1]
        XCTAssertTrue(updatedSection.isCollapsed)
    }

    func testExpandingSection() {
        testInitialSectionCollapse()
        let sectionToExpand = controller.sections[0]
        controller.expand(section: sectionToExpand)
        let updatedSection = controller.sections[0]
        XCTAssertFalse(updatedSection.isCollapsed)
    }

    func testInitialSectionConfigCheck() {
        let maxNumberOfItems = 4
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "0"
            },
            sectionConfigCheck: { section in
                if section.name == "0" {
                    return SectionCollapseConfig(maxNumberOfItemsToDisplay: maxNumberOfItems)
                } else {
                    return nil
                }
            }
        )

        let originalObjects = createTestObjects(count: 20, inSectionsOfLength: 10)
        try! performFetch(originalObjects)

        XCTAssert(controller.sections[0].allObjects.count == 10)
        XCTAssertEqual(controller.sections[0].displayableObjects.count, maxNumberOfItems)

        XCTAssert(controller.sections[1].allObjects.count == 10)
        XCTAssert(controller.sections[1].displayableObjects.count == controller.sections[1].allObjects.count)

        controller.update(section: controller.sections[0], maximumNumberOfItemsToDisplay: 6)
        XCTAssertEqual(controller.sections[0].displayableObjects.count, 6)
    }

    func testSectionUpdatesWhenCollapsed() {
        let maxNumberOfItems = 4
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "0"
            },
            sectionConfigCheck: { section in
                if section.name == "0" {
                    return SectionCollapseConfig(maxNumberOfItemsToDisplay: maxNumberOfItems)
                } else {
                    return nil
                }
            }
        )
        controller.setDelegate(self)

        let originalObjects = createTestObjects(count: 6, inSectionsOfLength: 3)
        try! performFetch(originalObjects)

        XCTAssertTrue(controller.sections[0].isCollapsed)
        XCTAssertEqual(controller.sections[0].displayableObjects, controller.sections[0].allObjects)

        fetchCompletion = nil
        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        let testObject = TestObject(id: "6", sectionName: "0")
        let firstInsertNotification = Notification(name: TestObject.objectWasCreated(), object: testObject.data)
        NotificationCenter.default.post(firstInsertNotification)

        XCTAssertNil(fetchCompletion)
        XCTAssertTrue(controller.sections[0].isCollapsed)
        XCTAssertEqual(changeEvents.count, 0)
        XCTAssertEqual(sectionChangeEvents.count, 1)
        XCTAssertEqual(sectionChangeEvents[0].change, FetchedResultsChange.update(location: 0))
    }

    func testObjectUpdatesAfterExpanding() {
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "0"
            }
        )
        controller.setDelegate(self)

        let originalObjects = createTestObjects(count: 6, inSectionsOfLength: 3)
        try! performFetch(originalObjects)

        controller.update(section: controller.sections[0], maximumNumberOfItemsToDisplay: 4)
        XCTAssertTrue(controller.sections[0].isCollapsed)
        XCTAssertEqual(controller.sections[0].displayableObjects, controller.sections[0].allObjects)

        controller.expand(section: controller.sections[0])

        fetchCompletion = nil
        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        let testObject = TestObject(id: "6", sectionName: "0")
        let firstInsertNotification = Notification(name: TestObject.objectWasCreated(), object: testObject.data)
        NotificationCenter.default.post(firstInsertNotification)

        XCTAssertFalse(controller.sections[0].isCollapsed)
        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(sectionChangeEvents.count, 0)
    }

    func testNumberOfItemsToShowWhenExceedingMax() {
        testInitialSectionCollapse()
        controller.expand(section: controller.sections[0])
        controller.update(section: controller.sections[0], maximumNumberOfItemsToDisplay: 4, whenExceedingMax: 3)
        XCTAssertEqual(controller.sections[0].displayableObjects.count, controller.sections[0].allObjects.count)

        controller.collapse(section: controller.sections[0])
        XCTAssertEqual(controller.sections[0].displayableObjects.count, 3)
    }

    func testIndexPath() {
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "0"
            }
        )
        controller.setDelegate(self)

        let originalObjects = createTestObjects(count: 6, inSectionsOfLength: 6)
        try! performFetch(originalObjects)

        let maxNumberOfItems = 4
        controller.update(section: controller.sections[0], maximumNumberOfItemsToDisplay: maxNumberOfItems)
        controller.collapse(section: controller.sections[0])

        let lastItem = controller.sections[0].allObjects[maxNumberOfItems - 1]
        let indexPath = controller.indexPath(for: lastItem)
        XCTAssertNotNil(indexPath)
    }

    // Test hidden item is not found
    func testIndexPathNilFromCollapse() {
        testIndexPath()

        let objectHiddenFromCollapse = controller.sections[0].allObjects.last!
        let indexPath = controller.indexPath(for: objectHiddenFromCollapse)
        XCTAssertNil(indexPath)
    }

    func testItemMovingSections() {
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "0"
            },
            sectionConfigCheck: { section in
                if section.name == "0" {
                    return SectionCollapseConfig(maxNumberOfItemsToDisplay: 3)
                } else {
                    return nil
                }
            }
        )
        controller.setDelegate(self)

        let originalObjects = createTestObjects(count: 10, inSectionsOfLength: 5)
        try! performFetch(originalObjects)

        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        let objectToMove = controller.sections[0].allObjects.first!
        objectToMove.sectionName = "1"
        let notification = Notification(name: TestObject.objectWasCreated(), object: objectToMove.data)
        NotificationCenter.default.post(notification)

        XCTAssertEqual(changeEvents.count, 1)
        switch changeEvents[0].change {
        case .insert:
            XCTAssert(true)

        default:
            XCTAssert(false)
        }
        XCTAssertEqual(sectionChangeEvents.count, 1)

        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        let secondObjectToMove = controller.sections[1].allObjects.first!
        objectToMove.sectionName = "0"
        let secondNotification = Notification(name: TestObject.objectWasCreated(), object: secondObjectToMove.data)
        NotificationCenter.default.post(secondNotification)

        XCTAssertEqual(changeEvents.count, 1)
        switch changeEvents[0].change {
        case .delete:
            XCTAssert(true)

        default:
            XCTAssert(false)
        }
        XCTAssertEqual(sectionChangeEvents.count, 1)
    }

    func testInsertingItemsTriggersCollapse() {
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "0"
            },
            sectionConfigCheck: { section in
                guard section.name == "0" else {
                    return nil
                }

                return SectionCollapseConfig(
                    maxNumberOfItemsToDisplay: 5,
                    whenExceedingMax: 4
                )
            }
        )

        controller.setDelegate(self)

        let originalObjects = createTestObjects(count: 6, inSectionsOfLength: 3)
        try! performFetch(originalObjects)

        XCTAssertEqual(controller.sections[0].numberOfDisplayableObjects, 3)
        XCTAssertTrue(controller.sections[0].isCollapsed)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["0", "1", "2"])

        // Insert enough objects to trigger a collapse

        let newObjectIDs = ["a", "b", "c", "d"]
        let newObjects = newObjectIDs.map {
            TestObject(id: $0, sectionName: "0")
        }

        fetchCompletion = nil
        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        try! performFetch(originalObjects + newObjects)

        XCTAssertEqual(controller.sections[0].numberOfDisplayableObjects, 4)
        XCTAssertTrue(controller.sections[0].isCollapsed)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["0", "1", "2", "a", "b", "c", "d"])

        // Received reload event

        XCTAssertEqual(sectionChangeEvents.count, 1)
        XCTAssertEqual(sectionChangeEvents[0].change, FetchedResultsChange.update(location: 0))
    }

    func testDeletingItemsTriggersExpansion() {
        testInsertingItemsTriggersCollapse()

        // Delete Entity

        fetchCompletion = nil
        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        getObjectAtIndex(0, withObjectID: "0").isDeleted = true

        // Received reload event

        XCTAssertEqual(sectionChangeEvents.count, 1)
        XCTAssertEqual(sectionChangeEvents[0].change, FetchedResultsChange.update(location: 0))

        // Delete Entity, crossing threshold

        fetchCompletion = nil
        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        XCTAssertEqual(controller.sections[0].numberOfDisplayableObjects, 4)
        XCTAssertTrue(controller.sections[0].isCollapsed)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["1", "2", "a", "b", "c", "d"])

        fetchCompletion = nil
        changeEvents.removeAll()
        sectionChangeEvents.removeAll()

        getObjectAtIndex(0, withObjectID: "1").isDeleted = true

        XCTAssertEqual(controller.sections[0].numberOfDisplayableObjects, 5)
        XCTAssertTrue(controller.sections[0].isCollapsed)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["2", "a", "b", "c", "d"])

        // Received reload event

        XCTAssertEqual(sectionChangeEvents.count, 1)
        XCTAssertEqual(sectionChangeEvents[0].change, FetchedResultsChange.update(location: 0))
    }
}

// MARK: - FetchedResultsControllerTestCase Tests

extension CollapsibleSectionsFetchedResultsControllerTestCase {
    func testBasicFetch() {
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false,
            initialSectionCollapseCheck: { section in
                return section.name == "1"
            }
        )

        let objects = createTestObjects(count: 15, inSectionsOfLength: 5)

        try! performFetch(objects)

        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].allObjects.count, 5)
    }

    func testResort() {
        controller = FetchController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )

        let objectIDs = ["a", "b", "c"]

        try! performFetch(objectIDs)

        controller.resort(using: [NSSortDescriptor(keyPath: \TestObject.id, ascending: false)])

        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, objectIDs.reversed())
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
        controller = FetchController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )

        let objects = createTestObjects(count: 3, inSectionsOfLength: Int.max)
        var currentTag = (objects.last?.tag ?? 0) + 1

        try! performFetch(objects)

        // Replace our instances

        let secondaryObjectIDs = ["9", "0", "2", "1", "4"]
        let secondaryObjects = secondaryObjectIDs.compactMap { id -> TestObject? in
            let object = TestObject(id: id, tag: currentTag)

            currentTag += 1

            return object
        }

        try! performFetch(secondaryObjects)

        XCTAssertEqual(controller.fetchedIDs.count, secondaryObjectIDs.count)
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["9", "0", "2", "1", "4"])

        XCTAssertEqual(controller.tags, [3, 0, 2, 6, 7])
        XCTAssertEqual(controller.sections[0].allTags, [3, 0, 2, 6, 7])
    }

    func testBasicFetchWithSortDescriptors() {
        controller = FetchController(
            request: createFetchRequest(),
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
        XCTAssertEqual(controller.sections[0].allFetchedIDs, objectIDs)
    }
}

// MARK: - Sections
extension CollapsibleSectionsFetchedResultsControllerTestCase {
    func testFetchingIntoSections() {
        controller = FetchController(
            request: createFetchRequest(),
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
        XCTAssertEqual(controller.sections[0].allObjects, [objects[2]])
        XCTAssertEqual(controller.sections[1].allObjects, [objects[1], objects[3]])
        XCTAssertEqual(controller.sections[2].allObjects, [objects[0]])
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
        controller = FetchController(
            request: createFetchRequest(),
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
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["c", "b", "d"])

        XCTAssertEqual(controller.tags, [4, 0, 6, 1, 2])
        XCTAssertEqual(controller.sections[0].allTags, [4, 0])
        XCTAssertEqual(controller.sections[1].allTags, [6, 1, 2])
    }

    func testFetchingIntoSectionsWithSortDescriptors() {
        controller = FetchController(
            request: createFetchRequest(),
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
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["a", "z"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["b", "d"])
        XCTAssertEqual(controller.sections[2].allFetchedIDs, ["c"])
    }
}

// MARK: - Associated Values
extension CollapsibleSectionsFetchedResultsControllerTestCase {
    func testFetchingAssociatedObjects() {
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tag]),
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
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tag]),
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
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tag]),
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
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tagID]),
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

        inclusionCheck = { json in
            TestObject.entityID(from: json) != "0"
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

extension CollapsibleSectionsFetchedResultsControllerTestCase {
    private func setupControllerForKVO(_ file: StaticString = #file, line: UInt = #line) {
        controller = FetchController(
            request: createFetchRequest(),
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
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["z", "a"], file: file, line: line)
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["b"], file: file, line: line)
        XCTAssertEqual(controller.sections[2].allFetchedIDs, ["c", "d"], file: file, line: line)
    }

    func testSectionChangeFromKVO() {
        setupControllerForKVO()

        // Modify C ~> Move Section w/o Adding or Deleting

        let indexPath = IndexPath(item: 0, section: 2)
        let object = controller.object(at: indexPath)

        object.sectionName = "b"

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "c", "b", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["c", "b"])
        XCTAssertEqual(controller.sections[2].allFetchedIDs, ["d"])
    }

    func testSectionCreationFromKVO() {
        setupControllerForKVO()

        // Modify Z ~> Move Section Adding Section

        let indexPath = IndexPath(item: 0, section: 0)
        let object = controller.object(at: indexPath)

        object.sectionName = "d"

        XCTAssertEqual(controller.fetchedIDs, ["a", "b", "c", "d", "z"])
        XCTAssertEqual(controller.sections.count, 4)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["a"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].allFetchedIDs, ["c", "d"])
        XCTAssertEqual(controller.sections[3].allFetchedIDs, ["z"])
    }

    func testSectionDeletionFromKVO() {
        setupControllerForKVO()

        // Modify B ~> Move Section Deleting Section

        let indexPath = IndexPath(item: 0, section: 1)
        let object = controller.object(at: indexPath)

        object.sectionName = "c"

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "c", "b", "d"])
        XCTAssertEqual(controller.sections.count, 2)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["c", "b", "d"])
    }

    func testOrderChangeFromKVO() {
        setupControllerForKVO()

        // Modify Z ~> Reorder contents in section

        getObjectAtIndex(0, withObjectID: "z").tag = 99

        XCTAssertEqual(controller.fetchedIDs, ["a", "z", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["a", "z"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].allFetchedIDs, ["c", "d"])
    }

    func testDeleteFromKVO() {
        controller = FetchController(request: createFetchRequest(), debounceInsertsAndReloads: false)
        controller.setDelegate(self)

        try! performFetch(["a", "b", "c"])

        changeEvents.removeAll()

        // Delete our object in memory

        getObjectAtIndex(0, withObjectID: "a").isDeleted = true

        XCTAssertEqual(controller.fetchedIDs, ["b", "c"])
        XCTAssertEqual(controller.sections.count, 1)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["b", "c"])

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.delete(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")
    }

    func testAssociatedObjectDeleteFromKVO() {
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tagID]),
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
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tagIDs]),
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

        let deletedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObjectArray()?.first
        XCTAssertNil(deletedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectNoReloadFromKVO() {
        // We need a custom controller so that sort descriptors is "empty"
        controller = FetchController(
            request: createFetchRequest(),
            sectionNameKeyPath: \.sectionName,
            debounceInsertsAndReloads: false
        )

        let objectSectionPairs = [("z", "a"), ("a", "a"), ("c", "c"), ("b", "b"), ("d", "c")]
        let objects = objectSectionPairs.compactMap { TestObject(id: $0, sectionName: $1) }

        try! performFetch(objects)

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].allFetchedIDs, ["c", "d"])

        // Modify Z ~> Do not reorder contents in section

        changeEvents.removeAll()

        getObjectAtIndex(1, withObjectID: "a").sectionName = "a"

        XCTAssert(changeEvents.isEmpty)

        XCTAssertEqual(controller.fetchedIDs, ["z", "a", "b", "c", "d"])
        XCTAssertEqual(controller.sections.count, 3)
        XCTAssertEqual(controller.sections[0].allFetchedIDs, ["z", "a"])
        XCTAssertEqual(controller.sections[1].allFetchedIDs, ["b"])
        XCTAssertEqual(controller.sections[2].allFetchedIDs, ["c", "d"])
    }

    func testExpectReloadFromKVO() {
        controller = FetchController(request: createFetchRequest(), debounceInsertsAndReloads: false)
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
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tagID]),
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

        // Mutate our associated object in memory

        associatedObject.data = ["id": "0", "key": "value", "updatedAt": 1]

        XCTAssertEqual(changeEvents.count, 1)
        XCTAssertEqual(changeEvents[0].change, FetchedResultsChange.update(location: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(changeEvents[0].object.id, "a")

        // We should *not* fault here & our object should be non-nil

        let updatedAssociatedObject = getObjectAtIndex(0, withObjectID: "a").tagObject()
        XCTAssertEqual(associatedObject, updatedAssociatedObject)
        XCTAssertNil(associationRequest)
    }

    func testExpectReloadFromAssociatedObjectArrayKVO() {
        controller = FetchController(
            request: createFetchRequest(associations: [\TestObject.tagIDs]),
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
        controller = FetchController(
            request: createFetchRequest(),
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
        controller = FetchController(
            request: createFetchRequest(),
            debounceInsertsAndReloads: false
        )
        controller.setDelegate(self)

        let initialObjects = ["a", "b", "c"].compactMap { TestObject(id: $0) }

        try! performFetch(initialObjects)

        fetchCompletion = nil
        changeEvents.removeAll()

        // Broadcast an update event & expect an insert check to occur, but no insert

        let newObject = TestObject(id: "d")

        inclusionCheck = { json in
            TestObject.entityID(from: json) != newObject.id
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
}

private extension CollapsibleSectionsFetchedResultsControllerTestCase {
    func performFetch(_ objectIDs: [String], file: StaticString = #file, line: UInt = #line) throws {
        let objects = objectIDs.compactMap { TestObject(id: $0) }

        try performFetch(objects, file: file, line: line)
    }

    func performFetch(_ objects: [TestObject], file: StaticString = #file, line: UInt = #line) throws {
        controller.performFetch()

        self.fetchCompletion(objects)

        let sortedObjects = objects.sorted(by: controller.sortDescriptors)
        XCTAssertEqual(sortedObjects, controller.fetchedObjects, file: file, line: line)
    }

    func getObjectAtIndex(_ index: Int, withObjectID objectID: String, file: StaticString = #file, line: UInt = #line) -> TestObject! {
        let object = controller.fetchedObjects[index]

        XCTAssertEqual(object.id, objectID, file: file, line: line)

        return object
    }

    func createTestObjects(count: Int, inSectionsOfLength maxSectionLength: Int, startingWithID startID: Int = 0) -> [TestObject] {
        let idRange = startID ..< (startID + count)
        return idRange.compactMap { index in
            return TestObject(
                id: "\(index)",
                tag: index,
                sectionName: "\(index / maxSectionLength)"
            )
        }
    }
}

extension CollapsibleSectionsFetchedResultsController where FetchedObject: TestObject {
    var fetchedIDs: [String] {
        return fetchedObjects.compactMap { $0.id }
    }

    var tags: [Int] {
        return fetchedObjects.compactMap { $0.tag }
    }
}

extension CollapsibleResultsSection where FetchedObject: TestObject {
    var allFetchedIDs: [String] {
        return allObjects.compactMap { $0.id }
    }

    var displayableFetchedIDs: [String] {
        return displayableObjects.compactMap { $0.id }
    }

    var allTags: [Int] {
        return allObjects.compactMap { $0.tag }
    }
}
