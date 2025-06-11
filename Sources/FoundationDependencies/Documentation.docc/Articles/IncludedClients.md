# Included Clients

This package provides two injectable dependencies:

## `mainBundleClient`

A wrapper around `Bundle` that uses a `BundleResourceProvider` abstraction to allow safe access to resource URLs, bundle metadata, and versioning info.

## `userDefaultsClient`

A testable interface to `UserDefaults`, using `UserDefaultsStoreProtocol` to support injection and mocking.

## `fileSystemClient`

A protocol-oriented, testable interface to the file system designed to support modular and dependency-injected file operations. It abstracts common file and directory operations, such as reading, writing, and deleting files, while allowing the actual implementation (real or mocked) to be injected at runtime.

## Additional Built-ins

Types like `date`, `calendar`, and `uuid` are available transitively via `swift-dependencies`.  
See: [Built-in Dependency Values](https://github.com/pointfreeco/swift-dependencies/tree/main/Sources/Dependencies/DependencyValues)
