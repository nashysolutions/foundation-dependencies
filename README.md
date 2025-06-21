# Foundation Dependencies

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Ffoundation-dependencies%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/nashysolutions/foundation-dependencies)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Ffoundation-dependencies%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/nashysolutions/foundation-dependencies)

A modular, testable collection of lightweight wrappers for common Foundation types, designed for seamless use with [`swift-dependencies`](https://github.com/pointfreeco/swift-dependencies). This package makes it easy to mock, inject, and override behaviours like `UserDefaults`, `Bundle`, and file system operations in both production and test environments.

---

## 📦 Installation

Add this package via Swift Package Manager:

```swift
.product(name: "FoundationDependencies", package: "foundation-dependencies")
```

---

## 📚 Documentation & API Reference

Comprehensive documentation is available via Swift Package Index:

➡️ [Browse Documentation on Swift Package Index](https://swiftpackageindex.com/nashysolutions/foundation-dependencies/documentation)

---

## 🔧 Included Clients

| Client                     | Description |
|---------------------------|-------------|
| `mainBundleClient`        | A wrapper around `Bundle`, exposing APIs for loading resources via a `BundleResourceProvider` abstraction. |
| `userDefaultsClient`      | A testable interface for `UserDefaults`, built using `UserDefaultsStoreProtocol`. Ideal for dependency injection and isolating persistent state in tests. |
| `fileSystemClient`        | A robust file system interface supporting operations such as reading, writing, copying, moving, and deleting files or directories. Suitable for sandboxed storage and fully mockable for tests. |
| `fileSystemResourceClient`| A factory for creating typed file stores that conform to `FileSystemOperations`. Supports saving and loading `Codable` values and binary data into specific folders and subfolders, without exposing raw file system APIs. |
| `loggerClient` | An interface to os.Logger, auto-populated with the MainBundle bundle identifier (even if you're logging outside the main bundle). |

> **Note**  
> Many additional dependencies like `date`, `uuid`, and `calendar` are provided transitively via `swift-dependencies`.  
> See the [complete list of built-ins](https://github.com/pointfreeco/swift-dependencies/tree/main/Sources/Dependencies/DependencyValues).
