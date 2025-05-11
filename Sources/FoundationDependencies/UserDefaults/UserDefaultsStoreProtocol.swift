//
//  UserDefaultsStoreProtocol.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A protocol that defines a type-safe, testable interface for accessing and modifying values stored in `UserDefaults`.
///
/// Types conforming to this protocol provide an abstraction over `UserDefaults`, making it easier to inject mock
/// implementations for unit testing or to isolate user preferences in different contexts.
///
/// This protocol is `Sendable`, and individual read/write operations are generally thread-safe when backed by `UserDefaults`.
/// However, race conditions may occur when accessing the same keys from multiple threads concurrently—especially when
/// working with compound values (e.g. dictionaries, arrays, or custom objects) or derived state (e.g. reading a value,
/// modifying it in memory, then writing it back).
///
/// Please see Apple’s documentation on `UserDefaults` thread safety for further guidance.
public protocol UserDefaultsStoreProtocol: Sendable {

    // MARK: - Reading Values

    /// Returns the boolean value associated with the specified key.
    ///
    /// - Parameter key: The key associated with the boolean value.
    /// - Returns: The boolean value, or `false` if the key does not exist.
    func bool(forKey key: String) -> Bool

    /// Returns the integer value associated with the specified key.
    ///
    /// - Parameter key: The key associated with the integer value.
    /// - Returns: The integer value, or `0` if the key does not exist.
    func int(forKey key: String) -> Int

    /// Returns the double value associated with the specified key.
    ///
    /// - Parameter key: The key associated with the double value.
    /// - Returns: The double value, or `0.0` if the key does not exist.
    func double(forKey key: String) -> Double

    /// Returns the string value associated with the specified key.
    ///
    /// - Parameter key: The key associated with the string value.
    /// - Returns: The string value, or `nil` if the key does not exist or the value is not a string.
    func string(forKey key: String) -> String?

    /// Returns the string array associated with the specified key.
    ///
    /// - Parameter key: The key associated with the array.
    /// - Returns: The array of strings, or `nil` if the key does not exist or the value is not an array of strings.
    func stringArray(forKey key: String) -> [String]?

    /// Returns the object associated with the specified key.
    ///
    /// - Parameter key: The key associated with the value.
    /// - Returns: The stored object, or `nil` if the key does not exist.
    func object(forKey key: String) -> Any?

    /// Returns the date value associated with the specified key.
    ///
    /// - Parameter key: The key associated with the date.
    /// - Returns: The date value, or `nil` if the key does not exist or the value is not a date.
    func date(forKey key: String) -> Date?

    /// Removes the value associated with the specified key.
    ///
    /// - Parameter key: The key of the value to remove.
    func removeObject(forKey key: String)

    // MARK: - Writing Values

    /// Sets a boolean value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The boolean value to store.
    ///   - key: The key under which to store the value.
    func set(_ value: Bool, forKey key: String)

    /// Sets a string value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The optional string value to store.
    ///   - key: The key under which to store the value.
    func set(_ value: String?, forKey key: String)

    /// Sets an array of strings for the specified key.
    ///
    /// - Parameters:
    ///   - value: The optional array of strings to store.
    ///   - key: The key under which to store the value.
    func set(_ value: [String]?, forKey key: String)

    /// Sets an arbitrary object for the specified key.
    ///
    /// - Parameters:
    ///   - value: The optional object to store.
    ///   - key: The key under which to store the value.
    func set(_ value: Any?, forKey key: String)

    /// Sets a date value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The optional date value to store.
    ///   - key: The key under which to store the value.
    func set(_ value: Date?, forKey key: String)
}
