# Using `fileSystemResourceClient`

Use this dependency to obtain a store: an object scoped to one folder that saves and loads `Codable` values and raw `Data` by filename, without the calling code ever handling a URL.

## Overview

```swift
@Dependency(\.fileSystemResourceClient) var resourceClient

let store = try resourceClient.makeStore(.caches, "Thumbnails")

try store.saveData(Data("png bytes".utf8), withName: "avatar.png")
let restored = try store.loadData(named: "avatar.png")
```

`makeStore` is a stored closure rather than a method, so it takes no argument labels and offers no defaults. The subfolder is `String?` and has to be written out even when there is not one.

```swift
@Dependency(\.fileSystemResourceClient) var resourceClient

let store = try resourceClient.makeStore(.documents, nil)
```

The directory is a `FileSystemDirectory` case from the `Files` package, the same four values <doc:FileSystemClient> describes. Until your app registers a live client, this resolves to `FileSystemResourceClientKey.testValue`, whose stores accept every write and keep nothing.

## What a Store Is

The returned value is `any FileSystemOperations`, a protocol from `Files`. It offers:

- `saveResource(_:filename:)` and `loadResource(filename:)` for `Codable` values, encoding to and decoding from JSON.
- `updateResource(filename:modify:)`, which loads, hands you the value `inout`, and saves it back.
- `deleteResource(filename:)`.
- `saveData(_:withName:)` and `loadData(named:)` for bytes you have already encoded yourself.
- `contents()` and `contents(includingPropertiesForKeys:options:)`, which enumerate the store's own folder and return `DirectoryEntry` values.
- `deleteFiles(matching:)`, `moveFiles(matching:to:)`, and `copyAllFiles(to:)`, each returning the number of files it acted on.
- `folderExists`, `isEmpty()`, and `totalSizeOfFiles()`.

Saving creates the folder if it is not there yet, so no separate setup call is needed before the first write.

The two members that describe the store itself come back at their protocol types rather than the concrete ones. `store.folder` is `any Directory`, which is enough to read `location`, and `store.agent` is `any FileSystemContext`. Anything the concrete type adds beyond the protocol is not reachable through the existential, including `FileSystemFolderStore.kind`, so keep hold of the `FileSystemDirectory` you passed in if you need it later.

## Registering a Live Client

`FileSystemResourceClientKey` conforms to `TestDependencyKey` only, and `Files` 3.0.0 ships no concrete `FileSystemContext`, so the live client is yours to build. It needs the same context <doc:FileSystemClient> shows how to write, and `Files` supplies the store type.

```swift
import Dependencies
import Files
import FoundationDependencies

extension FileSystemResourceClient {

    static func fileManager(_ context: FileManagerContext = FileManagerContext()) -> FileSystemResourceClient {
        FileSystemResourceClient { directory, subfolder in
            try FileSystemFolderStore(agent: context, kind: directory, subfolder: subfolder)
        }
    }
}
```

`FileSystemFolderStore(agent:kind:subfolder:)` takes its arguments in that order and with those labels. It resolves the directory and creates the folder during initialisation rather than on first use, so `makeStore` throws when the directory cannot be resolved or the folder cannot be created, and a store you are holding has a folder behind it.

Register it at launch, alongside `fileSystemClient` and sharing one context, as <doc:FileSystemClient> shows. Both clients then agree about what is on disk.

Failing to register is quiet. In a debug build `swift-dependencies` reports an issue on first resolution from a live context and falls back to the test value; in a release build that report is compiled out, and the app runs on stores that discard every write and fail every load.

## Working With a Store

```swift
struct Profile: Codable {
    var name: String
    var theme: String
}
```

```swift
@Dependency(\.fileSystemResourceClient) var resourceClient

let store = try resourceClient.makeStore(.applicationSupport, "Accounts")

try store.saveResource(Profile(name: "Sam", theme: "dark"), filename: "profile.json")

let profile: Profile = try store.loadResource(filename: "profile.json")
print(profile.name)
```

`loadResource` is generic in its return type and has nothing else to infer from, so the annotation on the receiving variable is doing real work. Without it the call does not compile.

Reading, changing, and writing back is a single call.

```swift
@Dependency(\.fileSystemResourceClient) var resourceClient

let store = try resourceClient.makeStore(.applicationSupport, "Accounts")

try store.updateResource(filename: "profile.json") { (profile: inout Profile) in
    profile.theme = "light"
}
```

The closure's parameter type is what tells the call which resource to decode, so annotate it. It is not a place to put a failure path either: the closure cannot throw, so a change that might not be possible has to be handled by loading, deciding, and saving as separate steps.

Bulk operations take a predicate over `DirectoryEntry` and return a count.

```swift
@Dependency(\.fileSystemResourceClient) var resourceClient

let store = try resourceClient.makeStore(.caches, "Thumbnails")

let removed = try store.deleteFiles { entry in
    entry.url.pathExtension == "png"
}

print("removed \(removed) files")
```

The entries handed to that predicate carry exactly two resource values and no others. All three bulk operations enumerate with `.isRegularFileKey` and `.nameKey` requested, so `entry.value(\.isRegularFile)` and `entry.value(\.name)` are populated, while anything else, a file size or a modification date, reads back as absent. Deciding on one of those means listing the folder yourself with the keys you want and acting on the result.

Only `copyAllFiles` filters for you, skipping anything that is not a regular file. `deleteFiles` and `moveFiles` act on every entry the predicate accepts, subdirectories included, and deleting a directory takes its contents with it. A predicate that looks only at the path extension will delete a folder named `Cache.png`.

## Testing

The gap here is worth stating plainly, because the shape of the API suggests otherwise.

`FileSystemResourceClientKey.testValue` returns a store that is `private` to this package. You cannot name it, construct it, subclass it, or configure it, and it is inert in an asymmetric way: `saveResource`, `saveData`, `deleteResource`, and `updateResource` accept anything and do nothing, `loadResource` always throws, `loadData` returns empty `Data`, `contents()` is always empty, and `folderExists` is `false`. A test that saves a value and reads it back does not get the value back, and neither this package nor `Files` 3.0.0 offers a reachable double that would.

So a test needing a store that actually round-trips has to build one, and there are two routes.

### A Store in a Temporary Folder

This is the route to reach for. It is a real `FileSystemFolderStore` over the real file system, scoped to a folder nothing else uses.

```swift
import Dependencies
import Files
import Foundation
import FoundationDependencies

func makeTemporaryStore() throws -> any FileSystemOperations {
    try FileSystemFolderStore(
        agent: FileManagerContext(),
        kind: .temporary,
        subfolder: UUID().uuidString
    )
}
```

```swift
let store = try makeTemporaryStore()
defer { try? FileManager.default.removeItem(at: store.folder.location) }

withDependencies {
    $0.fileSystemResourceClient = FileSystemResourceClient { _, _ in store }
} operation: {
    MyService()
}
```

The subfolder is a fresh UUID per store, so cases running in parallel cannot see each other's files, and the `defer` removes the folder rather than leaving one behind per case. Note that the factory ignores the directory and subfolder it is handed and returns the one store, which is what lets a test inspect afterwards the same folder the code under test wrote into.

### An In-Memory Context

The other route is a `FileSystemContext` backed by a dictionary, paired with the same `FileSystemFolderStore`. Every operation in `FileSystemOperations` is implemented in terms of the store's `agent` and `folder`, so replacing the agent replaces the storage, and no disk access is left.

It has a real limit, so decide before writing one. Enumeration is only half available. `FileSystemOperations.contents` asks Foundation to materialise resource values for each URL the agent returned, and Foundation reads those from disk, not from your dictionary. For a URL with no file behind it, an empty key list succeeds and yields an entry whose values are all absent, while requesting any key at all fails with a "no such file" error.

So `contents()` and `isEmpty()` work against an in-memory context, and `contents(includingPropertiesForKeys:options:)` does not once the key list is non-empty. That also rules out `totalSizeOfFiles()` and all three bulk operations, since each of them asks for `.isRegularFileKey` and `.nameKey`.

That leaves the temporary folder as the better default. Reach for an in-memory context when a case needs an error the file system will not produce on demand, such as a read failing part way through.
