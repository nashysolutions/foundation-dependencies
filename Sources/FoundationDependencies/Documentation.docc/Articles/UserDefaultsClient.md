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

## What `nil` Means

Every reader returns an optional, and `??` is where a default lives. There is no defaulted variant of any endpoint, because that is what `??` already is.

`bool`, `int` and `double` return `nil` **only** when the key holds nothing:

```swift
@Dependency(\.userDefaultsClient) var userDefaults

let launches = userDefaults.int(forKey: "launches") ?? 0
userDefaults.setInt(launches + 1, forKey: "launches")

if userDefaults.bool(forKey: "hasOnboarded") == nil {
    // Nothing has been written under this key yet. A stored `false` is a
    // different situation, and reads back as `false`.
    userDefaults.setBool(false, forKey: "hasOnboarded")
}
```

A key holding a value always has a reading through those three, because `UserDefaults` coerces rather than refusing. A stored `Date` reads as `false` and `0`, a stored `"42"` reads as `42`, and a stored `"YES"` reads as `true`, exactly as they do in production. What changed is only that absence is no longer spelled the same way as a stored `false` or a stored zero, which is what the earlier non-optional readers did and what nothing at the call site could see through.

The remaining readers return `nil` for a key that holds nothing *and* for a key whose value has no reading of that type, which is again what production does: a stored `Date` has no `string` reading. `contains(key:)` is what separates those two cases, and is the only endpoint that answers presence whatever the stored type.

```swift
@Dependency(\.userDefaultsClient) var userDefaults

userDefaults.setDate(.now, forKey: "installedAt")

// A `Date` has no string reading, so `string` is `nil` for a key that does hold
// a value. `contains` is what tells that apart from a key holding nothing.
if userDefaults.string(forKey: "installedAt") == nil,
   userDefaults.contains(key: "installedAt") {
    print("There is a value here, but not one that reads as text.")
}
```

## `Codable` Values

`encode(_:forKey:)` and `decode(_:forKey:)` store a value as JSON. They are the way to keep anything above a raw scalar, and are methods rather than endpoints because an endpoint is a stored closure and a stored closure cannot be generic.

```swift
struct Preferences: Codable {

    var theme: String
    var launches: Int
}

@Dependency(\.userDefaultsClient) var userDefaults

try userDefaults.encode(Preferences(theme: "dark", launches: 0), forKey: "preferences")
let stored = try userDefaults.decode(Preferences.self, forKey: "preferences")
```

The two failure modes are deliberately different. A key that holds nothing, or holds something that is not data, returns `nil`: not having stored a value yet is ordinary, and every other reader answers it the same way. Data that is present but does not decode throws, because that is a value written by an earlier version of the app or by something else entirely, and swallowing it would turn a migration defect into a silent reset.

Both sides go through `data` and `setData`, so a test that replaces those two endpoints has replaced the `Codable` path with them, and a test that seeds a store with JSON has seeded it. There is no third thing to stub. Writing `nil` removes the key, as it does through every other setter that accepts one.

## URLs

`setURL` stores a URL as its `absoluteString`, and `url` reads that text back, returning `nil` unless it parses as a URL with a scheme. A stored URL is therefore also readable through `string`, and any stored string that is an absolute URL is readable through `url`.

That is deliberately not what `UserDefaults.url(forKey:)` does, and the difference is worth knowing if values are shared with an Objective-C component. Measured against a real suite: `UserDefaults.set(_:forKey:)` writes a **file** URL as a bare path and every **other** URL as 263 bytes of `NSKeyedArchiver` output, so its two kinds of URL are two unrelated formats, neither legible in the `plist`. Its reader is worse: `url(forKey:)` interprets any stored string as a file path relative to the process's working directory, so a key holding `"hello"` reads back as `file:///…/hello` rather than as `nil`. A reader whose failure mode is a plausible wrong answer is not one this package wants to hand a caller.

The cost is that a URL written by `UserDefaults` itself does not read back through `url` here. There is no representation that interoperates with both of Foundation's, because they are not the same as each other.

## Values With No Typed Setter

`setPropertyList` is the way in for a mixed array or a nested dictionary — a shape none of the typed setters describes. It takes a ``PropertyListValue``, which is built from literals, so the call site usually looks the way it would have with `Any`:

```swift
@Dependency(\.userDefaultsClient) var userDefaults

userDefaults.setPropertyList(["launches": 3, "seen": true], forKey: "state")
userDefaults.setPropertyList(["light", "dark"], forKey: "themes")
```

It replaces an endpoint that took `Any?`. `UserDefaults` raises `NSInvalidArgumentException` when handed a value a property list cannot hold, and that is a crash no call site can catch and no `Any?` signature warns about — `URL` was the value most likely to reach it by accident, because `UserDefaults` does have a dedicated overload that accepts one and that overload is not this endpoint. `PropertyListValue` has no case for anything a property list cannot hold, so there is now no way to write the argument.

There is no matching reader. The typed readers cover what a caller wants a value *as*, and `contains(key:)` covers whether there is one at all, which between them is what the retired `object` endpoint was used for.

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

Writes need no validation. Every setter takes a type `UserDefaults` can hold, and the one that accepts a heterogeneous value takes a `PropertyListValue`, which has no case for anything else. An earlier `setObject` took `Any?` and had to check its argument and trap; the check went when the type made the input unrepresentable.

There is no longer a divergence to know about. The endpoint that had one was `object`, which returned the value as written here and the Foundation counterpart production had normalised it into, so a stored `1` was an `Int` here and an `NSNumber` there and `object(forKey:) as? Bool` found one in production and nothing here. It is retired: `contains(key:)` answers the only question it was reliably good for, and the typed readers answer the rest.

Every case in this package's contract suite runs against both stores, so the fidelity above is a checked fact rather than a claim in this article. A divergence fails on the day it appears.

### Stubbing Individual Endpoints

Every endpoint is a `var`, so a single one can be replaced without restating the other eighteen:

```swift
withDependencies {
    $0.userDefaultsClient = UserDefaultsClient(UserDefaultsTestStore())
    $0.userDefaultsClient.bool = { _ in true }
} operation: {
    MyService()
}
```

Assign to the closure, and call the method. The two are the same endpoint; the method exists so that call sites read `setBool(true, forKey: "key")` rather than `setBool(true, "key")`.

Replacing `data` and `setData` replaces the `Codable` path along with them, since `encode(_:forKey:)` and `decode(_:forKey:)` are written over those two endpoints and nothing else.

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

The `Codable` methods are covered by it too, for the same reason they are covered by a stub: they call `data` and `setData`, so an unimplemented client reports through those.
