# Using `fileSystemClient`

Use this dependency to interact with the file system in a safe, testable, and modular way. It is designed for Swift Concurrency and dependency injection environments.

## Overview

```swift
@Dependency(\.fileSystemClient) var fileSystem

let directory = try fileSystem.urlForDirectory(.documentDirectory)
let fileURL = directory.appendingPathComponent("save.json")

if fileSystem.fileExists(fileURL) {
    let data = try fileSystem.read(fileURL)
    // process data
}
```

The `FileSystemClient` provides ergonomic access to file operations like reading, writing, moving, copying, and deleting files or directories. Its modular design enables mocking and testability for unit and integration testing.

## Providing Live Values

In production, provide a concrete implementation backed by a live file system context:

```swift
extension FileSystemClientKey: DependencyKey {

    public static let liveValue: FileSystemClient = FileSystemClient(
        fileExists: FileSystemAgent.live.fileExists,
        folderExists: FileSystemAgent.live.folderExists,
        createDirectory: FileSystemAgent.live.createDirectory,
        deleteLocation: FileSystemAgent.live.deleteLocation,
        moveResource: FileSystemAgent.live.moveResource,
        copyResource: FileSystemAgent.live.copyResource,
        write: FileSystemAgent.live.write,
        read: FileSystemAgent.live.read,
        urlForDirectory: FileSystemAgent.live.urlForDirectory,
        makeStore: { directory in
            try FileSystemFolderStore<LiveFileSystemContext>(
                directory: directory,
                agent: .live
            )
        }
    )
}
```

## SPM Modules

If used from within a Swift Package or tests, you can provide your own mock or in-memory file system implementation:

```swift
$0.fileSystemClient = FileSystemClient(
    fileExists: { _ in false },
    folderExists: { _ in false },
    createDirectory: { _ in },
    deleteLocation: { _ in },
    moveResource: { _, _ in },
    copyResource: { _, _ in },
    write: { _, _, _ in },
    read: { _ in Data() },
    urlForDirectory: { _ in URL(fileURLWithPath: "/dev/null") },
    makeStore: { _ in MockFileSystemStore() }
)
```

You can also use the built-in default for tests:

```swift
public enum FileSystemClientKey: TestDependencyKey {
    public static let testValue = FileSystemClient(
        fileExists: { _ in false },
        folderExists: { _ in false },
        createDirectory: { _ in },
        deleteLocation: { _ in },
        moveResource: { _, _ in },
        copyResource: { _, _ in },
        write: { _, _, _ in },
        read: { _ in Data() },
        urlForDirectory: { _ in URL(fileURLWithPath: "/dev/null") },
        makeStore: { _ in MockFileSystemStore() }
    )
}
```

This makes it easy to test file logic in isolation without accessing the actual file system.

## Common Patterns

### Saving Codable Models

```swift
let resource = MyModel(...)
let store = try fileSystem.makeStore(.documentDirectory)
try store.saveResource(resource, filename: "model.json")
```

### Loading Codable Models

```swift
let store = try fileSystem.makeStore(.documentDirectory)
let model: MyModel = try store.loadResource(filename: "model.json")
```

### Saving and Reading Raw Data

```swift
let rawData = Data("Hello".utf8)
let store = try fileSystem.makeStore(.cachesDirectory)

try store.saveData(rawData, withName: "cache.bin")
let restored = try store.loadData(named: "cache.bin")
```
