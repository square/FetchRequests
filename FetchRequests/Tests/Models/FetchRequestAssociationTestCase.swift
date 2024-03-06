//
//  FetchRequestAssociationTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class FetchRequestAssociationTestCase: XCTestCase {
    private typealias Association = FetchRequestAssociation<TestObject>

    private let objects: [TestObject] = [
        TestObject(id: "a", tag: 0),
        TestObject(id: "b", tag: 1),
        TestObject(id: "c", tag: 2),
    ]

    private var objectIDs: [String] {
        objects.map(\.id)
    }

    private var tags: [Int] {
        objects.map(\.tag)
    }

    private var tagIDs: [String] {
        objects.map(\.nonOptionalTagID)
    }
}

// MARK: - Basic Associations

extension FetchRequestAssociationTestCase {
    @MainActor
    func testBasicNonOptionalAssociation() {
        let expected: [String: Int] = ["a": 2]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByParent<Int> = { [unowned self] objects, completion in
            XCTAssertEqual(objects, self.objects)
            completion(expected)
            expectation.fulfill()
        }

        let association = Association(keyPath: \.tag, request: request)

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: Int], expected)
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can't observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertFalse(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? Int, 2)
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    @MainActor
    func testBasicOptionalAssociation() {
        let expected: [String: Int] = ["a": 2]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByParent<Int> = { objects, completion in
            XCTAssertEqual(objects, self.objects)
            completion(expected)
            expectation.fulfill()
        }

        let association = Association(keyPath: \.tagID, request: request)

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: Int], expected)
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can't observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertFalse(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? String, "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - Observed Creation Associations

extension FetchRequestAssociationTestCase {
    @MainActor
    func testCreatableNonOptionalAssociation() {
        let expected: [String: TestObject] = ["a": objects[0]]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByParent<TestObject> = { [unowned self] objects, completion in
            XCTAssertEqual(objects, self.objects)
            completion(expected)
            expectation.fulfill()
        }

        let token = TestObjectTestToken()
        let tokenGenerator: Association.TokenGenerator<TestObject, TestObjectTestToken> = { object in
            token
        }

        let association = Association(
            keyPath: \.tag,
            request: request,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: TestObject], expected)
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(TestObject(id: "b"))

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? Int, 2)
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    @MainActor
    func testCreatableOptionalAssociation() {
        let expected: [String: TestObject] = ["a": objects[0]]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByParent<TestObject> = { [unowned self] objects, completion in
            XCTAssertEqual(objects, self.objects)
            completion(expected)
            expectation.fulfill()
        }

        let token = TestObjectTestToken()
        let tokenGenerator: Association.TokenGenerator<TestObject, TestObjectTestToken> = { object in
            token
        }

        let association = Association(
            keyPath: \.tagID,
            request: request,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: TestObject], expected)
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(TestObject(id: "b"))

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? String, "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - Observed Creation by RawData Associations

extension FetchRequestAssociationTestCase {
    @MainActor
    func testCreatableNonOptionalAssociationByRawData() {
        let expected: [TestObject] = [TestObject(id: "0")]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByID<TestObject.ID, TestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            completion(expected)

            expectation.fulfill()
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<TestObject.ID, DataTestToken> = { object in
            token
        }

        let association = Association(
            for: TestObject.self,
            keyPath: \.nonOptionalTagID,
            request: request,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: TestObject], ["a": expected[0]])
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(["id": "b"])

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? String, "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    @MainActor
    func testCreatableOptionalAssociationByRawData() {
        let expected: [TestObject] = [TestObject(id: "0")]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByID<TestObject.ID, TestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            completion(expected)
            expectation.fulfill()
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<TestObject.ID, DataTestToken> = { object in
            token
        }

        let association = Association(
            for: TestObject.self,
            keyPath: \.tagID,
            request: request,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: TestObject], ["a": expected[0]])
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(["id": "b"])

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? String, "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - Observed Creation Array Associations

extension FetchRequestAssociationTestCase {
    @MainActor
    func testCreatableNonOptionalArrayAssociationByRawData() {
        let expected: [TestObject] = [TestObject(id: "0")]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByID<TestObject.ID, TestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            completion(expected)
            expectation.fulfill()
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<[TestObject.ID], DataTestToken> = { object in
            token
        }

        let creationObserved: Association.CreationObserved<[TestObject], TestObject.RawData> = { lhs, rhs in
            .invalid
        }

        let association = Association(
            for: [TestObject].self,
            keyPath: \.nonOptionalTagIDs,
            request: request,
            creationTokenGenerator: tokenGenerator,
            creationObserved: creationObserved
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: [TestObject]], ["a": expected])
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(["id": "b"])

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? [String], ["2"])
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    @MainActor
    func testCreatableOptionalArrayAssociationByRawData() {
        let expected: [TestObject] = [TestObject(id: "0")]

        let expectation = XCTestExpectation(description: "calledRequest")
        let request: Association.AssocationRequestByID<TestObject.ID, TestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            completion(expected)

            expectation.fulfill()
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<[TestObject.ID], DataTestToken> = { object in
            token
        }

        let creationObserved: Association.CreationObserved<[TestObject], TestObject.RawData> = { lhs, rhs in
            .invalid
        }

        let association = Association(
            for: [TestObject].self,
            keyPath: \.tagIDs,
            request: request,
            creationTokenGenerator: tokenGenerator,
            creationObserved: creationObserved
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: [TestObject]], ["a": expected])
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(["id": "b"])

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? [String], ["2"])
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - FetchableEntityID Associations

extension FetchRequestAssociationTestCase {
    @MainActor
    func testNonOptionalFetchableEntityID() {
        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<TestFetchableEntityID, DataTestToken> = { object in
            token
        }

        let association = Association(
            keyPath: \.nonOptionalTagEntityID,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        let expected: [String: TestObject] = objects.reduce(into: [:]) { memo, element in
            memo[element.id] = TestObject(id: element.nonOptionalTagID)
        }

        let expectation = XCTestExpectation(description: "calledRequest")
        association.request(objects) { results in
            XCTAssertEqual(results as? [String: TestObject], expected)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(["id": "b"])

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? TestFetchableEntityID, TestFetchableEntityID(id: "2"))
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    @MainActor
    func testOptionalFetchableEntityID() {
        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<TestFetchableEntityID, DataTestToken> = { object in
            token
        }

        let association = Association(
            keyPath: \.tagEntityID,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        let expected: [String: TestObject] = objects.reduce(into: [:]) { memo, element in
            memo[element.id] = TestObject(id: element.nonOptionalTagID)
        }

        let expectation = XCTestExpectation(description: "calledRequest")
        association.request(objects) { results in
            XCTAssertEqual(results as? [String: TestObject], expected)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)

        // Verify we can observe creation

        let object = TestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(["id": "b"])

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual(newValue as? TestFetchableEntityID, TestFetchableEntityID(id: "2"))
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

extension FetchRequestAssociationTestCase {
    @MainActor
    func testEntityFetchByID() {
        let id = TestFetchableEntityID(id: "a")
        let object = TestObject(id: "a")

        XCTAssertEqual(TestFetchableEntityID.fetch(byID: id), object)

        let expectation = XCTestExpectation(description: "calledRequest")
        TestFetchableEntityID.fetch(byID: id) { result in
            XCTAssertEqual(result, object)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    @MainActor
    func testFaultByEntityID() {
        let object = TestObject(id: "a")
        let expected = TestObject(id: "0")

        let optionalResult = object.performFault(on: \.tagEntityID)
        let nonOptionalResult = object.performFault(on: \.nonOptionalTagEntityID)

        XCTAssertEqual(optionalResult, expected)
        XCTAssertEqual(nonOptionalResult, expected)
    }

    @MainActor
    func testFaultByEntityIDArray() {
        let object = TestObject(id: "a")
        let expected = [TestObject(id: "0")]

        let optionalResult = object.performFault(on: \.tagArrayEntityID)
        let nonOptionalResult = object.performFault(on: \.nonOptionalTagArrayEntityID)

        XCTAssertEqual(optionalResult, expected)
        XCTAssertEqual(nonOptionalResult, expected)
    }
}

// MARK: - Helpers

private extension TestObject {
    @objc
    dynamic var nonOptionalTagID: String {
        String(tag)
    }

    @objc
    dynamic var nonOptionalTagIDs: [String] {
        [nonOptionalTagID]
    }

    @objc
    dynamic var nonOptionalTagEntityID: TestFetchableEntityID {
        TestFetchableEntityID(id: nonOptionalTagID)
    }

    @objc
    dynamic var tagEntityID: TestFetchableEntityID? {
        tagID.map { TestFetchableEntityID(id: $0) }
    }

    @objc
    class func keyPathsForValuesAffectingNonOptionalTagID() -> Set<String> {
        [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingNonOptionalTagIDs() -> Set<String> {
        [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingTagEntityID() -> Set<String> {
        [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingNonOptionalTagEntityID() -> Set<String> {
        [#keyPath(tag)]
    }

    var nonOptionalTagArrayEntityID: [TestFetchableEntityID] {
        [TestFetchableEntityID(id: nonOptionalTagID)]
    }

    var tagArrayEntityID: [TestFetchableEntityID]? {
        nonOptionalTagArrayEntityID
    }
}

private final class TestFetchableEntityID: NSObject, FetchableEntityID {
    let id: TestObject.ID

    init(id: String) {
        self.id = id
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TestFetchableEntityID else {
            return super.isEqual(object)
        }
        return id == other.id
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)

        return hasher.finalize()
    }

    required convenience init(from entity: TestObject) {
        self.init(id: entity.id)
    }

    class func fetch(byIDs objectIDs: [TestFetchableEntityID]) -> [TestObject] {
        TestObject.fetch(byIDs: objectIDs.map(\.id))
    }

    class func fetch(byIDs objectIDs: [TestFetchableEntityID], completion: @escaping @MainActor ([TestObject]) -> Void) {
        Task {
            await completion(self.fetch(byIDs: objectIDs))
        }
    }
}

private class TestToken<Parameter>: ObservableToken {
    var handler: ((Parameter) -> Void)?

    func observe(handler: @escaping (Parameter) -> Void) {
        self.handler = handler
    }

    func invalidate() {
        self.handler = nil
    }
}

private typealias DataTestToken = TestToken<TestObject.RawData>
private typealias TestObjectTestToken = TestToken<TestObject>
