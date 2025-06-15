# ``FoundationDependencies``

Provides clearly defined, testable abstractions for Foundation types — such as `UserDefaults` and `Bundle` — via lightweight clients compatible with Swift Concurrency.

## Overview

`FoundationDependencies` provides lightweight, testable wrappers around common system types such as `UserDefaults` and `Bundle`. It is built for seamless integration with [`swift-dependencies`](https://github.com/pointfreeco/swift-dependencies), and is designed to improve composability, testability, and safety — especially in Swift Concurrency contexts.

Each system client is exposed as a `@Dependency`-injected value, enabling clear, predictable behaviour across both production and test environments.

The package includes:

- Simple, protocol-backed wrappers for key Foundation types.
- Fully testable `.mock` and `.testValue` variants for each dependency.
- Native integration with [swift-dependencies](https://github.com/pointfreeco/swift-dependencies).
- Support for SwiftPM modules and SwiftUI applications.

## Topics

- <doc:IncludedClients>
- <doc:TestingAndOverrides>
- <doc:ScopingDependencies>
- <doc:MainBundleClient>
- <doc:FileSystemClient>
- <doc:FileSystemResourceClient>
- <doc:UserDefaultsClient>
