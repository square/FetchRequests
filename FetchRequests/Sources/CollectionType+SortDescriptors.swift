//
//  CollectionType+SortDescriptors.swift
//  Crew
//
//  Created by Adam Lickel on 7/7/16.
//  Copyright © 2016 Speramus Inc. All rights reserved.
//

import Foundation

public extension Sequence where Iterator.Element: NSSortDescriptor {
    var comparator: Comparator {
        return { lhs, rhs in
            for sort in self {
                let result = sort.compare(lhs, to: rhs)
                guard result == .orderedSame else {
                    return result
                }
            }
            return .orderedSame
        }
    }
}

public extension Sequence where Iterator.Element: NSObject {
    func sorted(by descriptors: [NSSortDescriptor]) -> [Iterator.Element] {
        guard !descriptors.isEmpty else {
            return Array(self)
        }

        return sorted(by: descriptors.comparator)
    }

    func sorted(by comparator: Comparator) -> [Iterator.Element] {
        return sorted { comparator($0, $1) == .orderedAscending }
    }
}
