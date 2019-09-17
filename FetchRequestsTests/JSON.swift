//
//  JSON.swift
//  FetchRequests
//
//  Created by Adam Lickel on 9/16/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

struct JSON {
    var data: [String: Any]

    subscript(key: String) -> Any? {
        get {
            return data[key]
        }
        set {
            data[key] = newValue
        }
    }
}

extension JSON: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, Any)...) {
        let data: [String: Any] = elements.reduce(into: [:]) { memo, element in
            memo[element.0] = element.1
        }
        self.init(data: data)
    }
}

extension JSON: Equatable {
    static func == (lhs: JSON, rhs: JSON) -> Bool {
        return (lhs.data as NSDictionary) == (rhs.data as NSDictionary)
    }
}
