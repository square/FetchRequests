# FetchRequests

FetchRequests is an eventing library inspired by NSFetchedResultsController and written in Swift.

[![Build Status](https://img.shields.io/travis/crewos/FetchRequests.svg)](https://travis-ci.org/crewos/FetchRequests)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/FetchRequests.svg)](https://cocoapods.org/pods/FetchRequests)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/FetchRequests.svg?style=flat)](https://cocoapods.org/pods/FetchRequests)
[![Pod License](http://img.shields.io/cocoapods/l/FetchRequests.svg?style=flat)](https://opensource.org/licenses/MIT)
[![codecov](https://img.shields.io/codecov/c/github/crewos/FetchRequests.svg)](https://codecov.io/gh/crewos/FetchRequests)

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
- [x] Comprehensive Unit Test Coverage

## Usage

FetchRequests can be used for any combination of networking, database, and file queries.
It is best when backed by something like a [WebSocket](https://en.wikipedia.org/wiki/WebSocket) where you're expecting your data to live update.

To get started, you create a `CWFetchRequest` which explains your data access patterns.
The `CWFetchedResultsController` is the interface to access the your data.
It will automatically cache your associated values for the lifetime of that controller.
If a memory pressure event occurs, it will release its hold on those objects, allowing them to be deinited.

The example app has an UserDefaults-backed storage mechanism.
The unit tests have in-memory objects, with NotificationCenter eventing.

Today, it is heavily dependent on the Obj-C runtime, as well as Key-Value Observation.
With Swift 5.1 it should be possible to further remove those restrictions.

It currently relies upon a `[String: Any]` raw data representation.
Everything is in place to remove this restriction, but the swift compiler crashes if so.

## Requirements

- iOS 10+ / macOS 10.12+ / tvOS 10+ / watchOS 3+
- Xcode 10.2+
- Swift 5+

## Communication

- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## Installation

### CocoaPods

Install with [CocoaPods](http://cocoapods.org) by specifying the following in your `Podfile`:

```ruby
pod 'FetchRequests', '~> 1.0'
```

### Carthage

Install with [Carthage](https://github.com/Carthage/Carthage) by specify the following in your `Cartfile`:

```ogdl
github "crewos/FetchRequests" ~> 1.0
```

### Swift Package Manager

Install with [Swift Package Manager](https://swift.org/package-manager/) by adding it to the `dependencies` value of your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/crewos/FetchRequests.git", from: "1.0.0")
]
```

## License

FetchRequests is released under the MIT license. [See LICENSE](https://github.com/crewos/FetchRequests/blob/master/LICENSE) for details.
