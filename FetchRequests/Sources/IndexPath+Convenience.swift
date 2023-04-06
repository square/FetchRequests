//
//  IndexPath+Convenience.swift
//  FetchRequests
//
//  Created by Adam Lickel on 7/1/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#else
extension IndexPath {
    var section: Int { self[0] }
    var item: Int { self[1] }

    init(item: Int, section: Int) {
        self.init(indexes: [section, item])
    }
}
#endif
