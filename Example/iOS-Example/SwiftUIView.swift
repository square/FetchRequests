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
        if #available(iOS 14.0, *) {
            NavigationView {
                List(models) { model in
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
                .listStyle(PlainListStyle())
                .transition(.slide)
                .navigationTitle("SwiftUI Example")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            try? Model().save()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Model.reset()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        } else {
            Text("Example requires iOS 14.")
        }
    }
    
    static var viewController: UIHostingController<SwiftUIView> {
        return UIHostingController(rootView: SwiftUIView())
    }
}
