# Using `fileSystemClient`

Use this dependency for direct file and folder work: existence checks, reads, writes, moves, copies, deletes, directory listings, and resolving the sandbox directories your app is allowed to write to.

## Overview

```swift
@Dependency(\.fileSystemClient) var fileSystem

let documents = try fileSystem.urlForDirectory(.documents)
let file = documents.appendingPathComponent("save.json")

if fileSystem.fileExists(file) {
    let data = try fileSystem.read(file)
    print(data.count)
}
```

Three details in that snippet are easy to get wrong.

The directory is `.documents`. It is a case of `FileSystemDirectory`, declared in the `Files` package, and it is not `FileManager.SearchPathDirectory`. There is no `.documentDirectory` here, and writing one does not compile.

`FileSystemClient` is a struct of stored closures rather than a type with methods, so no endpoint takes an argument label and none offers a default. `fileSystem.write(data, file, [])` is the shortest legal write, and the empty options set has to be written out.

Until your app registers a live client, all of it resolves to `FileSystemClientKey.testValue`, which does nothing at all. Registering one is the first thing to do.

## Registering a Live Client

`FileSystemClientKey` conforms to `TestDependencyKey` only. That is deliberate, and it goes further than it does for the other clients in this package: `Files` 3.0.0 declares the `FileSystemContext` protocol but ships no type conforming to it, so there is no live implementation anywhere for this package to hand you. Writing one is a step you cannot skip.

Nothing stops the app from running without it. In a debug build, `swift-dependencies` reports an issue the first time an unregistered client is resolved from a live context and then falls back to the test value. In a release build that report is compiled out, so an app shipped without the registration reads empty data, reports that every file is missing, and discards every write, silently.

### A `FileManager`-Backed Context

`FileSystemContext` is the low-level protocol both file system clients are built on, so write it once and use it for both.

```swift
import Foundation
import Files

struct FileManagerContext: FileSystemContext, Sendable {

    private var manager: FileManager { .default }

    func fileExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let found = manager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return found && isDirectory.boolValue == false
    }

    func folderExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let found = manager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return found && isDirectory.boolValue
    }

    func createDirectory(at url: URL) throws {
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func removeDirectory(at url: URL) throws {
        try manager.removeItem(at: url)
    }

    func deleteLocation(at url: URL) throws {
        try manager.removeItem(at: url)
    }

    func moveResource(from fromURL: URL, to toURL: URL) throws {
        try manager.moveItem(at: fromURL, to: toURL)
    }

    func copyResource(from fromURL: URL, to toURL: URL) throws {
        try manager.copyItem(at: fromURL, to: toURL)
    }

    func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {
        try data.write(to: url, options: options)
    }

    func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func url(for directory: FileSystemDirectory) throws -> URL {
        switch directory {
        case .temporary:
            return manager.temporaryDirectory
        case .documents:
            return try systemURL(for: .documentDirectory)
        case .caches:
            return try systemURL(for: .cachesDirectory)
        case .applicationSupport:
            return try systemURL(for: .applicationSupportDirectory)
        }
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        try manager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        )
    }

    private func systemURL(for searchPath: FileManager.SearchPathDirectory) throws -> URL {
        try manager.url(
            for: searchPath,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}
```

`.temporary` is handled on its own because it is the one case with no `FileManager.SearchPathDirectory` behind it. `FileSystemDirectory.searchPath` returns `nil` for it and a search path for the other three, so a context that reads `searchPath` and force-unwraps it crashes on the temporary directory.

Marking the type `Sendable` matters. Every endpoint on `FileSystemClient` is `@Sendable`, so a context captured by those closures has to be safe to share. An empty struct that reaches for `FileManager.default` inside each call is; one holding mutable state would not be.

### Wiring the Client

```swift
import Dependencies
import Files
import FoundationDependencies

extension FileSystemClient {

    static func fileManager(_ context: FileManagerContext = FileManagerContext()) -> FileSystemClient {
        FileSystemClient(
            fileExists: { context.fileExists(at: $0) },
            folderExists: { context.folderExists(at: $0) },
            createDirectory: { try context.createDirectoryIfNecessary(at: $0) },
            deleteLocation: { try context.deleteLocation(at: $0) },
            moveResource: { try context.moveResource(from: $0, to: $1) },
            copyResource: { try context.copyResource(from: $0, to: $1) },
            write: { try context.write($0, to: $1, options: $2) },
            read: { try context.read(from: $0) },
            contents: { url, keys, options in
                try Folder(location: url).contents(
                    using: context,
                    includingPropertiesForKeys: keys,
                    options: options
                )
            },
            urlForDirectory: { try context.url(for: $0) }
        )
    }
}
```

`createDirectory` is wired to `createDirectoryIfNecessary` rather than to `createDirectory` on the context. The client's endpoint is documented as creating the directory only if it is not already there, and `createDirectoryIfNecessary` is how `FileSystemContext` says that. The context above happens to tolerate an existing folder anyway, because it passes `withIntermediateDirectories: true`, but the wiring should not depend on that: a context that passes `false` would start throwing on the second launch.

`contents` is the one endpoint with no direct counterpart on the context. The context returns bare URLs, while the client returns `DirectoryEntry` values, so the wiring goes through `Folder`, whose `contents` method performs the enumeration and then materialises the requested resource values for each URL.

### Registering at Launch

Register once, as early in the app lifecycle as you can.

```swift
import Dependencies
import FoundationDependencies
import SwiftUI

@main
struct MyApp: App {

    init() {
        let context = FileManagerContext()

        prepareDependencies {
            $0.fileSystemClient = .fileManager(context)
            $0.fileSystemResourceClient = .fileManager(context)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Both clients are registered together and share one context, so they agree about what is on disk. `.fileManager` for the resource client is covered in <doc:FileSystemResourceClient>.

Conforming `FileSystemClientKey` to `DependencyKey` in your own module is the alternative, with the same caveats it carries for `userDefaultsClient`. See <doc:UserDefaultsClient>.

## Directories

`FileSystemDirectory` has four cases, and each names a place with different rules about backup and deletion.

- `.documents` is user-visible and backed up. Use it for files the person using the app would expect to keep.
- `.caches` is not backed up and the system may empty it. Use it only for files you can rebuild.
- `.applicationSupport` is backed up and not user-visible. Use it for the app's own working files.
- `.temporary` may be emptied at any time, including while the app is running.

`urlForDirectory` throws, so treat a failure as a real failure rather than falling back to another directory. Silently writing to `.caches` because `.documents` could not be resolved produces an app that loses data on a schedule the system chooses.

## Listing a Directory

```swift
@Dependency(\.fileSystemClient) var fileSystem

let caches = try fileSystem.urlForDirectory(.caches)

let entries = try fileSystem.contents(
    caches,
    [.isRegularFileKey, .fileSizeKey],
    [.skipsHiddenFiles]
)

let totalBytes = entries.reduce(into: 0) { total, entry in
    guard entry.value(\.isRegularFile) == true else { return }
    total += entry.value(\.fileSize) ?? 0
}
```

Each `DirectoryEntry` carries the item's `url` and a `URLResourceValues` holding the keys you asked for. The keys are the load-bearing argument: every property inside `resourceValues` is optional, and one you did not request is not populated rather than being reported as an error. Pass an empty key list and `entry.value(\.fileSize)` cannot be relied on to return anything, so the total above comes out as zero with nothing to say why.

`value(_:)` is a convenience on `DirectoryEntry` that reads a key path into `resourceValues`, so `entry.value(\.fileSize)` and `entry.resourceValues.fileSize` are the same thing.

Note that this endpoint takes the URL to enumerate. That is what separates it from the same-named method on a resource store, which is fixed to the store's own folder.

## Testing

`FileSystemClientKey.testValue` needs no registration and touches nothing. Every predicate returns `false`, `read` returns empty `Data`, `contents` returns an empty array, the mutating endpoints accept anything and do nothing, and `urlForDirectory` returns a URL pointing at `/dev/null`.

That is enough for code whose file access is incidental, and not enough for anything under test. A test that needs particular behaviour should start from the test value and replace the endpoints it cares about.

```swift
import Dependencies
import Foundation
import FoundationDependencies

func makeSeededClient(returning data: Data) -> FileSystemClient {
    var fileSystem = FileSystemClientKey.testValue
    fileSystem.fileExists = { _ in true }
    fileSystem.read = { _ in data }
    return fileSystem
}
```

```swift
withDependencies {
    $0.fileSystemClient = makeSeededClient(returning: Data("{}".utf8))
} operation: {
    MyService()
}
```

Every endpoint is a `var`, so a single one can be swapped without restating the other nine. This is the pattern described in <doc:TestingAndOverrides>, and it works here in a way it does not for `userDefaultsClient`, whose operations are read-only.

Sharing is safe. `testValue` is a single stored instance shared by every test that does not override the dependency, but it holds no state, so nothing one test does through it can be observed by the next. Taking a copy and mutating the copy leaves the shared instance untouched.

To record what the code under test asked for, build a client around your own storage rather than mutating the test value in place.

```swift
import Dependencies
import Foundation
import FoundationDependencies

final class WriteRecorder: @unchecked Sendable {

    private let lock = NSLock()
    private var urls: [URL] = []

    var recorded: [URL] {
        lock.withLock { urls }
    }

    func makeClient() -> FileSystemClient {
        var fileSystem = FileSystemClientKey.testValue
        fileSystem.write = { [self] _, url, _ in
            lock.withLock { urls.append(url) }
        }
        return fileSystem
    }
}
```

The lock is not ceremony. The endpoint is `@Sendable`, so the client may be resolved and called from any concurrency domain, and an unsynchronised array behind it is a data race whether or not a given test happens to trigger one.

## What This Client Does Not Do

It does not build stores. There is no `makeStore` endpoint on `FileSystemClient`, and encoding, decoding, and folder-scoped file management belong to `fileSystemResourceClient`. See <doc:FileSystemResourceClient>.

It also does not create intermediate directories before a write. The endpoint maps straight onto the context, so with the wiring above, writing into a folder that is not there yet fails rather than creating it. Call `createDirectory` for the containing folder first, or use a resource store, whose save endpoints do that step for you.
