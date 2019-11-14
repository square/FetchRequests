//
//  CWTestObject.swift
//  FetchRequests-iOSTests
//
//  Created by Adam Lickel on 2/25/18.
//  Copyright © 2018 Speramus Inc. All rights reserved.
//

import Foundation
@testable import FetchRequests

final class CWTestObject: NSObject, CWIdentifiable {
    typealias RawData = CWJSON

    @objc dynamic var id: String
    @objc dynamic var tag: Int = 0
    @objc dynamic var sectionName: String = ""
    @objc dynamic var data: RawData = [:] {
        didSet {
            integrate(data: data)
        }
    }

    @objc dynamic var isDeleted: Bool = false

    // MARK: NSObject Overrides

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CWTestObject else {
            return false
        }

        return id == other.id
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)

        return hasher.finalize()
    }

    required init?(data: RawData) {
        guard let id = CWTestObject.entityID(from: data) else {
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
        tag = data.tag?.int ?? 0
        sectionName = data.sectionName?.string ?? ""
    }
}

// MARK: - KVO-able synthetic properties

extension CWTestObject {
    @objc
    dynamic var tagID: String? {
        return String(tag)
    }

    @objc
    dynamic var tagIDs: [String]? {
        return tagID.map { [$0] }
    }

    @objc
    class func keyPathsForValuesAffectingTagID() -> Set<String> {
        return [#keyPath(tag)]
    }

    @objc
    class func keyPathsForValuesAffectingTagIDs() -> Set<String> {
        return [#keyPath(tag)]
    }
}
