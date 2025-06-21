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
    
    init(category: String) {
        @Dependency(\.mainBundleClient) var mainBundleClient
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
