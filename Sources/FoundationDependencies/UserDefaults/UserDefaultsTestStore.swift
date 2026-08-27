//
//  UserDefaultsTestStore.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 07/05/2025.
//

import Foundation

/// An in-memory store for use in tests.
///
/// Values live in a dictionary owned by the instance, so a test neither reads nor
/// writes a real `UserDefaults` suite and nothing survives the process. Create one
/// per test to get a clean store, and wrap it in a ``UserDefaultsClient`` to install
/// it:
///
/// ```swift
/// let store = UserDefaultsTestStore()
/// store.setBool(true, forKey: "hasOnboarded")
///
/// withDependencies {
///     $0.userDefaultsClient = UserDefaultsClient(store)
/// } operation: {
///     // The code under test reads `true` for that key.
/// }
/// ```
///
/// ## Fidelity to live `UserDefaults`
///
/// A test double is only worth having if a test that passes against it would also
/// pass against production. `UserDefaults` coerces between types on read rather
/// than returning a default whenever the stored type differs from the requested
/// one, so the typed readers here reproduce those coercions instead of casting the
/// stored value directly. Reading a stored `"42"` through ``int`` returns `42`, and
/// reading a stored `"YES"` through ``bool`` returns `true`, exactly as they would
/// in production.
///
/// The rules are not the obvious ones and they are not symmetrical between readers.
/// `LiveUserDefaultsSemantics` is their authoritative home: it states each rule
/// against a measured example, and the readers below point at it rather than
/// restating it. Every rule was measured against a real `UserDefaults` suite rather
/// than taken from the prose documentation, which describes the coercions only in
/// general terms.
///
/// Writes need no validation. Every setter takes a type `UserDefaults` can hold,
/// and the one that accepts a heterogeneous value takes a ``PropertyListValue``,
/// which has no case for anything else. An earlier `setObject` took `Any?` and had
/// to check its argument against `PropertyListSerialization` and trap, reproducing
/// the `NSInvalidArgumentException` live `UserDefaults` raises; the check went when
/// the type made the input unrepresentable.
///
/// There is no longer a divergence to know about. The endpoint that had one was
/// `object`, which returned the value as written here and the Foundation counterpart
/// production had normalised it into, so a stored `1` was an `Int` here and an
/// `NSNumber` there. It is retired: ``contains(key:)`` answers the only question it
/// was reliably good for, and the typed readers answer the rest.
///
/// ## Thread safety
///
/// The `Sendable` conformance is `@unchecked` because `storage` is mutable state on
/// a class, which the compiler cannot prove is free of races on its own. What makes
/// it safe is that `storage` is `private`, that the only two things which touch it
/// are ``value(forKey:)`` and ``write(_:forKey:)`` at the foot of the type, and that
/// both hold `lock` for the whole of their access. Every endpoint goes through one
/// of those two, so no endpoint can read the dictionary while another is writing it.
///
/// The endpoints are synchronous and nonisolated, matching the rest of this package,
/// and ``UserDefaultsClient`` captures a whole store in the `@Sendable` closures it is
/// made of, so a store genuinely can be called from two domains at once and the lock is
/// not ceremony. It replaced an earlier arrangement that made every endpoint
/// `@MainActor` and leaned on that for serialisation, which cost every caller off the
/// main actor a hop and made the double harder to use than the thing it doubles.
///
/// The rule the conformance rests on is that nothing else reaches `storage` directly.
/// Add an endpoint that does and the guarantee is gone, with no compiler diagnostic
/// pointing back at this conformance; call one of the two accessors instead and there
/// is nothing to remember.
public final class UserDefaultsTestStore: UserDefaultsStore, @unchecked Sendable {

    /// The backing store.
    ///
    /// Holds each value exactly as it was written, without the normalisation into
    /// Foundation types that live `UserDefaults` performs on the way in, so a value
    /// written through ``setInt(_:forKey:)`` is still a Swift `Int` in here. That is
    /// invisible from outside now that no endpoint returns the stored value itself:
    /// the coercions in `LiveUserDefaultsSemantics` read a Swift `Int` and the
    /// `NSNumber` production holds identically, and every reader goes through them.
    ///
    /// Only ever read through ``value(forKey:)`` and written through
    /// ``write(_:forKey:)``, both of which hold ``lock``. See the thread safety note.
    private var storage: [String: Any] = [:]

    /// Guards ``storage``.
    ///
    /// `NSLock` rather than an actor because every endpoint here is synchronous and
    /// returns its value to the caller. An actor would make each one `async`, which
    /// ``UserDefaultsClient`` does not allow, and which live `UserDefaults` does not
    /// require of a caller either.
    private let lock = NSLock()

    /// Creates an empty store.
    public init() {}

    // MARK: - Reading Values

    /// Retrieves a Boolean value for the specified key, or `nil` if the key holds
    /// nothing.
    ///
    /// Coerces a stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.boolean(from:)` for the rules.
    public func bool(forKey key: String) -> Bool? {
        value(forKey: key).map(LiveUserDefaultsSemantics.boolean(from:))
    }

    /// Retrieves an integer value for the specified key, or `nil` if the key holds
    /// nothing.
    ///
    /// Coerces a stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.integer(from:)` for the rules.
    public func int(forKey key: String) -> Int? {
        value(forKey: key).map(LiveUserDefaultsSemantics.integer(from:))
    }

    /// Retrieves a double value for the specified key, or `nil` if the key holds
    /// nothing.
    ///
    /// Coerces a stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.double(from:)` for the rules.
    public func double(forKey key: String) -> Double? {
        value(forKey: key).map(LiveUserDefaultsSemantics.double(from:))
    }

    /// Retrieves a string value for the specified key.
    ///
    /// Coerces a stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.string(from:)` for the rules.
    public func string(forKey key: String) -> String? {
        value(forKey: key).flatMap(LiveUserDefaultsSemantics.string(from:))
    }

    /// Retrieves an array of strings for the specified key.
    ///
    /// Coerces a stored value as live `UserDefaults` does. See
    /// `LiveUserDefaultsSemantics.stringArray(from:)` for the rules.
    public func stringArray(forKey key: String) -> [String]? {
        value(forKey: key).flatMap(LiveUserDefaultsSemantics.stringArray(from:))
    }

    /// Retrieves a `Date` value for the specified key.
    ///
    /// Returns `nil` when the stored value is anything other than a date. A number
    /// is not interpreted as a time interval, matching production.
    public func date(forKey key: String) -> Date? {
        value(forKey: key) as? Date
    }

    /// Retrieves a `Data` value for the specified key.
    ///
    /// Returns `nil` when the stored value is anything other than data. A string is
    /// not decoded into its bytes, matching production.
    public func data(forKey key: String) -> Data? {
        value(forKey: key) as? Data
    }

    /// Retrieves a `URL` value for the specified key.
    ///
    /// Reads this store's own text and parses it by the same rule the live store
    /// uses, so the two agree for the same reason ``string(forKey:)`` does. See
    /// `StoredURL`.
    public func url(forKey key: String) -> URL? {
        string(forKey: key).flatMap(StoredURL.url(from:))
    }

    // MARK: - Presence

    /// Reports whether the specified key holds a value.
    public func contains(key: String) -> Bool {
        value(forKey: key) != nil
    }

    // MARK: - Writing Values

    /// Stores a Boolean value for the specified key.
    public func setBool(_ value: Bool, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores an integer value for the specified key.
    public func setInt(_ value: Int, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a double value for the specified key.
    public func setDouble(_ value: Double, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a string value for the specified key, or removes the key when `value`
    /// is `nil`.
    public func setString(_ value: String?, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores an array of strings for the specified key, or removes the key when
    /// `value` is `nil`.
    public func setStringArray(_ value: [String]?, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a `Date` value for the specified key, or removes the key when `value`
    /// is `nil`.
    public func setDate(_ value: Date?, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a `Data` value for the specified key, or removes the key when `value`
    /// is `nil`.
    public func setData(_ value: Data?, forKey key: String) {
        write(value, forKey: key)
    }

    /// Stores a `URL` value for the specified key, or removes the key when `value`
    /// is `nil`.
    ///
    /// Stored as text, exactly as the live store stores it. See `StoredURL`.
    public func setURL(_ value: URL?, forKey key: String) {
        setString(value.map(StoredURL.text(for:)), forKey: key)
    }

    /// Stores a property list value for the specified key, or removes the key when
    /// `value` is `nil`.
    ///
    /// The value is converted to its Foundation shape on the way in, so a nested
    /// array or dictionary is held as the array or dictionary the live store would
    /// hold rather than as a ``PropertyListValue``, and the coercions above read it
    /// the same way in both stores.
    public func setPropertyList(_ value: PropertyListValue?, forKey key: String) {
        write(value?.foundationValue, forKey: key)
    }

    // MARK: - Deletion

    /// Removes the value associated with the specified key.
    public func removeValue(forKey key: String) {
        write(nil, forKey: key)
    }

    // MARK: - Storage

    /// Returns the value stored under `key`, or `nil` when there is none.
    ///
    /// One of the two places `storage` is touched. The lock is given back before the
    /// readers do anything with the result, because neither the coercions nor the
    /// `as? Date` cast needs the dictionary.
    private func value(forKey key: String) -> Any? {
        lock.withLock { storage[key] }
    }

    /// Stores `value` under `key`, removing the key when `value` is `nil`.
    ///
    /// Live `UserDefaults` treats a `nil` write as a removal rather than storing an
    /// empty placeholder, so afterwards both stores agree that the key is absent. The
    /// setters that cannot receive `nil` call this too rather than assigning to
    /// `storage` themselves, which is what keeps the count of places that touch the
    /// dictionary at two.
    private func write(_ value: Any?, forKey key: String) {
        lock.withLock {
            // Assigning `nil` through a dictionary subscript removes the key rather
            // than storing an empty box, which is the behaviour described above.
            storage[key] = value
        }
    }
}
