//
//  UserDefaultsLiveStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A live implementation of `UserDefaultsStoreProtocol` backed by `UserDefaults`.
///
/// This class provides access to values stored in a named `UserDefaults` suite, enabling
/// separation of user preferences, app groups, or isolated testing environments.
///
/// All reads and writes are forwarded to the corresponding `UserDefaults` instance.
///
/// This type is `Sendable` and generally safe for concurrent use. However, when multiple threads
/// access the same keys at the same time—especially when reading, modifying, and writing complex
/// data like dictionaries, arrays, or custom objects—race conditions may occur. This includes
/// operations where values are read, mutated in memory, and written back (i.e. derived state).
/// Please see Apple’s documentation on `UserDefaults` thread safety for further guidance.
public final class UserDefaultsLiveStore: UserDefaultsStoreProtocol, Sendable {
    
    /// The name of the `UserDefaults` suite to use.
    private let suiteName: String
    
    /// Creates a new live store backed by the given `UserDefaults` suite.
    ///
    /// - Parameter suiteName: The suite name used to initialise the `UserDefaults` instance.
    ///                        This must match a suite registered with your app or app group.
    public init(suiteName: String) {
        self.suiteName = suiteName
    }

    /// The underlying `UserDefaults` instance, if one exists for the given suite name.
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    public func bool(forKey key: String) -> Bool {
        userDefaults?.bool(forKey: key) ?? false
    }
    
    public func int(forKey key: String) -> Int {
        userDefaults?.integer(forKey: key) ?? 0
    }

    public func double(forKey key: String) -> Double {
        userDefaults?.double(forKey: key) ?? 0
    }
    
    public func string(forKey key: String) -> String? {
        userDefaults?.string(forKey: key)
    }
    
    public func stringArray(forKey key: String) -> [String]? {
        userDefaults?.stringArray(forKey: key)
    }
    
    public func object(forKey key: String) -> Any? {
        userDefaults?.object(forKey: key)
    }
    
    public func date(forKey key: String) -> Date? {
        object(forKey: key) as? Date
    }
    
    public func removeObject(forKey key: String) {
        userDefaults?.removeObject(forKey: key)
    }
    
    public func value<T>(forKey key: String) -> T? {
        userDefaults?.value(forKey: key) as? T
    }
    
    public func set<T>(_ value: T, forKey key: String) {
        userDefaults?.set(value, forKey: key)
    }
}
