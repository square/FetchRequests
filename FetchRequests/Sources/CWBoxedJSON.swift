//
//  CWBoxedJSON.swift
//  FetchRequests
//
//  Created by Adam Lickel on 11/13/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

@objc(BoxedJSON)
public class CWBoxedJSON: NSObject {
    internal let json: JSON

    public init(_ json: JSON) {
        self.json = json
    }

    @objc
    public var object: Any {
        return json.object
    }

    @objc
    public subscript(key: String) -> CWBoxedJSON? {
        return json[key] as CWBoxedJSON?
    }

    @objc
    public subscript(offset: Int) -> CWBoxedJSON? {
        return json[offset] as CWBoxedJSON?
    }
}

//swiftlint:disable identifier_name

extension JSON: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> CWBoxedJSON {
        return CWBoxedJSON(self)
    }

    public static func _forceBridgeFromObjectiveC(
      _ source: CWBoxedJSON,
      result: inout JSON?
    ) {
        result = source.json
    }

    public static func _conditionallyBridgeFromObjectiveC(
      _ source: CWBoxedJSON,
      result: inout JSON?
    ) -> Bool {
        result = source.json
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(
        _ source: CWBoxedJSON?
    ) -> JSON {
      var result: JSON?
      _forceBridgeFromObjectiveC(source!, result: &result)
      return result!
    }
}
