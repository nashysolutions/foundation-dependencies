//
//  UserDefaultsLiveStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// A live store backed by Foundation's `UserDefaults`.
///
/// Wrap one in a ``UserDefaultsClient`` to register it as a dependency:
///
/// ```swift
/// $0.userDefaultsClient = UserDefaultsClient(.standard)
/// ```
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
/// Every endpoint is synchronous and nonisolated, so a store can be read and written from any
/// concurrency domain: a background task, or a widget extension reaching an app group suite,
/// as readily as the main actor.
///
/// - Note: The `Sendable` conformance is unchecked because this store holds a `UserDefaults`
///   reference, and Foundation does not mark that class `Sendable`. Sharing it is safe
///   because Apple documents `UserDefaults` itself as thread-safe, so concurrent use of a
///   single instance is that class's own guarantee rather than something this type arranges.
///   The reference is the only state the store holds, and nothing here replaces it after
///   initialisation.
///
///   That one conformance is what lets ``UserDefaultsClient`` capture a whole store in the
///   `@Sendable` closures it is made of. The argument for safety is therefore made once,
///   here, rather than fifteen times at the closures. Capturing `userDefaults` directly
///   would not compile under complete concurrency checking, and the obvious way to make it
///   compile is a second escape hatch that carries no rationale.
public struct UserDefaultsLiveStore: UserDefaultsStore, @unchecked Sendable {

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

    /// Retrieves a Boolean value for the specified key, or `nil` if the key holds
    /// nothing.
    ///
    /// The presence check is a second lookup rather than something `bool(forKey:)`
    /// can report, because that endpoint answers `false` for a key that holds `false`
    /// and for a key that holds nothing alike. Both lookups search the same domain
    /// list, registered defaults included, so they agree about what is there.
    public func bool(forKey key: String) -> Bool? {
        guard contains(key: key) else {
            return nil
        }
        return userDefaults.bool(forKey: key)
    }

    /// Retrieves an integer value for the specified key, or `nil` if the key holds
    /// nothing.
    public func int(forKey key: String) -> Int? {
        guard contains(key: key) else {
            return nil
        }
        return userDefaults.integer(forKey: key)
    }

    /// Retrieves a double value for the specified key, or `nil` if the key holds
    /// nothing.
    public func double(forKey key: String) -> Double? {
        guard contains(key: key) else {
            return nil
        }
        return userDefaults.double(forKey: key)
    }

    /// Retrieves a string value for the specified key.
    public func string(forKey key: String) -> String? {
        userDefaults.string(forKey: key)
    }

    /// Retrieves an array of strings for the specified key.
    public func stringArray(forKey key: String) -> [String]? {
        userDefaults.stringArray(forKey: key)
    }

    /// Retrieves a `Date` value for the specified key.
    public func date(forKey key: String) -> Date? {
        userDefaults.object(forKey: key) as? Date
    }

    /// Retrieves a `Data` value for the specified key.
    public func data(forKey key: String) -> Data? {
        userDefaults.data(forKey: key)
    }

    /// Retrieves a `URL` value for the specified key.
    ///
    /// Reads the stored text and parses it. `UserDefaults.url(forKey:)` is
    /// deliberately not called; `StoredURL` records what it does instead and why this
    /// package does not want it.
    public func url(forKey key: String) -> URL? {
        string(forKey: key).flatMap(StoredURL.url(from:))
    }

    // MARK: - Presence

    /// Reports whether the specified key holds a value.
    ///
    /// The one reading that separates a key holding nothing from a key holding a
    /// value with no reading of the type asked for. A stored `Date` is `nil` through
    /// ``string(forKey:)`` and present through this.
    public func contains(key: String) -> Bool {
        userDefaults.object(forKey: key) != nil
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public func setBool(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// Stores an integer value for the specified key.
    public func setInt(_ value: Int, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// Stores a double value for the specified key.
    public func setDouble(_ value: Double, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// Stores a string value for the specified key, or removes it when `nil`.
    public func setString(_ value: String?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// Stores an array of strings for the specified key, or removes it when `nil`.
    public func setStringArray(_ value: [String]?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// Stores a `Date` value for the specified key, or removes it when `nil`.
    public func setDate(_ value: Date?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// Stores a `Data` value for the specified key, or removes it when `nil`.
    public func setData(_ value: Data?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// Stores a `URL` value for the specified key, or removes it when `nil`.
    ///
    /// Stored as text, so the value is legible in the `plist` and reads back through
    /// ``string(forKey:)`` as well. See `StoredURL` for why this is not
    /// `UserDefaults.set(_:forKey:)` with a URL.
    public func setURL(_ value: URL?, forKey key: String) {
        setString(value.map(StoredURL.text(for:)), forKey: key)
    }

    /// Stores a property list value for the specified key, or removes it when `nil`.
    public func setPropertyList(_ value: PropertyListValue?, forKey key: String) {
        userDefaults.set(value?.foundationValue, forKey: key)
    }

    // MARK: - Deletion

    /// Removes the value associated with the specified key.
    public func removeValue(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}
