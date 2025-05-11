# Included Clients

This package provides two injectable dependencies:

## `mainBundleClient`

A wrapper around `Bundle` that uses a `BundleResourceProvider` abstraction to allow safe access to resource URLs, bundle metadata, and versioning info.

## `userDefaultsClient`

A testable interface to `UserDefaults`, using `UserDefaultsStoreProtocol` to support injection and mocking.

## Additional Built-ins

Types like `date`, `calendar`, and `uuid` are available transitively via `swift-dependencies`.  
See: [Built-in Dependency Values](https://github.com/pointfreeco/swift-dependencies/tree/main/Sources/Dependencies/DependencyValues)
