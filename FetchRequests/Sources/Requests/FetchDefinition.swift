//
//  FetchDefinition.swift
//  Crew
//
//  Created by Adam Lickel on 7/7/16.
//  Copyright © 2016 Speramus Inc. All rights reserved.
//

import Foundation

public class FetchDefinition<FetchedObject: FetchableObject> {
    public typealias Request = (_ completion: @escaping ([FetchedObject]) -> Void) -> Void
    public typealias CreationInclusionCheck = (_ rawData: FetchedObject.RawData) -> Bool

    internal let request: Request
    internal let objectCreationToken: FetchRequestObservableToken<FetchedObject.RawData>
    internal let creationInclusionCheck: CreationInclusionCheck
    internal let associations: [FetchRequestAssociation<FetchedObject>]
    internal let dataResetTokens: [FetchRequestObservableToken<Void>]

    internal let associationsByKeyPath: [FetchRequestAssociation<FetchedObject>.AssociationKeyPath: FetchRequestAssociation<FetchedObject>]

    public init<VoidToken: ObservableToken, DataToken: ObservableToken>(
        request: @escaping Request,
        objectCreationToken: DataToken,
        creationInclusionCheck: @escaping CreationInclusionCheck = { _ in true },
        associations: [FetchRequestAssociation<FetchedObject>] = [],
        dataResetTokens: [VoidToken] = []
    ) where VoidToken.Parameter == Void, DataToken.Parameter == FetchedObject.RawData {
        self.request = request
        self.objectCreationToken = FetchRequestObservableToken(token: objectCreationToken)
        self.creationInclusionCheck = creationInclusionCheck
        self.associations = associations
        self.dataResetTokens = dataResetTokens.map { FetchRequestObservableToken(token: $0) }

        associationsByKeyPath = associations.reduce(into: [:]) { memo, element in
            assert(element.keyPath._kvcKeyPathString != nil, "\(element.keyPath) is not KVC compliant?")
            assert(memo[element.keyPath] == nil, "You cannot reuse \(element.keyPath) for two associations")
            memo[element.keyPath] = element
        }
    }
}
