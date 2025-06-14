//
//  FileSystemResourceClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 14/06/2025.
//

import Foundation
import Dependencies
import Files

public struct FileSystemResourceClient: Sendable {
    
    public var makeStore: @Sendable (
        _ directory: FileSystemDirectory,
        _ subfolder: String?
    ) throws -> any FileSystemOperations

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
