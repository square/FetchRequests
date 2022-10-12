//
//  OrderedSetCompat.swift
//  OrderedSetCompat
//
//  Created by Adam Lickel on 7/20/21.
//  Copyright © 2021 Speramus Inc. All rights reserved.
//

#if canImport(Collections)

import Collections

typealias OrderedSet = Collections.OrderedSet

#else

import Foundation

struct OrderedSet<Element: Hashable> {
    private(set) var elements: [Element] {
        didSet {
            reindex()
        }
    }
    private(set) var unordered: Set<Element>
    private var indexed: [Element: Int]

    init() {
        elements = []
        unordered = []
        indexed = [:]
    }

    init(_ sequence: some Sequence<Element>) {
        self.init()
        sequence.forEach { insert($0) }
    }
}

// MARK: - Capacity

extension OrderedSet {
    mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        elements.removeAll(keepingCapacity: keepCapacity)
        unordered.removeAll(keepingCapacity: keepCapacity)
    }

    mutating func reserveCapacity(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
        unordered.reserveCapacity(minimumCapacity)
    }

    var capacity: Int {
        elements.capacity
    }
}

// MARK: - Equatable

extension OrderedSet: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.elements == rhs.elements
    }
}

// MARK: - Hashable

extension OrderedSet: Hashable {
    func hash(into hasher: inout Hasher) {
        elements.hash(into: &hasher)
    }
}

// MARK: - CustomStringConvertible

extension OrderedSet: CustomStringConvertible {
    var description: String {
        elements.description
    }
}

// MARK: - ExpressibleByArrayLiteral

extension OrderedSet: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - SetAlgebra

extension OrderedSet: SetAlgebra {
    func contains(_ member: Element) -> Bool {
        unordered.contains(member)
    }

    @discardableResult
    mutating func remove(_ member: Element) -> Element? {
        guard contains(member), let index = index(of: member) else {
            return nil
        }
        elements.remove(at: index)
        return unordered.remove(member)
    }

    @discardableResult
    mutating func update(with newMember: Element) -> Element? {
        // Unconditionally update our set, even if our set contains it

        if contains(newMember), let index = index(of: newMember) {
            elements[index] = newMember
            return unordered.update(with: newMember)
        } else {
            insert(newMember)
            return nil
        }
    }

    @discardableResult
    mutating func insert(
        _ newMember: Element
    ) -> (inserted: Bool, memberAfterInsert: Element) {
        // Conditionally update our set, iff our set does not contain it

        guard contains(newMember) else {
            elements.append(newMember)
            unordered.insert(newMember)
            return (true, newMember)
        }

        // This should return (false, oldMember)
        return unordered.insert(newMember)
    }

    // Copies

    func union(_ other: some Sequence<Element>) -> OrderedSet<Element> {
        var copy = self
        copy.formUnion(other)
        return copy
    }

    func intersection(_ other: some Sequence<Element>) -> OrderedSet<Element> {
        var copy = self
        copy.formIntersection(other)
        return copy
    }

    func symmetricDifference(_ other: some Sequence<Element>) -> OrderedSet<Element>  {
        var copy = self
        copy.formSymmetricDifference(other)
        return copy
    }

    func subtracting(_ other: some Sequence<Element>) -> OrderedSet<Element>  {
        var copy = self
        copy.subtract(other)
        return copy
    }

    // Mutating

    mutating func formUnion(_ other: some Sequence<Element>) {
        let maxCapacity = elements.count + other.underestimatedCount
        if capacity < maxCapacity {
            reserveCapacity(maxCapacity)
        }

        other.forEach { insert($0) }
    }

    mutating func formIntersection(_ other: some Sequence<Element>) {
        unordered.formIntersection(other)
        let newElements = elements.filter { !unordered.contains($0) }
        elements = newElements
    }

    mutating func formSymmetricDifference(_ other: some Sequence<Element>) {
        let maxCapacity = elements.count + other.underestimatedCount
        if capacity < maxCapacity {
            reserveCapacity(maxCapacity)
        }

        for member in other {
            if contains(member) {
                remove(member)
            } else {
                insert(member)
            }
        }
    }

    mutating func subtract(_ other: some Sequence<Element>) {
        unordered.subtract(other)
        let newElements = elements.filter { !unordered.contains($0) }
        elements = newElements
    }
}

// MARK: - Collection

extension OrderedSet: Collection {
    var count: Int {
        elements.count
    }

    var isEmpty: Bool {
        elements.isEmpty
    }

    mutating func removeFirst() -> Element {
        let firstElement = elements.removeFirst()
        unordered.remove(firstElement)
        return firstElement
    }
}

// MARK: - BidirectionalCollection

extension OrderedSet: BidirectionalCollection {
    mutating func removeLast() -> Element {
        let lastElement = elements.removeLast()
        unordered.remove(lastElement)
        return lastElement
    }
}

// MARK: - RandomAccessCollection

extension OrderedSet: RandomAccessCollection {
    var startIndex: Int {
        elements.startIndex
    }

    var endIndex: Int {
        elements.endIndex
    }

    subscript(position: Int) -> Element {
        elements[position]
    }
}

// MARK: - O(1) Index access

extension OrderedSet {
    private mutating func reindex() {
        indexed = elements.enumerated().reduce(into: [:]) { memo, entry in
            memo[entry.element] = entry.offset
        }
    }

    private func index(of element: Element) -> Int? {
        return indexed[element]
    }

    public func firstIndex(of element: Element) -> Int? {
        index(of: element)
    }

    public func lastIndex(of element: Element) -> Int? {
        index(of: element)
    }
}

#endif
