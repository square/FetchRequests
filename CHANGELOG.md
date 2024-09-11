# Change Log
All notable changes to this project will be documented in this file.
`FetchRequests` adheres to [Semantic Versioning](https://semver.org/).

## [7.0](https://github.com/square/FetchRequests/releases/tag/7.0.0)
Release 2024-09-XX

* Compiles cleanly in the Swift 6 language mode
* Requires the Swift 6 compiler
* `JSON` has been removed from the library as it is no longer necessary

## [6.1](https://github.com/square/FetchRequests/releases/tag/6.1.0)
Release 2024-04-03

* Add async overloads for `performFetch() and `resort(using:)`
* Add completion closure to `performPagination()`, with a boolean value indicating if values were returned or not
* Add async overload to `performPagination()`

## [6.0.3](https://github.com/square/FetchRequests/releases/tag/6.0.3)
Released on 2024-03-06

* Cleanup warnings in Xcode 15.3

## [6.0.2](https://github.com/square/FetchRequests/releases/tag/6.0.2)
Released on 2023-09-21

* Cleanup warnings in Xcode 15

## [6.0.1](https://github.com/square/FetchRequests/releases/tag/6.0.1)
Released on 2023-06-23

* The demo now includes a SwiftUI example
* Fix for SwiftUI when a FetchDefinition request is synchronous

## [6.0](https://github.com/square/FetchRequests/releases/tag/6.0.0)
Released on 2023-04-05

* Requires Swift 5.8
* FetchableEntityID's async methods are now marked as @MainActor
* Association Request completion handlers are now marked as @MainActor
    * Previously the handler would immediately bounce to the main thread if needed
* Bump deployment targets:
    * iOS, tvOS, Catalyst: v14
    * watchOS v7
    * macOS v11

## [5.0](https://github.com/square/FetchRequests/releases/tag/5.0.0)
Released on 2022-10-25

* Requires Swift 5.7
* Protocols define their primary associated types
* JSON literal arrays and dictionaries now must be strongly typed via the `JSONConvertible` protocol
* Annotate many methods as @MainActor
    * All delegate methods
    * All code with assert(Thread.isMainThread)
* Faulting an association when you're off the main thread will have different characteristics
    * If the association already exists, nothing will change
    * If the association does not already exist, it will always return nil and hit the main thread to batch fetch the associations
* More eventing supports occurring off of the main thread
    * If needed, it will async bounce to the main thread to actually perform the change
    * Newly allowed Events:
        * Associated Value creation events
        * Entity creation events
        * Data reset events
    * Note any changes to your model still must occur on the main thread
        * data
        * isDeleted
        * NSSortDescriptor keyPaths
        * Association keyPaths

## [4.0.4](https://github.com/square/FetchRequests/releases/tag/4.0.4)
Released on 2022-08-30

* Reduce some cases of no-op eventing

## [4.0.3](https://github.com/square/FetchRequests/releases/tag/4.0.3)
Released on 2022-05-09

* Support array associations by an arbitrary reference instead of just by ID. This is specified via a new referenceAccessor parameter.
* Updated example to use Codable model
* Updated linting

## [4.0.2](https://github.com/square/FetchRequests/releases/tag/4.0.2)
Released on 2021-12-14

* Expose `hasFetchedObjects` on FetchableRequest and SectionedFetchableRequest. It has the same semantics as the property on the Controller.

## [4.0.1](https://github.com/square/FetchRequests/releases/tag/4.0.1)
Released on 2021-10-20

* Respect insertion order for pagination / live updates

## [4.0.0](https://github.com/square/FetchRequests/releases/tag/4.0.0)
Released on 2021-09-14

* Updated minimum SDKs to iOS 13 and related OSes
* Added a Swift 5.5 package definition
* Renamed `FetchRequest` to `FetchDefinition` to avoid SwiftUI naming collisions
* Removed `FRIdentifiable` in deference to `Identifiable`
* Added `Identifiable` conformance to FetchedResultsSection
* Removed simplediff in deference to `BidirectionalCollection.difference(from:)`
* Added `objectWillChange` and `objectDidChange` Publishers to all Controllers
    * Removed the Wrapper controller as it is duplicative with `objectDidChange`
* Objects are no longer sorted by `id`
    * The `ID` does not need to be comparable
    * Stable sorting is maintained by respecting the insertion order of objects

## [3.2.0](https://github.com/square/FetchRequests/releases/tag/3.2.0)
Released on 2021-06-21

* Added FetchableRequest SwiftUI Property Wrapper and friends

## [3.1.1](https://github.com/square/FetchRequests/releases/tag/3.1.1)
Released on 2021-05-19

* Fix warnings related to deprecation of using `class` in protocol definitions

## [3.1](https://github.com/square/FetchRequests/releases/tag/3.1)
Released on 2021-01-15

* Add `func resort(using newSortDescriptors: [NSSortDescriptor])`

## [3.0.2](https://github.com/square/FetchRequests/releases/tag/3.0.2)
Released on 2020-11-19

* Expose test target in Swift Package Manager
* Fix thread safety bug with insertion

## [3.0.1](https://github.com/square/FetchRequests/releases/tag/3.0.1)
Released on 2020-10-26

* Tweaked logging format

## [3.0](https://github.com/square/FetchRequests/releases/tag/3.0)
Released on 2020-09-15

* Renamed Identifiable to FRIdentifiable to avoid naming collisions with Swift.Identifiable
* Changed to require Xcode 12, and increased the minimum OS by 2, so iOS 14, tvOS 14, macOS 10.14, & watchOS 5
* RawDataRepresentable.RawData is now an associatedtype as the tests execute cleanly in Xcode 12
* Note: The JSON type is still being vended by this framework

## [2.2.1](https://github.com/square/FetchRequests/releases/tag/2.2.1)
Released on 2020-09-02

* Made Sequence.sorted(by comparator: Comparator) private

## [2.2](https://github.com/square/FetchRequests/releases/tag/2.2)
Released on 2019-12-05

* BoxedJSON.init(__object: NSObject?) for Obj-C uses

## [2.1](https://github.com/square/FetchRequests/releases/tag/2.1)
Released on 2019-12-02

* Support NS(Secure)Coding in BoxedJSON

## [2.0](https://github.com/square/FetchRequests/releases/tag/2.0)
Released on 2019-11-15

* Change `objectID` to `id`
* Remove a bunch of KVO requirements and weird conformance rules
* Remove the CW prefix from everything
* Change the `RawData` type from `[String: Any]` to `JSON`
    * `JSON` is an equatable struct
    * It supports dynamic member lookup
    * It does lazy initialization and lookup, so it's very cheap
    * It is bridgeable to Obj-C, so you can still use KVO with it

Sadly, we still cannot make `data` an `associatedtype`. Something about it breaks the runtime.

## [1.0.2](https://github.com/square/FetchRequests/releases/tag/1.0.2)
Released on 2019-08-01.

* CWObservableNotificationCenterToken will automatically invalidate itself on deinit
* Added SwiftLint validation

## [1.0.1](https://github.com/square/FetchRequests/releases/tag/1.0.1)
Released on 2019-07-02.

* Adds an example app

## [1.0.0](https://github.com/square/FetchRequests/releases/tag/1.0.0)
Released on 2019-07-01.

#### Added
- Initial release of FetchRequests
