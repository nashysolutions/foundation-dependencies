//
//  FileSystemResourceClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Dependencies
import Files

/// A client for constructing file system-backed resource stores using a configurable factory closure.
///
/// `FileSystemResourceClient` provides a mechanism for creating typed, configurable file storage
/// interfaces that conform to the `FileSystemOperations` protocol. This allows resources to be
/// encoded and persisted to disk in a structured, testable, and dependency-injectable manner.
///
/// This client is typically injected into a higher-level service that needs to store or retrieve
/// resources on disk.
///
/// Example usage:
///
/// ```swift
/// let client = FileSystemResourceClient { directory, subfolder in
///     return try FileSystemFolderStore(directory: directory, subfolder: subfolder)
/// }
/// let store = try client.makeStore(.documents, "Cache")
/// try store.saveResource(someCodableObject, filename: "resource.json")
/// ```
public struct FileSystemResourceClient: Sendable {

    /// A closure used to construct a resource store for a specific directory and optional subfolder.
    ///
    /// The returned store must conform to `FileSystemOperations`, and can be used to read/write
    /// resources to disk using filenames as keys.
    ///
    /// - Parameters:
    ///   - directory: The base directory to store resources in (e.g. `.documents`, `.caches`).
    ///   - subfolder: An optional subfolder name inside the specified directory.
    /// - Returns: An instance conforming to `FileSystemOperations`.
    /// - Throws: Any error encountered during store creation (e.g. directory creation failure).
    public var makeStore: @Sendable (
        _ directory: FileSystemDirectory,
        _ subfolder: String?
    ) throws -> any FileSystemOperations

    /// Creates a new file system resource client with a custom store factory closure.
    ///
    /// Use this to inject a custom resource store strategy (e.g. a mock store for testing, or
    /// a persistent store for production).
    ///
    /// - Parameter makeStore: A closure that creates a resource store for a given directory and optional subfolder.
    public init(
        makeStore: @Sendable @escaping (
            _ directory: FileSystemDirectory,
            _ subfolder: String?
        ) throws -> any FileSystemOperations
    ) {
        self.makeStore = makeStore
    }
}

public enum FileSystemResourceClientKey: TestDependencyKey {
    public static let testValue = FileSystemResourceClient { _, _ in MockFileSystemStore() }
}

public extension DependencyValues {
    var fileSystemResourceClient: FileSystemResourceClient {
        get { self[FileSystemResourceClientKey.self] }
        set { self[FileSystemResourceClientKey.self] = newValue }
    }
}

private struct MockFileSystemStore: FileSystemOperations {
    
    struct DummyFolder: Directory {
        let location = URL(fileURLWithPath: "/dev/null")
    }

    struct DummyAgent: FileSystemContext {
        func fileExists(at url: URL) -> Bool { false }
        func folderExists(at url: URL) -> Bool { false }
        func createDirectory(at url: URL) throws {}
        func removeDirectory(at url: URL) throws {}
        func deleteLocation(at url: URL) throws {}
        func moveResource(from fromURL: URL, to toURL: URL) throws {}
        func copyResource(from fromURL: URL, to toURL: URL) throws {}
        func write(_ data: Data, to url: URL, options: NSData.WritingOptions) throws {}
        func read(from url: URL) throws -> Data { Data() }
        func url(for directory: FileSystemDirectory) throws -> URL {
            URL(fileURLWithPath: "/dev/null")
        }
    }

    let folder = DummyFolder()
    let agent = DummyAgent()

    func saveResource<Resource: Encodable>(_ resource: Resource, filename name: String) throws {}
    func loadResource<Resource: Decodable>(filename: String) throws -> Resource {
        throw NSError(domain: "mock", code: 1)
    }
    func deleteResource(filename: String) throws {}
    func updateResource<Resource: Codable>(filename name: String, modify: (inout Resource) -> Void) throws {}
    func saveData(_ data: Data, withName name: String) throws {}
    func loadData(named name: String) throws -> Data { Data() }
}
