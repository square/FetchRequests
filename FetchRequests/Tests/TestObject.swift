//
//  TestObject.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 2/25/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation
import FetchRequests

final class TestObject: NSObject, @unchecked Sendable {
    typealias RawData = [String: Any]

    @objc dynamic var id: String
    @objc dynamic var tag: Int = 0
    @objc dynamic var sectionName: String = ""
    @objc dynamic var data: RawData = RawData() {
        didSet {
            integrate(data: data)
        }
    }

    @objc dynamic var isDeleted: Bool = false

    // MARK: NSObject Overrides

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TestObject else {
            return false
        }

        return id == other.id
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)

        return hasher.finalize()
    }

    // MARK: - Initialization & Integration

    required init?(data: RawData) {
        guard let id = TestObject.entityID(from: data) else {
            return nil
        }
        self.id = id
        super.init()
        self.data = data
        integrate(data: data)
    }

    init(id: String, tag: Int = 0, sectionName: String = "") {
        self.id = id
        super.init()
        data = [
            "id": id,
            "tag": tag,
            "sectionName": sectionName,
        ]
        integrate(data: data)
    }

    private func integrate(data: RawData) {
        tag = (data["tag"] as? Int) ?? 0
        sectionName = (data["sectionName"] as? String) ?? ""
    }
}

// MARK: - KVO-able synthetic properties

extension TestObject {
    @objc
    dynamic var tagID: String? {
        String(tag)
    }

    @objc
    dynamic var tagIDs: [String]? {
        tagID.map { [$0] }
    }

    @objc
    class func keyPathsForValuesAffectingTagID() -> Set<String> {
        [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingTagIDs() -> Set<String> {
        [#keyPath(tag)]
    }
}
