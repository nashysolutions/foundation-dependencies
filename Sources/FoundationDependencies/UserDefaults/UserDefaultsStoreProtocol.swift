//
//  UserDefaultsStoreProtocol.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A protocol that defines a type-safe and actor-isolated interface for interacting with a `UserDefaults`-like key-value store.
///
/// All operations are performed on the main actor to ensure thread safety when accessing or modifying underlying storage.
/// This protocol is `Sendable` and can be safely used in concurrent contexts where main-actor isolation is maintained.
public protocol UserDefaultsStoreProtocol: Sendable {

    // MARK: - Boolean Values

    /// Retrieves a Boolean value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The Boolean value if present, or `false` if not found.
    var bool: @MainActor (String) -> Bool { get }

    /// Stores a Boolean value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The Boolean value to store.
    ///   - key: The key to associate the value with.
    var setBool: @MainActor (Bool, String) -> Void { get }

    // MARK: - Integer Values

    /// Retrieves an integer value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The integer value if present, or `0` if not found.
    var int: @MainActor (String) -> Int { get }

    /// Stores an integer value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The integer value to store.
    ///   - key: The key to associate the value with.
    var setInt: @MainActor (Int, String) -> Void { get }

    // MARK: - Double Values

    /// Retrieves a double value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The double value if present, or `0` if not found.
    var double: @MainActor (String) -> Double { get }

    /// Stores a double value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The double value to store.
    ///   - key: The key to associate the value with.
    var setDouble: @MainActor (Double, String) -> Void { get }

    // MARK: - String Values

    /// Retrieves a string value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The string value if present, or `nil` if not found.
    var string: @MainActor (String) -> String? { get }

    /// Stores a string value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The string value to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setString: @MainActor (String?, String) -> Void { get }

    // MARK: - String Array Values

    /// Retrieves an array of strings for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The string array if present, or `nil` if not found.
    var stringArray: @MainActor (String) -> [String]? { get }

    /// Stores an array of strings for the specified key.
    ///
    /// - Parameters:
    ///   - value: The string array to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setStringArray: @MainActor ([String]?, String) -> Void { get }

    // MARK: - Object Values

    /// Retrieves a raw object for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The object if present, or `nil` if not found.
    var object: @MainActor (String) -> Any? { get }

    /// Stores a raw object for the specified key.
    ///
    /// - Parameters:
    ///   - value: The object to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setObject: @MainActor (Any?, String) -> Void { get }

    // MARK: - Date Values

    /// Retrieves a `Date` value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The `Date` value if present, or `nil` if not found.
    var date: @MainActor (String) -> Date? { get }

    /// Stores a `Date` value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The `Date` value to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setDate: @MainActor (Date?, String) -> Void { get }

    // MARK: - Deletion

    /// Removes the value associated with the specified key.
    ///
    /// - Parameter key: The key for which the value should be removed.
    var removeObject: @MainActor (String) -> Void { get }
}
