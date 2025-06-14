//
//  FileSystemClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 10/06/2025.
//

import Foundation
import Files
import Dependencies

public struct FileSystemClient: Sendable {
    
    public var fileExists: @Sendable (_ url: URL) -> Bool
    public var folderExists: @Sendable (_ url: URL) -> Bool
    public var createDirectory: @Sendable (_ url: URL) throws -> Void
    public var deleteLocation: @Sendable (_ url: URL) throws -> Void
    public var moveResource: @Sendable (_ from: URL, _ to: URL) throws -> Void
    public var copyResource: @Sendable (_ from: URL, _ to: URL) throws -> Void
    public var write: @Sendable (_ data: Data, _ url: URL, _ options: NSData.WritingOptions) throws -> Void
    public var read: @Sendable (_ url: URL) throws -> Data
    public var urlForDirectory: @Sendable (_ directory: FileSystemDirectory) throws -> URL

    public init(
        fileExists: @Sendable @escaping (_ url: URL) -> Bool,
        folderExists: @Sendable @escaping (_ url: URL) -> Bool,
        createDirectory: @Sendable @escaping (_ url: URL) throws -> Void,
        deleteLocation: @Sendable @escaping (_ url: URL) throws -> Void,
        moveResource: @Sendable @escaping (_ from: URL, _ to: URL) throws -> Void,
        copyResource: @Sendable @escaping (_ from: URL, _ to: URL) throws -> Void,
        write: @Sendable @escaping (_ data: Data, _ url: URL, _ options: NSData.WritingOptions) throws -> Void,
        read: @Sendable @escaping (_ url: URL) throws -> Data,
        urlForDirectory: @Sendable @escaping (_ directory: FileSystemDirectory) throws -> URL
    ) {
        self.fileExists = fileExists
        self.folderExists = folderExists
        self.createDirectory = createDirectory
        self.deleteLocation = deleteLocation
        self.moveResource = moveResource
        self.copyResource = copyResource
        self.write = write
        self.read = read
        self.urlForDirectory = urlForDirectory
    }
}

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
        urlForDirectory: { _ in URL(fileURLWithPath: "/dev/null") }
    )
}

public extension DependencyValues {
    
    var fileSystemClient: FileSystemClient {
        get { self[FileSystemClientKey.self] }
        set { self[FileSystemClientKey.self] = newValue }
    }
}
