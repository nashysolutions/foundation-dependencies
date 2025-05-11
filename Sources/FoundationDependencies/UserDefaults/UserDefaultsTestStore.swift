//
//  UserDefaultsTestStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A testable implementation of `UserDefaultsStoreProtocol` backed by an in-memory dictionary.
///
/// This class is intended for use in unit tests or previews where persistence to disk is not required.
///
/// > Note: This type is marked as `@unchecked Sendable`. If used across concurrency domains, access must be externally synchronised.
public final class UserDefaultsTestStore: UserDefaultsStoreProtocol, @unchecked Sendable {
    
    private var storage: [String: Any] = [:]
    
    public init() {
        
    }

    public func bool(forKey key: String) -> Bool {
        storage[key] as? Bool ?? false
    }
    
    public func int(forKey key: String) -> Int {
        storage[key] as? Int ?? 0
    }

    public func double(forKey key: String) -> Double {
        storage[key] as? Double ?? 0
    }
    
    public func string(forKey key: String) -> String? {
        storage[key] as? String
    }
    
    public func stringArray(forKey key: String) -> [String]? {
        storage[key] as? [String]
    }
    
    public func object(forKey key: String) -> Any? {
        storage[key]
    }
    
    public func date(forKey key: String) -> Date? {
        storage[key] as? Date
    }
    
    public func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }
    
    public func set(_ value: Bool, forKey key: String) {
        storage[key] = value
    }

    public func set(_ value: String?, forKey key: String) {
        storage[key] = value
    }

    public func set(_ value: [String]?, forKey key: String) {
        storage[key] = value
    }

    public func set(_ value: Any?, forKey key: String) {
        storage[key] = value
    }

    public func set(_ value: Date?, forKey key: String) {
        storage[key] = value
    }
}
