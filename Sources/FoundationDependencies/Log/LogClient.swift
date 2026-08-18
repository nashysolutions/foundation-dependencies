//
//  LogClient.swift
//  logging
//
//  Created by Robert Nash on 17/05/2025.
//

import Foundation
import Dependencies
import os.log

public struct LogClient: Sendable {

    public var logger: @Sendable (String) -> Logger

    public init(logger: @Sendable @escaping (String) -> Logger) {
        self.logger = logger
    }
}

private enum LogClientKey: DependencyKey {
    static let liveValue = LogClient(logger: { Logger(category: $0) })
    static let testValue = LogClient(logger: { Logger(category: $0) })
}

private extension Logger {

    /// Creates a logger whose subsystem is the identifier of the main bundle.
    ///
    /// The bundle client is resolved from its dependency key, `MainBundleClientKey.self`,
    /// rather than from the `\.mainBundleClient` key path that the rest of this package's
    /// documentation shows. Both routes read and write the same stored value, so a client
    /// installed with `withDependencies { $0.mainBundleClient = ... }` is still seen here.
    ///
    /// The reason for the longer form is that `@Dependency` asks for a key path that is safe
    /// to share between threads, and in the Swift 5 language mode that this package builds in,
    /// no key path written in source is treated as safe to share. The key path form therefore
    /// warns under `-strict-concurrency=complete`. Passing the key type instead leaves the key
    /// path to be formed inside swift-dependencies, where it is accepted.
    ///
    /// The Swift 6 language mode does treat such a key path as safe to share, so if this
    /// package ever moves to that language mode the shorter key path form becomes correct
    /// again and this comment can go with it.
    init(category: String) {
        @Dependency(MainBundleClientKey.self) var mainBundleClient
        let subsystem = (try? mainBundleClient.extractIdentifier()) ?? "Unknown Bundle Identifier"
        self.init(subsystem: subsystem, category: category)
    }
}

public extension DependencyValues {

    var loggerClient: LogClient {
        get { self[LogClientKey.self] }
        set { self[LogClientKey.self] = newValue }
    }
}
