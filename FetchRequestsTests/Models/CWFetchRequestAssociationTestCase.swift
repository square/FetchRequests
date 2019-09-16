//
//  CWFetchRequestAssociationTestCase.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 9/28/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import XCTest
@testable import FetchRequests

class CWFetchRequestAssociationTestCase: XCTestCase {
    typealias Association = CWFetchRequestAssociation<CWTestObject>

    private var objects: [CWTestObject] = []

    private var objectIDs: [String] {
        return objects.map { $0.id }
    }

    private var tags: [Int] {
        return objects.map { $0.tag }
    }

    private var tagIDs: [String] {
        return objects.map { $0.nonOptionalTagID }
    }

    override func setUp() {
        super.setUp()

        objects = [
            CWTestObject(id: "a", tag: 0),
            CWTestObject(id: "b", tag: 1),
            CWTestObject(id: "c", tag: 2),
        ]
    }
}

// MARK: - Basic Associations

extension CWFetchRequestAssociationTestCase {
    func testBasicNonOptionalAssociation() {
        let expected: [String: Int] = ["a": 2]

        var calledRequest = false
        let request: Association.AssocationRequestByParent<Int> = { [unowned self] objects, completion in
            XCTAssertEqual(objects, self.objects)
            calledRequest = true
            completion(expected)
        }

        let association = Association(keyPath: \.tag, request: request)

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: Int], expected)
        }

        XCTAssertTrue(calledRequest)

        // Verify we can't observe creation

        let object = CWTestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertFalse(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual((newValue as? Int), 2)
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    func testBasicOptionalAssociation() {
        let expected: [String: Int] = ["a": 2]

        var calledRequest = false
        let request: Association.AssocationRequestByParent<Int> = { objects, completion in
            XCTAssertEqual(objects, self.objects)
            calledRequest = true
            completion(expected)
        }

        let association = Association(keyPath: \.tagID, request: request)

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: Int], expected)
        }

        XCTAssertTrue(calledRequest)

        // Verify we can't observe creation

        let object = CWTestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertFalse(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual((newValue as? String), "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - Observed Creation Associations

extension CWFetchRequestAssociationTestCase {
    func testCreatableNonOptionalAssociation() {
        let expected: [String: CWTestObject] = ["a": objects[0]]

        var calledRequest = false
        let request: Association.AssocationRequestByParent<CWTestObject> = { [unowned self] objects, completion in
            XCTAssertEqual(objects, self.objects)
            calledRequest = true
            completion(expected)
        }

        let token = TestObjectTestToken()
        let tokenGenerator: Association.TokenGenerator<CWTestObject, TestObjectTestToken> = { object in
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
            XCTAssertEqual(results as? [String: CWTestObject], expected)
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(CWTestObject(id: "b"))

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual((newValue as? Int), 2)
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    func testCreatableOptionalAssociation() {
        let expected: [String: CWTestObject] = ["a": objects[0]]

        var calledRequest = false
        let request: Association.AssocationRequestByParent<CWTestObject> = { [unowned self] objects, completion in
            XCTAssertEqual(objects, self.objects)
            calledRequest = true
            completion(expected)
        }

        let token = TestObjectTestToken()
        let tokenGenerator: Association.TokenGenerator<CWTestObject, TestObjectTestToken> = { object in
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
            XCTAssertEqual(results as? [String: CWTestObject], expected)
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

        let ref = association.referenceGenerator(object)
        XCTAssertTrue(ref.canObserveCreation)
        XCTAssertNil(ref.value)

        var calledHandler = false
        ref.observeChanges { invalidate in
            calledHandler = true
        }

        token.handler?(CWTestObject(id: "b"))

        ref.stopObserving()

        XCTAssertTrue(calledHandler)

        // Verify KVO triggers our closure

        var calledKVO = false
        let observer = association.observeKeyPath(object) { object, oldValue, newValue in
            XCTAssertEqual((newValue as? String), "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - Observed Creation by RawData Associations

extension CWFetchRequestAssociationTestCase {
    func testCreatableNonOptionalAssociationByRawData() {
        let expected: [CWTestObject] = [CWTestObject(id: "0")]

        var calledRequest = false
        let request: Association.AssocationRequestByID<CWTestObject.ID, CWTestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            calledRequest = true
            completion(expected)
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<CWTestObject.ID, DataTestToken> = { object in
            token
        }

        let association = Association(
            for: CWTestObject.self,
            keyPath: \.nonOptionalTagID,
            request: request,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: CWTestObject], ["a": expected[0]])
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

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
            XCTAssertEqual((newValue as? String), "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    func testCreatableOptionalAssociationByRawData() {
        let expected: [CWTestObject] = [CWTestObject(id: "0")]

        var calledRequest = false
        let request: Association.AssocationRequestByID<CWTestObject.ID, CWTestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            calledRequest = true
            completion(expected)
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<CWTestObject.ID, DataTestToken> = { object in
            token
        }

        let association = Association(
            for: CWTestObject.self,
            keyPath: \.tagID,
            request: request,
            creationTokenGenerator: tokenGenerator,
            preferExistingValueOnCreate: true
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: CWTestObject], ["a": expected[0]])
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

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
            XCTAssertEqual((newValue as? String), "2")
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - Observed Creation Array Associations

extension CWFetchRequestAssociationTestCase {
    func testCreatableNonOptionalArrayAssociationByRawData() {
        let expected: [CWTestObject] = [CWTestObject(id: "0")]

        var calledRequest = false
        let request: Association.AssocationRequestByID<CWTestObject.ID, CWTestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            calledRequest = true
            completion(expected)
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<[CWTestObject.ID], DataTestToken> = { object in
            token
        }

        let creationObserved: Association.CreationObserved<[CWTestObject], CWTestObject.RawData> = { lhs, rhs in
            return .invalid
        }

        let association = Association(
            for: [CWTestObject].self,
            keyPath: \.nonOptionalTagIDs,
            request: request,
            creationTokenGenerator: tokenGenerator,
            creationObserved: creationObserved
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: [CWTestObject]], ["a": expected])
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

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
            XCTAssertEqual((newValue as? [String]), ["2"])
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

    func testCreatableOptionalArrayAssociationByRawData() {
        let expected: [CWTestObject] = [CWTestObject(id: "0")]

        var calledRequest = false
        let request: Association.AssocationRequestByID<CWTestObject.ID, CWTestObject> = { [unowned self] objectIDs, completion in
            XCTAssertEqual(objectIDs, self.tagIDs)
            calledRequest = true
            completion(expected)
        }

        let token = DataTestToken()
        let tokenGenerator: Association.TokenGenerator<[CWTestObject.ID], DataTestToken> = { object in
            token
        }

        let creationObserved: Association.CreationObserved<[CWTestObject], CWTestObject.RawData> = { lhs, rhs in
            return .invalid
        }

        let association = Association(
            for: [CWTestObject].self,
            keyPath: \.tagIDs,
            request: request,
            creationTokenGenerator: tokenGenerator,
            creationObserved: creationObserved
        )

        // Request an association

        association.request(objects) { results in
            XCTAssertEqual(results as? [String: [CWTestObject]], ["a": expected])
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

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
            XCTAssertEqual((newValue as? [String]), ["2"])
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

// MARK: - CWFetchableEntityID Associations

extension CWFetchRequestAssociationTestCase {
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

        let expected: [String: CWTestObject] = objects.reduce(into: [:]) { memo, element in
            memo[element.id] = CWTestObject(id: element.nonOptionalTagID)
        }

        var calledRequest = false
        association.request(objects) { results in
            calledRequest = true
            XCTAssertEqual(results as? [String: CWTestObject], expected)
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

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
            XCTAssertEqual((newValue as? TestFetchableEntityID), TestFetchableEntityID(id: "2"))
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }

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

        let expected: [String: CWTestObject] = objects.reduce(into: [:]) { memo, element in
            memo[element.id] = CWTestObject(id: element.nonOptionalTagID)
        }

        var calledRequest = false
        association.request(objects) { results in
            calledRequest = true
            XCTAssertEqual(results as? [String: CWTestObject], expected)
        }

        XCTAssertTrue(calledRequest)

        // Verify we can observe creation

        let object = CWTestObject(id: "a")

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
            XCTAssertEqual((newValue as? TestFetchableEntityID), TestFetchableEntityID(id: "2"))
            calledKVO = true
        }

        object.tag = 2
        XCTAssertTrue(calledKVO)

        observer.invalidate()
    }
}

extension CWFetchRequestAssociationTestCase {
    func testEntityFetchByID() {
        let id = TestFetchableEntityID(id: "a")
        let object = CWTestObject(id: "a")

        XCTAssertEqual(TestFetchableEntityID.fetch(byID: id), object)

        var called = false
        TestFetchableEntityID.fetch(byID: id) { result in
            XCTAssertEqual(result, object)
            called = true
        }

        XCTAssertTrue(called)
    }

    func testFaultByEntityID() {
        let object = CWTestObject(id: "a")
        let expected = CWTestObject(id: "0")

        let optionalResult = object.performFault(on: \.tagEntityID)
        let nonOptionalResult = object.performFault(on: \.nonOptionalTagEntityID)

        XCTAssertEqual(optionalResult, expected)
        XCTAssertEqual(nonOptionalResult, expected)
    }

    func testFaultByEntityIDArray() {
        let object = CWTestObject(id: "a")
        let expected = [CWTestObject(id: "0")]

        let optionalResult = object.performFault(on: \.tagArrayEntityID)
        let nonOptionalResult = object.performFault(on: \.nonOptionalTagArrayEntityID)

        XCTAssertEqual(optionalResult, expected)
        XCTAssertEqual(nonOptionalResult, expected)
    }
}

// MARK: - Helpers

private extension CWTestObject {
    @objc
    dynamic var nonOptionalTagID: String {
        return String(tag)
    }

    @objc
    dynamic var nonOptionalTagIDs: [String] {
        return [nonOptionalTagID]
    }

    @objc
    dynamic var nonOptionalTagEntityID: TestFetchableEntityID {
        return TestFetchableEntityID(id: nonOptionalTagID)
    }

    @objc
    dynamic var tagEntityID: TestFetchableEntityID? {
        return tagID.map { TestFetchableEntityID(id: $0) }
    }

    @objc
    class func keyPathsForValuesAffectingNonOptionalTagID() -> Set<String> {
        return [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingNonOptionalTagIDs() -> Set<String> {
        return [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingTagEntityID() -> Set<String> {
        return [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingNonOptionalTagEntityID() -> Set<String> {
        return [#keyPath(tag)]
    }

    var nonOptionalTagArrayEntityID: [TestFetchableEntityID] {
        return [TestFetchableEntityID(id: nonOptionalTagID)]
    }

    var tagArrayEntityID: [TestFetchableEntityID]? {
        return nonOptionalTagArrayEntityID
    }
}

private final class TestFetchableEntityID: NSObject, CWFetchableEntityID {
    let id: CWTestObject.ID

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

    required convenience init(from entity: CWTestObject) {
        self.init(id: entity.id)
    }

    class func fetch(byIDs objectIDs: [TestFetchableEntityID]) -> [CWTestObject] {
        return CWTestObject.fetch(byIDs: objectIDs.map { $0.id })
    }

    class func fetch(byIDs objectIDs: [TestFetchableEntityID], completion: @escaping ([CWTestObject]) -> Void) {
        completion(self.fetch(byIDs: objectIDs))
    }
}

private class TestToken<Parameter>: CWObservableToken {
    var handler: ((Parameter) -> Void)?

    func observe(handler: @escaping (Parameter) -> Void) {
        self.handler = handler
    }

    func invalidate() {
        self.handler = nil
    }
}

private typealias DataTestToken = TestToken<CWTestObject.RawData>
private typealias TestObjectTestToken = TestToken<CWTestObject>
