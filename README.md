# FetchRequests

FetchRequests is an eventing library inspired by NSFetchedResultsController and written in Swift.

[![Build Status](https://github.com/square/FetchRequests/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/square/FetchRequests/actions/workflows/build.yml)
[![codecov](https://img.shields.io/codecov/c/github/square/FetchRequests/main)](https://codecov.io/gh/square/FetchRequests)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/FetchRequests)](https://cocoapods.org/pods/FetchRequests)
[![Carthage Compatible](https://img.shields.io/badge/carthage-compatible-4BC51D)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/FetchRequests)](https://cocoapods.org/pods/FetchRequests)
[![Pod License](https://img.shields.io/cocoapods/l/FetchRequests)](https://opensource.org/licenses/MIT)

- [Features](#features)
- [Usage](#usage)
- [Requirements](#requirements)
- [Communication](#communication)
- [Installation](#installation)
- [License](#license)

## Features

- [x] Sort and section a list of items
- [x] Listen for live updates
- [x] Animate underlying data changes
- [x] Fetch associated values in batch
- [x] Support paginated requests
- [x] SwiftUI Integration
- [x] Comprehensive Unit Test Coverage

## Usage

FetchRequests can be used for any combination of networking, database, and file queries.
It is best when backed by something like a [WebSocket](https://en.wikipedia.org/wiki/WebSocket) where you're expecting your data to live update.

To get started, you create a `FetchRequest` which explains your data access patterns.
The `FetchedResultsController` is the interface to access the your data.
Objects are sorted with the following heuristic:
* Section Name ascending (if present)
* Passed in sort descriptors
* Insertion order of the entity ascending

You can associate related values to your fetched entities.
It will automatically cache these associated values for the lifetime of that controller.
If a memory pressure event occurs, it will release its hold on those objects, allowing them to be de-inited.

The example app has an UserDefaults-backed storage mechanism.
The unit tests have in-memory objects, with NotificationCenter eventing.

Today, it is heavily dependent on the Obj-C runtime, as well as Key-Value Observation.
It should be possible to further remove those restrictions, and some effort has been made to remove them.

### SwiftUI

There are two SwiftUI Property Wrappers available for use, `FetchableRequest` and `SectionedFetchableRequest`. These are analagous to CoreData's property wrappers.

The controller will perform a fetch once and only once upon the first view render. After that point, it is dependent upon live update events.

Examples:

```swift
struct AllUsersView: View {
    @FetchableRequest(
        definition: FetchDefinition(request: User.fetchAll),
        sortDescriptors: [
            NSSortDescriptor(
                key: #keyPath(User.name),
                ascending: true,
                selector: #selector(NSString.localizedStandardCompare)
            ),
        ]
    )
    private var members: FetchableResults<User>

    // ...
}
```

For more complicated use cases, you probably will need to write initializers for your view, for example:

```swift
struct MembersView: View {
    private let fromID: EntityID

    @FetchableRequest
    private var members: FetchableResults<Membership>

    func init(fromID: EntityID) {
        self.fromID = fromID
        _members = FetchableRequest(
            definition: Membership.fetchDefinition(from: fromID, toEntityType: .user)
        )
    }

    // ...
}
```

## Requirements

- iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+
- Xcode 12+
- Swift 5+

When installing via SPM, we will use [Swift Collections](https://github.com/apple/swift-collections).
Otherwise we will use a [less efficient OrderedSet](https://github.com/square/FetchRequests/blob/main/FetchRequests/Sources/OrderedSetCompat.swift).

## Communication

- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## Installation

### CocoaPods

Install with [CocoaPods](http://cocoapods.org) by specifying the following in your `Podfile`:

```ruby
pod 'FetchRequests', '~> 4.0'
```

### Carthage

Install with [Carthage](https://github.com/Carthage/Carthage) by specify the following in your `Cartfile`:

```
github "square/FetchRequests" ~> 4.0
```

### Swift Package Manager

Install with [Swift Package Manager](https://swift.org/package-manager/) by adding it to the `dependencies` value of your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/square/FetchRequests.git", from: "4.0.0")
]
```

## Contributing

If you would like to contribute code to FetchRequests you can do so through GitHub by forking the repository and sending a pull request.

When submitting code, please make every effort to follow existing conventions and style in order to keep the code as readable as possible.

Before your code can be accepted into the project you must also sign the [Individual Contributor License Agreement (CLA)](https://spreadsheets.google.com/spreadsheet/viewform?formkey=dDViT2xzUHAwRkI3X3k5Z0lQM091OGc6MQ&ndplr=1).

### Code of Conduct

We expect contributors to adhere to the Square Open Source Code of Conduct. A copy of this document is available [here](https://developer.squareup.com/blog/open-source-code-of-conduct).

## License

FetchRequests is released under the MIT license.

```
MIT License

Copyright (c) 2019 Square Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```
