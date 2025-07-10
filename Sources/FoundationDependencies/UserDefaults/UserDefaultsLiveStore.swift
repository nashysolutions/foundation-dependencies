//
//  UserDefaultsLiveStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A live implementation of `UserDefaultsStoreProtocol` backed by Foundation's `UserDefaults`.
///
/// This store reads from and writes to a real `UserDefaults` suite identified by a suite name.
/// All operations are isolated to the main actor, which guarantees thread-safety despite
/// the fact that `UserDefaults` itself is not `Sendable`.
///
/// Although `UserDefaults` is a reference type and not marked `Sendable`, this implementation
/// is safe to use in `Sendable` contexts because **all closure properties are explicitly
/// isolated to the `@MainActor`**, ensuring serial access and avoiding data races.
///
/// Use this type in production environments where persistent app settings or preferences
/// need to be stored and retrieved.
///
/// - Note: The suite name can be used to access an app group or shared user defaults container.
public struct UserDefaultsLiveStore: UserDefaultsStoreProtocol {

    /// The suite name used to initialise the underlying `UserDefaults` instance.
    private let suiteName: String

    /// Creates a new `UserDefaultsLiveStore` with the specified suite name.
    ///
    /// - Parameter suiteName: The suite name to use when instantiating `UserDefaults`.
    ///                        Pass `nil` to use `.standard`.
    public init(suiteName: String) {
        self.suiteName = suiteName
    }

    /// A lazily-evaluated computed property for accessing the backing `UserDefaults` instance.
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Reading Values

    /// Retrieves a Boolean value for the specified key.
    public var bool: @MainActor (String) -> Bool {
        { key in
            userDefaults?.bool(forKey: key) ?? false
        }
    }

    /// Retrieves an integer value for the specified key.
    public var int: @MainActor (String) -> Int {
        { key in
            userDefaults?.integer(forKey: key) ?? 0
        }
    }

    /// Retrieves a double value for the specified key.
    public var double: @MainActor (String) -> Double {
        { key in
            userDefaults?.double(forKey: key) ?? 0
        }
    }

    /// Retrieves a string value for the specified key.
    public var string: @MainActor (String) -> String? {
        { key in
            userDefaults?.string(forKey: key)
        }
    }

    /// Retrieves an array of strings for the specified key.
    public var stringArray: @MainActor (String) -> [String]? {
        { key in
            userDefaults?.stringArray(forKey: key)
        }
    }

    /// Retrieves a raw object for the specified key.
    public var object: @MainActor (String) -> Any? {
        { key in
            userDefaults?.object(forKey: key)
        }
    }

    /// Retrieves a `Date` value for the specified key.
    public var date: @MainActor (String) -> Date? {
        { key in
            userDefaults?.object(forKey: key) as? Date
        }
    }

    /// Removes the value associated with the specified key.
    public var removeObject: @MainActor (String) -> Void {
        { key in
            userDefaults?.removeObject(forKey: key)
        }
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public var setBool: @MainActor (Bool, String) -> Void {
        { value, key in
            userDefaults?.set(value, forKey: key)
        }
    }

    /// Stores an integer value for the specified key.
    public var setInt: @MainActor (Int, String) -> Void {
        { value, key in
            userDefaults?.set(value, forKey: key)
        }
    }

    /// Stores a double value for the specified key.
    public var setDouble: @MainActor (Double, String) -> Void {
        { value, key in
            userDefaults?.set(value, forKey: key)
        }
    }

    /// Stores a string value for the specified key.
    public var setString: @MainActor (String?, String) -> Void {
        { value, key in
            userDefaults?.set(value, forKey: key)
        }
    }

    /// Stores an array of strings for the specified key.
    public var setStringArray: @MainActor ([String]?, String) -> Void {
        { value, key in
            userDefaults?.set(value, forKey: key)
        }
    }

    /// Stores a raw object for the specified key.
    public var setObject: @MainActor (Any?, String) -> Void {
        { value, key in
            userDefaults?.set(value, forKey: key)
        }
    }

    /// Stores a `Date` value for the specified key.
    public var setDate: @MainActor (Date?, String) -> Void {
        { value, key in
            userDefaults?.set(value, forKey: key)
        }
    }
}
