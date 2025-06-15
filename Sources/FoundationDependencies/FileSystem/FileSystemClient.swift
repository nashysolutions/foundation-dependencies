//
//  FileSystemClient.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 10/06/2025.
//

import Foundation
import Files
import Dependencies

/// A protocol-oriented, testable interface for performing file system operations.
///
/// `FileSystemClient` provides a lightweight abstraction over common file and folder operations,
/// making it suitable for dependency injection, unit testing, and mocking.
///
/// Each operation is exposed as a `@Sendable` closure, enabling safe use from concurrent contexts.
public struct FileSystemClient: Sendable {

    /// Returns a Boolean indicating whether a file exists at the given URL.
    ///
    /// - Parameter url: The location to check.
    /// - Returns: `true` if a file exists at the given location; otherwise, `false`.
    public var fileExists: @Sendable (_ url: URL) -> Bool

    /// Returns a Boolean indicating whether a folder exists at the given URL.
    ///
    /// - Parameter url: The location to check.
    /// - Returns: `true` if a folder exists at the given location; otherwise, `false`.
    public var folderExists: @Sendable (_ url: URL) -> Bool

    /// Creates a directory at the specified URL if it does not already exist.
    ///
    /// - Parameter url: The directory path to create.
    /// - Throws: An error if the directory cannot be created.
    public var createDirectory: @Sendable (_ url: URL) throws -> Void

    /// Deletes the file or folder at the specified URL.
    ///
    /// - Parameter url: The location to delete.
    /// - Throws: An error if the file or folder cannot be deleted.
    public var deleteLocation: @Sendable (_ url: URL) throws -> Void

    /// Moves a resource from one location to another.
    ///
    /// - Parameters:
    ///   - from: The source URL.
    ///   - to: The destination URL.
    /// - Throws: An error if the move operation fails.
    public var moveResource: @Sendable (_ from: URL, _ to: URL) throws -> Void

    /// Copies a resource from one location to another.
    ///
    /// - Parameters:
    ///   - from: The source URL.
    ///   - to: The destination URL.
    /// - Throws: An error if the copy operation fails.
    public var copyResource: @Sendable (_ from: URL, _ to: URL) throws -> Void

    /// Writes data to a file at the specified URL with the given write options.
    ///
    /// - Parameters:
    ///   - data: The data to write.
    ///   - url: The target file URL.
    ///   - options: Options that affect how the data is written to disk.
    /// - Throws: An error if the write operation fails.
    public var write: @Sendable (_ data: Data, _ url: URL, _ options: NSData.WritingOptions) throws -> Void

    /// Reads data from a file at the specified URL.
    ///
    /// - Parameter url: The location to read data from.
    /// - Returns: The data read from the file.
    /// - Throws: An error if the file cannot be read.
    public var read: @Sendable (_ url: URL) throws -> Data

    /// Resolves the file system URL for a logical directory (e.g. `.documents`, `.caches`).
    ///
    /// - Parameter directory: The logical directory to resolve.
    /// - Returns: A file system URL pointing to the requested directory.
    /// - Throws: An error if the URL cannot be resolved.
    public var urlForDirectory: @Sendable (_ directory: FileSystemDirectory) throws -> URL

    /// Creates a new `FileSystemClient` using custom implementations for all file operations.
    ///
    /// - Parameters:
    ///   - fileExists: Closure to check for file existence.
    ///   - folderExists: Closure to check for folder existence.
    ///   - createDirectory: Closure to create a folder at a given URL.
    ///   - deleteLocation: Closure to delete a file or folder at a given URL.
    ///   - moveResource: Closure to move a resource from one location to another.
    ///   - copyResource: Closure to copy a resource from one location to another.
    ///   - write: Closure to write data to disk.
    ///   - read: Closure to read data from disk.
    ///   - urlForDirectory: Closure to resolve logical directory URLs.
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
