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
    /// The shorter form becomes available again once the compiler infers that a key path
    /// written in source is safe to share, which is what SE-0418 does for a literal whose
    /// captures are all themselves safe to share. Two routes turn that inference on, and
    /// both are declared in `Package.swift`: the Swift 6 language mode enables it as part of
    /// the mode, and the Swift 5 language mode can enable it on its own as the upcoming
    /// feature `InferSendableFromCaptures`. Neither is reachable from here today, because
    /// `enableUpcomingFeature` needs swift-tools-version 5.8 and this package declares 5.7,
    /// which is also why the manifest is not the place this was fixed.
    ///
    /// Revisit when that tools version moves. The check is to put the key path back and run
    /// `swift package clean && swift build -Xswiftc -strict-concurrency=complete`: a clean
    /// build means the inference is now reaching this file and the longer form has stopped
    /// earning its place.
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
