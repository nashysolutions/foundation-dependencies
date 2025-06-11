# ``FoundationDependencies``

Provides clearly defined, testable abstractions for Foundation types — such as `UserDefaults` and `Bundle` — via lightweight clients compatible with Swift Concurrency and [swift-dependencies](https://github.com/pointfreeco/swift-dependencies).

## Overview

`FoundationDependencies` is designed to make system dependencies — such as `UserDefaults` and `Bundle` — more testable, composable, and safer to use in Swift Concurrency contexts. It exposes clients as `@Dependency`-injected values, enabling predictable behaviour in both production and testing environments.

The package includes:

- Simple, protocol-backed wrappers for key Foundation types.
- Fully testable `.mock` and `.testValue` variants for each dependency.
- Native integration with [swift-dependencies](https://github.com/pointfreeco/swift-dependencies).
- Support for SwiftPM modules and SwiftUI applications.

## Topics

- <doc:IncludedClients>
- <doc:MainBundleClient>
- <doc:UserDefaultsClient>
- <doc:FileSystemClient>
- <doc:TestingAndOverrides>
- <doc:ScopingDependencies>
- <doc:BestPractices>
