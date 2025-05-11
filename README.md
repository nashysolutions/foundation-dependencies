# Foundation Dependencies

This package provides clearly defined, testable abstractions for select Foundation types — such as `UserDefaults` and `Bundle` — via lightweight clients designed for testability, SwiftUI compatibility, and integration with [swift-dependencies](https://github.com/pointfreeco/swift-dependencies).

> This package requires Swift 5.5 or later, and is tested with Swift 5.5 through 6.1.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Ffoundation-dependencies%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/nashysolutions/foundation-dependencies)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnashysolutions%2Ffoundation-dependencies%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/nashysolutions/foundation-dependencies)

---

## 🔧 Included Dependencies

This package currently provides two injectable clients:

- `mainBundleClient`: a wrapper around `Bundle` using a `BundleResourceProvider` abstraction  
- `userDefaultsClient`: a testable interface for `UserDefaults`, built on `UserDefaultsStoreProtocol`

> **Note**  
> Additional dependencies such as `date`, `uuid`, and `calendar` are available transitively via [swift-dependencies](https://github.com/pointfreeco/swift-dependencies).  
> See the [full list of built-ins](https://github.com/pointfreeco/swift-dependencies/tree/main/Sources/Dependencies/DependencyValues).
