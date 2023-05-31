//
//  SwiftUIView.swift
//  iOS Example
//
//  Created by Ansel Merino on 5/31/23.
//  Copyright © 2023 Speramus Inc. All rights reserved.
//

import Foundation
import SwiftUI
import FetchRequests

struct SwiftUIView: View {
    @FetchableRequest(
        definition: Model.fetchDefinition(),
        sortDescriptors: [
            NSSortDescriptor(
                key: #keyPath(Model.updatedAt),
                ascending: false
            ),
        ],
        animation: Animation.easeIn(duration: 1.0)
    )
    
    private var models: FetchableResults<Model>

    var body: some View {
        NavigationView {
            List(models) { model in
                row(for: model)
            }
            .listStyle(PlainListStyle())
            .transition(.slide)
            .navigationBarTitle("SwiftUI Example", displayMode: .inline)
            .navigationBarItems(
                leading:
                    Button {
                        Model.reset()
                    } label: {
                        Image(systemName: "trash")
                    },
                trailing:
                    Button {
                        try? Model().save()
                    } label: {
                        Image(systemName: "plus")
                    }
            )
        }
    }
    
    static var viewController: UIHostingController<SwiftUIView> {
        return UIHostingController(rootView: SwiftUIView())
    }
}

// Mark: List Row
extension SwiftUIView {
    @ViewBuilder
    func row(for model: Model) -> some View {
        if #available(iOS 15.0, *) {
            VStack(alignment: .leading) {
                Text(model.id)
                    .font(Font.system(.body))
                    .scaledToFit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(model.createdAt.description)
                    .font(Font.system(.footnote))
                    .lineLimit(1)
            }
            .swipeActions {
                Button("Delete") {
                    try? model.delete()
                }
                .tint(.red)
            }
            .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        } else {
            VStack(alignment: .leading) {
                Text(model.id)
                    .font(Font.system(.body))
                    .scaledToFit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(model.createdAt.description)
                    .font(Font.system(.footnote))
                    .lineLimit(1)
            }
            .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        }
    }
}
