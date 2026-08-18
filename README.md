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
| `userDefaultsClient`      | A testable interface for `UserDefaults`, built using `UserDefaultsStoreProtocol`. Ideal for dependency injection and isolating persistent state in tests. **Your app must register a live store at launch (see below).** |
| `fileSystemClient`        | A robust file system interface supporting operations such as reading, writing, copying, moving, and deleting files or directories. Suitable for sandboxed storage and fully mockable for tests. |
| `fileSystemResourceClient`| A factory for creating typed file stores that conform to `FileSystemOperations`. Supports saving and loading `Codable` values and binary data into specific folders and subfolders, without exposing raw file system APIs. |
| `loggerClient` | An interface to os.Logger, auto-populated with the MainBundle bundle identifier (even if you're logging outside the main bundle). |

> **Note**  
> Many additional dependencies like `date`, `uuid`, and `calendar` are provided transitively via `swift-dependencies`.  
> See the [complete list of built-ins](https://github.com/pointfreeco/swift-dependencies/tree/main/Sources/Dependencies/DependencyValues).

---

## ⚙️ Registering the Live User Defaults Store

`userDefaultsClient` is the one client that does nothing useful until your app registers a live store. `UserDefaultsKey` conforms to `TestDependencyKey` only, and that is deliberate: the suite name is app-specific, so the package cannot supply a live value and still build in isolation.

Register the store once, as early in the app lifecycle as you can:

```swift
import Dependencies
import FoundationDependencies

@main
struct MyApp: App {

    init() {
        prepareDependencies {
            $0.userDefaultsClient = UserDefaultsLiveStore(suiteName: "group.com.example.myapp")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

This is the recommended route. It requires no conformance of your own, and it is the only step needed before `@Dependency(\.userDefaultsClient)` resolves to real storage anywhere in your app.

### What Happens If You Skip It

When a live context asks for a key that has no `DependencyKey` conformance, `swift-dependencies` falls back to that key's `testValue`. Here that fallback is `UserDefaultsTestStore`, which is an in-memory dictionary. Reads and writes still appear to succeed, so nothing looks broken, but nothing is persisted and everything is gone at the next launch.

A debug build reports the missing registration as a runtime warning. In a release build that report is compiled out, so the fallback is completely silent and the only symptom is that your users lose their data.

### Choosing a Suite Name

An app group identifier such as `group.com.example.myapp` is the intended form, and it is what lets an app extension read the same values.

Do not pass your app's own bundle identifier or `NSGlobalDomain`. Foundation rejects both, `UserDefaults(suiteName:)` returns `nil`, and because `UserDefaultsLiveStore` holds that result as an optional, every read then returns a default and every write is discarded with no error and no warning.

### Registering via `DependencyKey`

Conforming the key in your own module also works:

```swift
import Dependencies
import FoundationDependencies

extension UserDefaultsKey: @retroactive DependencyKey {

    public static let liveValue: any UserDefaultsStoreProtocol = UserDefaultsLiveStore(suiteName: "group.com.example.myapp")
}
```

Prefer `prepareDependencies`. A retroactive conformance is declared in your module but belongs to this package's type, so if `FoundationDependencies` ever declares `DependencyKey` itself, every consumer holding a copy of it hits a duplicate conformance and stops compiling.
