# Using `userDefaultsClient`

Use this dependency to access `UserDefaults` in a safe, testable way within Swift Concurrency contexts.

## Overview

```swift
@Dependency(\.userDefaultsClient) var userDefaults

userDefaults.setString("Hello", forKey: "welcomeKey")
let value = userDefaults.string(forKey: "welcomeKey") ?? "Default"
```

`UserDefaultsClient` provides typed access to user defaults using dependency injection, allowing your app to remain testable and concurrency-safe.

It is the whole interface: a struct of closures, one per operation, with a method for each carrying argument labels. There is no protocol to conform to. Call the methods, and replace the closures when a test needs different behaviour.

Until your app registers a live store, that code resolves to an in-memory store and nothing it writes is persisted. Registering one is the first thing to do.

## Where You Can Call It From

Anywhere. Every endpoint is a nonisolated `@Sendable` closure and none of them is `async`, so a read returns its value in whichever domain asked for it: a background task, a widget extension reaching a shared app group suite, or the main actor. Nothing hops, and a client can be handed across a domain boundary because `UserDefaultsClient` is `Sendable`.

Each store says for itself how it stays safe under that. `UserDefaultsLiveStore` holds one `UserDefaults` instance, which Apple documents as thread-safe, and `UserDefaultsTestStore` keeps its dictionary behind a lock. A client you assemble from closures of your own inherits neither guarantee: nothing serialises the closures you supply, so anything mutable they capture needs a lock of its own. See <doc:FileSystemClient> for that shape written out.

## Registering a Live Store

`UserDefaultsClient` conforms to `TestDependencyKey` only. That is deliberate: which defaults a store should read is app-specific, so the package cannot choose for you and still build in isolation. Nothing else in this package needs the step, so it is easy to miss.

Register a client once, as early in the app lifecycle as you can.

### The App's Own Defaults

`UserDefaultsLiveStore.standard` reads and writes the same domains as `UserDefaults.standard`. Use it whenever the values are not shared with another process.

```swift
import Dependencies
import FoundationDependencies
import SwiftUI

@main
struct MyApp: App {

    init() {
        prepareDependencies {
            $0.userDefaultsClient = UserDefaultsClient(.standard)
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

Failing loudly is the right response here. A suite name is a compile-time constant, so a `nil` result is a mistake in the name itself and will be `nil` on every launch on every device. Substituting a fallback store would hide it and move the symptom to wherever the values are later read.

### Choosing a Suite Name

Use an app group identifier, in the style of `group.com.example.myapp`. That is the form which lets an app extension read the same values.

Two names are refused. Foundation rejects the current app's own bundle identifier, and it rejects `NSGlobalDomain`. Neither can be recovered from, so the initialiser returns `nil` rather than handing back a store whose every read is empty and every write is discarded. No supported suite name reaches the app's own defaults, which is what `UserDefaultsLiveStore.standard` is for.

A name Foundation accepts is not necessarily the container you meant. A mistyped app group identifier, or one the app holds no entitlement for, still produces a working store, but it is backed by a private domain rather than the shared container. Nothing at this layer can tell the two apart, so check the spelling against the app's App Groups entitlement.

### Conforming the Key Instead

`UserDefaultsClient` is its own dependency key, so conforming it in your own module also works:

```swift
extension UserDefaultsClient: @retroactive DependencyKey {

    public static let liveValue = UserDefaultsClient(.standard)
}
```

Prefer `prepareDependencies`. A stored property has nowhere sensible to handle a failable initialiser, so this route is awkward for anything but `standard`. A retroactive conformance is also declared in your module while belonging to this package's type, so if `FoundationDependencies` ever declares `DependencyKey` itself, every consumer holding a copy of it hits a duplicate conformance and stops compiling.

## Testing

The default value for this dependency is a client over `UserDefaultsTestStore`, an in-memory store that touches no real suite, so nothing has to be registered before a test can run.

Each test gets its own. `UserDefaultsClient.testValue` is computed rather than stored, and `swift-dependencies` caches what it resolves against the running test, so two tests leaning on the default hold two different stores while repeated resolutions inside one test hold the same one. A value written by one test is not there for the next one to read.

Two places that isolation does not reach:

- The argument rows of a parameterised `@Test` share one test identity, so they share one store, and the order they run in is not promised.
- Code inside a detached task is outside the running test as far as the cache is concerned, so it resolves a store of its own rather than the one the test body is holding.

Inject your own store whenever a test needs seeded values, and whenever either of those applies:

```swift
let store = UserDefaultsTestStore()
store.setBool(true, forKey: "hasSeenOnboarding")

withDependencies {
    $0.userDefaultsClient = UserDefaultsClient(store)
} operation: {
    MyService()
}
```

Nothing survives the process.

### Fidelity to Live `UserDefaults`

The test store is not a plain dictionary wrapper. `UserDefaults` coerces between types on read rather than returning a default when the stored type differs from the requested one, and the typed readers reproduce those coercions. A value stored through `setString` as `"42"` reads back through `int` as `42`, and `"YES"` reads back through `bool` as `true`, exactly as they would in production.

Writes are validated the same way. `UserDefaults` raises `NSInvalidArgumentException` when asked to store anything that is not a property list value, so `setObject` traps on the same input rather than accepting it. Note this rejects `URL`, which production also rejects through this endpoint.

One divergence is worth knowing. `object` returns the value as it was written, whereas live `UserDefaults` returns the Foundation counterpart it normalised the value into. A value stored through `setInt` reads back from `object` as an `Int` here and as an `NSNumber` in production, so `object(forKey:) as? Bool` finds a `Bool` in production for a stored `1` and finds nothing here. The typed readers are unaffected and are the endpoints a test should prefer.

### Stubbing Individual Endpoints

Every endpoint is a `var`, so a single one can be replaced without restating the other fourteen:

```swift
withDependencies {
    $0.userDefaultsClient = UserDefaultsClient(UserDefaultsTestStore())
    $0.userDefaultsClient.bool = { _ in true }
} operation: {
    MyService()
}
```

Assign to the closure, and call the method. The two are the same endpoint; the method exists so that call sites read `setBool(true, forKey: "key")` rather than `setBool(true, "key")`.

Seeding a `UserDefaultsTestStore` is still the better move when the test only needs values in place. Reach for a replaced endpoint when a test needs behaviour a real store cannot produce, such as recording which keys were written, or a read that fails.

### The Unimplemented Client

`UserDefaultsClient()` builds a client whose every endpoint reports a test failure when it is called:

```swift
withDependencies {
    $0.userDefaultsClient = UserDefaultsClient()
    $0.userDefaultsClient.bool = { _ in true }
} operation: {
    MyService()
}
```

That test now fails if the code under test touches any endpoint other than `bool`, which is what to reach for when the point of the test is which storage calls are made. It is the opposite default from `testValue`, which is a working store precisely so that a test using storage incidentally does not have to say so.
