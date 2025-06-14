# Using `fileSystemResourceClient`

Use this dependency to create file-backed storage containers (stores) for Codable models or binary data. It is designed to integrate with Swift Concurrency and dependency injection, offering modularity and testability across runtime and testing environments.

---

## Overview

```swift
@Dependency(\.fileSystemResourceClient) var resourceClient

let store = try resourceClient.makeStore(.documentDirectory, "MySubfolder")
let data = try store.loadData(named: "file.dat")
```

The `FileSystemResourceClient` is responsible for constructing storage interfaces that abstract away encoding, decoding, and file management logic. These stores conform to the `FileSystemOperations` protocol, enabling easy interaction with structured file resources.

---

## Responsibilities

This client **does not** handle low-level file operations (e.g. `read`, `write`, `move`, etc.). Instead, it:

- Creates `FileSystemOperations` stores
- Configures them with a specified directory and optional subfolder
- Injects an appropriate file system context (e.g. live, mock, or in-memory)

---

## Providing Live Values

In production, configure it to use a concrete folder store and live agent:

```swift
extension FileSystemResourceClientKey: DependencyKey {
    public static let liveValue: FileSystemResourceClient = FileSystemResourceClient(
        makeStore: { directory, subfolder in
            try FileSystemFolderStore<LiveFileSystemContext>(
                directory: directory,
                subfolder: subfolder,
                agent: .live
            )
        }
    )
}
```

---

## Providing Test Values

When testing, you can use the built-in mock implementation:

```swift
extension FileSystemResourceClientKey: TestDependencyKey {
    public static let testValue: FileSystemResourceClient = FileSystemResourceClient(
        makeStore: { _, _ in MockFileSystemStore() }
    )
}
```

You can also define your own in-memory or deterministic store factory if needed:

```swift
$0.fileSystemResourceClient = FileSystemResourceClient(
    makeStore: { _, _ in InMemoryTestStore() }
)
```

---

## Example Usage

### Saving a Codable Value

```swift
let store = try resourceClient.makeStore(.applicationSupportDirectory, "Cache")
try store.saveResource(userProfile, filename: "profile.json")
```

### Updating a Model in Place

```swift
let store = try resourceClient.makeStore(.documentDirectory, nil)
try store.updateResource(filename: "settings.json") { (settings: inout AppSettings) in
    settings.theme = .dark
}
```

### Saving Raw Data

```swift
let store = try resourceClient.makeStore(.cachesDirectory, "Images")
try store.saveData(imageData, withName: "avatar.png")
```

### Reading Raw Data

```swift
let store = try resourceClient.makeStore(.documentDirectory, nil)
let data = try store.loadData(named: "notes.txt")
```

---

## Notes

- The result of `makeStore(...)` conforms to `FileSystemOperations`, which supports:
  - `saveResource` / `loadResource`
  - `updateResource`
  - `saveData` / `loadData`
  - `deleteResource`

- This approach separates store construction from low-level operations, enabling:
  - Focused testing of model behaviour
  - Clearer architectural boundaries
  - Easier mocking and error simulation
