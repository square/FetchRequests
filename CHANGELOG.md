# Change Log
All notable changes to this project will be documented in this file.
`FetchRequests` adheres to [Semantic Versioning](https://semver.org/).

## [2.2](https://github.com/crewos/FetchRequests/releases/tag/2.2)
Released on 2019-12-05

* BoxedJSON.init(__object: NSObject?) for Obj-C uses

## [2.1](https://github.com/crewos/FetchRequests/releases/tag/2.1)
Released on 2019-12-02

* Support NS(Secure)Coding in BoxedJSON

## [2.0](https://github.com/crewos/FetchRequests/releases/tag/2.0)
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

## [1.0.2](https://github.com/crewos/FetchRequests/releases/tag/1.0.2)
Released on 2019-08-01.

* CWObservableNotificationCenterToken will automatically invalidate itself on deinit
* Added SwiftLint validation

## [1.0.1](https://github.com/crewos/FetchRequests/releases/tag/1.0.1)
Released on 2019-07-02.

* Adds an example app

## [1.0.0](https://github.com/crewos/FetchRequests/releases/tag/1.0.0)
Released on 2019-07-01.

#### Added
- Initial release of FetchRequests
