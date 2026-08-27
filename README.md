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
| `userDefaultsClient`      | A testable interface for `UserDefaults`, built as a struct of closures with a method per endpoint. Every read is optional, so a key holding nothing is distinguishable from a key holding `false` or `0`. Ideal for dependency injection and isolating persistent state in tests. **Your app must register a live store at launch (see below).** |
| `fileSystemClient`        | A robust file system interface supporting operations such as reading, writing, copying, moving, and deleting files or directories. Suitable for sandboxed storage and fully mockable for tests. |
| `fileSystemResourceClient`| A factory for creating typed file stores that conform to `FileSystemOperations`. Supports saving and loading `Codable` values and binary data into specific folders and subfolders, without exposing raw file system APIs. |
| `loggerClient` | An interface to os.Logger, auto-populated with the MainBundle bundle identifier (even if you're logging outside the main bundle). |

> **Note**  
> Many additional dependencies like `date`, `uuid`, and `calendar` are provided transitively via `swift-dependencies`.  
> See the [complete list of built-ins](https://github.com/pointfreeco/swift-dependencies/tree/main/Sources/Dependencies/DependencyValues).

---

## ⚙️ Registering the Live User Defaults Store

`userDefaultsClient` is the one client that does nothing useful until your app registers a live store. `UserDefaultsClient` conforms to `TestDependencyKey` only, and that is deliberate: the suite name is app-specific, so the package cannot supply a live value and still build in isolation.

Register the store once, as early in the app lifecycle as you can:

```swift
import Dependencies
import FoundationDependencies
import SwiftUI

@main
struct MyApp: App {

    init() {
        guard let store = UserDefaultsLiveStore(suiteName: "group.com.example.myapp") else {
            preconditionFailure("group.com.example.myapp is not a usable suite name")
        }

        prepareDependencies {
            $0.userDefaultsClient = UserDefaultsClient(store)
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

When a live context asks for a key that has no `DependencyKey` conformance, `swift-dependencies` falls back to that key's `testValue`. Here that fallback is a client over `UserDefaultsTestStore`, which is an in-memory dictionary. Reads and writes still appear to succeed, so nothing looks broken, but nothing is persisted and everything is gone at the next launch.

A debug build reports the missing registration as a runtime warning. In a release build that report is compiled out, so the fallback is completely silent and the only symptom is that your users lose their data.

### Choosing a Suite Name

An app group identifier such as `group.com.example.myapp` is the intended form, and it is what lets an app extension read the same values.

Do not pass your app's own bundle identifier or `NSGlobalDomain`. Foundation refuses both, so `UserDefaultsLiveStore(suiteName:)` returns `nil` and no store is produced at all. That is why the example above handles the optional rather than assigning it straight through, and why it fails loudly when it is `nil`. A suite name is a compile-time constant, so a `nil` result is a mistake in the name itself and will be `nil` on every launch on every device. Substituting a fallback store would hide it and move the symptom to wherever the values are later read.

No supported suite name reaches the app's own defaults. When the values are not shared with another process, register `UserDefaultsClient(.standard)` instead, which reads and writes those domains and is not failable.

### Registering via `DependencyKey`

`UserDefaultsClient` is its own dependency key, so conforming it in your own module also works:

```swift
import Dependencies
import FoundationDependencies

extension UserDefaultsClient: @retroactive DependencyKey {

    public static let liveValue = UserDefaultsClient(.standard)
}
```

Prefer `prepareDependencies`. A stored property has nowhere sensible to handle a failable initialiser, so this route is awkward for anything but `standard`. A retroactive conformance is also declared in your module while belonging to this package's type, so if `FoundationDependencies` ever declares `DependencyKey` itself, every consumer holding a copy of it hits a duplicate conformance and stops compiling.

---

## 📖 Reading and Writing Values

Every reader returns an optional, and `??` is where a default lives:

```swift
@Dependency(\.userDefaultsClient) var userDefaults

let launches = userDefaults.int(forKey: "launches") ?? 0
userDefaults.setInt(launches + 1, forKey: "launches")

if userDefaults.bool(forKey: "hasOnboarded") == nil {
    userDefaults.setBool(false, forKey: "hasOnboarded")
}
```

`nil` from `bool`, `int` or `double` means the key holds nothing, and nothing else. A key holding a value always has a reading through those three, because `UserDefaults` coerces rather than refusing, so a stored `Date` still reads as `false` and `0` exactly as it does in production. The other readers return `nil` for a key that holds nothing *and* for a key whose value has no reading of that type — a stored `Date` has no `string` reading — and `contains(key:)` is what separates those two cases.

| Endpoint | Reads |
|---|---|
| `bool` / `int` / `double` | The coerced value, or `nil` when the key holds nothing |
| `string` / `stringArray` / `date` / `data` | The value, or `nil` when there is no reading of that type |
| `url` | The stored text parsed as a URL, or `nil` unless it has a scheme |
| `contains(key:)` | Whether the key holds anything at all |
| `decode(_:forKey:)` | A `Codable` value from stored JSON, throwing when the data does not decode |

Writing mirrors the readers: `setBool`, `setInt`, `setDouble`, `setString`, `setStringArray`, `setDate`, `setData`, `setURL`, `encode(_:forKey:)`, and `setPropertyList` for a mixed array or a nested dictionary. Every setter that takes an optional removes the key when handed `nil`, as does `removeValue(forKey:)`.

See <doc:UserDefaultsClient> for the `Codable` and property list paths in full, and for what a URL is stored as and why it is not what `UserDefaults.url(forKey:)` reads.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) before running the test suite locally. It records a toolchain requirement that applies to running the tests and not to using this package, along with the unhelpful errors you get when it is unmet.
