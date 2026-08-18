# Using `userDefaultsClient`

Use this dependency to access `UserDefaults` in a safe, testable way within Swift Concurrency contexts.

## Overview

```swift
@Dependency(\.userDefaultsClient) var userDefaults

userDefaults.setString("Hello", "welcomeKey")
let value = userDefaults.string("welcomeKey") ?? "Default"
```

The `UserDefaultsClient` provides typed access to user defaults using dependency injection, allowing your app to remain testable and concurrency-safe.

Until your app registers a live store, that code resolves to `UserDefaultsTestStore` and nothing it writes is persisted. Registering one is the first thing to do.

## Registering a Live Store

`UserDefaultsKey` conforms to `TestDependencyKey` only. That is deliberate: which defaults a store should read is app-specific, so the package cannot choose for you and still build in isolation. Nothing else in this package needs the step, so it is easy to miss.

Register a store once, as early in the app lifecycle as you can.

### The App's Own Defaults

`UserDefaultsLiveStore.standard` reads and writes the same domains as `UserDefaults.standard`. Use it whenever the values are not shared with another process.

```swift
import Dependencies
import FoundationDependencies

@main
struct MyApp: App {

    init() {
        prepareDependencies {
            $0.userDefaultsClient = UserDefaultsLiveStore.standard
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### A Shared App Group Container

`UserDefaultsLiveStore(suiteName:)` reads and writes a named suite, typically an app group container shared with an app extension or a sibling app. It is failable, because Foundation refuses some names outright.

```swift
import Dependencies
import FoundationDependencies

@main
struct MyApp: App {

    init() {
        guard let store = UserDefaultsLiveStore(suiteName: "group.com.example.myapp") else {
            preconditionFailure("group.com.example.myapp is not a usable suite name")
        }

        prepareDependencies {
            $0.userDefaultsClient = store
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Failing loudly is the right response here. A suite name is a compile-time constant, so a `nil` result is a mistake in the name itself and will be `nil` on every launch on every device. Substituting a fallback store would hide it and move the symptom to wherever the values are later read.

### Choosing a Suite Name

Use an app group identifier, in the style of `group.com.example.myapp`. That is the form which lets an app extension read the same values.

Two names are refused. Foundation rejects the current app's own bundle identifier, and it rejects `NSGlobalDomain`. Neither can be recovered from, so the initialiser returns `nil` rather than handing back a store whose every read is empty and every write is discarded. There is no suite name that reaches the app's own defaults, which is what `UserDefaultsLiveStore.standard` is for.

A name Foundation accepts is not necessarily the container you meant. A mistyped app group identifier, or one the app holds no entitlement for, still produces a working store, but it is backed by a private domain rather than the shared container. Nothing at this layer can tell the two apart, so check the spelling against the app's App Groups entitlement.

### Conforming the Key Instead

Conforming the key in your own module also works:

```swift
extension UserDefaultsKey: @retroactive DependencyKey {

    public static let liveValue: any UserDefaultsStoreProtocol = UserDefaultsLiveStore.standard
}
```

Prefer `prepareDependencies`. A stored property has nowhere sensible to handle a failable initialiser, so this route is awkward for anything but `standard`. A retroactive conformance is also declared in your module while belonging to this package's type, so if `FoundationDependencies` ever declares `DependencyKey` itself, every consumer holding a copy of it hits a duplicate conformance and stops compiling.

## Testing

The default value for this dependency is already `UserDefaultsTestStore`, an in-memory store that touches no real suite, so a test that simply reads and writes needs no override at all.

To start from known state, create a store, seed it, and inject it:

```swift
let store = UserDefaultsTestStore()
store.setBool(true, "hasSeenOnboarding")

withDependencies {
    $0.userDefaultsClient = store
} operation: {
    MyService()
}
```

Create one store per test. Nothing survives the process, but a store shared between tests carries values from one into the next.

### Fidelity to Live `UserDefaults`

The test store is not a plain dictionary wrapper. `UserDefaults` coerces between types on read rather than returning a default when the stored type differs from the requested one, and the typed readers reproduce those coercions. A value stored through `setString` as `"42"` reads back through `int` as `42`, and `"YES"` reads back through `bool` as `true`, exactly as they would in production.

Writes are validated the same way. `UserDefaults` raises `NSInvalidArgumentException` when asked to store anything that is not a property list value, so `setObject` traps on the same input rather than accepting it. Note this rejects `URL`, which production also rejects through this endpoint.

One divergence is worth knowing. `object` returns the value as it was written, whereas live `UserDefaults` returns the Foundation counterpart it normalised the value into. A value stored through `setInt` reads back from `object` as an `Int` here and as an `NSNumber` in production, so `object(key) as? Bool` finds a `Bool` in production for a stored `1` and finds nothing here. The typed readers are unaffected and are the endpoints a test should prefer.

### Stubbing Individual Endpoints

There is no shorthand for replacing a single endpoint. `UserDefaultsStoreProtocol` exposes its operations as read-only properties, so an existing store cannot have one of them swapped out, and building a `UserDefaultsClient` means supplying all fifteen closures.

Prefer `UserDefaultsTestStore` and seed it with the values the test needs. Reach for a hand-built `UserDefaultsClient` only when a test needs behaviour a real store cannot produce, such as recording which keys were written.
