//
//  UserDefaultsLiveStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A live implementation of `UserDefaultsStoreProtocol` backed by Foundation's `UserDefaults`.
///
/// There are two ways to create one:
///
/// - ``standard`` reads and writes the app's own defaults, the same domains
///   `UserDefaults.standard` searches. Use it whenever the values are not shared with
///   another process.
/// - ``init(suiteName:)`` reads and writes a named suite, typically an app group container
///   shared with an app extension or a sibling app.
///
/// The backing `UserDefaults` instance is resolved once, when the store is created, and held
/// for the lifetime of the store. A suite name Foundation refuses fails the initialiser, so
/// the mistake surfaces where the store is composed rather than as empty reads and dropped
/// writes everywhere the store is later used.
///
/// Use this type in production environments where persistent app settings or preferences need
/// to be stored and retrieved.
///
/// - Note: The `Sendable` conformance is unchecked because `UserDefaults` is a class that
///   Foundation does not mark `Sendable`. Two things make it safe here. Apple documents
///   `UserDefaults` itself as thread-safe, and every endpoint on this store is isolated to the
///   main actor, so calls through this type reach the backing instance one at a time in any
///   case.
public struct UserDefaultsLiveStore: UserDefaultsStoreProtocol, @unchecked Sendable {

    /// The backing instance, resolved once when this store is created.
    private let userDefaults: UserDefaults

    /// A store backed by the app's own defaults.
    ///
    /// This is the equivalent of `UserDefaults.standard`, and is the only way to reach those
    /// domains through this type. No suite name reaches them: `UserDefaults(suiteName:)`
    /// rejects the app's own bundle identifier outright.
    public static let standard = UserDefaultsLiveStore(userDefaults: .standard)

    /// Creates a store backed by the named suite, or returns `nil` when Foundation refuses
    /// the name.
    ///
    /// Foundation refuses two names: the current process's own bundle identifier, and
    /// `NSGlobalDomain`. Neither can be recovered from here, so the initialiser fails instead
    /// of producing a store whose every read is empty and every write is discarded.
    ///
    /// - Parameter suiteName: The name of the suite to read and write, typically an app group
    ///                        identifier such as `group.com.example.myapp`.
    ///
    /// - Important: A name Foundation accepts is not necessarily the container you meant. A
    ///              mistyped app group identifier, or one the app has no entitlement for,
    ///              still produces a working store, but it is backed by a private domain
    ///              rather than the shared container. Nothing at this layer can tell the two
    ///              apart, so check the spelling against the app's App Groups entitlement.
    public init?(suiteName: String) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        self.userDefaults = userDefaults
    }

    private init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    // MARK: - Reading Values

    /// Retrieves a Boolean value for the specified key.
    public var bool: @MainActor (String) -> Bool {
        { [userDefaults] key in
            userDefaults.bool(forKey: key)
        }
    }

    /// Retrieves an integer value for the specified key.
    public var int: @MainActor (String) -> Int {
        { [userDefaults] key in
            userDefaults.integer(forKey: key)
        }
    }

    /// Retrieves a double value for the specified key.
    public var double: @MainActor (String) -> Double {
        { [userDefaults] key in
            userDefaults.double(forKey: key)
        }
    }

    /// Retrieves a string value for the specified key.
    public var string: @MainActor (String) -> String? {
        { [userDefaults] key in
            userDefaults.string(forKey: key)
        }
    }

    /// Retrieves an array of strings for the specified key.
    public var stringArray: @MainActor (String) -> [String]? {
        { [userDefaults] key in
            userDefaults.stringArray(forKey: key)
        }
    }

    /// Retrieves a raw object for the specified key.
    public var object: @MainActor (String) -> Any? {
        { [userDefaults] key in
            userDefaults.object(forKey: key)
        }
    }

    /// Retrieves a `Date` value for the specified key.
    public var date: @MainActor (String) -> Date? {
        { [userDefaults] key in
            userDefaults.object(forKey: key) as? Date
        }
    }

    /// Removes the value associated with the specified key.
    public var removeObject: @MainActor (String) -> Void {
        { [userDefaults] key in
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public var setBool: @MainActor (Bool, String) -> Void {
        { [userDefaults] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores an integer value for the specified key.
    public var setInt: @MainActor (Int, String) -> Void {
        { [userDefaults] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a double value for the specified key.
    public var setDouble: @MainActor (Double, String) -> Void {
        { [userDefaults] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a string value for the specified key.
    public var setString: @MainActor (String?, String) -> Void {
        { [userDefaults] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores an array of strings for the specified key.
    public var setStringArray: @MainActor ([String]?, String) -> Void {
        { [userDefaults] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a raw object for the specified key.
    public var setObject: @MainActor (Any?, String) -> Void {
        { [userDefaults] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a `Date` value for the specified key.
    public var setDate: @MainActor (Date?, String) -> Void {
        { [userDefaults] value, key in
            userDefaults.set(value, forKey: key)
        }
    }
}
