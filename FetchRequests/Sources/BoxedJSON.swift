//
//  BoxedJSON.swift
//  FetchRequests
//
//  Created by Adam Lickel on 11/13/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

@objc(CWBoxedJSON)
public class BoxedJSON: NSObject, NSSecureCoding {
    internal let json: JSON

    public static var supportsSecureCoding: Bool {
        return true
    }

    public init(_ json: JSON) {
        self.json = json
    }

    @objc(initWithObject:)
    public convenience init?(__object object: NSObject?) {
        guard let object, let json = JSON(object) else {
            return nil
        }
        self.init(json)
    }

    public required init?(coder: NSCoder) {
        guard let jsonRaw = coder.decodeData() else {
            return nil
        }
        guard let json = JSON(jsonRaw) else {
            return nil
        }
        self.json = json
    }

    @objc
    public var object: Any {
        return json.object
    }

    @objc
    public subscript(key: String) -> BoxedJSON? {
        return json[key] as BoxedJSON?
    }

    @objc
    public subscript(offset: Int) -> BoxedJSON? {
        return json[offset] as BoxedJSON?
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? BoxedJSON else {
            return super.isEqual(object)
        }
        return json == other.json
    }

    public func encode(with coder: NSCoder) {
        guard let data = try? JSONEncoder().encode(json) else {
            return
        }
        coder.encode(data)
    }
}

// swiftlint:disable identifier_name

extension JSON: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> BoxedJSON {
        return BoxedJSON(self)
    }

    public static func _forceBridgeFromObjectiveC(
        _ source: BoxedJSON,
        result: inout JSON?
    ) {
        result = source.json
    }

    public static func _conditionallyBridgeFromObjectiveC(
        _ source: BoxedJSON,
        result: inout JSON?
    ) -> Bool {
        result = source.json
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(
        _ source: BoxedJSON?
    ) -> JSON {
        var result: JSON?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}
