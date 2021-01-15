//
//  simplediff.swift
//  simplediff
//
//  Created by Matthias Hochgatterer on 31/03/15.
//  Copyright (c) 2015 Matthias Hochgatterer. All rights reserved.
//

import Foundation
import Swift

// This should be eventually replaced by the standard library function

enum OperationType {
    case insert, delete, noop

    var description: String {
        switch self {
        case .insert: return "+"
        case .delete: return "-"
        case .noop: return "="
        }
    }
}

/// Operation describes an operation (insertion, deletion, or noop) of elements.
struct Operation<T: Hashable>: Equatable {
    let type: OperationType
    let elements: [T]

    var elementsString: String {
        return elements.map { "\($0)" }.joined(separator: "")
    }

    var description: String {
        switch type {
        case .insert:
            return "[+\(elementsString)]"
        case .delete:
            return "[-\(elementsString)]"
        default:
            return "\(elementsString)"
        }
    }
}

/// diff finds the difference between two lists.
/// This algorithm a shameless copy of simplediff https://github.com/paulgb/simplediff
///
/// - parameter before: Old list of elements.
/// - parameter after: New list of elements
/// - returns: A list of operation (insert, delete, noop) to transform the list *before* to the list *after*.
func diff<T>(_ before: [T], _ after: [T]) -> [Operation<T>] {
    // Create map of indices for every element
    var beforeIndices: [T: [Int]] = [:]
    for index: Int in before.indices {
        let element: T = before[index]

        var indices: [Int] = beforeIndices[element] ?? []
        indices.append(index)
        beforeIndices[element] = indices
    }

    var beforeStart: Int = 0
    var afterStart: Int = 0
    var maxOverlayLength: Int = 0
    var overlay: [Int: Int] = [:] // remembers *overlayLength* of previous element

    for index: Int in after.indices {
        let element: T = after[index]

        // swiftlint:disable:next identifier_name
        var _overlay: [Int: Int] = [:]
         // Element must be in *before* list
        if let elemIndices: [Int] = beforeIndices[element] {
            // Iterate over element indices in *before*
            for elemIndex: Int in elemIndices {
                var overlayLength: Int = 1
                if let previousSub: Int = overlay[elemIndex - 1] {
                    overlayLength += previousSub
                }
                _overlay[elemIndex] = overlayLength
                if overlayLength > maxOverlayLength { // longest overlay?
                    maxOverlayLength = overlayLength
                    beforeStart = elemIndex - overlayLength + 1
                    afterStart = index - overlayLength + 1
                }
            }
        }
        overlay = _overlay
    }

    return populateOperations(
        before: before,
        beforeStart: beforeStart,
        after: after,
        afterStart: afterStart,
        maxOverlayLength: maxOverlayLength
    )
}

private func populateOperations<T>(
    before: [T],
    beforeStart: Int,
    after: [T],
    afterStart: Int,
    maxOverlayLength: Int
) -> [Operation<T>] {
    var operations: [Operation<T>] = []
    if maxOverlayLength == 0 {
         // No overlay; remove before and add after elements
        if !before.isEmpty {
            let operation: Operation = Operation(type: .delete, elements: before)
            operations.append(operation)
        }
        if !after.isEmpty {
            let operation: Operation = Operation(type: .insert, elements: after)
            operations.append(operation)
        }
    } else {
        // Recursive call with elements before overlay
        let beforeOverlay: [Operation<T>] = {
            let beforeSlice: [T] = Array(before[0..<beforeStart])
            let afterSlice: [T] = Array(after[0..<afterStart])

            return diff(beforeSlice, afterSlice)
        }()
        operations += beforeOverlay

        // Noop for longest overlay
        let longestOverlay: [T] = Array(after[afterStart..<afterStart+maxOverlayLength])
        let noop: Operation = Operation(type: .noop, elements: longestOverlay)
        operations.append(noop)

        // Recursive call with elements after overlay
        let afterOverlay: [Operation<T>] = {
            let beforeSliceStart: Int = beforeStart+maxOverlayLength
            let afterSliceStart: Int = afterStart+maxOverlayLength
            let beforeSlice: [T] = Array(before[beforeSliceStart..<before.count])
            let afterSlice: [T] = Array(after[afterSliceStart..<after.count])

            return diff(beforeSlice, afterSlice)
        }()
        operations += afterOverlay
    }
    return operations
}
