# Included Clients

This package provides multiple injectable dependencies:

## `mainBundleClient`

A wrapper around `Bundle` that uses a `BundleResourceProvider` abstraction to allow safe access to resource URLs, bundle metadata, and versioning info.

## `userDefaultsClient`

A testable interface to `UserDefaults`, using `UserDefaultsStoreProtocol` to support injection and mocking.

## `fileSystemClient`

A protocol-oriented, testable interface to the file system, designed to support modular and dependency-injected file operations.  
It abstracts common file and directory operations such as reading, writing, copying, and deleting files, while allowing the actual implementation (real or mocked) to be injected at runtime.

## `fileSystemResourceClient`

A factory for creating typed file stores that conform to `FileSystemOperations`.  
It supports saving and loading `Codable` values and binary data into specific folders and subfolders, without exposing raw file system APIs. This design separates store construction from file handling logic, improving modularity and testability.

---

## Additional Built-ins

Types like `date`, `calendar`, and `uuid` are available transitively via `swift-dependencies`.  
See: [Built-in Dependency Values](https://github.com/pointfreeco/swift-dependencies/tree/main/Sources/Dependencies/DependencyValues)
