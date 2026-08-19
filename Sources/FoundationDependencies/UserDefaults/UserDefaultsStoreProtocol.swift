//
//  UserDefaultsStoreProtocol.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A protocol that defines a type-safe interface for interacting with a
/// `UserDefaults`-like key-value store.
///
/// Every operation is a nonisolated `@Sendable` closure, so a store may be resolved
/// and called from any concurrency domain: a background task, a widget extension
/// reading an app group suite, or the main actor. No endpoint hops, and none of them
/// is `async`, so a read returns its value in the caller's own domain.
///
/// Thread safety is therefore the conformer's to arrange, not this protocol's, and
/// each conformer states at its own declaration how it arranges it.
/// ``UserDefaultsLiveStore`` leans on `UserDefaults` being thread-safe, and
/// ``UserDefaultsTestStore`` takes a lock around its dictionary. A conformer that
/// cannot make that argument for itself does not belong behind this protocol,
/// because the `Sendable` requirement here is what lets a store cross into another
/// domain in the first place.
public protocol UserDefaultsStoreProtocol: Sendable {

    // MARK: - Boolean Values

    /// Retrieves a Boolean value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The Boolean value if present, or `false` if not found.
    var bool: @Sendable (String) -> Bool { get }

    /// Stores a Boolean value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The Boolean value to store.
    ///   - key: The key to associate the value with.
    var setBool: @Sendable (Bool, String) -> Void { get }

    // MARK: - Integer Values

    /// Retrieves an integer value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The integer value if present, or `0` if not found.
    var int: @Sendable (String) -> Int { get }

    /// Stores an integer value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The integer value to store.
    ///   - key: The key to associate the value with.
    var setInt: @Sendable (Int, String) -> Void { get }

    // MARK: - Double Values

    /// Retrieves a double value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The double value if present, or `0` if not found.
    var double: @Sendable (String) -> Double { get }

    /// Stores a double value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The double value to store.
    ///   - key: The key to associate the value with.
    var setDouble: @Sendable (Double, String) -> Void { get }

    // MARK: - String Values

    /// Retrieves a string value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The string value if present, or `nil` if not found.
    var string: @Sendable (String) -> String? { get }

    /// Stores a string value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The string value to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setString: @Sendable (String?, String) -> Void { get }

    // MARK: - String Array Values

    /// Retrieves an array of strings for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The string array if present, or `nil` if not found.
    var stringArray: @Sendable (String) -> [String]? { get }

    /// Stores an array of strings for the specified key.
    ///
    /// - Parameters:
    ///   - value: The string array to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setStringArray: @Sendable ([String]?, String) -> Void { get }

    // MARK: - Object Values

    /// Retrieves a raw object for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The object if present, or `nil` if not found.
    var object: @Sendable (String) -> Any? { get }

    /// Stores a raw object for the specified key.
    ///
    /// - Parameters:
    ///   - value: The object to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setObject: @Sendable (Any?, String) -> Void { get }

    // MARK: - Date Values

    /// Retrieves a `Date` value for the specified key.
    ///
    /// - Parameter key: The key associated with the desired value.
    /// - Returns: The `Date` value if present, or `nil` if not found.
    var date: @Sendable (String) -> Date? { get }

    /// Stores a `Date` value for the specified key.
    ///
    /// - Parameters:
    ///   - value: The `Date` value to store, or `nil` to remove it.
    ///   - key: The key to associate the value with.
    var setDate: @Sendable (Date?, String) -> Void { get }

    // MARK: - Deletion

    /// Removes the value associated with the specified key.
    ///
    /// - Parameter key: The key for which the value should be removed.
    var removeObject: @Sendable (String) -> Void { get }
}
