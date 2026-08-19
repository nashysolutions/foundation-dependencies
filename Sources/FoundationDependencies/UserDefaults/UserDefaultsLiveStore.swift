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
/// Every endpoint is a nonisolated `@Sendable` closure, so a store can be read and written
/// from any concurrency domain: a background task, or a widget extension reaching an app
/// group suite, as readily as the main actor.
///
/// - Note: The `Sendable` conformance is unchecked because this store holds a `UserDefaults`
///   reference, and Foundation does not mark that class `Sendable`. Sharing it is safe
///   because Apple documents `UserDefaults` itself as thread-safe, so concurrent use of a
///   single instance is that class's own guarantee rather than something this type arranges.
///   The reference is the only state the store holds, and nothing here replaces it after
///   initialisation.
///
///   Each endpoint below captures the store rather than the `UserDefaults` reference
///   directly, which is why a `@Sendable` closure is allowed to hold it at all. That routes
///   the whole type through the one unchecked conformance above, so the argument for safety
///   is made once, here, instead of fifteen times with nothing written down. Capturing
///   `userDefaults` on its own would not compile under complete concurrency checking, and
///   the obvious way to make it compile is a second escape hatch that carries no rationale.
public struct UserDefaultsLiveStore: UserDefaultsStoreProtocol, @unchecked Sendable {

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
    public var bool: @Sendable (String) -> Bool {
        { [self] key in
            userDefaults.bool(forKey: key)
        }
    }

    /// Retrieves an integer value for the specified key.
    public var int: @Sendable (String) -> Int {
        { [self] key in
            userDefaults.integer(forKey: key)
        }
    }

    /// Retrieves a double value for the specified key.
    public var double: @Sendable (String) -> Double {
        { [self] key in
            userDefaults.double(forKey: key)
        }
    }

    /// Retrieves a string value for the specified key.
    public var string: @Sendable (String) -> String? {
        { [self] key in
            userDefaults.string(forKey: key)
        }
    }

    /// Retrieves an array of strings for the specified key.
    public var stringArray: @Sendable (String) -> [String]? {
        { [self] key in
            userDefaults.stringArray(forKey: key)
        }
    }

    /// Retrieves a raw object for the specified key.
    public var object: @Sendable (String) -> Any? {
        { [self] key in
            userDefaults.object(forKey: key)
        }
    }

    /// Retrieves a `Date` value for the specified key.
    public var date: @Sendable (String) -> Date? {
        { [self] key in
            userDefaults.object(forKey: key) as? Date
        }
    }

    /// Removes the value associated with the specified key.
    public var removeObject: @Sendable (String) -> Void {
        { [self] key in
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public var setBool: @Sendable (Bool, String) -> Void {
        { [self] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores an integer value for the specified key.
    public var setInt: @Sendable (Int, String) -> Void {
        { [self] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a double value for the specified key.
    public var setDouble: @Sendable (Double, String) -> Void {
        { [self] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a string value for the specified key.
    public var setString: @Sendable (String?, String) -> Void {
        { [self] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores an array of strings for the specified key.
    public var setStringArray: @Sendable ([String]?, String) -> Void {
        { [self] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a raw object for the specified key.
    public var setObject: @Sendable (Any?, String) -> Void {
        { [self] value, key in
            userDefaults.set(value, forKey: key)
        }
    }

    /// Stores a `Date` value for the specified key.
    public var setDate: @Sendable (Date?, String) -> Void {
        { [self] value, key in
            userDefaults.set(value, forKey: key)
        }
    }
}
